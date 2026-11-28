// t344u / t346u: HA routes (local + Tailscale + remote), token reuse, guide.
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/devices/ha_routes.dart';
import 'package:molaplan/devices/ha_setup.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/migrations.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/guides_page.dart';
import 'package:molaplan/ui/ha_picker.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/drivers/ha_catalog.dart';

void main() {
  widgetTests();
  group('classify and candidates', () {
    test('LAN, Tailscale CGNAT / ts.net, Nabu Casa and custom', () {
      expect(classifyHaUrl('http://192.168.1.20:8123'), HaRouteKind.local);
      expect(classifyHaUrl('http://homeassistant.local:8123'), HaRouteKind.local);
      expect(classifyHaUrl('homeassistant'), HaRouteKind.local);
      expect(classifyHaUrl('http://100.64.1.10:8123'), HaRouteKind.tailscale);
      expect(classifyHaUrl('http://100.127.0.5:8123'), HaRouteKind.tailscale);
      expect(classifyHaUrl('https://ha.tailnet-name.ts.net'), HaRouteKind.tailscale);
      expect(isTailscaleHost('100.63.0.1'), isFalse);
      expect(classifyHaUrl('https://abcd1234.ui.nabu.casa'), HaRouteKind.remote);
      expect(classifyHaUrl('https://ha.example.com'), HaRouteKind.remote);
      expect(haRouteLabel(HaRouteKind.local), 'Paikallinen');
      expect(haRouteLabel(HaRouteKind.tailscale), 'Tailscale');
      expect(haRouteLabel(HaRouteKind.remote), 'Etä');
      expect(haRouteLabel(HaRouteKind.local, lang: 'en'), 'Local');
      expect(haRouteLabel(HaRouteKind.remote, lang: 'en'), 'Remote');
    });

    test('Tailscale addresses try http on 8123 first; Serve *.ts.net prefers https', () {
      expect(haCandidates('100.64.1.10:8123').first, 'http://100.64.1.10:8123');
      expect(haCandidates('ha.example.ts.net').first, 'https://ha.example.ts.net');
      expect(haCandidates('http://ha.example.ts.net:8123').first, 'http://ha.example.ts.net:8123');
    });
  });

  group('storage and overlap', () {
    test('migrate a single baseUrl into routes; fields round-trip', () {
      final c = ConnectionConfig(
        name: 'Home Assistant',
        type: 'homeassistant',
        settings: {'baseUrl': 'http://homeassistant.local:8123', 'liveUpdates': true},
        secrets: {'token': 'tok'},
      );
      final routes = haRoutesOf(c);
      expect(routes.single.kind, HaRouteKind.local);
      expect(haUrlSet(c), {'http://homeassistant.local:8123'});
      c.settings['tailscaleUrl'] = 'http://100.64.1.10:8123';
      applyHaFieldsToSettings(c.settings, activeUrl: 'http://homeassistant.local:8123');
      expect(haRoutesOf(c).map((r) => r.kind), containsAll([HaRouteKind.local, HaRouteKind.tailscale]));
      expect(c.settings['baseUrl'], 'http://homeassistant.local:8123');
      expect(haRouteKindOf(c), HaRouteKind.local);
    });

    test('existingHaConnection matches any overlapping URL of the same instance', () {
      final a = ConnectionConfig(
        name: 'HA',
        type: 'homeassistant',
        settings: {
          'baseUrl': 'http://100.64.1.10:8123',
          'haRoutes': [
            {'url': 'http://192.168.1.20:8123', 'kind': 'local'},
            {'url': 'http://100.64.1.10:8123', 'kind': 'tailscale'},
          ],
        },
      );
      final all = [a];
      expect(existingHaConnection(all, urls: ['http://192.168.1.20:8123'])?.id, a.id);
      expect(existingHaConnection(all, urls: ['http://100.64.1.10:8123'])?.id, a.id);
      expect(existingHaConnection(all, urls: ['http://192.168.1.99:8123']), isNull);
    });

    test('dedupe merges the same token when a Tailscale URL overlaps a stored local+remote pair', () {
      final a = ConnectionConfig(
        id: 'a',
        name: 'HA',
        type: 'homeassistant',
        settings: {
          'baseUrl': 'http://192.168.1.20:8123',
          'haRoutes': [
            {'url': 'http://192.168.1.20:8123', 'kind': 'local'},
            {'url': 'http://100.64.1.10:8123', 'kind': 'tailscale'},
          ],
        },
        secrets: {'token': 'tok'},
      );
      final b = ConnectionConfig(
        id: 'b',
        name: 'HA',
        type: 'homeassistant',
        settings: {'baseUrl': 'http://100.64.1.10:8123'},
        secrets: {'token': 'tok'},
      );
      final cfg = AppConfig(connections: [a, b]);
      expect(dedupeHaConnections(cfg).map((c) => c.id), ['b']);
      expect(cfg.connections.single.id, 'a');
      expect(haUrlSet(cfg.connections.single), contains('http://100.64.1.10:8123'));
    });
  });

  group('selectHaRoute', () {
    test('prefers local when it answers; otherwise Tailscale then remote; remembers last if asked', () async {
      final routes = [
        const HaRoute(url: 'http://192.168.1.20:8123', kind: HaRouteKind.local),
        const HaRoute(url: 'http://100.64.1.10:8123', kind: HaRouteKind.tailscale),
        const HaRoute(url: 'https://example.ui.nabu.casa', kind: HaRouteKind.remote),
      ];
      final hits = <String>[];
      Future<({bool ok, bool selfSigned, String message})> probe(
        String url, {
        required String token,
        required bool allowSelfSigned,
      }) async {
        hits.add(url);
        final ok = url.contains('192.168');
        return (ok: ok, selfSigned: false, message: ok ? 'API running' : '');
      }

      final local = await selectHaRoute(routes: routes, token: 'tok', probe: probe);
      expect(local.kind, HaRouteKind.local);
      expect(hits.first, 'http://192.168.1.20:8123');

      hits.clear();
      Future<({bool ok, bool selfSigned, String message})> onlyTail(
        String url, {
        required String token,
        required bool allowSelfSigned,
      }) async {
        hits.add(url);
        final ok = url.contains('100.64');
        return (ok: ok, selfSigned: false, message: ok ? 'API running' : '');
      }

      final ts = await selectHaRoute(routes: routes, token: 'tok', probe: onlyTail);
      expect(ts.kind, HaRouteKind.tailscale);

      hits.clear();
      final last = await selectHaRoute(
        routes: routes,
        token: 'tok',
        lastUrl: 'https://example.ui.nabu.casa',
        preferLocal: false,
        probe: (url, {required token, required allowSelfSigned}) async {
          hits.add(url);
          return (ok: url.contains('nabu'), selfSigned: false, message: 'API running');
        },
      );
      expect(last.kind, HaRouteKind.remote);
      expect(hits.first, 'https://example.ui.nabu.casa');
    });
  });

  test('mixed content: https web page cannot use http HA', () {
    expect(haMixedContentBlocked('http://100.64.1.10:8123', isWeb: true, pageScheme: 'https'), isTrue);
    expect(haMixedContentBlocked('https://ha.example.ts.net', isWeb: true, pageScheme: 'https'), isFalse);
    expect(haMixedContentBlocked('http://192.168.1.20:8123', isWeb: false, pageScheme: 'https'), isFalse);
  });

  test('help and the in-app guide stay generic', () {
    expect(haTailscaleHelpFi.toLowerCase(), isNot(contains('kotselainen')));
    expect(haTailscaleHelpFi, contains('Tailscale'));
    expect(haTailscaleHelpFi, contains('*.ts.net'));
    expect(haMixedContentHelpFi, contains('https'));
    final g = guideById('ha_tailscale')!;
    expect(g.steps, hasLength(5));
    expect(g.steps[0].$1, contains('Lisäosakauppa'));
    expect(g.steps[1].$1, contains('Disable key expiry'));
    expect(g.steps[1].$1, contains('MagicDNS'));
    expect(g.steps[2].$1, contains('samalle tilille'));
    expect(g.steps[3].$1, contains('proxy: true'));
    expect(g.steps[3].$1, contains('trusted_proxies'));
    expect(g.steps[4].$1, contains('pitkäikäinen tunnus'));
    expect(g.steps[0].$2, contains('Add-on store'));
    for (final (fi, en) in [g.title, g.summary, g.good, ...g.steps, g.note!]) {
      expect(fi.toLowerCase(), isNot(contains('kotselainen')));
      expect(en.toLowerCase(), isNot(contains('kotselainen')));
    }
  });

  test('applyTemplate reuses the stored HA and does not wipe the token', () async {
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final existing = ConnectionConfig(
      id: 'ha1',
      name: 'Home Assistant',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://homeassistant.local:8123', 'liveUpdates': true},
      secrets: {'token': 'kept-token'},
    );
    st.config.connections.add(existing);
    await st.upsertConnection(existing);
    final built = templateById('homeassistant')!.build({
      'address': 'http://homeassistant.local:8123',
      'tailscaleUrl': 'http://100.64.1.10:8123',
    }, 'fi');
    // No token in the second form.
    expect(built.connections.single.secrets['token'], isNull);
    final used = await st.applyTemplate(built);
    expect(used.single.id, 'ha1');
    expect(st.config.connections, hasLength(1));
    expect(st.config.connections.single.secrets['token'], 'kept-token');
    expect(haUrlSet(st.config.connections.single), contains('http://100.64.1.10:8123'));
  });
}

Widget _host(AppState st, Widget home) => AppScope(
  state: st,
  child: MaterialApp(theme: molaplanTheme(), home: home),
);

void widgetTests() {
  testWidgets('Lisää Home Assistant with a stored connection: no token form, opens the entity list', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1600);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final conn = ConnectionConfig(
      id: 'ha1',
      name: 'Kodin HA',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://homeassistant.local:8123', 'liveUpdates': true},
      secrets: {'token': 'stored-token'},
    );
    await st.upsertConnection(conn);
    await tester.pumpWidget(
      _host(
        st,
        Builder(
          builder: (context) => Scaffold(
            body: FilledButton(
              key: const ValueKey('open-ha-add'),
              onPressed: () => openHaAddFlow(context),
              child: const Text('open'),
            ),
          ),
        ),
      ),
    );
    await tester.pump();
    await tester.tap(find.byKey(const ValueKey('open-ha-add')));
    await tester.pumpAndSettle();
    // Sheet offers the stored connection; token field is not shown.
    expect(find.text('Kodin HA'), findsOneWidget);
    expect(find.text('Lisää uusi Home Assistant'), findsOneWidget);
    expect(find.textContaining('tunnusta ei kysytä uudelleen'), findsOneWidget);
    expect(find.widgetWithText(TextField, ''), findsNothing);
    await tester.tap(find.byKey(const ValueKey('ha-pick-ha1')));
    await tester.pumpAndSettle();
    // Entity picker (catalog may fail in the test; the token form must not appear).
    expect(find.textContaining('Valitse Home Assistantin laitteet'), findsOneWidget);
    expect(find.text('Pitkäikäinen tunnus (token)'), findsNothing);
    expect(find.text('Paikallinen osoite'), findsNothing);
  });

  testWidgets('HA setup form: Edistyneet holds Tailscale + remote, and the in-app guide link', (tester) async {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    await tester.pumpWidget(
      _host(st, TemplateSetupPage(template: templateById('homeassistant')!)),
    );
    await tester.pump();
    expect(find.textContaining('Paikallinen osoite'), findsOneWidget);
    expect(find.textContaining('Pitkäikäinen tunnus (token)'), findsOneWidget);
    expect(find.text('Etäyhteys Tailscalella – ohje'), findsOneWidget);
    await tester.ensureVisible(find.byKey(const ValueKey('advanced')));
    await tester.tap(find.byKey(const ValueKey('advanced')));
    await tester.pumpAndSettle();
    expect(find.text('Edistyneet'), findsWidgets);
    expect(find.text('Tailscale-osoite'), findsOneWidget);
    expect(find.text('Etäosoite (Nabu Casa tai muu)'), findsOneWidget);
    await tester.tap(find.byKey(const ValueKey('ha-tailscale-guide')));
    await tester.pumpAndSettle();
    expect(find.text('Etäyhteys Tailscalella (Home Assistant)'), findsOneWidget);
    expect(find.textContaining('Lisäosakauppa'), findsOneWidget);
    expect(find.textContaining('MagicDNS'), findsOneWidget);
    expect(find.textContaining('proxy: true'), findsOneWidget);
  });

  testWidgets('entity picker still hides already-added items by default', (tester) async {
    tester.view.physicalSize = const Size(800, 1400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    await st.setOnboardingDone(true);
    final conn = ConnectionConfig(
      id: 'ha1',
      name: 'HA',
      type: 'homeassistant',
      settings: {'baseUrl': 'http://homeassistant.local:8123'},
      secrets: {'token': 't'},
    );
    await st.upsertConnection(conn);
    st.config.dashboards.first.tiles.add(
      TileConfig(
        type: TileType.toggle,
        title: 'Valo',
        connectionId: conn.id,
        read: {'entityId': 'light.a'},
      ),
    );
    HaEntity e(String id) => HaEntity(entityId: id, name: id);
    await tester.pumpWidget(
      _host(
        st,
        HaEntityPickerPage(
          connection: conn,
          loader: () async => HaCatalog([e('light.a'), e('light.b')], const []),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const ValueKey('ha-light.b')), findsOneWidget);
    expect(find.byKey(const ValueKey('ha-light.a')), findsNothing);
    expect(find.byKey(const ValueKey('ha-route-local')), findsOneWidget);
  });
}

