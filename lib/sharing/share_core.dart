/// R215–R217 (t215u): sharing devices with another Molaplan user and the installer ('Asentaja')
/// role – the parts that are pure logic (no UI, no network), shared by the app and the bridge.
///
/// How it fits together:
///  * Every account has a share identity: an X25519 key derived from the account key (which only
///    the user's own devices have). Its public half is in the account profile.
///  * The owner picks tiles + a permission level. The owner's home bridge stores the tiles and
///    their connections (with secrets – they never leave the home) and mints a client credential
///    for the recipient's share key, limited to those tiles ([ShareScope]).
///  * The credential (relay token etc.) travels to the recipient only sealed to the recipient's
///    share key ([sealForRecipient]); the server stores ciphertext.
///  * The recipient sees only [publicTile]s (title, type, unit, range – no connection, address,
///    command or password) and asks the bridge to act on a tile id. The BRIDGE checks the scope on
///    every request, so a modified app cannot do more than it was given.
library;

import 'dart:convert';
import 'dart:math';

import 'package:cryptography/cryptography.dart';

import '../models/models.dart';
import '../remote/e2e.dart';

/// What a recipient may do with one shared tile.
enum ShareCap { view, control, settings }

/// Permission presets offered in the UI (limited = per capability).
enum SharePreset { view, control, full }

/// The permission of one share: which tiles, and per tile what.
class ShareScope {
  ShareScope({required this.level, required this.tiles});

  /// 'full' = control + settings on every shared tile; 'limited' = per tile below.
  final String level;

  /// tileId -> capabilities.
  final Map<String, Set<ShareCap>> tiles;

  bool get full => level == 'full';

  factory ShareScope.preset(SharePreset p, Iterable<String> tileIds) => ShareScope(
    level: p == SharePreset.full ? 'full' : 'limited',
    tiles: {
      for (final id in tileIds)
        id: switch (p) {
          SharePreset.view => {ShareCap.view},
          SharePreset.control => {ShareCap.view, ShareCap.control},
          SharePreset.full => ShareCap.values.toSet(),
        },
    },
  );

  bool allows(String tileId, ShareCap cap) {
    final t = tiles[tileId];
    if (t == null) return false;
    if (full) return true;
    // Control implies seeing the state it changes.
    if (cap == ShareCap.view) return t.contains(ShareCap.view) || t.contains(ShareCap.control);
    return t.contains(cap);
  }

  /// Short label for lists.
  SharePreset get preset {
    if (full) return SharePreset.full;
    return tiles.values.any((c) => c.contains(ShareCap.control) || c.contains(ShareCap.settings))
        ? SharePreset.control
        : SharePreset.view;
  }

  Map<String, dynamic> toJson() => {
    'level': level,
    'tiles': {for (final e in tiles.entries) e.key: [for (final c in e.value) c.name]},
  };

  factory ShareScope.fromJson(Map<String, dynamic> j) => ShareScope(
    level: j['level'] == 'full' ? 'full' : 'limited',
    tiles: {
      for (final e in ((j['tiles'] as Map?) ?? const {}).entries)
        '${e.key}': {
          for (final c in (e.value as List? ?? const []))
            ...ShareCap.values.where((x) => x.name == '$c'),
        },
    },
  );
}

/// Tile types that can be shared in v0.9.0 (thermostats run as bridge jobs and are not yet).
bool shareableTile(TileConfig t) =>
    t.type != TileType.thermostat &&
    (t.connectionId != null || t.onCommand != null || t.offCommand != null || t.commands.isNotEmpty);

/// A "setting" rather than a control: changing it needs [ShareCap.settings]
/// (temperature setpoints, heat-pump mode / fan / vane).
bool isSettingTile(TileConfig t) {
  if (t.type != TileType.slider && t.type != TileType.value) return false;
  if (t.type == TileType.value && t.commands.isEmpty) return false;
  final u = t.unit.trim();
  final f = '${t.read['field'] ?? t.read['set'] ?? ''}';
  return u == '°C' || u == '°F' || const {'mode', 'fan', 'vane', 'temp', 'setpoint'}.contains(f);
}

/// What the action on a tile needs.
ShareCap capFor(TileConfig t, String action) {
  if (action == 'read' || action == 'snapshot') return ShareCap.view;
  return isSettingTile(t) ? ShareCap.settings : ShareCap.control;
}

/// The tile as the recipient sees it: how it looks and its range, but no connection, address,
/// read spec, command or picture file.
Map<String, dynamic> publicTile(TileConfig t, Set<ShareCap> caps) => {
  'id': t.id,
  'type': t.type.name,
  'title': t.title,
  'icon': t.icon,
  'unit': t.unit,
  'decimals': t.decimals,
  'valueMap': t.valueMap,
  'onValue': t.onValue,
  'min': t.min,
  'max': t.max,
  'step': t.step,
  'confirm': t.confirm,
  'color': ?t.color,
  'sensor': ?t.sensor,
  'thresholds': [for (final x in t.thresholds) x.toJson()],
  'caps': [for (final c in caps) c.name],
  'setting': isSettingTile(t),
};

/// What the owner's app pushes to the home bridge for one share ("share_put"). The bridge keeps it
/// at home; the connections carry the secrets the drivers need.
Map<String, dynamic> sharePackage(AppConfig cfg, ShareScope scope) {
  final tiles = <String, TileConfig>{
    for (final d in cfg.dashboards)
      for (final t in d.tiles)
        if (scope.tiles.containsKey(t.id) && shareableTile(t)) t.id: t,
  };
  final connIds = <String>{
    for (final t in tiles.values) ...[
      ?t.connectionId,
      ?t.onCommand?.connectionId,
      ?t.offCommand?.connectionId,
      for (final c in t.commands) c.connectionId,
      if (t.battery != null) ?t.connectionId,
    ],
  };
  return {
    'scope': scope.toJson(),
    'tiles': {for (final t in tiles.values) t.id: t.toJson()},
    'conns': {
      for (final c in cfg.connections)
        if (connIds.contains(c.id)) c.id: c.toJson(includeSecrets: true),
    },
  };
}

/// Non-secret summary stored with the share row (so both sides can list it without the bridge).
Map<String, dynamic> shareSummary(AppConfig cfg, ShareScope scope) => {
  'preset': scope.preset.name,
  'tiles': [
    for (final d in cfg.dashboards)
      for (final t in d.tiles)
        if (scope.tiles.containsKey(t.id) && shareableTile(t)) {'id': t.id, 'title': t.title, 'view': d.name},
  ],
};

// ---------------------------------------------------------------- keys + sealing

final _hkdf = Hkdf(hmac: Hmac.sha256(), outputLength: 32);

/// The account's share identity, derived from the account key (same on every own device).
Future<Identity> shareIdentity(List<int> accountKey, String userId) async {
  final k = await _hkdf.deriveKey(
    secretKey: SecretKey(accountKey),
    nonce: utf8.encode(userId),
    info: utf8.encode('molaplan-share-x25519-v1'),
  );
  return Identity.fromSeed(await k.extractBytes());
}

const _shareHome = 'molaplan-share-v1';

/// Seals [message] so that only the holder of [recipientPub]'s private key can open it.
/// Bound to the share id and the recipient's user id (a payload cannot be moved to another share).
Future<String> sealForRecipient(Object message, {required String recipientPub, required String shareId, required String recipientId}) async {
  final eph = await Identity.generate();
  final key = await sessionKey(eph, unb64(recipientPub), _shareHome, shareId);
  final box = await seal(key, message, home: _shareHome, dev: shareId, dir: recipientId);
  return '${b64(eph.publicKey)}.$box';
}

/// Throws [CryptoFailure] when the payload is not for this identity / share.
Future<Map<String, dynamic>> openFromOwner(String payload, {required Identity me, required String shareId, required String myUserId}) async {
  final i = payload.indexOf('.');
  if (i <= 0) throw CryptoFailure('bad payload');
  final key = await sessionKey(me, unb64(payload.substring(0, i)), _shareHome, shareId);
  final v = await open(key, payload.substring(i + 1), home: _shareHome, dev: shareId, dir: myUserId);
  if (v is! Map) throw CryptoFailure('bad payload');
  return Map<String, dynamic>.from(v);
}

// ---------------------------------------------------------------- invite codes

const _codeAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789'; // no 0/O, 1/I
final _rng = Random.secure();

/// 12 characters (60 bits) in groups: "K7QM-2XPA-R9TD". Valid for a week, used once.
String newInviteCode() {
  final s = List.generate(12, (_) => _codeAlphabet[_rng.nextInt(_codeAlphabet.length)]).join();
  return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}';
}

/// Accepts typing variations (lower case, spaces, missing dashes, the whole link).
String? normalizeInviteCode(String input) {
  var s = input.trim();
  final u = Uri.tryParse(s);
  if (u != null && u.scheme == 'molaplan' && u.host == 'share') s = u.queryParameters['c'] ?? '';
  s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (s.length != 12 || s.split('').any((c) => !_codeAlphabet.contains(c))) return null;
  return '${s.substring(0, 4)}-${s.substring(4, 8)}-${s.substring(8)}';
}

String inviteLink(String code) => 'molaplan://share?c=$code';

/// What the server stores instead of the code.
Future<String> inviteCodeHash(String code) => sha256Hex('molaplan-invite-v1|${normalizeInviteCode(code) ?? code}');

// ---------------------------------------------------------------- installer IDs (R257)

/// Characters of a public installer ID: no 0/O, 1/I/L (easy to read aloud and type).
const installerIdAlphabet = 'ABCDEFGHJKMNPQRSTUVWXYZ23456789';

/// "MPL-K7Q-M2X" from what a customer typed or scanned (lower case, spaces, missing dashes or
/// prefix, an installer link / QR). Null when it cannot be an installer ID. Same rules as
/// private.normalize_installer_id() on the server.
String? normalizeInstallerId(String input) {
  var s = input.trim();
  final u = Uri.tryParse(s);
  if (u != null && u.scheme == 'molaplan' && u.host == 'installer') s = u.queryParameters['id'] ?? '';
  if (u != null && (u.scheme == 'https' || u.scheme == 'http') && u.pathSegments.length >= 2 && u.pathSegments.first == 'asentaja') {
    s = u.pathSegments[1];
  }
  s = s.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
  if (s.startsWith('MPL')) s = s.substring(3);
  if (s.length != 6 || s.split('').any((c) => !installerIdAlphabet.contains(c))) return null;
  return 'MPL-${s.substring(0, 3)}-${s.substring(3)}';
}

/// What the installer's QR code holds.
String installerLink(String publicId) => 'molaplan://installer?id=$publicId';
