// R290: TVs and Cast devices – all against simulated devices (UNTESTED ON REAL HARDWARE).
import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart' as c;
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/core/aes_cbc.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/drivers/digest_auth.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/media/cast.dart';
import 'package:molaplan/media/lg_webos.dart';
import 'package:molaplan/media/media_driver.dart';
import 'package:molaplan/media/media_model.dart';
import 'package:molaplan/media/media_providers.dart';
import 'package:molaplan/media/philips_tv.dart';
import 'package:molaplan/media/samsung_tv.dart';
import 'package:molaplan/media/wol.dart';
import 'package:molaplan/models/models.dart';

/// Simulated Cast receiver (plain TCP; the app uses TLS on 8009).
class FakeCast {
  late ServerSocket server;
  double level = 0.3;
  bool muted = false;
  bool appRunning = true;
  String playerState = 'PLAYING';
  final log = <String>[];
  int get port => server.port;

  Future<FakeCast> start() async {
    server = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((s) {
      final buf = BytesBuilder();
      void reply(CastMessage m, Map<String, dynamic> p) =>
          s.add(encodeCast(CastMessage(m.destination, m.source, m.namespace, jsonEncode(p))));
      // The receiver pings too: the client must answer PONG.
      s.add(encodeCast(CastMessage('receiver-0', 'sender-0', nsHeartbeat, '{"type":"PING"}')));
      s.listen((d) {
        buf.add(d);
        while (true) {
          final b = buf.toBytes();
          if (b.length < 4) return;
          final n = ByteData.sublistView(b).getUint32(0);
          if (b.length < 4 + n) return;
          final m = decodeCast(b.sublist(4, 4 + n));
          buf.clear();
          buf.add(b.sublist(4 + n));
          final j = m.json;
          log.add('${m.namespace.split('.').last}:${j['type']}');
          final id = j['requestId'];
          Map<String, dynamic> status() => {
            'type': 'RECEIVER_STATUS',
            'requestId': id,
            'status': {
              'applications': [
                if (appRunning)
                  {
                    'appId': 'CC1AD845',
                    'displayName': 'YouTube',
                    'sessionId': 'sess-1',
                    'transportId': 'tr-1',
                    'statusText': 'Casting',
                    'namespaces': [
                      {'name': nsMedia},
                    ],
                  },
              ],
              'volume': {'level': level, 'muted': muted},
            },
          };
          switch ('${m.namespace}/${j['type']}') {
            case '$nsReceiver/GET_STATUS':
              reply(m, status());
            case '$nsReceiver/SET_VOLUME':
              final v = j['volume'] as Map;
              if (v['level'] != null) level = (v['level'] as num).toDouble();
              if (v['muted'] != null) muted = v['muted'] as bool;
              reply(m, status());
            case '$nsReceiver/STOP':
              expect(j['sessionId'], 'sess-1');
              appRunning = false;
              reply(m, status());
            case '$nsMedia/GET_STATUS':
              expect(m.destination, 'tr-1');
              reply(m, {
                'type': 'MEDIA_STATUS',
                'requestId': id,
                'status': [
                  {
                    'mediaSessionId': 7,
                    'playerState': playerState,
                    'media': {
                      'metadata': {'title': 'Uutiset'},
                    },
                  },
                ],
              });
            case '$nsMedia/PAUSE':
            case '$nsMedia/PLAY':
              expect(j['mediaSessionId'], 7);
              playerState = j['type'] == 'PAUSE' ? 'PAUSED' : 'PLAYING';
              reply(m, {'type': 'MEDIA_STATUS', 'requestId': id, 'status': []});
          }
        }
      });
    });
    return this;
  }

  Future<void> stop() => server.close();
}

/// Simulated Samsung TV: REST info (8001), remote WebSocket (8002) and UPnP (9197) on one port.
class FakeSamsung {
  late HttpServer server;
  bool allow = true;
  String power = 'on';
  int volume = 12;
  bool muted = false;
  final keys = <String>[];
  String? tokenSeen;
  int get port => server.port;

  Future<FakeSamsung> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      if (r.uri.path == '/api/v2/') {
        r.response.write(
          jsonEncode({
            'name': '[TV] Olohuone',
            'device': {
              'name': '[TV] Olohuone',
              'modelName': 'QE55Q80B',
              'type': 'Samsung SmartTV',
              'wifiMac': 'aa:bb:cc:dd:ee:ff',
              'PowerState': power,
              'TokenAuthSupport': 'true',
            },
          }),
        );
        return r.response.close();
      }
      if (r.uri.path.startsWith('/upnp/control/RenderingControl1')) {
        final body = await utf8.decodeStream(r);
        final action = r.headers.value('soapaction') ?? '';
        if (action.contains('#SetVolume')) volume = int.parse(RegExp('<DesiredVolume>(\\d+)').firstMatch(body)![1]!);
        if (action.contains('#SetMute')) muted = body.contains('<DesiredMute>1');
        r.response.write(
          action.contains('#GetVolume')
              ? '<s:Envelope><s:Body><u:GetVolumeResponse><CurrentVolume>$volume</CurrentVolume></u:GetVolumeResponse></s:Body></s:Envelope>'
              : action.contains('#GetMute')
              ? '<s:Envelope><s:Body><u:GetMuteResponse><CurrentMute>${muted ? 1 : 0}</CurrentMute></u:GetMuteResponse></s:Body></s:Envelope>'
              : '<ok/>',
        );
        return r.response.close();
      }
      if (r.uri.path == '/api/v2/channels/samsung.remote.control') {
        expect(r.uri.queryParameters['name'], base64.encode(utf8.encode('Molaplan')));
        tokenSeen = r.uri.queryParameters['token'];
        final ws = await WebSocketTransformer.upgrade(r);
        ws.add(
          jsonEncode(
            allow
                ? {
                    'event': 'ms.channel.connect',
                    'data': {'token': '12345678'},
                  }
                : {'event': 'ms.channel.unauthorized'},
          ),
        );
        ws.listen((m) {
          final j = jsonDecode('$m') as Map;
          keys.add('${(j['params'] as Map)['DataOfCmd']}');
        });
        return;
      }
      r.response.statusCode = 404;
      await r.response.close();
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

/// Simulated LG webOS TV (SSAP over WebSocket).
class FakeLg {
  late HttpServer server;
  int volume = 8;
  bool muted = false;
  bool on = true;
  bool newFormat = true;
  final calls = <String>[];
  Map? lastManifest;
  int get port => server.port;

  Future<FakeLg> start() async {
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((r) async {
      final ws = await WebSocketTransformer.upgrade(r);
      ws.listen((m) async {
        final j = jsonDecode('$m') as Map;
        if (j['type'] == 'register') {
          final p = j['payload'] as Map;
          lastManifest = p['manifest'] as Map;
          if (p['client-key'] == null) {
            ws.add(
              jsonEncode({
                'type': 'response',
                'id': j['id'],
                'payload': {'pairingType': 'PROMPT', 'returnValue': true},
              }),
            );
            await Future<void>.delayed(const Duration(milliseconds: 100));
          }
          ws.add(
            jsonEncode({
              'type': 'registered',
              'id': j['id'],
              'payload': {'client-key': 'lg-key-1'},
            }),
          );
          return;
        }
        final uri = '${j['uri']}'.replaceFirst('ssap://', '');
        calls.add(uri);
        final p = (j['payload'] as Map?) ?? {};
        Map<String, dynamic> out = {'returnValue': true};
        switch (uri) {
          case 'system/getSystemInfo':
            out = {'modelName': 'OLED55C2'};
          case 'com.webos.service.connectionmanager/getinfo':
            out = {
              'wiredInfo': {'macAddress': '11:22:33:44:55:66'},
            };
          case 'com.webos.service.tvpower/power/getPowerState':
            out = {'state': on ? 'Active' : 'Suspend'};
          case 'audio/getVolume':
            out = newFormat
                ? {
                    'volumeStatus': {'volume': volume, 'muteStatus': muted},
                  }
                : {'volume': volume, 'muted': muted};
          case 'com.webos.applicationManager/getForegroundAppInfo':
            out = {'appId': 'netflix'};
          case 'audio/setVolume':
            volume = p['volume'] as int;
          case 'audio/setMute':
            muted = p['mute'] as bool;
          case 'system/turnOff':
            on = false;
        }
        ws.add(jsonEncode({'type': 'response', 'id': j['id'], 'payload': out}));
      });
    });
    return this;
  }

  Future<void> stop() => server.close(force: true);
}

ConnectionConfig mediaConn(Map<String, dynamic> s, [Map<String, String> sec = const {}]) =>
    ConnectionConfig(name: 'TV', type: 'media', settings: s, secrets: sec);

void main() {
  tearDown(() {
    CastChannel.secure = true;
    mediaTestBackend = null;
    samsungWsScheme = 'wss';
    samsungWsPort = 8002;
    samsungRestPort = 8001;
    samsungUpnpPort = 9197;
    lgUrls = (h) => ['wss://$h:3001', 'ws://$h:3000'];
    mediaHttp = () => http.Client();
  });

  group('Google Cast', () {
    test('CastMessage protobuf round trip', () {
      final m = CastMessage('sender-0', 'receiver-0', nsReceiver, '{"type":"GET_STATUS","requestId":1}');
      final b = encodeCast(m);
      expect(ByteData.sublistView(b).getUint32(0), b.length - 4);
      // protocol_version = 0 (field 1, varint) first.
      expect(b.sublist(4, 6), [0x08, 0x00]);
      final d = decodeCast(b.sublist(4));
      expect(
        [d.source, d.destination, d.namespace, d.json['type']],
        ['sender-0', 'receiver-0', nsReceiver, 'GET_STATUS'],
      );
      // Long payload (> 127 bytes) uses a multi-byte varint length.
      final long = CastMessage('a', 'b', nsMedia, jsonEncode({'x': 'y' * 300}));
      expect(decodeCast(encodeCast(long).sublist(4)).payload, long.payload);
    });

    test('status, volume, mute, pause and stop against a simulated receiver', () async {
      final tv = await FakeCast().start();
      addTearDown(tv.stop);
      CastChannel.secure = false;
      final d = createDriver(mediaConn({'brand': 'cast', 'address': '127.0.0.1', 'port': tv.port}));
      addTearDown(d.dispose);
      expect(await d.read({'media': 'status'}), 'YouTube – Uutiset');
      expect(await d.read({'media': 'volume'}), 30);
      expect(await d.read({'media': 'playing'}), 1);
      expect(tv.log, contains('connection:CONNECT'));
      expect(tv.log, contains('heartbeat:PONG'));
      await d.send({'media': 'volume', 'value': '{{value}}'}, value: 55);
      expect(tv.level, closeTo(0.55, 1e-9));
      await d.send({'media': 'mute', 'value': '1'});
      expect(tv.muted, isTrue);
      await d.send({'media': 'key', 'key': 'playpause'});
      expect(tv.playerState, 'PAUSED');
      expect(await d.read({'media': 'playing'}), 0);
      await d.send({'media': 'key', 'key': 'stop'});
      expect(tv.appRunning, isFalse);
      expect(await d.read({'media': 'status'}), isNot(contains('YouTube')));
      await expectLater(d.send({'media': 'power', 'value': '1'}), throwsA(isA<Exception>()));
    });
  });

  group('Samsung Tizen', () {
    test('pairing token, info, UPnP volume, keys, unauthorized', () async {
      final tv = await FakeSamsung().start();
      addTearDown(tv.stop);
      samsungWsScheme = 'ws';
      samsungWsPort = samsungRestPort = samsungUpnpPort = tv.port;
      final b = SamsungBackend({'address': '127.0.0.1'});
      final info = await b.info();
      expect(info.name, 'Olohuone');
      expect(info.mac, 'aa:bb:cc:dd:ee:ff');
      expect(info.extra['token'], '12345678');
      final b2 = SamsungBackend({'address': '127.0.0.1', 'token': '12345678', 'mac': info.mac});
      final st = await b2.state();
      expect([st.power, st.volume, st.muted], [true, 12, false]);
      await b2.setVolume(25);
      expect(tv.volume, 25);
      await b2.setMuted(true);
      expect(tv.muted, isTrue);
      await b2.key('playpause');
      await b2.setPower(false);
      await Future<void>.delayed(const Duration(milliseconds: 200));
      expect(tv.keys, ['KEY_PLAY', 'KEY_POWER']);
      expect(tv.tokenSeen, '12345678');
      tv.power = 'standby';
      expect((await b2.state()).power, isFalse);
      tv.allow = false;
      await expectLater(b2.key('home'), throwsA(isA<MediaAuthError>()));
    });
  });

  group('LG webOS', () {
    test('PROMPT pairing returns a client key; volume, mute, app, power off', () async {
      final tv = await FakeLg().start();
      addTearDown(tv.stop);
      lgUrls = (h) => ['ws://127.0.0.1:1', 'ws://$h:${tv.port}'];
      final info = await LgBackend({'address': '127.0.0.1'}).info();
      expect(info.extra['clientKey'], 'lg-key-1');
      expect(info.mac, '11:22:33:44:55:66');
      expect(tv.lastManifest!['permissions'], contains('CONTROL_POWER'));
      final b = LgBackend({'address': '127.0.0.1', 'clientKey': 'lg-key-1'});
      var st = await b.state();
      expect([st.power, st.volume, st.muted, st.app], [true, 8, false, 'netflix']);
      tv.newFormat = false;
      st = await b.state();
      expect(st.volume, 8);
      await b.setVolume(20);
      await b.setMuted(true);
      expect([tv.volume, tv.muted], [20, true]);
      await b.key('pause');
      expect(tv.calls, contains('media.controls/pause'));
      await b.setPower(false);
      expect(tv.on, isFalse);
      expect((await b.state()).power, isFalse);
    });
  });

  group('Philips JointSPACE', () {
    test('v6 PIN pairing (HMAC signature) then digest-authenticated volume and power', () async {
      const user = 'dev1';
      var pairedUser = '', pairedKey = '';
      var volume = 20, power = 'On', muted = false;
      final seen = <String>[];
      mediaHttp = () => MockClient((r) async {
        seen.add('${r.method} ${r.url}');
        final path = r.url.path;
        if (path == '/6/system') {
          return http.Response(
            jsonEncode({
              'name': 'Philips OLED',
              'api_version': {'Major': 6},
              'featuring': {
                'systemfeatures': {'pairing_type': 'digest_auth_pairing'},
              },
              'serialnumber_encrypted': _enc('SN123'),
            }),
            200,
          );
        }
        if (path == '/6/pair/request') {
          final b = jsonDecode(r.body) as Map;
          expect((b['access'] as Map)['scope'], ['read', 'write', 'control']);
          pairedUser = '${(b['device'] as Map)['id']}';
          return http.Response(jsonEncode({'error_id': 'SUCCESS', 'auth_key': 'k3y', 'timestamp': 1700}), 200);
        }
        // Everything else needs digest auth.
        final a = r.headers['Authorization'];
        if (a == null) {
          return http.Response('', 401, headers: {'www-authenticate': 'Digest realm="XTV", nonce="n1", qop="auth"'});
        }
        final u = RegExp('username="([^"]+)"').firstMatch(a)![1]!;
        final cn = RegExp('cnonce="([^"]+)"').firstMatch(a)![1]!;
        final pw = u == pairedUser ? (pairedKey.isEmpty ? 'k3y' : pairedKey) : '';
        final exp = digestExpected(
          algorithm: 'MD5',
          username: u,
          realm: 'XTV',
          password: pw,
          method: r.method,
          uri: path,
          nonce: 'n1',
          nc: '00000001',
          cnonce: cn,
        );
        if (!a.contains('response="$exp"')) return http.Response('', 401);
        if (path == '/6/pair/grant') {
          final b = jsonDecode(r.body) as Map;
          final auth = b['auth'] as Map;
          final sig = base64.encode(
            c.Hmac(c.sha1, philipsSharedKey).convert(utf8.encode('${auth['auth_timestamp']}${auth['pin']}')).bytes,
          );
          if (auth['pin'] != '4321' || auth['auth_signature'] != sig) {
            return http.Response(jsonEncode({'error_id': 'INVALID_PIN'}), 200);
          }
          pairedKey = 'k3y';
          return http.Response(jsonEncode({'error_id': 'SUCCESS'}), 200);
        }
        if (path == '/6/audio/volume') {
          if (r.method == 'POST') {
            final b = jsonDecode(r.body) as Map;
            volume = b['current'] as int;
            muted = b['muted'] as bool;
            return http.Response('', 200);
          }
          return http.Response(jsonEncode({'current': volume, 'min': 0, 'max': 60, 'muted': muted}), 200);
        }
        if (path == '/6/powerstate') {
          if (r.method == 'POST') {
            power = (jsonDecode(r.body) as Map)['powerstate'] as String;
            return http.Response('', 200);
          }
          return http.Response(jsonEncode({'powerstate': power}), 200);
        }
        if (path == '/6/input/key') return http.Response('', 200);
        return http.Response('', 404);
      });
      final p = mediaProviderById('media_philips')!;
      final cand = Candidate(provider: p.id, address: '10.0.0.5');
      final ctx = AddContext(driver: createDriver);
      await expectLater(
        p.connect(ctx, cand, const {}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.needsDetails)),
      );
      expect(philipsPending.containsKey('10.0.0.5'), isTrue);
      await expectLater(
        p.connect(ctx, cand, const {'pin': '9999'}),
        throwsA(isA<AddDeviceError>().having((e) => e.problem, 'p', AddProblem.wrongPassword)),
      );
      final r = await p.connect(ctx, cand, const {'pin': '4321'});
      expect(r.connection.settings['username'], pairedUser);
      expect(r.connection.secrets['password'], 'k3y');
      expect(r.connection.settings['api'], 6);
      expect(r.label, 'Philips OLED');
      final tiles = p.tiles(r);
      expect(tiles.map((t) => t.type), [
        TileType.value,
        TileType.toggle,
        TileType.slider,
        TileType.toggle,
        TileType.button,
        TileType.button,
      ]);
      final d = createDriver(r.connection);
      addTearDown(d.dispose);
      expect(await d.read(tiles[2].read), 33); // 20 / 60
      await d.send(tiles[2].commands.single.spec, value: 50);
      expect(volume, 30);
      await d.send(tiles[1].offCommand!.spec);
      expect(power, 'Standby');
      expect(await d.read({'media': 'power'}), 0);
      expect(philipsDecode(_enc('SN123')), 'SN123');
      expect(user, isNotEmpty);
    });

    test('v1 (old sets): plain http 1925, no login', () async {
      mediaHttp = () => MockClient((r) async {
        if (r.url.port == 1926) throw const SocketException('refused');
        if (r.url.path == '/1/system') {
          return http.Response(
            jsonEncode({
              'name': '42PFL',
              'api_version': {'Major': 1},
            }),
            200,
          );
        }
        if (r.url.path == '/1/audio/volume') {
          return http.Response(jsonEncode({'current': 30, 'max': 60, 'muted': false}), 200);
        }
        return http.Response('', 404);
      });
      final (api, sys) = await PhilipsBackend.detect('10.0.0.6');
      expect(api, 1);
      expect(PhilipsBackend.needsPairing(sys), isFalse);
      final st = await PhilipsBackend({'address': '10.0.0.6', 'api': 1}).state();
      expect([st.power, st.volume], [true, 50]);
    });
  });

  group('Wake-on-LAN', () {
    test('magic packet = 6×FF + 16×MAC, sent over UDP', () async {
      final p = magicPacket('AA:BB:CC:DD:EE:FF');
      expect(p.length, 102);
      expect(p.sublist(0, 6), List.filled(6, 0xFF));
      expect(p.sublist(96), [0xAA, 0xBB, 0xCC, 0xDD, 0xEE, 0xFF]);
      expect(() => magicPacket('nope'), throwsArgumentError);
      final rx = await RawDatagramSocket.bind(InternetAddress.loopbackIPv4, 0);
      addTearDown(rx.close);
      wolTarget = InternetAddress.loopbackIPv4;
      wolPort = rx.port;
      addTearDown(() {
        wolTarget = InternetAddress('255.255.255.255');
        wolPort = 9;
      });
      final got = Completer<List<int>>();
      rx.listen((e) {
        final dg = rx.receive();
        if (dg != null && !got.isCompleted) got.complete(dg.data);
      });
      await wakeOnLan('aa-bb-cc-dd-ee-ff');
      expect(await got.future.timeout(const Duration(seconds: 2)), p);
    });
  });

  group('wizard provider', () {
    test('Cast: found with mDNS, connect lists one TV with media tiles', () async {
      final fake = _FakeBackend();
      mediaTestBackend = (s) => fake..s.addAll(s);
      final p = mediaProviderById('media_cast')!;
      final cand = p.fromMdns(
        '192.168.1.40:8009',
        'Chromecast-Ultra-0123456789abcdef0123456789abcdef',
        '_googlecast._tcp',
      )!;
      expect(cand.address, '192.168.1.40');
      expect(cand.name, 'Chromecast Ultra');
      expect(p.pairMode, PairMode.none);
      final r = await p.connect(AddContext(driver: createDriver), cand, const {});
      expect(r.items.single.subtitle, 'Kodi – Elokuva');
      final tiles = p.tiles(r);
      // No power tile: a Chromecast has no power state.
      expect(tiles.map((t) => t.read['media'] ?? t.commands.firstOrNull?.spec['key']), [
        'status',
        'volume',
        'muted',
        'playpause',
        'stop',
      ]);
      expect(tiles.every((t) => t.connectionId == r.connection.id), isTrue);
    });

    test('Samsung / LG use the "accept on the TV" countdown and save the key as a secret', () async {
      final fake = _FakeBackend(
        extra: {'clientKey': 'K1'},
        caps: {'power', 'volume', 'mute'},
        mac: '11:22:33:44:55:66',
      );
      mediaTestBackend = (s) => fake..s.addAll(s);
      final p = mediaProviderById('media_lg')!;
      expect(p.pairMode, PairMode.button);
      final cand = Candidate(provider: p.id, address: '192.168.1.41');
      final ticks = <int>[];
      final creds = await p.pair(AddContext(driver: createDriver), cand, tick: ticks.add);
      expect(creds['token'], 'K1');
      expect(ticks.first, 40);
      final r = await p.connect(AddContext(driver: createDriver), cand, creds);
      expect(r.connection.secrets['clientKey'], 'K1');
      expect(r.connection.settings['mac'], '11:22:33:44:55:66');
      expect(r.connection.settings.containsKey('clientKey'), isFalse);
      expect(p.tiles(r).map((t) => t.type), [TileType.value, TileType.toggle, TileType.slider, TileType.toggle]);
    });

    test('registries: chooser card, providers and driver type', () {
      expect(deviceProviders.whereType<MediaChooser>(), hasLength(1));
      for (final id in ['media_cast', 'media_samsung', 'media_lg', 'media_philips']) {
        expect(providerById(id), isA<MediaProvider>());
      }
      expect(descriptorFor('media').type, 'media');
      expect(MediaChooser().keywords, containsAll(['chromecast', 'samsung', 'webos', 'philips', 'android tv']));
      expect(mediaNotYet, isNotEmpty);
    });
  });
}

String _enc(String s) {
  final iv = List<int>.generate(16, (i) => i);
  return base64.encode([...iv, ...aesCbcEncrypt(philipsSharedKey.sublist(0, 16), iv, utf8.encode(s))]);
}

class _FakeBackend extends MediaBackend {
  _FakeBackend({this.extra = const {}, this.caps = const {'volume', 'mute', 'playpause', 'stop'}, this.mac = ''})
    : super(<String, dynamic>{});
  final Map<String, String> extra;
  final Set<String> caps;
  final String mac;
  @override
  Future<MediaInfo> info() async => MediaInfo(name: 'Olohuoneen TV', caps: caps, mac: mac, extra: extra);
  @override
  Future<MediaState> state() async => MediaState(app: 'Kodi', title: 'Elokuva', volume: 10);
  @override
  Future<void> key(String key) async {}
  @override
  Future<void> setMuted(bool muted) async {}
  @override
  Future<void> setPower(bool on) async {}
  @override
  Future<void> setVolume(num level) async {}
}
