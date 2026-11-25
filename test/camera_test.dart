import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:image/image.dart' as img;
import 'package:molaplan/devices/cameras.dart';
import 'package:molaplan/devices/onvif.dart';
import 'package:molaplan/devices/registry.dart';
import 'package:molaplan/devices/rtsp_probe.dart';
import 'package:molaplan/drivers/camera_driver.dart';
import 'package:molaplan/drivers/digest_auth.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/remote/executor.dart';

final jpeg = Uint8List.fromList(img.encodeJpg(img.Image(width: 32, height: 24)));

String md5s(String s) => md5.convert(utf8.encode(s)).toString();

/// Checks an `Authorization: Digest` header like a camera does (MD5, qop=auth).
bool digestOk(String? header, String method, String user, String pw, String realm, String nonce) {
  final ch = DigestChallenge.parse(header?.replaceFirst('Digest', 'Digest '));
  if (ch == null) return false;
  final p = ch.params;
  if (p['username'] != user) return false;
  return p['response'] ==
      digestExpected(
        algorithm: 'MD5',
        username: user,
        realm: realm,
        password: pw,
        method: method,
        uri: p['uri']!,
        nonce: nonce,
        nc: p['nc']!,
        cnonce: p['cnonce']!,
      );
}

/// A Hikvision-like HTTP camera with Digest login; [handler] serves the paths.
Future<HttpServer> digestServer(
  String user,
  String pw,
  Future<void> Function(HttpRequest req, String body) handler,
) async {
  final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
  s.listen((req) async {
    final body = await utf8.decoder.bind(req).join();
    if (!digestOk(req.headers.value('authorization'), req.method, user, pw, 'IP Camera', 'abc123')) {
      req.response
        ..statusCode = 401
        ..headers.set('WWW-Authenticate', 'Digest realm="IP Camera", qop="auth", nonce="abc123", algorithm=MD5');
      await req.response.close();
      return;
    }
    await handler(req, body);
  });
  return s;
}

AddContext ctx() => AddContext(driver: CameraDriver.new);

Matcher problem(AddProblem p) => throwsA(isA<AddDeviceError>().having((e) => e.problem, 'problem', p));

void main() {
  test('one camera card; every brand has a provider for the bridge search', () {
    expect(deviceProviders.whereType<CameraChooser>().length, 1);
    for (final id in ['hikvision', 'dahua', 'reolink', 'tapo', 'ezviz', 'onvif']) {
      expect(providerById('camera_$id'), isA<CameraProvider>(), reason: id);
    }
    expect(CameraChooser().keywords, containsAll(['hikvision', 'tapo', 'reolink', 'onvif']));
  });

  test('Hikvision: password asked, Digest snapshot checked, picture tile + RTSP with the login filled in', () async {
    final s = await digestServer('admin', 'Salasana1', (req, _) async {
      expect(req.uri.path, '/ISAPI/Streaming/channels/101/picture');
      req.response.add(jpeg);
      await req.response.close();
    });
    addTearDown(() => s.close(force: true));
    final p = CameraProvider(cameraPresetById('hikvision')!);
    final c = Candidate(provider: p.id, address: '127.0.0.1:${s.port}', name: 'Piha');
    await expectLater(p.connect(ctx(), c, {}), problem(AddProblem.needsPassword));
    await expectLater(p.connect(ctx(), c, {'password': 'väärä'}), problem(AddProblem.wrongPassword));
    final r = await p.connect(ctx(), c, {'password': 'Salasana1'});
    expect(r.connection.type, 'camera');
    expect(r.connection.settings['auth'], 'digest');
    expect(r.connection.secrets['password'], 'Salasana1');
    final t = p.tiles(r).single;
    expect(t.type, TileType.camera);
    expect(t.title, 'Piha');
    expect(t.read, {'mode': 'snapshot', 'path': '/ISAPI/Streaming/channels/101/picture', 'refreshSeconds': 2});
    final d = CameraDriver(r.connection);
    expect(d.rtspUrl(), 'rtsp://admin:Salasana1@127.0.0.1:554/Streaming/Channels/101');
    expect(d.rtspUrl(sub: true), endsWith('/Streaming/Channels/102'));
    // The tile's own snapshot goes through the same Digest login.
    expect(await d.snapshot(t.read['path'] as String), jpeg);
  });

  test('Reolink: login in the query; a refused login (HTTP 200 JSON) means wrong password', () async {
    final s = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    s.listen((req) async {
      final q = req.uri.queryParameters;
      if (q['user'] == 'admin' && q['password'] == 'p&ss w') {
        req.response.add(jpeg);
      } else {
        req.response.write('[{"cmd":"Snap","code":1,"error":{"detail":"login failed","rspCode":-6}}]');
      }
      await req.response.close();
    });
    addTearDown(() => s.close(force: true));
    final p = CameraProvider(cameraPresetById('reolink')!);
    final c = Candidate(provider: p.id, address: '127.0.0.1:${s.port}');
    await expectLater(p.connect(ctx(), c, {'password': 'nope'}), problem(AddProblem.wrongPassword));
    final r = await p.connect(ctx(), c, {'password': 'p&ss w'});
    expect(p.tiles(r).single.read['mode'], 'snapshot');
    expect(r.connection.settings['auth'], 'none');
  });

  test('Tapo: camera account user + password, checked with RTSP; live-only tile', () async {
    var code = 401;
    final urls = <String>[];
    final p = CameraProvider(
      cameraPresetById('tapo')!,
      rtspCheck: (u) async {
        urls.add(u);
        return code;
      },
    );
    final c = Candidate(provider: p.id, address: '192.168.1.80');
    await expectLater(
      p.connect(ctx(), c, {'password': 'x'}),
      problem(AddProblem.needsPassword),
      reason: 'no default user',
    );
    await expectLater(p.connect(ctx(), c, {'username': 'kamera', 'password': 'x'}), problem(AddProblem.wrongPassword));
    code = 200;
    final r = await p.connect(ctx(), c, {'username': 'kamera', 'password': 'hyvä @salasana'});
    expect(urls.last, 'rtsp://kamera:hyv%C3%A4%20%40salasana@192.168.1.80:554/stream1');
    expect(p.tiles(r).single.read, {'mode': 'rtsp'});
    expect(r.items.single.subtitle, contains('kotiverkossa'));
    // Through the home bridge the RTSP check is skipped (the phone cannot reach it).
    code = 401;
    final viaBridge = Candidate(provider: p.id, address: '192.168.1.80', viaBridge: true);
    expect((await p.connect(ctx(), viaBridge, {'username': 'kamera', 'password': 'x'})).items, hasLength(1));
  });

  test('generic ONVIF: WS-Security login, profiles, stream + snapshot addresses', () async {
    late HttpServer s;
    String? created, nonce;
    String soap(String body) =>
        '<?xml version="1.0"?><s:Envelope xmlns:s="http://www.w3.org/2003/05/soap-envelope"><s:Body>$body</s:Body></s:Envelope>';
    s = await digestServer('admin', 'kamera1', (req, body) async {
      if (req.uri.path == '/snap.jpg') {
        req.response.add(jpeg);
        await req.response.close();
        return;
      }
      // WS-Security: digest = base64(sha1(nonce + created + password)).
      nonce = RegExp(r'<Nonce[^>]*>([^<]+)</Nonce>').firstMatch(body)?.group(1);
      created = RegExp(r'<Created[^>]*>([^<]+)</Created>').firstMatch(body)?.group(1);
      final pw = RegExp(r'<Password[^>]*>([^<]+)</Password>').firstMatch(body)?.group(1);
      final want = base64Encode(
        sha1.convert([...base64Decode(nonce!), ...utf8.encode(created!), ...utf8.encode('kamera1')]).bytes,
      );
      req.response.headers.contentType = ContentType('application', 'soap+xml');
      if (pw != want) {
        req.response.statusCode = 400;
        req.response.write(
          soap('<s:Fault><s:Code><s:Subcode><s:Value>ter:NotAuthorized</s:Value></s:Subcode></s:Code></s:Fault>'),
        );
      } else if (body.contains('GetDeviceInformation')) {
        req.response.write(
          soap(
            '<tds:GetDeviceInformationResponse><tds:Manufacturer>Uniview</tds:Manufacturer><tds:Model>IPC2124</tds:Model></tds:GetDeviceInformationResponse>',
          ),
        );
      } else if (body.contains('GetCapabilities')) {
        req.response.write(
          soap(
            '<tds:Capabilities><tt:Media><tt:XAddr>http://127.0.0.1:${s.port}/onvif/media</tt:XAddr></tt:Media></tds:Capabilities>',
          ),
        );
      } else if (body.contains('GetProfiles')) {
        expect(req.uri.path, '/onvif/media');
        req.response.write(
          soap(
            '<trt:Profiles token="main" fixed="true"><tt:Name>main</tt:Name></trt:Profiles><trt:Profiles token="sub"></trt:Profiles>',
          ),
        );
      } else if (body.contains('GetStreamUri')) {
        final sub = body.contains('>sub<');
        req.response.write(
          soap(
            '<trt:MediaUri><tt:Uri>rtsp://127.0.0.1:554/media/video${sub ? 2 : 1}?a=1&amp;b=2</tt:Uri></trt:MediaUri>',
          ),
        );
      } else if (body.contains('GetSnapshotUri')) {
        req.response.write(soap('<trt:MediaUri><tt:Uri>http://127.0.0.1:${s.port}/snap.jpg</tt:Uri></trt:MediaUri>'));
      }
      await req.response.close();
    });
    addTearDown(() => s.close(force: true));
    final p = CameraProvider(cameraPresetById('onvif')!);
    final c = Candidate(provider: p.id, address: '127.0.0.1', id: ':${s.port}/onvif/device_service');
    await expectLater(p.connect(ctx(), c, {'password': 'väärä'}), problem(AddProblem.wrongPassword));
    final r = await p.connect(ctx(), c, {'password': 'kamera1'});
    expect(r.label, 'Uniview IPC2124');
    expect(r.connection.settings['rtsp'], 'rtsp://{{host}}:554/media/video1?a=1&b=2');
    expect(r.connection.settings['rtspSub'], 'rtsp://{{host}}:554/media/video2?a=1&b=2');
    expect(p.tiles(r).single.read['path'], ':${s.port}/snap.jpg');
    expect(CameraDriver(r.connection).rtspUrl(), 'rtsp://admin:kamera1@127.0.0.1:554/media/video1?a=1&b=2');
  });

  test('WS-Discovery answer: address, name, brand guess', () {
    const xml =
        '<SOAP-ENV:Envelope><SOAP-ENV:Body><d:ProbeMatches><d:ProbeMatch><d:Scopes>onvif://www.onvif.org/type/video_encoder '
        'onvif://www.onvif.org/name/HIKVISION%20DS-2CD2143G2 onvif://www.onvif.org/hardware/DS-2CD2143G2-I</d:Scopes>'
        '<d:XAddrs>http://[fe80::1]/onvif/device_service http://192.168.1.64/onvif/device_service</d:XAddrs>'
        '</d:ProbeMatch></d:ProbeMatches></SOAP-ENV:Body></SOAP-ENV:Envelope>';
    final f = parseProbeMatch(xml)!;
    expect(f.host, '192.168.1.64');
    expect(f.name, 'HIKVISION DS-2CD2143G2');
    expect(f.brand, 'hikvision');
    expect(guessCameraBrand('TP-IPC C200'), 'tapo');
    expect(guessCameraBrand('Dahua IPC-HFW'), 'dahua');
    expect(onvifProbeMessage('x'), contains('NetworkVideoTransmitter'));
    expect(rtspTemplate('rtsp://u:p@192.168.1.64:554/s', '192.168.1.64'), 'rtsp://{{host}}:554/s');
  });

  test('ONVIF search filters by brand (Hikvision list hides a Tapo)', () async {
    Future<List<OnvifFound>> found() async => [
      OnvifFound(xaddr: 'http://192.168.1.64/onvif/device_service', scopes: ['onvif://www.onvif.org/name/HIKVISION']),
      OnvifFound(xaddr: 'http://192.168.1.80:2020/onvif/device_service', scopes: ['onvif://www.onvif.org/name/TP-IPC']),
      OnvifFound(xaddr: 'http://192.168.1.90:8899/onvif/device_service'),
    ];
    final hik = await CameraProvider(cameraPresetById('hikvision')!, discover: found).scan(const []);
    expect(hik.map((c) => c.address), ['192.168.1.64', '192.168.1.90']);
    final any = await CameraProvider(cameraPresetById('onvif')!, discover: found).scan(const []);
    expect(any.map((c) => c.id), ['', ':2020/onvif/device_service', ':8899/onvif/device_service']);
  });

  test('RTSP DESCRIBE with a Digest login (as cameras ask)', () async {
    final srv = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
    addTearDown(srv.close);
    srv.listen((sock) {
      final lines = <String>[];
      sock.cast<List<int>>().transform(utf8.decoder).transform(const LineSplitter()).listen((l) {
        if (l.isNotEmpty) {
          lines.add(l);
          return;
        }
        final cseq = lines.firstWhere((x) => x.startsWith('CSeq')).split(':')[1].trim();
        final auth = lines.where((x) => x.startsWith('Authorization:')).firstOrNull;
        final req = lines.first.split(' ')[1];
        var ok = false;
        if (auth != null) {
          final p = DigestChallenge.parse(auth.substring(14))!.params;
          final ha1 = md5s('cam:Live Camera:pw1');
          final ha2 = md5s('DESCRIBE:$req');
          ok = p['response'] == md5s('$ha1:n0nce:$ha2') && p['uri'] == req;
        }
        sock.write(
          ok
              ? 'RTSP/1.0 200 OK\r\nCSeq: $cseq\r\nContent-Type: application/sdp\r\nContent-Length: 5\r\n\r\nv=0\r\n'
              : 'RTSP/1.0 401 Unauthorized\r\nCSeq: $cseq\r\nWWW-Authenticate: Digest realm="Live Camera", nonce="n0nce"\r\n\r\n',
        );
        lines.clear();
      });
    });
    expect(await rtspDescribe('rtsp://cam:pw1@127.0.0.1:${srv.port}/stream1'), 200);
    expect(await rtspDescribe('rtsp://cam:wrong@127.0.0.1:${srv.port}/stream1'), 401);
  });

  test('a big camera picture is shrunk for the relay instead of failing', () async {
    final big = img.Image(width: 2560, height: 1440);
    for (var y = 0; y < big.height; y++) {
      for (var x = 0; x < big.width; x++) {
        big.setPixelRgb(x, y, (x * 7 + y * 13) % 256, (x * y) % 256, (x ^ y) % 256);
      }
    }
    final bytes = Uint8List.fromList(img.encodeJpg(big, quality: 100));
    expect(bytes.length, greaterThan(maxRemoteImageBytes));
    final small = (await shrinkForRemote(bytes))!;
    expect(small.length, lessThanOrEqualTo(maxRemoteImageBytes));
    expect(img.decodeJpg(small)!.width, lessThanOrEqualTo(1280));
  });

  test('RTSP address helper: no login, own login in the URL, {{host}} from the base URL', () {
    expect(cameraRtspUrl({'baseUrl': 'http://10.0.0.5', 'rtsp': 'rtsp://{{host}}/x'}), 'rtsp://10.0.0.5/x');
    expect(
      cameraRtspUrl({'baseUrl': 'http://10.0.0.5', 'rtsp': 'rtsp://a:b@{{host}}/x', 'username': 'u', 'password': 'p'}),
      'rtsp://a:b@10.0.0.5/x',
    );
    expect(cameraRtspUrl({'baseUrl': 'http://10.0.0.5'}), isNull);
  });
}
