// t132u/t133u: Home Assistant address resolution, plain errors, duplicate merging.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/core/discovery.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/devices/ha_setup.dart';
import 'package:molaplan/devices/scanner.dart';

const _manifest = '{"name":"Home Assistant","short_name":"Home Assistant"}';

void main() {
  widgetTests();
  test('t138u: empty integration-named views are removed, views with tiles stay', () {
    final cfg = AppConfig(
      connections: [ConnectionConfig(name: 'Home Assistant', type: 'homeassistant')],
      dashboards: [
        Dashboard(
          name: 'Koti',
          tiles: [TileConfig(type: TileType.toggle, title: 'x')],
        ),
        Dashboard(name: 'HA'),
        Dashboard(
          name: 'Pannuhuone',
          tiles: [TileConfig(type: TileType.toggle, title: 'y')],
        ),
        Dashboard(name: 'Home Assistant'),
        Dashboard(name: 'Oma tyhjä'),
      ],
    );
    expect(removeEmptyIntegrationViews(cfg), isTrue);
    expect([for (final d in cfg.dashboards) d.name], ['Koti', 'Pannuhuone', 'Oma tyhjä']);
    expect(removeEmptyIntegrationViews(AppConfig(dashboards: [Dashboard(name: 'HA')])), isFalse);
  });
  test('candidates: bare LAN address → http then https on 8123; Nabu Casa → https first', () {
    expect(haCandidates('192.168.50.1:8123'), ['http://192.168.50.1:8123', 'https://192.168.50.1:8123']);
    expect(haCandidates('homeassistant.local'), [
      'http://homeassistant.local:8123',
      'https://homeassistant.local:8123',
    ]);
    expect(haCandidates('https://192.168.1.20:8123/lovelace/0'), [
      'https://192.168.1.20:8123',
      'http://192.168.1.20:8123',
    ]);
    expect(haCandidates('abcd1234.ui.nabu.casa').first, 'https://abcd1234.ui.nabu.casa');
    expect(haCandidates('https://abcd1234.ui.nabu.casa/'), [
      'https://abcd1234.ui.nabu.casa',
      'http://abcd1234.ui.nabu.casa',
    ]);
  });

  test('https HA with a self-signed cert on the LAN: http fails with "Invalid response line", https works', () async {
    final used = <String>[];
    http.Client clients(bool ss) => MockClient((r) async {
      used.add('${r.url.scheme}${ss ? '+ss' : ''}');
      if (r.url.scheme == 'http') throw http.ClientException('Invalid response line', r.url);
      if (!ss) throw http.ClientException('HandshakeException: CERTIFICATE_VERIFY_FAILED', r.url);
      return http.Response('{"message":"API running."}', 200);
    });
    final res = await probeHomeAssistant('192.168.50.10:8123', 'tok', clients: clients);
    expect(res.baseUrl, 'https://192.168.50.10:8123');
    expect(res.selfSigned, isTrue);
    expect(used, ['http', 'https', 'https+ss']);
  });

  test('plain errors: wrong service, bad token, unreachable – never "Jokin meni pieleen"', () async {
    Future<HaSetupError> err(Future<http.Response> Function(http.Request r) h, [String a = '192.168.50.1:8123']) async {
      try {
        await probeHomeAssistant(a, 'tok', clients: (_) => MockClient(h));
      } on HaSetupError catch (e) {
        return e;
      }
      throw StateError('expected an error');
    }

    final proto = await err((r) async => throw http.ClientException('Invalid response line', r.url));
    expect(proto.problem, HaProblem.wrongProtocol);
    final f = friendlyError(proto, 'fi');
    expect(f.title, 'Osoitteessa ei vastaa Home Assistant – tarkista osoite (http vai https?)');
    expect(f.title, isNot(contains('Jokin meni pieleen')));

    final tok = await err((r) async => http.Response('401: Unauthorized', 401));
    expect(friendlyError(tok, 'fi').title, 'Tunnus ei kelpaa');

    final down = await err((r) async => throw http.ClientException('Connection refused', r.url));
    expect(friendlyError(down, 'fi').title, 'Laitetta ei tavoitettu');

    // A router answering 404 on 8123 is "not HA" (wrong address), not a token problem.
    final router = await err((r) async => http.Response('<html>router</html>', 404));
    expect(router.problem, HaProblem.wrongProtocol);
  });

  test('generic errors: invalid response line → readable, unknown is never bare', () {
    final f = friendlyError(
      Exception('ClientException: Invalid response line, uri=http://192.168.50.1:8123/api/'),
      'fi',
    );
    expect(f.kind, ErrorKind.wrongProtocol);
    expect(f.title, contains('http vai https'));
    expect(friendlyError(Exception('weird'), 'fi').title, isNot('Jokin meni pieleen'));
  });

  test('discovery: three records of one HA collapse to one entry, the answering LAN IP preselected', () async {
    final seen = [
      HaSighting(
        ip: '192.168.50.1',
        host: 'homeassistant.local.',
        txt: {'uuid': 'u1', 'location_name': 'Koti', 'external_url': 'https://abc.ui.nabu.casa'},
      ),
      HaSighting(ip: '192.168.50.20', host: 'homeassistant.local.', txt: {'uuid': 'u1', 'location_name': 'Koti'}),
      HaSighting(ip: '172.30.32.1', host: 'homeassistant.local.', txt: {'uuid': 'u1'}),
    ];
    final g = groupHaSightings(seen);
    expect(g, hasLength(1));
    expect(g.first.name, 'Koti');
    final res = await resolveHaInstances(
      g,
      clients: (_) => MockClient((r) async {
        // Only the real HA box answers; .1 is the router.
        if (r.url.host == '192.168.50.20' && r.url.path == '/manifest.json') return http.Response(_manifest, 200);
        return http.Response('nope', 404);
      }),
    );
    expect(res, hasLength(1));
    expect(res.first.best, 'http://192.168.50.20:8123');
    expect(res.first.ordered.last, 'https://abc.ui.nabu.casa');
  });

  test('discovery without uuid: duplicates confirmed by /api/discovery_info merge; non-HA dropped', () async {
    final g = groupHaSightings([
      HaSighting(ip: '192.168.50.20'),
      HaSighting(ip: '192.168.50.21'),
      HaSighting(ip: '192.168.50.1'),
    ]);
    expect(g, hasLength(3));
    final res = await resolveHaInstances(
      g,
      clients: (_) => MockClient((r) async {
        if (r.url.path == '/api/discovery_info' && r.url.host != '192.168.50.1') {
          return http.Response('{"uuid":"u9","location_name":"Mökki"}', 200);
        }
        return http.Response('nope', 404);
      }),
    );
    expect(res, hasLength(1));
    expect(res.first.name, 'Mökki');
  });

  test('scanner: port-forwarded 8123 on the router is not HA; same-uuid hits collapse', () async {
    final all = {
      '192.168.50.1': ScanHit(ip: '192.168.50.1', kind: 'homeassistant', port: 8123, via: {'port'}, role: 'router'),
      '192.168.50.20': ScanHit(ip: '192.168.50.20', kind: 'homeassistant', port: 8123, via: {'mDNS'})..haUuid = 'u1',
      '172.30.32.1': ScanHit(ip: '172.30.32.1', kind: 'homeassistant', port: 8123, via: {'mDNS'})..haUuid = 'u1',
    };
    await dedupeHaHits(all, confirm: (ip, port) async => false);
    expect(
      [
        for (final h in all.values)
          if (h.kind == 'homeassistant') h.ip,
      ],
      ['192.168.50.20'],
    );
    expect(all['192.168.50.1']!.kind, 'unknown');
  });
}

Future<AppState> _st() async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  return st;
}

Widget _page(AppState st, TemplateSetupPage p) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: p),
);

void widgetTests() {
  testWidgets('HA form: the wrong 192.168.50.1:8123 gives the plain HA message, not "Jokin meni pieleen"', (
    tester,
  ) async {
    final st = await _st();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(
        st,
        TemplateSetupPage(
          template: templateById('homeassistant')!,
          initialValues: const {'address': '192.168.50.1:8123', 'token': 'tok'},
          haProbe: (a, t, {more = const []}) async =>
              throw HaSetupError(HaProblem.wrongProtocol, 'Invalid response line'),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('template-add')));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.textContaining('Osoitteessa ei vastaa Home Assistant'), findsOneWidget);
    expect(find.textContaining('Jokin meni pieleen'), findsNothing);
    expect(st.config.connections, isEmpty);
  });

  testWidgets('HA form: "Etsi verkosta" shows ONE instance and fills the URL that answers', (tester) async {
    final st = await _st();
    tester.view.physicalSize = const Size(800, 3000);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(
      _page(
        st,
        TemplateSetupPage(
          template: templateById('homeassistant')!,
          discover: ({services = const [], timeout = const Duration(seconds: 4), onRecord}) async {
            for (final ip in ['192.168.50.1', '192.168.50.20']) {
              onRecord?.call(
                FoundDevice(
                  name: 'Koti._home-assistant._tcp.local',
                  service: '_home-assistant._tcp',
                  host: 'homeassistant.local.',
                  ip: ip,
                  port: 8123,
                ),
                {'uuid': 'u1', 'location_name': 'Koti'},
              );
            }
            return (const <FoundDevice>[], null);
          },
          haResolve: (found) async {
            expect(found, hasLength(1));
            return [found.first..best = 'http://192.168.50.20:8123'];
          },
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.text('Etsi verkosta'));
    await tester.pump(const Duration(milliseconds: 100));
    expect(find.text('http://192.168.50.20:8123'), findsOneWidget);
    expect(find.byKey(const ValueKey('ha-note')), findsOneWidget);
  });
}
