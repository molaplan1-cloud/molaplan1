// R510–R514 (t314u / t315u): every tile as a link, a one-tile home-screen web app and an iPhone
// widget (Scriptable script, ntfy feed) – never with a PIN or secret.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/price_view.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/sharing/share_core.dart';
import 'package:molaplan/sharing/tile_links.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/home_launcher.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/tile_feed.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_shortcuts_page.dart';
import 'package:molaplan/ui/tile_view_page.dart';
import 'package:molaplan/ui/tile_widget.dart';

class _Rec extends Driver {
  _Rec() : super(ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'));
  Object? nextRead = 0;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => nextRead;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => true;
  @override
  Future<String> test() async => 'ok';
}

TileConfig _alarmButton() => TileConfig(
  id: 'alarm-off',
  type: TileType.button,
  title: 'Valvonta pois',
  connectionId: 'c1',
  commands: [
    CommandStep(connectionId: 'c1', spec: {'path': 'disarm', 'askPin': true}),
  ],
);

TileConfig _priceTile() => TileConfig(
  id: 'pr1',
  type: TileType.value,
  title: 'Sähkön hinta',
  connectionId: 'p1',
  read: {'field': 'chart'},
);

ConnectionConfig _priceConn() => ConnectionConfig(
  id: 'p1',
  name: 'Sähkön hinta',
  type: 'price',
  settings: {'zone': 'FI', 'vat': '25.5', 'margin': '0.49', 'transfer': '5.1', 'hourly': true},
);

Future<AppState> _state(List<TileConfig> tiles, {List<ConnectionConfig> conns = const []}) async {
  final st = AppState(
    configStore: MemoryConfigStore()..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  st.config.connections
    ..add(ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'))
    ..addAll(conns);
  st.debugSetDriver('c1', _Rec());
  st.config.dashboards.first.tiles
    ..clear()
    ..addAll(tiles);
  return st;
}

bool _secretFree(String s) {
  // The script header says "Contains no PINs or passwords" – only the code counts.
  final l = s.split('\n').where((x) => !x.startsWith('//')).join('\n').toLowerCase();
  return !l.contains('pin=') && !l.contains('password') && !l.contains('token') && !l.contains('secret=');
}

void main() {
  group('links (R510)', () {
    test('open / run / view links point at molaplan.com and hold only the tile id', () {
      expect(webOpenLink('ab-12'), 'https://molaplan.com/?tile=ab-12');
      expect(webRunLink('ab-12'), 'https://molaplan.com/?run=ab-12');
      expect(webViewLink('ab-12', name: 'Sähkö & hinta'), startsWith('https://molaplan.com/?view=ab-12&name='));
      for (final l in [webOpenLink('x'), webRunLink('x'), webViewLink('x', name: 'Valvonta')]) {
        expect(_secretFree(l), isTrue, reason: l);
      }
    });

    test('WebLaunch.parse: price > view > run > tile; bad ids ignored', () {
      expect(WebLaunch.parse(Uri.parse('https://molaplan.com/')), isNull);
      expect(WebLaunch.parse(Uri.parse('https://molaplan.com/?tile=a%20b')), isNull);
      final open = WebLaunch.parse(Uri.parse('https://molaplan.com/?tile=t1'));
      expect(open, isA<TileOpenLaunch>());
      expect(open!.appLink, 'molaplan://tile/t1');
      expect(open.consumeOnce, isTrue);
      final run = WebLaunch.parse(Uri.parse('https://molaplan.com/?run=t1'))!;
      expect(run, isA<TileRunLaunch>());
      // A run link always asks first – anyone holding the link could open it.
      expect(run.appLink, 'molaplan://run/t1?confirm=1');
      final view = WebLaunch.parse(Uri.parse('https://molaplan.com/?view=t1&name=X'))!;
      expect(view, isA<TileViewLaunch>());
      expect(view.appLink, isNull);
      expect(view.consumeOnce, isFalse);
      final price = WebLaunch.parse(Uri.parse('https://molaplan.com/?price=SE3&vat=25&h=0&name=El&lang=sv'));
      expect(price, isA<PriceViewLaunch>());
      final p = (price as PriceViewLaunch).params;
      expect((p.zone, p.vat, p.hourly, p.name, p.lang), ('SE3', 25.0, false, 'El', 'sv'));
      expect(WebLaunch.parse(Uri.parse('https://molaplan.com/?price=XX')), isNull);
    });

    test('price link round-trips and clamps nonsense', () {
      const p = PriceLinkParams(zone: 'FI', vat: 25.5, margin: 0.49, transfer: 5.1, hourly: true, name: 'Hinta', lang: 'fi');
      final back = (WebLaunch.parse(Uri.parse(webPriceLink(p))) as PriceViewLaunch).params;
      expect((back.zone, back.vat, back.margin, back.transfer, back.hourly, back.name), ('FI', 25.5, 0.49, 5.1, true, 'Hinta'));
      final bad = PriceLinkParams.fromQuery({'price': 'FI', 'vat': '9999', 'margin': 'x', 'lang': 'zz'})!;
      expect((bad.vat, bad.margin, bad.lang), (100.0, 0.0, 'fi'));
    });

    test('priceParamsFor follows the tile: VAT / margin off, 15 min', () {
      final t = _priceTile()
        ..priceIncludeVat = false
        ..priceResolution = '15min';
      final p = priceParamsFor(t, _priceConn(), lang: 'fi');
      expect((p.zone, p.vat, p.margin, p.transfer, p.hourly), ('FI', 0.0, 0.49, 5.1, false));
      expect(isPriceTile(t, _priceConn()), isTrue);
      expect(isPriceTile(t, ConnectionConfig(name: 'x', type: 'http')), isFalse);
    });

    test('price view config is a valid one-tile app config (no secrets)', () {
      final j = priceViewConfigJson(const PriceLinkParams(zone: 'EE', vat: 24, name: 'Elekter', lang: 'et'));
      final c = AppConfig.fromJson(j);
      expect(c.connections.single.type, 'price');
      expect(c.connections.single.secrets, isEmpty);
      final t = c.dashboards.single.tiles.single;
      expect((t.id, t.read['field'], t.title, t.connectionId), (priceViewTileId, 'chart', 'Elekter', c.connections.single.id));
      expect(c.language, 'et');
    });
  });

  group('feed (R512)', () {
    test('topics are random, well-formed and validated', () {
      final a = newFeedTopic(), b = newFeedTopic();
      expect(validFeedTopic(a), isTrue);
      expect(a, isNot(b));
      expect(validFeedTopic('kv-state-abc'), isFalse);
      expect(validFeedTopic('mf-../x'), isFalse);
      expect(feedLatestUrl(a), 'https://ntfy.molaplan.com/$a/json?poll=1&since=latest');
    });

    test('TileConfig.feed survives JSON; shares never carry it', () {
      final t = _priceTile()..feed = 'mf-abcdefghijklmnopqrst1234';
      expect(TileConfig.fromJson(t.toJson()).feed, t.feed);
      expect(TileConfig.fromJson(_priceTile().toJson()).feed, isNull);
      expect(publicTile(t, {ShareCap.view}).containsKey('feed'), isFalse);
    });

    test('publish on change, throttle, heartbeat', () {
      final t0 = DateTime(2026, 11, 27, 12);
      expect(feedShouldPublish(body: 'a', lastBody: null, now: t0, lastAt: null), isTrue);
      expect(feedShouldPublish(body: 'b', lastBody: 'a', now: t0.add(const Duration(seconds: 10)), lastAt: t0), isFalse);
      expect(feedShouldPublish(body: 'b', lastBody: 'a', now: t0.add(const Duration(seconds: 40)), lastAt: t0), isTrue);
      expect(feedShouldPublish(body: 'a', lastBody: 'a', now: t0.add(const Duration(minutes: 5)), lastAt: t0), isFalse);
      expect(feedShouldPublish(body: 'a', lastBody: 'a', now: t0.add(const Duration(minutes: 16)), lastAt: t0), isTrue);
    });

    test('publisher posts the widget view (priority 1, no Apple push, no secrets)', () async {
      final posts = <http.Request>[];
      final pub = TileFeedPublisher(
        client: () => MockClient((r) async {
          posts.add(r);
          return http.Response('{}', 200);
        }),
      );
      final t = _alarmButton()..feed = 'mf-abcdefghijklmnopqrst1234';
      final now = DateTime(2026, 11, 27, 12);
      expect(await pub.onValue(t, 'armed', lang: 'fi', now: now), isTrue);
      expect(await pub.onValue(t, 'armed', lang: 'fi', now: now.add(const Duration(minutes: 1))), isFalse);
      expect(await pub.onValue(t, 'disarmed', lang: 'fi', now: now.add(const Duration(seconds: 5))), isFalse);
      expect(await pub.onValue(t, 'disarmed', lang: 'fi', now: now.add(const Duration(minutes: 2))), isTrue);
      expect(posts, hasLength(2));
      final r = posts.first;
      expect(r.url.toString(), 'https://ntfy.molaplan.com/mf-abcdefghijklmnopqrst1234');
      expect(r.headers['X-Priority'], '1');
      expect(r.headers['X-Firebase'], 'no');
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body['title'], 'Valvonta pois');
      expect(body['open'], 'https://molaplan.com/?tile=alarm-off');
      expect(body.containsKey('link'), isFalse);
      expect(_secretFree(r.body), isTrue);
      expect(payloadLeaksSecret(body), isFalse);
      // No feed → nothing goes out.
      expect(await pub.onValue(_alarmButton(), 1, lang: 'fi'), isFalse);
      // Revoking overwrites the latest message.
      expect(await pub.revoke('mf-abcdefghijklmnopqrst1234', title: 'x', lang: 'fi'), isTrue);
      expect(jsonDecode(posts.last.body)['revoked'], isTrue);
    });

    test('price tile feed carries c/kWh and bars like the Android widget', () {
      final now = DateTime.now();
      final d0 = DateTime(now.year, now.month, now.day);
      final pts = [
        for (var h = 0; h < 48; h++) [d0.add(Duration(hours: h)).millisecondsSinceEpoch, 5.0 + h % 7],
      ];
      final p = feedPayload(
        launcherWidgetPayload(_priceTile(), {'points': pts, 'res': 3600}, lang: 'fi'),
        tileId: 'pr1',
      );
      expect(p['bars'], isA<List>());
      expect((p['bars'] as List).length, 48);
      expect(p['nowBar'], greaterThanOrEqualTo(0));
      expect('${p['value']}', contains('c/kWh'));
    });
  });

  group('scripts and recipes (R513, R514)', () {
    const price = PriceLinkParams(zone: 'FI', vat: 25.5, margin: 0.49, name: 'Sähkö "koti"', lang: 'fi');

    test('price script: relay, zone, settings – nothing secret, title JSON-escaped', () {
      final s = scriptablePriceScript(price);
      expect(s, contains('"server": "https://relay.molaplan.com"'));
      expect(s, contains('"zone": "FI"'));
      expect(s, contains('"margin": 0.49'));
      expect(s, contains(r'Sähkö \"koti\"'));
      expect(s, contains('Script.setWidget'));
      expect(_secretFree(s), isTrue);
    });

    test('feed script reads only the feed', () {
      final s = scriptableFeedScript(topic: 'mf-abcdefghijklmnopqrst1234', title: 'Valvonta', tileId: 'kv', lang: 'en');
      expect(s, contains('https://ntfy.molaplan.com/mf-abcdefghijklmnopqrst1234/json?poll=1&since=latest'));
      expect(s, contains('"open": "https://molaplan.com/?tile=kv"'));
      expect(s, contains('No data'));
      expect(_secretFree(s), isTrue);
    });

    test('generated JavaScript parses (node --check)', () async {
      final node = await Process.run('which', ['node']);
      if (node.exitCode != 0) {
        markTestSkipped('node not installed');
        return;
      }
      final dir = await Directory.systemTemp.createTemp('mpl-js');
      for (final (name, src) in [
        ('price', scriptablePriceScript(price)),
        ('feed', scriptableFeedScript(topic: 'mf-abcdefghijklmnopqrst1234', title: 'X', tileId: 'x', lang: 'fi')),
      ]) {
        // Scriptable allows top-level await; wrap so node can parse it as a plain script.
        final f = File('${dir.path}/$name.js')..writeAsStringSync('(async () => {\n$src\n})();\n');
        final r = await Process.run('node', ['--check', f.path]);
        expect(r.exitCode, 0, reason: '$name: ${r.stderr}');
      }
      await dir.delete(recursive: true);
    });

    test('Shortcuts recipes: run asks in the app, read uses the feed', () {
      final run = shortcutRunRecipe(_alarmButton(), 'fi');
      expect(run, contains('https://molaplan.com/?run=alarm-off'));
      expect(run, contains('Hei Siri, Valvonta pois'));
      expect(run, contains('PIN-koodia ei tallenneta'));
      expect(shortcutOpenRecipe(_alarmButton(), 'en'), contains('https://molaplan.com/?tile=alarm-off'));
      expect(shortcutReadRecipe(_alarmButton(), 'mf-abcdefghijklmnopqrst1234', 'en'), contains('since=latest'));
      expect(_secretFree(run), isTrue);
    });
  });

  group('UI', () {
    testWidgets('every tile: long-press → Pikakomento / jaa opens the shortcuts page', (tester) async {
      final tile = _alarmButton();
      final st = await _state([tile]);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(body: SizedBox(width: 400, height: 240, child: TileWidget(tile: tile, control: true))),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Valvonta pois').first);
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tile-shortcuts')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tile-shortcuts')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tile-shortcuts-page')), findsOneWidget);
      expect(find.byKey(const ValueKey('link-open-url')), findsOneWidget);
      expect(find.byKey(const ValueKey('link-run-url')), findsOneWidget);
      expect(find.byKey(const ValueKey('link-view-url')), findsOneWidget);
      // Not a price tile: no price view / price script.
      expect(find.byKey(const ValueKey('link-price-url')), findsNothing);
      expect(find.byKey(const ValueKey('script-price')), findsNothing);
    });

    testWidgets('price tile: price view link + Scriptable script; feed switch saves a topic', (tester) async {
      final tile = _priceTile();
      final st = await _state([tile], conns: [_priceConn()]);
      st.tileFeeds.enabled = false; // no network in tests
      tester.view.physicalSize = const Size(900, 2400);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            scaffoldMessengerKey: snackMessengerKey,
            home: TileShortcutsPage(tile: tile),
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('link-price-url')), findsOneWidget);
      expect(find.byKey(const ValueKey('script-price')), findsOneWidget);
      expect(find.byKey(const ValueKey('link-run-url')), findsNothing);
      expect(find.byKey(const ValueKey('script-feed')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('feed-switch')));
      await tester.pumpAndSettle();
      expect(validFeedTopic(tile.feed), isTrue);
      expect(find.byKey(const ValueKey('script-feed')), findsOneWidget);
      expect(find.byKey(const ValueKey('recipe-read')), findsOneWidget);
      final saved = AppConfig.fromJson(jsonDecode((st.configStore as MemoryConfigStore).data!) as Map<String, dynamic>);
      expect(saved.dashboards.first.tiles.first.feed, tile.feed);
      final first = tile.feed;
      await tester.ensureVisible(find.byKey(const ValueKey('feed-renew')));
      await tester.tap(find.byKey(const ValueKey('feed-renew')));
      await tester.pumpAndSettle();
      expect(tile.feed, isNot(first));
      await tester.ensureVisible(find.byKey(const ValueKey('feed-switch')));
      await tester.tap(find.byKey(const ValueKey('feed-switch')));
      await tester.pumpAndSettle();
      expect(tile.feed, isNull);
    });

    testWidgets('single-tile view shows the tile, or a sign-in hint when it is not here', (tester) async {
      final tile = _alarmButton();
      final st = await _state([tile]);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(theme: molaplanTheme(), home: const TileViewPage(tileId: 'alarm-off')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.byKey(const ValueKey('tile-view-box')), findsOneWidget);
      expect(find.text('Valvonta pois'), findsWidgets);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(theme: molaplanTheme(), home: const TileViewPage(tileId: 'nope')),
        ),
      );
      await tester.pump(const Duration(milliseconds: 300));
      expect(find.textContaining('Laattaa ei löytynyt'), findsOneWidget);
    });
  });

  test('hourly bars from 15-min data: published tomorrow counts as complete (not hatched)', () {
    final now = DateTime(2026, 11, 27, 17, 15);
    final d0 = DateTime(2026, 11, 27);
    final pts = [for (var q = 0; q < 2 * 96; q++) (d0.add(Duration(minutes: 15 * q)), 50.0 + q % 9)];
    expect(PriceView.build(pts, 900, now, hourly: true).hasTomorrow, isTrue);
    expect(PriceView.build(pts, 900, now, hourly: false).hasTomorrow, isTrue);
    final todayOnly = pts.where((p) => p.$1.day == 27).toList();
    expect(PriceView.build(todayOnly, 900, now, hourly: true).hasTomorrow, isFalse);
  });

  test('web shell: tile_app.js loaded, blob manifests allowed, precached, nothing user-specific', () {
    final index = File('web/index.html').readAsStringSync();
    expect(index, contains('<script src="tile_app.js"></script>'));
    expect(index.indexOf('tile_app.js'), lessThan(index.indexOf('flutter_bootstrap.js"')));
    expect(File('tool/web/_headers').readAsStringSync(), contains("manifest-src 'self' blob:"));
    expect(File('tool/web/sw.template.js').readAsStringSync(), contains("'/tile_app.js'"));
    expect(File('tool/web/make_sw.py').readAsStringSync(), contains("'/tile_app.js'"));
    final js = File('web/tile_app.js').readAsStringSync();
    expect(js, contains('apple-mobile-web-app-title'));
    expect(RegExp(r'192\.168\.|kv-[a-z0-9]{8,}|kotselainen').hasMatch(js), isFalse);
  });
}
