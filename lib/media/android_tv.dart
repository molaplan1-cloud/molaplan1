/// R324: Android TV / Google TV Remote protocol v2 (the protocol of the Google TV phone remote):
/// keys (incl. channels, D-pad, digits), power, volume, mute and the foreground app – things Cast
/// cannot do. Written from the public protocol description and the protobuf definitions of
/// androidtvremote2 (Apache-2.0, see THIRD-PARTY-NOTICES); no code copied.
///
/// - Pairing: TLS on port 6467 with our own self-signed client certificate ([selfSignedCert]);
///   polo messages PairingRequest → Options → Configuration (hex, 6 symbols) → the TV shows a
///   6-character code → Secret = SHA-256(client n, client e, server n, server e, code[2:]),
///   whose first byte must equal code[0:2].
/// - Remote: TLS on port 6466 with the same certificate; RemoteMessage handshake
///   (remote_configure, remote_set_active), pings answered, keys as remote_key_inject.
/// Messages are length-delimited by a varint. Found with mDNS `_androidtvremote2._tcp`.
/// UNTESTED ON HARDWARE – tested against a simulated TV.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

import '../core/rsa_cert.dart';
import '../drivers/driver.dart';
import 'media_model.dart';

/// Test hooks.
int atvPairPort = 6467;
int atvRemotePort = 6466;

// ---- tiny protobuf (wire types 0 and 2 only) ----

class Pb {
  final _b = BytesBuilder();
  static void _varint(BytesBuilder b, int v) {
    while (v >= 0x80 || v < 0) {
      b.addByte((v & 0x7F) | 0x80);
      v = v >>> 7;
    }
    b.addByte(v);
  }

  Pb vint(int field, int v) {
    _varint(_b, field << 3);
    _varint(_b, v);
    return this;
  }

  Pb bytes(int field, List<int> v) {
    _varint(_b, (field << 3) | 2);
    _varint(_b, v.length);
    _b.add(v);
    return this;
  }

  Pb str(int field, String s) => bytes(field, utf8.encode(s));
  Pb msg(int field, Pb m) => bytes(field, m.toBytes());
  Uint8List toBytes() => _b.toBytes();

  /// Varint length prefix + message.
  static Uint8List frame(Pb m) {
    final body = m.toBytes();
    final b = BytesBuilder();
    _varint(b, body.length);
    b.add(body);
    return b.toBytes();
  }
}

/// Decoded message: field → values (int for varints, Uint8List for length-delimited).
class PbMsg {
  PbMsg(this.f);
  final Map<int, List<Object>> f;
  bool has(int n) => f.containsKey(n);
  int vint(int n, [int d = 0]) => f[n]?.first is int ? f[n]!.first as int : d;
  Uint8List bytes(int n) => f[n]?.first is Uint8List ? f[n]!.first as Uint8List : Uint8List(0);
  String str(int n) => utf8.decode(bytes(n), allowMalformed: true);
  PbMsg msg(int n) => PbMsg.parse(bytes(n));

  static (int, int) _readVarint(List<int> b, int i) {
    var v = 0, shift = 0;
    while (true) {
      if (i >= b.length) throw const FormatException('protobuf: truncated varint');
      final x = b[i++];
      v |= (x & 0x7f) << shift;
      if (x & 0x80 == 0) return (v, i);
      shift += 7;
    }
  }

  factory PbMsg.parse(List<int> b) {
    final f = <int, List<Object>>{};
    var i = 0;
    while (i < b.length) {
      final (key, j) = _readVarint(b, i);
      i = j;
      final field = key >> 3;
      switch (key & 7) {
        case 0:
          final (v, k) = _readVarint(b, i);
          i = k;
          (f[field] ??= []).add(v);
        case 2:
          final (len, k) = _readVarint(b, i);
          if (k + len > b.length) throw const FormatException('protobuf: truncated field');
          (f[field] ??= []).add(Uint8List.fromList(b.sublist(k, k + len)));
          i = k + len;
        case 5:
          i += 4;
        case 1:
          i += 8;
        default:
          throw const FormatException('protobuf: unsupported wire type');
      }
    }
    return PbMsg(f);
  }
}

/// Splits a byte stream into varint-length-delimited messages.
class PbFramer {
  final _buf = BytesBuilder(copy: false);
  Iterable<Uint8List> add(List<int> data) sync* {
    _buf.add(data);
    var all = _buf.takeBytes();
    var i = 0;
    while (true) {
      int len, start;
      try {
        (len, start) = PbMsg._readVarint(all, i);
      } on FormatException {
        break;
      }
      if (start + len > all.length) break;
      yield Uint8List.sublistView(all, start, start + len);
      i = start + len;
    }
    if (i < all.length) _buf.add(Uint8List.sublistView(all, i));
  }
}

// ---- certificate ----

/// New client identity (PEM cert, PEM key). RSA key generation runs in an isolate. Test hook.
Future<(String, String)> Function() atvNewIdentity = () => Isolate.run(() => selfSignedCert(generateRsaKey()));

SecurityContext _ctx(String cert, String key) => SecurityContext(withTrustedRoots: false)
  ..useCertificateChainBytes(utf8.encode(cert))
  ..usePrivateKeyBytes(utf8.encode(key));

Future<SecureSocket> _connect(String host, int port, String cert, String key) async {
  try {
    return await SecureSocket.connect(
      host,
      port,
      context: _ctx(cert, key),
      onBadCertificate: (_) => true,
      timeout: const Duration(seconds: 6),
    );
  } on HandshakeException catch (e) {
    throw MediaPairingNeeded('Android TV: ${dtx('paritus tarvitaan', 'pairing needed')} ($e)');
  } catch (e) {
    throw DriverException('$host: ${dtx('televisioon ei saatu yhteyttä', 'TV not reachable')} ($e)');
  }
}

/// Pairing secret (also used by tests): SHA-256 over both public keys and the code's last 4 hex.
Uint8List atvSecret(List<int> clientCertDer, List<int> serverCertDer, String code) {
  final (cn, ce) = certRsaPublicKey(clientCertDer);
  final (sn, se) = certRsaPublicKey(serverCertDer);
  final h = sha256.convert([
    ...bigIntToBytes(cn),
    ...bigIntToBytes(ce),
    ...bigIntToBytes(sn),
    ...bigIntToBytes(se),
    ...hexBytes(code.substring(2)),
  ]);
  return Uint8List.fromList(h.bytes);
}

List<int> hexBytes(String h) => [for (var i = 0; i + 1 < h.length; i += 2) int.parse(h.substring(i, i + 2), radix: 16)];

/// One pairing in progress (between the two wizard steps).
class AtvPairing {
  AtvPairing._(this.host, this.cert, this.key, this._sock);
  final String host, cert, key;
  final SecureSocket _sock;
  final _framer = PbFramer();
  final _inbox = StreamController<PbMsg>.broadcast();
  StreamSubscription<Uint8List>? _sub;

  static Pb _outer() => Pb().vint(1, 2).vint(2, 200);

  Future<PbMsg> _next(int field) async {
    final m = await _inbox.stream
        .firstWhere((m) => m.vint(2, 200) != 200 || m.has(field))
        .timeout(const Duration(seconds: 10));
    final st = m.vint(2, 200);
    if (st == 402) throw MediaAuthError(dtx('Väärä koodi', 'Wrong code'));
    if (st != 200) throw DriverException('Android TV: pairing status $st');
    return m;
  }

  /// Opens 6467 and asks the TV to show its code.
  static Future<AtvPairing> start(String host, {String clientName = 'Molaplan', (String, String)? identity}) async {
    final (cert, key) = identity ?? await atvNewIdentity();
    final s = await _connect(host, atvPairPort, cert, key);
    final p = AtvPairing._(host, cert, key, s);
    p._sub = s.listen((d) {
      for (final m in p._framer.add(d)) {
        try {
          p._inbox.add(PbMsg.parse(m));
        } catch (_) {}
      }
    }, onError: (Object e) => p._inbox.addError(e), onDone: p._inbox.close);
    try {
      final ack = p._next(11);
      s.add(Pb.frame(_outer().msg(10, Pb().str(1, 'atvremote').str(2, clientName))));
      await ack;
      final opts = p._next(20);
      s.add(
        Pb.frame(
          _outer().msg(
            20,
            Pb().msg(1, Pb().vint(1, 3).vint(2, 6)).vint(3, 1),
          ),
        ),
      );
      await opts;
      final cfgAck = p._next(31);
      s.add(Pb.frame(_outer().msg(30, Pb().msg(1, Pb().vint(1, 3).vint(2, 6)).vint(2, 1))));
      await cfgAck;
      return p;
    } catch (e) {
      await p.close();
      if (e is DriverException) rethrow;
      throw DriverException('Android TV: ${dtx('paritus ei alkanut', 'pairing did not start')} ($e)');
    }
  }

  /// Sends the secret for the 6-character code on the TV screen.
  Future<void> finish(String code) async {
    final c = code.trim().toUpperCase();
    if (!RegExp(r'^[0-9A-F]{6}$').hasMatch(c)) {
      throw MediaAuthError(dtx('Koodissa on 6 merkkiä (0–9, A–F)', 'The code has 6 characters (0–9, A–F)'));
    }
    final server = _sock.peerCertificate?.der;
    if (server == null) throw DriverException('Android TV: no server certificate');
    final secret = atvSecret(pemToDer(cert), server, c);
    if (secret[0] != int.parse(c.substring(0, 2), radix: 16)) {
      throw MediaAuthError(dtx('Väärä koodi', 'Wrong code'));
    }
    final ack = _next(41);
    _sock.add(Pb.frame(_outer().msg(40, Pb().bytes(1, secret))));
    await ack;
  }

  Future<void> close() async {
    await _sub?.cancel();
    try {
      await _sock.close();
    } catch (_) {}
    _sock.destroy();
  }
}

/// Host → pairing waiting for the code (wizard step 2).
final atvPending = <String, AtvPairing>{};

final atvKeyCodes = <String, int>{
  'power': 26,
  'home': 3,
  'back': 4,
  'volup': 24,
  'voldown': 25,
  'mute': 164,
  'playpause': 85,
  'play': 126,
  'pause': 127,
  'stop': 86,
  'next': 87,
  'prev': 88,
  'chup': 166,
  'chdown': 167,
  'up': 19,
  'down': 20,
  'left': 21,
  'right': 22,
  'ok': 23,
  'menu': 82,
  'info': 165,
  'guide': 172,
  'tv': 170,
  'settings': 176,
  for (var i = 0; i <= 9; i++) '$i': 7 + i,
};

/// Features we ask for: PING | KEY | IME (current app) | POWER | VOLUME | APP_LINK.
const atvFeatures = 1 | 2 | 4 | 32 | 64 | 512;

class AndroidTvBackend extends MediaBackend {
  AndroidTvBackend(super.s);

  String get _cert => '${s['atvCert'] ?? ''}';
  String get _privKey => '${s['atvKey'] ?? ''}';

  SecureSocket? _sock;
  Future<void>? _opening;
  final _framer = PbFramer();
  Completer<void>? _ready;
  bool? _on;
  int? _vol, _volMax;
  bool? _muted;
  String _app = '', _model = '', _vendor = '';
  final _changed = StreamController<void>.broadcast();

  void _handle(PbMsg m) {
    final s = _sock;
    if (s == null) return;
    if (m.has(1)) {
      final cfg = m.msg(1);
      final dev = cfg.msg(2);
      _model = dev.str(1);
      _vendor = dev.str(2);
      final feats = cfg.vint(1, atvFeatures) & atvFeatures;
      s.add(
        Pb.frame(
          Pb().msg(
            1,
            Pb()
                .vint(1, feats == 0 ? atvFeatures : feats)
                .msg(2, Pb().str(1, 'Molaplan').str(2, 'Molaplan').vint(3, 1).str(4, '1').str(5, 'atvremote').str(6, '1.0.0')),
          ),
        ),
      );
    } else if (m.has(2)) {
      s.add(Pb.frame(Pb().msg(2, Pb().vint(1, atvFeatures))));
    } else if (m.has(8)) {
      s.add(Pb.frame(Pb().msg(9, Pb().vint(1, m.msg(8).vint(1)))));
    } else if (m.has(20)) {
      final pkg = m.msg(20).msg(1).str(12);
      if (pkg.isNotEmpty) _app = pkg;
    } else if (m.has(50)) {
      final v = m.msg(50);
      _volMax = v.vint(6);
      _vol = v.vint(7);
      _muted = v.vint(8) != 0;
    } else if (m.has(40)) {
      _on = m.msg(40).vint(1) != 0;
      final r = _ready;
      if (r != null && !r.isCompleted) r.complete();
    }
    _changed.add(null);
  }

  Future<void> _ensure() async {
    if (_sock != null) return;
    if (_cert.isEmpty || _privKey.isEmpty) {
      throw MediaPairingNeeded(dtx('Android TV pitää parittaa (koodi televisiosta)', 'Pair the Android TV first (code on the TV)'));
    }
    final o = _opening ??= () async {
      final r = _ready = Completer<void>();
      final s = await _connect(host, atvRemotePort, _cert, _privKey);
      _sock = s;
      s.listen(
        (d) {
          for (final m in _framer.add(d)) {
            try {
              _handle(PbMsg.parse(m));
            } catch (_) {}
          }
        },
        onError: (Object _) => _drop(),
        onDone: _drop,
        cancelOnError: true,
      );
      try {
        await r.future.timeout(const Duration(seconds: 6));
      } catch (_) {
        _drop();
        // The TV closes an unknown certificate right after the handshake.
        throw MediaPairingNeeded(dtx('Android TV ei hyväksynyt yhteyttä – paritus tarvitaan', 'The Android TV refused – pairing needed'));
      }
    }();
    try {
      await o;
    } finally {
      _opening = null;
    }
  }

  void _drop() {
    final s = _sock;
    _sock = null;
    s?.destroy();
  }

  Future<void> _press(int code) async {
    await _ensure();
    _sock!.add(Pb.frame(Pb().msg(10, Pb().vint(1, code).vint(2, 3))));
    await _sock!.flush();
  }

  @override
  Future<MediaInfo> info() async {
    await _ensure();
    // Volume / app arrive right after remote_start; give them a moment.
    await _changed.stream.first.timeout(const Duration(milliseconds: 700), onTimeout: () {});
    return MediaInfo(
      name: [_vendor, _model].where((x) => x.isNotEmpty).join(' ').ifEmpty('Android TV'),
      model: _model,
      caps: {'power', 'volume', 'mute', 'playpause', 'stop', 'keys', 'channels', 'next'},
      extra: {'atvCert': _cert, 'atvKey': _privKey},
    );
  }

  int? get _pct => _vol == null || (_volMax ?? 0) <= 0 ? _vol : (_vol! * 100 / _volMax!).round();

  @override
  Future<MediaState> state() async {
    try {
      await _ensure();
    } on MediaPairingNeeded {
      rethrow;
    } on DriverException {
      return MediaState(power: false);
    }
    return MediaState(power: _on, volume: _pct, muted: _muted, app: _appLabel(_app));
  }

  static String _appLabel(String pkg) => switch (pkg) {
    'com.netflix.ninja' => 'Netflix',
    'com.google.android.youtube.tv' => 'YouTube',
    'com.disney.disneyplus' => 'Disney+',
    'com.hbo.hbonow' || 'com.wbd.stream' => 'Max',
    'com.amazon.amazonvideo.livingroom' => 'Prime Video',
    'fi.yle.areena' || 'fi.yle.areena.tv' => 'Yle Areena',
    'fi.mtv.katsomo' || 'com.mtv.mtvkatsomo' => 'MTV Katsomo',
    'com.ruutu.android' || 'fi.ruutu.tv' => 'Ruutu',
    'com.spotify.tv.android' => 'Spotify',
    'com.google.android.tvlauncher' || 'com.google.android.apps.tv.launcherx' => '',
    _ => pkg,
  };

  @override
  Future<void> setPower(bool on) async {
    await _ensure();
    if (_on == on) return;
    await _press(26);
  }

  @override
  Future<void> setVolume(num level) async {
    await _ensure();
    final cur = _pct;
    final max = (_volMax ?? 0) > 0 ? _volMax! : 100;
    if (cur == null) throw DriverException(dtx('Televisio ei kerro äänenvoimakkuutta', 'The TV does not report volume'));
    final steps = ((level.clamp(0, 100) - cur) * max / 100).round().clamp(-50, 50);
    for (var i = 0; i < steps.abs(); i++) {
      await _press(steps > 0 ? 24 : 25);
      await Future<void>.delayed(const Duration(milliseconds: 60));
    }
  }

  @override
  Future<void> setMuted(bool muted) async {
    await _ensure();
    if (_muted == muted) return;
    await _press(164);
  }

  @override
  Future<void> key(String key) {
    final c = atvKeyCodes[key];
    if (c == null) throw DriverException('Android TV: unknown key $key');
    return _press(c);
  }

  /// Opens an app / deep link (e.g. https://www.youtube.com, market://launch?id=fi.yle.areena).
  Future<void> launch(String link) async {
    await _ensure();
    _sock!.add(Pb.frame(Pb().msg(90, Pb().str(1, link))));
  }

  @override
  Future<void> close() async => _drop();
}

extension on String {
  String ifEmpty(String d) => isEmpty ? d : this;
}
