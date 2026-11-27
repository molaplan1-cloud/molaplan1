import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/home_launcher.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/notify.dart';
import 'package:molaplan/ui/push_listener.dart';
import 'package:molaplan/ui/theme.dart';
import 'package:molaplan/ui/tile_widget.dart';

class _Rec extends Driver {
  _Rec() : super(ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'));
  final sent = <String>[];
  Object? nextRead = 0;
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => nextRead;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    sent.add('${spec['path']}=$value');
    return true;
  }

  @override
  Future<String> test() async => 'ok';
}

TileConfig _toggle({
  String title = 'Lamppu',
  String id = 'lamp',
  bool confirm = false,
}) => TileConfig(
  id: id,
  type: TileType.toggle,
  title: title,
  connectionId: 'c1',
  read: {'path': 'st'},
  onCommand: CommandStep(connectionId: 'c1', spec: {'path': 'on'}),
  offCommand: CommandStep(connectionId: 'c1', spec: {'path': 'off'}),
  confirm: confirm,
);

TileConfig _button({
  required String title,
  required String cmd,
  bool askPin = false,
  String id = 'btn',
}) => TileConfig(
  id: id,
  type: TileType.button,
  title: title,
  connectionId: 'c1',
  commands: [
    CommandStep(
      connectionId: 'c1',
      spec: {'path': cmd, if (askPin) 'askPin': true},
    ),
  ],
);

Future<AppState> _state(List<TileConfig> tiles, _Rec drv) async {
  final st = AppState(
    configStore: MemoryConfigStore()
      ..data = jsonEncode(AppConfig(onboardingDone: true).toJson()),
    secretStore: MemorySecretStore(),
  );
  await st.load();
  st.config.connections.add(
    ConnectionConfig(id: 'c1', name: 'Laite', type: 'http'),
  );
  st.debugSetDriver('c1', drv);
  st.config.dashboards.first.tiles
    ..clear()
    ..addAll(tiles);
  return st;
}

void main() {
  setUp(() {
    launcherEnabledInTests = true;
    launcherCalls.clear();
  });
  tearDown(launcherResetForTests);

  test('deep links: run, tile, confirm; never a PIN in the URI', () {
    final run = Uri.parse(launcherRunLink('ab-12', confirm: true));
    expect(DeepLinks.runOf(run), 'ab-12');
    expect(DeepLinks.tileOf(run), isNull);
    expect(DeepLinks.confirmOf(run), isTrue);
    expect(run.toString(), isNot(contains('pin')));
    expect(DeepLinks.tileOf(Uri.parse(launcherOpenLink('ab-12'))), 'ab-12');
    expect(DeepLinks.confirmOf(Uri.parse(launcherRunLink('x'))), isFalse);
  });

  test('alarm-off is dangerous; a lamp toggle is not', () {
    expect(
      commandIsDangerous(_button(title: 'Hälytys pois', cmd: 'pois')),
      isTrue,
    );
    expect(
      commandIsDangerous(
        _button(title: 'Kuittaa ja hälytys pois', cmd: 'kuittaa pois'),
      ),
      isTrue,
    );
    expect(
      commandIsDangerous(_button(title: 'Alarm off', cmd: 'disarm')),
      isTrue,
    );
    expect(
      commandIsDangerous(_button(title: 'Desarmar alarma', cmd: 'off')),
      isTrue,
    );
    expect(commandIsDangerous(_toggle(title: 'Lamppu')), isFalse);
    expect(
      commandIsDangerous(_button(title: 'Hälytys päälle', cmd: 'päälle')),
      isFalse,
    );
    expect(launcherNeedsConfirm(_toggle(confirm: true)), isTrue);
    expect(launcherNeedsConfirm(_toggle()), isFalse);
  });

  test('shortcut and widget payloads never contain a PIN or secret', () {
    final t = _button(title: 'Hälytys pois', cmd: 'pois 1234', askPin: true);
    final s = launcherShortcutPayload(t, confirm: true);
    expect(s['link'], 'molaplan://run/btn?confirm=1');
    expect(s['confirm'], isTrue);
    expect(payloadLeaksSecret(s), isFalse);
    expect(s.keys, isNot(contains(contains('pin'))));
    final w = launcherWidgetPayload(t, 'away', lang: 'fi');
    expect(payloadLeaksSecret(w), isFalse);
    expect(w['kind'], 'status');
    expect(w['link'], startsWith('molaplan://tile/'));
  });

  test('status text and colour follow the tile state', () {
    final lamp = _toggle();
    expect(launcherStatusText(lamp, 1, 'fi'), 'Päällä');
    expect(launcherStatusText(lamp, 0, 'en'), 'Off');
    expect(launcherStatusColor(lamp, 1), 0xFF1565C0);
    expect(launcherStatusColor(lamp, 0), 0xFF546E7A);
    final sensor = TileConfig(
      id: 's',
      type: TileType.value,
      title: 'Vuoto',
      sensor: 'leak',
      unit: '',
    );
    expect(launcherStatusText(sensor, true, 'fi'), 'Hälytys');
    expect(launcherStatusColor(sensor, true), 0xFFC62828);
    final v = TileConfig(
      id: 't',
      type: TileType.value,
      title: 'Lämpö',
      unit: '°C',
      decimals: 1,
    );
    expect(launcherStatusText(v, 21.5, 'fi'), '21.5 °C');
  });

  test('WorkManager refresh interval is at least 15 minutes', () {
    expect(launcherRefreshMinutes, greaterThanOrEqualTo(15));
  });

  testWidgets(
    'long-press any tile: Lisää aloitusnäytölle pins a command shortcut',
    (tester) async {
      final drv = _Rec();
      final tile = _toggle();
      final st = await _state([tile], drv);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 240,
                child: TileWidget(tile: tile, control: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Lamppu'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('tile-add-home')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('tile-add-home')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-home-dialog')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-home-command')), findsOneWidget);
      expect(find.byKey(const ValueKey('add-home-status')), findsOneWidget);
      // A lamp is not dangerous: confirm is off by default.
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('add-home-confirm')),
            )
            .value,
        isFalse,
      );
      await tester.tap(find.byKey(const ValueKey('add-home-ok')));
      await tester.pumpAndSettle();
      expect(
        launcherCalls.where((c) => c['method'] == 'pinShortcut'),
        isNotEmpty,
      );
      final pin = launcherCalls.firstWhere((c) => c['method'] == 'pinShortcut');
      expect(pin['id'], 'lamp');
      expect(pin['link'], 'molaplan://run/lamp');
      expect(pin['confirm'], isFalse);
      expect(payloadLeaksSecret(pin), isFalse);
    },
  );

  testWidgets(
    'alarm-off shortcut offers confirmation by default; status widget is the other choice',
    (tester) async {
      final drv = _Rec();
      final tile = _button(title: 'Hälytys pois', cmd: 'pois');
      final st = await _state([tile], drv);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: SizedBox(
                width: 400,
                height: 240,
                child: TileWidget(tile: tile, control: true),
              ),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();
      await tester.longPress(find.text('Hälytys pois'));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('tile-add-home')));
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<CheckboxListTile>(
              find.byKey(const ValueKey('add-home-confirm')),
            )
            .value,
        isTrue,
      );
      await tester.tap(find.byKey(const ValueKey('add-home-status')));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('add-home-confirm')), findsNothing);
      await tester.tap(find.byKey(const ValueKey('add-home-ok')));
      await tester.pumpAndSettle();
      expect(
        launcherCalls.where((c) => c['method'] == 'pinWidget'),
        isNotEmpty,
      );
      final w = launcherCalls.firstWhere((c) => c['method'] == 'pinWidget');
      expect(w['id'], 'btn');
      expect(w['kind'], 'status');
      expect(payloadLeaksSecret(w), isFalse);
    },
  );

  testWidgets(
    'run link with confirm asks first; cancel does not send the command',
    (tester) async {
      final drv = _Rec();
      final st = await _state([_toggle()], drv);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            navigatorKey: nav,
            home: PushListener(
              navigator: nav,
              child: const Scaffold(body: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
      DeepLinks.open('molaplan://run/lamp?confirm=1');
      await tester.pumpAndSettle();
      expect(find.text('Suoritetaanko komento?'), findsOneWidget);
      await tester.tap(find.text('Peruuta'));
      await tester.pumpAndSettle();
      expect(drv.sent, isEmpty);
    },
  );

  testWidgets('run link executes the command after confirmation', (
    tester,
  ) async {
    final drv = _Rec()..nextRead = 0;
    final st = await _state([_toggle()], drv);
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      AppScope(
        state: st,
        child: MaterialApp(
          theme: molaplanTheme(),
          navigatorKey: nav,
          home: PushListener(
            navigator: nav,
            child: const Scaffold(body: SizedBox()),
          ),
        ),
      ),
    );
    await tester.pump();
    DeepLinks.open('molaplan://run/lamp?confirm=1');
    await tester.pumpAndSettle();
    await tester.tap(find.text('OK'));
    await tester.pumpAndSettle();
    expect(drv.sent, isNotEmpty);
    expect(drv.sent.last, startsWith('on='));
  });

  testWidgets(
    'askPin command: PIN is typed in the app, not taken from the shortcut',
    (tester) async {
      final drv = _Rec();
      final tile = _button(
        title: 'Päivitä',
        cmd: 'päivitä',
        askPin: true,
        id: 'upd',
      );
      final st = await _state([tile], drv);
      final nav = GlobalKey<NavigatorState>();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            navigatorKey: nav,
            home: PushListener(
              navigator: nav,
              child: const Scaffold(body: SizedBox()),
            ),
          ),
        ),
      );
      await tester.pump();
      DeepLinks.open(launcherRunLink('upd'));
      await tester.pumpAndSettle();
      expect(find.byKey(const ValueKey('pin-field')), findsOneWidget);
      expect(
        tester
            .widget<TextField>(find.byKey(const ValueKey('pin-field')))
            .obscureText,
        isTrue,
      );
      await tester.enterText(find.byKey(const ValueKey('pin-field')), '1234');
      await tester.tap(find.byKey(const ValueKey('pin-ok')));
      await tester.pumpAndSettle();
      expect(drv.sent, ['päivitä=1234']);
      expect(launcherRunLink('upd'), isNot(contains('1234')));
      expect(await st.secretStore.read(AppState.pinKey('upd')), isNull);
    },
  );
}
