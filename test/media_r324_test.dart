// R324: Roku (ECP), Sonos (UPnP), Android TV Remote v2, RSA / X.509 helper and Home Assistant
// media extras – all against simulated devices (UNTESTED ON REAL HARDWARE).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/core/rsa_cert.dart';
import 'package:molaplan/core/template.dart';
import 'package:molaplan/devices/provider.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/ha_catalog.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/media/android_tv.dart';
import 'package:molaplan/media/media_driver.dart';
import 'package:molaplan/media/media_model.dart';
import 'package:molaplan/media/media_providers.dart';
import 'package:molaplan/media/roku.dart';
import 'package:molaplan/media/sonos.dart';
import 'package:molaplan/models/models.dart';

// One shared key pair per role (key generation is the slow part).
final (String, String) _client = selfSignedCert(generateRsaKey(), cn: 'atvremote');
final (String, String) _server = selfSignedCert(generateRsaKey(), cn: 'tv');

/// Simulated Android TV: pairing (6467) and remote (6466) on loopback TLS.
class FakeAtv {
  late SecureServerSocket pairSrv, remoteSrv;
  final paired = <String>{};
  String? shownCode;
  final keys = <int>[];
  final links = <String>[];
  bool on = true;
  int volume = 20;
  int pings = 0;

  Future<FakeAtv> start() async {
    final ctx = SecurityContext(withTrustedRoots: false)
      ..useCertificateChainBytes(utf8.encode(_server.$1))
      ..usePrivateKeyBytes(utf8.encode(_server.$2))
      // A real TV accepts any client certificate; Dart's test server needs it trusted.
      ..setTrustedCertificatesBytes(utf8.encode(_client.$1));
    pairSrv = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, ctx, requestClientCertificate: true);
    remoteSrv = await SecureServerSocket.bind(InternetAddress.loopbackIPv4, 0, ctx, requestClientCertificate: true);
    pairSrv.listen(_pair);
    remoteSrv.listen(_remote);
    atvPairPort = pairSrv.port;
    atvRemotePort = remoteSrv.port;
    return this;
  }

  Pb _outer([int status = 200]) => Pb().vint(1, 2).vint(2, status);

  void _pair(SecureSocket s) {
    final clientDer = s.peerCertificate?.der;
    final f = PbFramer();
    s.listen((d) {
      for (final raw in f.add(d)) {
        final m = PbMsg.parse(raw);
        if (m.has(10)) {
          s.add(Pb.frame(_outer().msg(11, Pb().str(1, 'Fake TV'))));
        } else if (m.has(20)) {
          final enc = m.msg(20).msg(1);
          expect(enc.vint(1), 3);
          expect(enc.vint(2), 6);
          s.add(Pb.frame(_outer().msg(20, Pb().msg(1, Pb().vint(1, 3).vint(2, 6)).vint(3, 1))));
        } else if (m.has(30)) {
          // Show a code: 2 random bytes + the hash check byte in front.
          final r = Random();
          final suffix = [r.nextInt(256), r.nextInt(256)].map((b) => b.toRadixString(16).padLeft(2, '0')).join();
          final h = atvSecret(clientDer!, pemToDer(_server.$1), '00$suffix');
          shownCode = '${h[0].toRadixString(16).padLeft(2, '0')}$suffix'.toUpperCase();
          s.add(Pb.frame(_outer().msg(31, Pb())));
        } else if (m.has(40)) {
          final want = atvSecret(clientDer!, pemToDer(_server.$1), shownCode!);
          if (base64.encode(m.msg(40).bytes(1)) == base64.encode(want)) {
            paired.add(base64.encode(clientDer));
            s.add(Pb.frame(_outer().msg(41, Pb().bytes(1, want))));
          } else {
            s.add(Pb.frame(_outer(402)));
          }
        }
      }
    });
  }

  void _remote(SecureSocket s) {
    final der = s.peerCertificate?.der;
    if (der == null || !paired.contains(base64.encode(der))) {
      s.destroy();
      return;
    }
    final f = PbFramer();
    s.add(Pb.frame(Pb().msg(1, Pb().vint(1, 0x27f).msg(2, Pb().str(1, 'BRAVIA 4K').str(2, 'Sony')))));
    s.listen((d) {
      for (final raw in f.add(d)) {
        final m = PbMsg.parse(raw);
        if (m.has(1)) {
          expect(m.msg(1).msg(2).str(5), 'atvremote');
          s.add(Pb.frame(Pb().msg(2, Pb())));
        } else if (m.has(2)) {
          s.add(Pb.frame(Pb().msg(8, Pb().vint(1, 7))));
          s.add(Pb.frame(Pb().msg(40, on ? (Pb().vint(1, 1)) : Pb())));
          s.add(Pb.frame(Pb().msg(50, Pb().vint(6, 100).vint(7, volume))));
          s.add(Pb.frame(Pb().msg(20, Pb().msg(1, Pb().str(12, 'com.netflix.ninja')))));
        } else if (m.has(9)) {
          expect(m.msg(9).vint(1), 7);
          pings++;
        } else if (m.has(10)) {
          final k = m.msg(10);
          expect(k.vint(2), 3);
          keys.add(k.vint(1));
        } else if (m.has(90)) {
          links.add(m.msg(90).str(1));
        }
      }
    });
  }

  Future<void> stop() async {
    await pairSrv.close();
    await remoteSrv.close();
  }
}

String _soapBody(String action, String inner) =>
    '<s:Envelope><s:Body><u:${action}Response>$inner</u:${action}Response></s:Body></s:Envelope>';

void main() {
  tearDown(() {
    mediaTestBackend = null;
    mediaHttp = () => http.Client();
    atvPairPort = 6467;
    atvRemotePort = 6466;
    atvPending.clear();
    atvNewIdentity = () async => _client;
  });
  setUp(() => atvNewIdentity = () async => _client);

  group('RSA / X.509 (own implementation)', () {
    test('certificate carries the key, signature verifies with the public key', () {
      final k = generateRsaKey(bits: 1024);
      final (cert, key) = selfSignedCert(k);
      expect(cert, startsWith('-----BEGIN CERTIFICATE-----'));
      expect(key, startsWith('-----BEGIN RSA PRIVATE KEY-----'));
      final (n, e) = certRsaPublicKey(pemToDer(cert));
      expect(n, k.n);
      expect(e, BigInt.from(65537));
      final sig = rsaSignSha256(k, utf8.encode('hello'));
      final em = bigIntToBytes(bytesToBigInt(sig).modPow(k.e, k.n), 128);
      expect(em.sublist(0, 2), [0, 1]);
      expect(em.sublist(em.length - 32), c.sha256.convert(utf8.encode('hello')).bytes);
      // The PEM pair loads into a TLS context (key and certificate match).
      SecurityContext(withTrustedRoots: false)
        ..useCertificateChainBytes(utf8.encode(cert))
        ..usePrivateKeyBytes(utf8.encode(key));
    });

    test('primality and DER integers', () {
      expect(isProbablePrime(BigInt.from(1000003)), isTrue);
      expect(isProbablePrime(BigInt.from(1000001)), isFalse);
      expect(derInt(BigInt.from(128)), [2, 2, 0, 128]);
      expect(bigIntToBytes(BigInt.from(65537)), [1, 0, 1]);
    });
  });

  group('protobuf framing', () {
    test('varint frames split across chunks', () {
      final a = Pb.frame(Pb().vint(1, 300).str(2, 'x' * 200));
      final f = PbFramer();
      final out = [...f.add(a.sublist(0, 1)), ...f.add(a.sublist(1, 50)), ...f.add(a.sublist(50))];
      expect(out, hasLength(1));
      final m = PbMsg.parse(out.single);
      expect(m.vint(1), 300);
      expect(m.str(2), 'x' * 200);
    });
  });

  group('Android TV Remote v2', () {
    late FakeAtv tv;
    setUp(() async => tv = await FakeAtv().start());
    tearDown(() => tv.stop());

    test('pairing with the code shown on the TV, then keys, volume, power and app', () async {
      final p = await AtvPairing.start('127.0.0.1', identity: _client);
      expect(tv.shownCode, hasLength(6));
      await p.finish(tv.shownCode!.toLowerCase());
      await p.close();
      final b = AndroidTvBackend({'brand': 'androidtv', 'address': '127.0.0.1', 'atvCert': p.cert, 'atvKey': p.key});
      final info = await b.info();
      expect(info.name, 'Sony BRAVIA 4K');
      expect(info.caps, containsAll(['power', 'volume', 'channels', 'keys']));
      final st = await b.state();
      expect(st.power, isTrue);
      expect(st.volume, 20);
      expect(st.app, 'Netflix');
      await b.setVolume(25);
      await b.key('chup');
      await b.channel('12');
      await b.setPower(false);
      await b.launch('https://www.youtube.com');
      await Future<void>.delayed(const Duration(milliseconds: 300));
      expect(tv.keys, [24, 24, 24, 24, 24, 166, 8, 9, 26]);
      expect(tv.links, ['https://www.youtube.com']);
      expect(tv.pings, 1);
      await b.close();
    });

    test('wrong code is refused locally; unknown certificate → pairing needed', () async {
      final p = await AtvPairing.start('127.0.0.1', identity: _client);
      final bad = '${((int.parse(tv.shownCode!.substring(0, 2), radix: 16) + 1) % 256).toRadixString(16).padLeft(2, '0')}'
          '${tv.shownCode!.substring(2)}';
      await expectLater(p.finish(bad), throwsA(isA<MediaAuthError>()));
      await expectLater(p.finish('12345'), throwsA(isA<MediaAuthError>()));
      await p.close();
      final b = AndroidTvBackend({'address': '127.0.0.1', 'atvCert': _client.$1, 'atvKey': _client.$2});
      await expectLater(b.info(), throwsA(isA<MediaPairingNeeded>()));
      await expectLater(
        AndroidTvBackend({'address': '127.0.0.1'}).state(),
        throwsA(isA<MediaPairingNeeded>()),
      );
    });

    test('wizard: first step asks for the code, second step saves the certificate as secrets', () async {
      final p = mediaProviderById('media_androidtv')!;
      final cand = Candidate(provider: p.id, address: '127.0.0.1', name: 'Olohuone');
      final ctx = AddContext(driver: createDriver);
      await expectLater(
        p.connect(ctx, cand, const {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', AddProblem.needsDetails)),
      );
      expect(atvPending.containsKey('127.0.0.1'), isTrue);
      final r = await p.connect(ctx, cand, {'pin': tv.shownCode!});
      expect(r.connection.secrets['atvCert'], startsWith('-----BEGIN CERTIFICATE'));
      expect(r.connection.secrets['atvKey'], contains('PRIVATE KEY'));
      expect(r.connection.settings.containsKey('atvKey'), isFalse);
      final keys = p.tiles(r).map((t) => t.read['media'] ?? t.commands.firstOrNull?.spec['key']).toList();
      expect(keys, containsAll(['status', 'power', 'volume', 'muted', 'playpause', 'chup', 'chdown']));
    }, timeout: const Timeout(Duration(seconds: 60)));
  });

  group('Roku ECP', () {
    final posts = <String>[];
    var powerMode = 'PowerOn';
    setUp(() {
      posts.clear();
      powerMode = 'PowerOn';
      mediaHttp = () => MockClient((r) async {
        expect(r.url.port, 8060);
        if (r.method == 'POST') {
          posts.add(r.url.path + (r.url.hasQuery ? '?${r.url.query}' : ''));
          return http.Response('', 200);
        }
        return switch (r.url.path) {
          '/query/device-info' => http.Response(
            '<?xml version="1.0"?><device-info><vendor-name>TCL</vendor-name><model-name>55S535</model-name>'
            '<user-device-name>Makuuhuone</user-device-name><wifi-mac>aa:bb:cc:dd:ee:ff</wifi-mac>'
            '<is-tv>true</is-tv><power-mode>$powerMode</power-mode></device-info>',
            200,
          ),
          '/query/active-app' => http.Response('<active-app><app id="12" version="1">Netflix</app></active-app>', 200),
          '/query/media-player' => http.Response('<player error="false" state="pause"><plugin id="12" name="Netflix"/></player>', 200),
          _ => http.Response('', 404),
        };
      });
    });

    test('info, state, keys, channel and power', () async {
      final b = RokuBackend({'address': '192.168.1.60'});
      final info = await b.info();
      expect(info.name, 'Makuuhuone');
      expect(info.model, 'TCL 55S535');
      expect(info.mac, 'aa:bb:cc:dd:ee:ff');
      expect(info.caps, containsAll(['power', 'volkeys', 'channels']));
      expect(info.caps, isNot(contains('volume')));
      final st = await b.state();
      expect(st.power, isTrue);
      expect(st.app, 'Netflix');
      expect(st.playing, isFalse);
      await b.key('volup');
      await b.key('chdown');
      await b.key('5');
      await b.channel('5.1');
      await b.setPower(false);
      expect(posts, [
        '/keypress/VolumeUp',
        '/keypress/ChannelDown',
        '/keypress/Lit_5',
        '/launch/tvinput.dtv?ch=5.1',
        '/keypress/PowerOff',
      ]);
      expect(() => b.setVolume(30), throwsA(isA<Exception>()));
      powerMode = 'DisplayOff';
      expect((await b.state()).power, isFalse);
    });

    test('403 = control by mobile apps is off', () async {
      mediaHttp = () => MockClient((r) async => http.Response('', 403));
      await expectLater(RokuBackend({'address': '192.168.1.60'}).info(), throwsA(isA<MediaAuthError>()));
    });

    test('tiles: volume buttons instead of a slider, channel buttons', () {
      final tiles = mediaTiles('c1', MediaInfo(name: 'Roku', caps: {'power', 'volkeys', 'mute', 'playpause', 'channels'}), title: 'Roku');
      final keys = tiles.map((t) => t.read['media'] ?? t.commands.firstOrNull?.spec['key']).toList();
      expect(keys, ['status', 'power', 'volup', 'voldown', 'mute', 'playpause', 'chup', 'chdown']);
      expect(tiles.where((t) => t.type == TileType.slider), isEmpty);
    });
  });

  group('Sonos UPnP', () {
    final calls = <String>[];
    setUp(() {
      calls.clear();
      mediaHttp = () => MockClient((r) async {
        if (r.url.path == '/xml/device_description.xml') {
          return http.Response(
            '<root><device><friendlyName>192.168.1.70 - Sonos One</friendlyName><modelName>Sonos One</modelName>'
            '<roomName>Keittiö</roomName><serialNum>00-0E-58-AA-BB-CC:5</serialNum><UDN>uuid:RINCON_A01400</UDN></device></root>',
            200,
          );
        }
        final action = (r.headers['SOAPACTION'] ?? '').split('#').last.replaceAll('"', '');
        calls.add('${r.url.host}:$action');
        if (action == 'GetZoneGroupState') {
          const zgs =
              '<ZoneGroupState><ZoneGroups><ZoneGroup Coordinator="RINCON_B01400" ID="x">'
              '<ZoneGroupMember UUID="RINCON_B01400" Location="http://192.168.1.71:1400/xml/device_description.xml"/>'
              '<ZoneGroupMember UUID="RINCON_A01400" Location="http://192.168.1.70:1400/xml/device_description.xml"/>'
              '</ZoneGroup></ZoneGroups></ZoneGroupState>';
          return http.Response(_soapBody(action, '<ZoneGroupState>${const HtmlEscape().convert(zgs)}</ZoneGroupState>'), 200);
        }
        return http.Response(switch (action) {
          'GetVolume' => _soapBody(action, '<CurrentVolume>23</CurrentVolume>'),
          'GetMute' => _soapBody(action, '<CurrentMute>0</CurrentMute>'),
          'GetTransportInfo' => _soapBody(action, '<CurrentTransportState>PLAYING</CurrentTransportState>'),
          'GetPositionInfo' => _soapBody(
            action,
            '<TrackURI>x-sonos-spotify:abc</TrackURI><TrackMetaData>${const HtmlEscape().convert('<DIDL-Lite><item><dc:title>Sininen uni</dc:title><dc:creator>Apulanta</dc:creator></item></DIDL-Lite>')}</TrackMetaData>',
          ),
          _ => _soapBody(action, ''),
        }, 200);
      });
    });

    test('state per speaker, transport to the group coordinator', () async {
      final b = SonosBackend({'address': '192.168.1.70'});
      final info = await b.info();
      expect(info.name, 'Keittiö');
      expect(info.mac, '00:0E:58:AA:BB:CC');
      final st = await b.state();
      expect(st.volume, 23);
      expect(st.muted, isFalse);
      expect(st.playing, isTrue);
      expect(st.title, 'Apulanta – Sininen uni');
      calls.clear();
      await b.setVolume(40);
      await b.key('playpause');
      await b.key('next');
      expect(calls, [
        '192.168.1.70:SetVolume',
        '192.168.1.71:GetTransportInfo',
        '192.168.1.71:Pause',
        '192.168.1.71:Next',
      ]);
    });

    test('UPnP fault is reported', () async {
      mediaHttp = () => MockClient(
        (r) async => http.Response('<s:Fault><detail><UPnPError><errorCode>402</errorCode></UPnPError></detail></s:Fault>', 500),
      );
      await expectLater(
        sonosSoap('192.168.1.70', ('RenderingControl', '/MediaRenderer/RenderingControl/Control'), 'GetVolume'),
        throwsA(isA<SonosFault>().having((e) => e.code, 'code', '402')),
      );
    });

    test('mDNS name and wizard tiles', () async {
      final p = mediaProviderById('media_sonos')!;
      final cand = p.fromMdns('192.168.1.70:1443', 'RINCON_A01400@Keittiö', '_sonos._tcp')!;
      expect(cand.name, 'Keittiö');
      final r = await p.connect(AddContext(driver: createDriver), cand, const {});
      final keys = p.tiles(r).map((t) => t.read['media'] ?? t.commands.firstOrNull?.spec['key']).toList();
      expect(keys, ['status', 'volume', 'muted', 'playpause', 'stop', 'next']);
    });
  });

  group('driver commands', () {
    test('channel and launch reach the backend', () async {
      final fake = _Rec();
      mediaTestBackend = (s) => fake;
      final d = createDriver(ConnectionConfig(name: 'TV', type: 'media', settings: {'brand': 'roku'}));
      await d.send({'media': 'channel', 'value': '{{value}}'}, value: '7');
      expect(fake.log, ['channel 7']);
      await expectLater(d.send({'media': 'launch', 'value': 'x'}), throwsA(isA<Exception>()));
    });
  });

  group('Home Assistant bridge extras', () {
    test('media_player: status, power, volume (0–1 ↔ %), play/pause, next', () {
      final e = HaEntity(
        entityId: 'media_player.olohuone',
        name: 'Olohuoneen TV',
        attributes: {'supported_features': 4 | 1 | 32 | 128 | 256, 'volume_level': 0.25},
      );
      final tiles = haTilesFor(e, 'ha', 'fi');
      expect(tiles.map((t) => t.type), [
        TileType.value,
        TileType.toggle,
        TileType.slider,
        TileType.button,
        TileType.button,
      ]);
      final vol = tiles[2];
      expect(vol.read, {'entityId': 'media_player.olohuone', 'attribute': 'volume_level', 'scale': 100});
      expect(applyTemplate(vol.commands.single.spec['data'] as String, 40), '{"volume_level": 0.40}');
      expect(tiles[1].onValue, contains('playing'));
    });

    test('vacuum, valve and humidifier get tiles', () {
      expect(haTilesFor(HaEntity(entityId: 'vacuum.roborock', name: 'Imuri'), 'ha', 'fi'), hasLength(3));
      final v = haTilesFor(HaEntity(entityId: 'valve.vesi', name: 'Vesi'), 'ha', 'fi').single;
      expect(v.confirm, isTrue);
      expect(v.onCommand?.spec['service'], 'valve.open_valve');
      expect(haTilesFor(HaEntity(entityId: 'humidifier.x', name: 'Kostutin'), 'ha', 'fi').single.type, TileType.toggle);
    });
  });

  test('registries: new providers and brands', () {
    for (final id in ['media_androidtv', 'media_sonos', 'media_roku']) {
      expect(providerById(id), isA<MediaProvider>());
    }
    expect(MediaChooser().keywords, containsAll(['sonos', 'roku', 'kaukosäädin']));
    expect(mediaNotYet.single.$1, 'Apple TV');
    expect(mediaBrands.keys, containsAll(['androidtv', 'sonos', 'roku']));
  });
}

class _Rec extends MediaBackend {
  _Rec() : super(<String, dynamic>{});
  final log = <String>[];
  @override
  Future<MediaInfo> info() async => MediaInfo(name: 'x');
  @override
  Future<MediaState> state() async => MediaState();
  @override
  Future<void> setPower(bool on) async {}
  @override
  Future<void> setVolume(num level) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> key(String key) async => log.add('key $key');
  @override
  Future<void> channel(String ch) async => log.add('channel $ch');
}
