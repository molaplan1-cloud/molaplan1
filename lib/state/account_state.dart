import '../account/merge3.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../account/supabase_api.dart';
import '../account/vault.dart';
import '../remote/e2e.dart' show b64, unb64, sha256Hex;
import 'stores.dart';

/// What the account needs from the app (implemented by AppState).
abstract class SyncHost {
  /// Homes, devices, tiles and layout – without secrets or device-local settings.
  Map<String, dynamic> syncConfig();

  /// Device passwords / tokens / cloud keys per connection id.
  Map<String, Map<String, String>> syncSecrets();

  /// Replaces the synced part of the local setup. [secrets] is null while the vault is locked.
  Future<void> applySynced(Map<String, dynamic> config, Map<String, Map<String, String>>? secrets);

  /// Uploads/downloads files referenced by the config (tile background images). Best effort.
  Future<void> syncFiles(AccountApi api, Session s);

  /// Adds the account's homes/devices to this device's own (first sign-in, "merge both").
  Future<void> mergeSynced(Map<String, dynamic> config, Map<String, Map<String, String>>? secrets);

  bool get hasLocalSetup;

  /// This device's home (relay) connection credential, if paired.
  Map<String, dynamic>? homeCredential();

  /// Connects this device to the account's home (no QR). Returns true on success.
  Future<bool> adoptHome(Map<String, dynamic> grant);

  /// If this device is the home bridge: a credential for the account's devices.
  Future<Map<String, dynamic>?> makeHomeGrant();

  String deviceName();

  /// t224u: if this device is a home bridge, its entry for the account's 'Omat kotisillat' list:
  /// {home, name, platform, app, deviceOwner, grant} (grant = a client credential made once by
  /// this bridge for the account). Null when this device is not a bridge.
  Future<Map<String, dynamic>?> bridgeEntry();
}

enum SyncStatus { off, syncing, ok, offline, error }

/// The first sign-in on a device that already has its own setup.
enum FirstSyncChoice { uploadLocal, useAccount, merge }

class PendingFirstSync {
  PendingFirstSync({required this.localHas, required this.remoteHas, required this.row});
  final bool localHas;
  final bool remoteHas;
  final SyncRow? row;
}

/// Molaplan account: sign-in, sync of the setup between the user's devices (PC, tablet,
/// phone) and the end-to-end encrypted vault for secrets and the home connection.
class AccountState extends ChangeNotifier {
  AccountState({required this.store, required this.host, AccountApi? api, this.kdfIterations = defaultIterations})
    : api = api ?? AccountApi();

  final SecretStore store;
  final SyncHost host;
  final AccountApi api;
  final int kdfIterations;

  static const storageKey = 'molaplan.account.v1';
  static String keyStorage(String uid) => 'molaplan.account.key.$uid';

  /// Off by default (tests); main() turns on background sync.
  bool autoSync = false;
  static const pollEvery = Duration(seconds: 60);
  static const pushDelay = Duration(seconds: 2);

  Session? session;
  List<int>? _key;
  int? lastRev;
  String? lastHash;
  int? localChangedAt;

  SyncStatus status = SyncStatus.off;
  Object? lastError;
  DateTime? lastSync;

  /// The account has saved passwords that this device cannot open yet (signed in with a code).
  bool needsUnlock = false;

  /// Set after sign-in when this device and/or the account already have a setup.
  PendingFirstSync? pendingFirstSync;

  /// R266: cancelling the first-sync choice signs out but must keep this browser's
  /// guest setup (the web gate wipes on a normal sign-out).
  bool preserveLocalOnSignOut = false;

  Timer? _poll;
  Timer? _push;
  Future<void>? _running;
  bool _again = false;

  bool get signedIn => session != null;
  String? get email => session?.email;
  bool get hasKey => _key != null;

  /// R215: the account key (only on the user's own devices) – sharing derives its key from it.
  List<int>? get accountKey => _key;

  /// A valid session (refreshed when needed), for features that call the account service.
  Future<Session> freshSession() => _fresh();

  // ---------------------------------------------------------------- persistence

  Future<void> load() async {
    try {
      final raw = await store.read(storageKey);
      if (raw == null) return;
      final j = Map<String, dynamic>.from(jsonDecode(raw) as Map);
      session = Session.fromJson(Map<String, dynamic>.from(j['session'] as Map));
      lastRev = (j['rev'] as num?)?.toInt();
      lastHash = j['hash'] as String?;
      localChangedAt = (j['changed'] as num?)?.toInt();
      needsUnlock = j['locked'] == true;
      final k = await store.read(keyStorage(session!.userId));
      _key = k == null ? null : unb64(k);
      status = SyncStatus.ok;
    } catch (e) {
      debugPrint('account load failed: $e');
      session = null;
    }
    if (signedIn) _startTimers();
    notifyListeners();
  }

  /// t246u: the synced config + secrets as this device last saw them in the account (for the
  /// three-way merge). Kept in the secure store (it holds secrets).
  static const baseKey = 'molaplan.account.base.v1';

  Future<void> _saveBase() async {
    try {
      await store.write(baseKey, jsonEncode({'c': host.syncConfig(), 's': host.syncSecrets()}));
    } catch (_) {}
  }

  Future<Map<String, dynamic>?> _readBase() async {
    try {
      final raw = await store.read(baseKey);
      return raw == null ? null : Map<String, dynamic>.from(jsonDecode(raw) as Map);
    } catch (_) {
      return null;
    }
  }

  Future<void> _persist() async {
    final s = session;
    if (s == null) return store.delete(storageKey);
    await store.write(
      storageKey,
      jsonEncode({
        'session': s.toJson(),
        'rev': ?lastRev,
        'hash': ?lastHash,
        'changed': ?localChangedAt,
        if (needsUnlock) 'locked': true,
      }),
    );
  }

  void _startTimers() {
    _poll?.cancel();
    if (!autoSync) return;
    _poll = Timer.periodic(pollEvery, (_) => unawaited(syncNow(quiet: true)));
  }

  void _set(SyncStatus s, [Object? err]) {
    status = s;
    lastError = err;
    notifyListeners();
  }

  // ---------------------------------------------------------------- sign in / up

  /// Creates an account. Returns true when signed in right away, false when the emailed
  /// confirmation code is needed ([confirmSignUp]).
  Future<bool> signUp(String email, String password) async {
    final s = await api.signUp(email.trim(), password);
    if (s == null) {
      _pendingPassword = password;
      return false;
    }
    await _afterSignIn(s, password: password);
    return true;
  }

  String? _pendingPassword;

  Future<void> confirmSignUp(String email, String code) async {
    final s = await api.verifyCode(email.trim(), code, type: 'signup');
    await _afterSignIn(s, password: _pendingPassword);
    _pendingPassword = null;
  }

  Future<void> signIn(String email, String password) async {
    final s = await api.signIn(email.trim(), password);
    await _afterSignIn(s, password: password);
  }

  Future<void> sendCode(String email, {bool create = false}) => api.sendCode(email.trim(), create: create);

  Future<void> signInWithCode(String email, String code) async {
    final s = await api.verifyCode(email.trim(), code);
    await _afterSignIn(s);
  }

  Future<void> sendRecovery(String email) => api.sendRecovery(email.trim());

  /// "Unohdin salasanan": code from the email + a new password.
  /// If this device does not hold the account key, the saved device passwords cannot be
  /// recovered: a new vault is made from what this device has ([resetVault]).
  Future<void> recoverWithCode(String email, String code, String newPassword) async {
    final s = await api.verifyCode(email.trim(), code, type: 'recovery');
    await api.setPassword(s, newPassword);
    await _afterSignIn(s, password: newPassword, resetIfLocked: true);
  }

  Future<void> _afterSignIn(Session s, {String? password, bool resetIfLocked = false}) async {
    final changedUser = session?.userId != s.userId;
    session = s;
    if (changedUser) {
      lastRev = null;
      lastHash = null;
    }
    final k = await store.read(keyStorage(s.userId));
    _key = k == null ? null : unb64(k);
    final row = await api.fetch(s);
    Map<String, dynamic>? keyWrap;
    if (row?.keyWrap != null) {
      if (_key == null && password != null) {
        try {
          _key = await unwrapAccountKey(row!.keyWrap!, password, s.userId);
        } on WrongVaultPassword {
          if (resetIfLocked) {
            _key = newAccountKey();
            keyWrap = await wrapAccountKey(_key!, password, s.userId, iter: kdfIterations);
          }
        }
      } else if (_key != null && password != null && resetIfLocked) {
        keyWrap = await wrapAccountKey(_key!, password, s.userId, iter: kdfIterations); // new password, same key
      }
    } else if (password != null) {
      _key ??= newAccountKey();
      keyWrap = await wrapAccountKey(_key!, password, s.userId, iter: kdfIterations);
    }
    if (_key != null) await store.write(keyStorage(s.userId), b64(_key!));
    needsUnlock = row?.vault != null && _key == null;
    _pendingWrap = keyWrap;
    await _persist();
    _startTimers();

    final remoteHas = row != null && _hasSetup(row.config);
    final localHas = host.hasLocalSetup;
    if (row == null || (!remoteHas && localHas && lastRev == null)) {
      // New or empty account: this device's setup moves into it (nothing to choose).
      await _upload(row);
    } else if (localHas && lastRev == null) {
      pendingFirstSync = PendingFirstSync(localHas: true, remoteHas: true, row: row);
    } else {
      await _adopt(row);
    }
    if (_pendingWrap != null && pendingFirstSync == null) await syncNow();
    notifyListeners();
  }

  Map<String, dynamic>? _pendingWrap;

  static bool _hasSetup(Map<String, dynamic> c) =>
      ((c['connections'] as List?) ?? const []).isNotEmpty ||
      ((c['dashboards'] as List?) ?? const []).any((d) => ((d as Map)['tiles'] as List? ?? const []).isNotEmpty);

  /// The user's answer to [pendingFirstSync]. [null] = keep this device out of sync (signs out).
  Future<void> resolveFirstSync(FirstSyncChoice? choice) async {
    final p = pendingFirstSync;
    pendingFirstSync = null;
    if (p == null) return;
    if (choice == null) return signOut(keepLocal: true);
    switch (choice) {
      case FirstSyncChoice.uploadLocal:
        if (p.row != null) await _adoptHome(p.row!);
        await _upload(p.row);
      case FirstSyncChoice.useAccount:
        await _adopt(p.row!);
      case FirstSyncChoice.merge:
        await _adoptHome(p.row!);
        final secrets = await _vaultSecrets(p.row!);
        await host.mergeSynced(p.row!.config, secrets);
        await _upload(p.row);
    }
    notifyListeners();
  }

  // ---------------------------------------------------------------- unlock / password

  /// Opens the saved device passwords on this device (after a code sign-in).
  Future<void> unlock(String password) async {
    final s = session!;
    final row = await api.fetch(s);
    if (row?.keyWrap == null) {
      needsUnlock = false;
      await _persist();
      notifyListeners();
      return;
    }
    _key = await unwrapAccountKey(row!.keyWrap!, password, s.userId);
    await store.write(keyStorage(s.userId), b64(_key!));
    needsUnlock = false;
    await _adopt(row);
    await _persist();
    notifyListeners();
  }

  /// Starts over with the passwords on this device (the old vault cannot be opened).
  Future<void> resetVault(String password) async {
    final s = session!;
    _key = newAccountKey();
    await store.write(keyStorage(s.userId), b64(_key!));
    _pendingWrap = await wrapAccountKey(_key!, password, s.userId, iter: kdfIterations);
    needsUnlock = false;
    lastHash = null;
    await syncNow();
  }

  Future<void> changePassword(String newPassword) async {
    final s = await _fresh();
    await api.setPassword(s, newPassword);
    // Account made with an email code only: the first password starts the encrypted vault.
    if (_key == null && !needsUnlock) {
      _key = newAccountKey();
      await store.write(keyStorage(s.userId), b64(_key!));
    }
    if (_key != null) {
      _pendingWrap = await wrapAccountKey(_key!, newPassword, s.userId, iter: kdfIterations);
      lastHash = null;
      await syncNow();
    }
  }

  // ---------------------------------------------------------------- sign out / delete

  Future<void> signOut({bool keepLocal = false}) async {
    preserveLocalOnSignOut = keepLocal;
    final s = session;
    _poll?.cancel();
    _push?.cancel();
    session = null;
    pendingFirstSync = null;
    needsUnlock = false;
    lastRev = null;
    lastHash = null;
    if (s != null) {
      await store.delete(keyStorage(s.userId));
      unawaited(api.signOut(s));
    }
    _key = null;
    await _persist();
    _set(SyncStatus.off);
  }

  /// GDPR: removes the account and all synced data from the server. This device keeps its
  /// own setup (local mode).
  Future<void> deleteAccount() async {
    final s = await _fresh();
    // Storage is not removed with the user row: delete this account's tile pictures first.
    try {
      await api.deleteImages(s, await api.listImages(s));
    } catch (_) {}
    await api.deleteAccount(s);
    await signOut();
  }

  // ---------------------------------------------------------------- sync

  /// This device was paired with a (different) home by QR/code: the account gets that home.
  void homeChanged(Map<String, dynamic> credential) {
    if (_vaultHome != null && _vaultHome!['home'] == credential['home']) return;
    _vaultHome = credential;
    localChanged();
  }

  /// Called by the app after every local save.
  void localChanged() {
    if (!signedIn || pendingFirstSync != null) return;
    localChangedAt = DateTime.now().millisecondsSinceEpoch;
    _push?.cancel();
    if (autoSync) _push = Timer(pushDelay, () => unawaited(syncNow(quiet: true)));
  }

  Future<Session> _fresh() async {
    var s = session;
    if (s == null) throw AccountError(AccountProblem.sessionExpired);
    if (s.expiresSoon) {
      try {
        s = await api.refresh(s.refresh);
      } on AccountError catch (e) {
        if (e.problem == AccountProblem.sessionExpired || e.problem == AccountProblem.server) {
          // Refresh token gone (signed out elsewhere / account deleted): back to local mode.
          await signOut();
          lastError = e;
        }
        rethrow;
      }
      session = s;
      await _persist();
    }
    return s;
  }

  /// Pulls changes from the account and pushes this device's changes. Serialized.
  Future<void> syncNow({bool quiet = false}) async {
    if (!signedIn || pendingFirstSync != null) return;
    if (_running != null) {
      _again = true;
      return _running;
    }
    final f = _sync(quiet);
    _running = f;
    try {
      await f;
    } finally {
      _running = null;
    }
    if (_again) {
      _again = false;
      await syncNow(quiet: quiet);
    }
  }

  Future<void> _sync(bool quiet) async {
    if (!quiet) _set(SyncStatus.syncing);
    try {
      for (var attempt = 0; attempt < 3; attempt++) {
        final s = await _fresh();
        final hash = await _localHash();
        final dirty = hash != lastHash || _pendingWrap != null || _ownBridgeStale;
        final rev = await api.remoteRev(s);
        if (rev == null) {
          await _upload(null);
          break;
        }
        if (rev != lastRev) {
          final row = (await api.fetch(s))!;
          final localNewer =
              dirty && lastRev != null && (localChangedAt ?? 0) > (row.updatedAt?.millisecondsSinceEpoch ?? 0);
          if (!localNewer) {
            await _adopt(row);
            if (_pendingWrap == null && !_ownBridgeStale) break;
            continue;
          }
          // t246u: never upload this device's whole config over newer account changes – only
          // what changed here since the last sync goes on top of the account's version.
          if (!await _mergeInto(row)) {
            await _adopt(row); // no base known (first sync after the update): the account wins
            if (_pendingWrap == null && !_ownBridgeStale) break;
            continue;
          }
          try {
            await _push2(s, row.rev);
            break;
          } on AccountError catch (e) {
            if (e.problem != AccountProblem.conflict) rethrow;
            continue;
          }
        }
        if (!dirty) break;
        try {
          await _push2(s, lastRev);
          break;
        } on AccountError catch (e) {
          if (e.problem != AccountProblem.conflict) rethrow;
        }
      }
      await _maybeShareHome();
      try {
        await host.syncFiles(api, await _fresh());
      } catch (_) {
        // images are optional; the config itself is in sync
      }
      lastSync = DateTime.now();
      _set(SyncStatus.ok);
    } on AccountError catch (e) {
      _set(e.problem == AccountProblem.offline ? SyncStatus.offline : SyncStatus.error, e);
      if (!quiet) rethrow;
    } catch (e) {
      _set(SyncStatus.error, e);
      if (!quiet) rethrow;
    }
  }

  Map<String, dynamic>? _vaultHome;
  Map<String, dynamic>? get vaultHome => _vaultHome;

  /// t224u: every home bridge registered to the account (end-to-end encrypted in the vault),
  /// keyed by home id. Each bridge adds / refreshes its own entry.
  final Map<String, Map<String, dynamic>> vaultBridges = {};
  bool _ownBridgeStale = false;

  /// The account's bridges for the UI, sorted by name.
  List<Map<String, dynamic>> get accountBridges =>
      vaultBridges.values.toList()..sort((a, b) => '${a['name']}'.compareTo('${b['name']}'));

  Future<Map<String, Map<String, dynamic>>> _bridgesForVault() async {
    final out = {for (final e in vaultBridges.entries) e.key: e.value};
    Map<String, dynamic>? own;
    try {
      own = await host.bridgeEntry();
    } catch (e) {
      debugPrint('bridge entry: $e');
    }
    if (own != null && own['home'] is String) out[own['home'] as String] = own;
    return out;
  }

  Future<Map<String, dynamic>> _vaultData() async {
    final bridges = await _bridgesForVault();
    return {
      'secrets': host.syncSecrets(),
      'home': ?(_vaultHome ?? host.homeCredential()),
      'bridges': ?(bridges.isEmpty ? null : bridges),
    };
  }

  void _readBridges(Map<String, dynamic>? v) {
    final b = v?['bridges'];
    if (b is! Map) return;
    vaultBridges
      ..clear()
      ..addAll({
        for (final e in b.entries)
          if (e.value is Map) '${e.key}': Map<String, dynamic>.from(e.value as Map),
      });
  }

  Future<void> _checkOwnBridge() async {
    Map<String, dynamic>? own;
    try {
      own = await host.bridgeEntry();
    } catch (_) {}
    if (own == null) return;
    final have = vaultBridges[own['home']];
    if (have == null || jsonEncode(have) != jsonEncode(own)) _ownBridgeStale = true;
  }

  Future<String> _localHash() async => sha256Hex(jsonEncode({'c': host.syncConfig(), 'v': await _vaultData()}));

  Future<void> _upload(SyncRow? row) async {
    final s = await _fresh();
    await _push2(s, row?.rev);
    await _maybeShareHome();
    lastSync = DateTime.now();
    status = SyncStatus.ok;
  }

  Future<void> _push2(Session s, int? baseRev) async {
    final hash = await _localHash();
    final data = _key == null ? null : await _vaultData();
    final vault = data == null ? null : await sealVault(_key!, data, s.userId);
    final row = await api.put(
      s,
      baseRev: baseRev,
      config: host.syncConfig(),
      keyWrap: _pendingWrap,
      vault: vault,
      device: host.deviceName(),
    );
    _pendingWrap = null;
    if (data != null) {
      _ownBridgeStale = false;
      _readBridges(data);
    }
    lastRev = row.rev;
    lastHash = hash;
    await _persist();
    await _saveBase();
  }

  Future<Map<String, Map<String, String>>?> _vaultSecrets(SyncRow row) async {
    final v = await _openVault(row);
    if (v == null) return null;
    return {
      for (final e in ((v['secrets'] as Map?) ?? const {}).entries)
        '${e.key}': {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'},
    };
  }

  Future<Map<String, dynamic>?> _openVault(SyncRow row) async {
    if (row.vault == null) return null;
    if (_key == null) {
      needsUnlock = true;
      return null;
    }
    try {
      return await openVault(_key!, row.vault!, session!.userId);
    } on WrongVaultPassword {
      // The vault was reset on another device: this device's key is stale.
      needsUnlock = true;
      await store.delete(keyStorage(session!.userId));
      _key = null;
      return null;
    }
  }

  /// Applies the account's setup on this device.
  Future<void> _adopt(SyncRow row) async {
    final v = await _openVault(row);
    final secrets = v == null
        ? null
        : {
            for (final e in ((v['secrets'] as Map?) ?? const {}).entries)
              '${e.key}': {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'},
          };
    await host.applySynced(row.config, secrets);
    await _useHome(v);
    lastRev = row.rev;
    lastHash = await _localHash();
    await _persist();
    await _saveBase();
    lastSync = DateTime.now();
    status = SyncStatus.ok;
    notifyListeners();
  }

  /// Lays this device's own changes (since [baseKey]) over [row]; false without a base.
  Future<bool> _mergeInto(SyncRow row) async {
    final base = await _readBase();
    if (base == null) return false;
    final v = await _openVault(row);
    final remoteSecrets = v == null
        ? null
        : {
            for (final e in ((v['secrets'] as Map?) ?? const {}).entries)
              '${e.key}': {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'},
          };
    final cfg = merge3(base['c'], host.syncConfig(), row.config);
    final sec = remoteSecrets == null ? null : merge3(base['s'], host.syncSecrets(), remoteSecrets) as Map?;
    await host.applySynced(
      Map<String, dynamic>.from(cfg as Map),
      sec == null
          ? null
          : {
              for (final e in sec.entries)
                '${e.key}': {for (final x in (e.value as Map).entries) '${x.key}': '${x.value}'},
            },
    );
    await _useHome(v);
    return true;
  }

  Future<void> _adoptHome(SyncRow row) async => _useHome(await _openVault(row));

  Future<void> _useHome(Map<String, dynamic>? v) async {
    _readBridges(v);
    if (v != null) await _checkOwnBridge();
    final home = v?['home'];
    if (home is! Map) return;
    _vaultHome = Map<String, dynamic>.from(home);
    if (host.homeCredential() == null) {
      try {
        await host.adoptHome(_vaultHome!);
      } catch (e) {
        debugPrint('adopt home failed: $e');
      }
    }
  }

  /// The bridge device puts a home credential into the account vault once.
  Future<void> _maybeShareHome() async {
    if (_key == null || _vaultHome != null) return;
    final own = host.homeCredential();
    final g = own ?? await host.makeHomeGrant();
    if (g == null) return;
    _vaultHome = g;
    final s = await _fresh();
    try {
      await _push2(s, lastRev);
    } on AccountError catch (e) {
      if (e.problem != AccountProblem.conflict) rethrow;
      _again = true;
    }
  }

  @override
  void dispose() {
    _poll?.cancel();
    _push?.cancel();
    super.dispose();
  }
}
