// R634–R638 (t338u): heating programs – a price-limit mode, one program per device, programs bound to
// one of several home bridges (each runs there alone, a bridge that is offline is shown per program,
// a device is never switched by two bridges), the short wizard and the folded advanced settings.

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:material_ui/material_ui.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/energy/heating_explain.dart';
import 'package:molaplan/energy/smart_heating.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/prices/prices.dart';
import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/state/stores.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/heat_program_pages.dart';
import 'package:molaplan/ui/heating_view.dart';
import 'package:molaplan/ui/smart_heating_pages.dart';

import 'v03_test.dart' show FakeRemote, fakeHome;

const dayPrices = <double>[
  30.0, 20, 10, 5, 8, 15, 40, 80, 120, 150, 100, 60, 50, 45, 55, 70, 200, 300, 250, 180, 90, 60, 40, 35, //
];
DateTime d0 = DateTime(2026, 11, 25);
double? cost(DateTime h) {
  final i = h.difference(d0).inHours;
  return i < -72 || i >= 96 ? null : dayPrices[i % 24] / 10;
}

HeatInputs inputs(DateTime now) => HeatInputs(now: now, cost: cost, outdoor: (_) => -5);

final varasto = 'a' * 32;
final mokki = '0' * 32;

Future<AppState> makeState({List<HeatLoad>? loads, bool twoBridges = false}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  await st.setOnboardingDone(true);
  await st.upsertConnection(
    ConnectionConfig(id: 'c1', name: 'Rele', type: 'http', settings: {'baseUrl': 'http://127.0.0.1:9'}),
  );
  TileConfig relay(String id, String title) => TileConfig(
    id: id,
    type: TileType.toggle,
    title: title,
    connectionId: 'c1',
    read: {'field': 'relay'},
    onCommand: CommandStep(connectionId: 'c1', spec: {'do': 'on'}),
    offCommand: CommandStep(connectionId: 'c1', spec: {'do': 'off'}),
  );
  st.config.dashboards.first.tiles.addAll([
    relay('floor', 'Lattian rele'),
    relay('boiler', 'Varaajan rele'),
    relay('pump', 'Pumpun rele'),
    TileConfig(
      id: 'room',
      type: TileType.value,
      title: 'Huoneen lämpö',
      unit: '°C',
      connectionId: 'c1',
      read: {'field': 't'},
    ),
  ]);
  st.config.energy.smartHeating = SmartHeatingConfig(
    site: SiteSurvey(types: ['concrete_floor']),
    loads:
        loads ??
        [
          HeatLoad(id: 'L1', name: 'Lattialämmitys', type: 'concrete_floor', tileId: 'floor', sensorTileId: 'room'),
          HeatLoad(id: 'L2', name: 'Varaaja', type: 'water_heater', tileId: 'boiler'),
        ],
  );
  await st.save();
  if (twoBridges) {
    st.remote.paired = fakeHome();
    st.account.vaultBridges[varasto] = {
      'home': varasto,
      'name': 'Varasto',
      'grant': {...fakeHome().toJson(), 'home': varasto, 'dev': '9' * 16, 'name': 'Varasto'},
    };
  }
  return st;
}

Future<void> settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> wide(WidgetTester tester) async {
  tester.view.physicalSize = const Size(1200, 1000);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> end(WidgetTester tester) async {
  await tester.pumpWidget(const SizedBox());
  await tester.pump(const Duration(minutes: 3));
}

void main() {
  setUp(() {
    PriceService.clock = () => DateTime(2026, 11, 25, 12);
    SharedPreferences.setMockInitialValues({});
    PriceService.shared.put(
      PriceSeries('FI', [for (var i = 0; i < 48; i++) PricePoint(d0.add(Duration(hours: i)), 3600, dayPrices[i % 24])]),
    );
  });
  tearDown(() => PriceService.clock = DateTime.now);

  group('price-limit mode (R634)', () {
    final c = SmartHeatingConfig(site: SiteSurvey(types: ['radiator']));

    test('a switch is on while the hour costs no more than the limit, off above it', () {
      final l = HeatLoad(type: 'radiator', tileId: 'x', priceLimit: 5.0);
      expect(l.mode, 'price');
      final cheap = decideSwitch(c, l, inputs(DateTime(2026, 11, 25, 3, 30))); // 0.5 c
      expect(cheap.on, isTrue);
      expect(cheap.reason, 'cheap');
      final at5 = decideSwitch(c, l, inputs(DateTime(2026, 11, 25, 15, 10))); // 7.0 c
      expect(at5.on, isFalse);
      expect(at5.reason, 'not_cheap');
      final exact = decideSwitch(
        c,
        HeatLoad(type: 'radiator', tileId: 'x', priceLimit: 7.0),
        inputs(DateTime(2026, 11, 25, 15)),
      );
      expect(exact.on, isTrue, reason: 'at the limit counts as under it');
      final no = decideSwitch(c, l, HeatInputs(now: DateTime(2026, 11, 25, 9), cost: (_) => null, outdoor: (_) => 0));
      expect(no.on, isTrue, reason: 'no prices: normal heating, as for every mode');
    });

    test('safety limits and manual override still come first', () {
      final l = HeatLoad(type: 'radiator', tileId: 'x', sensorTileId: 's', priceLimit: 1.0);
      final cold = decideSwitch(
        c,
        l,
        HeatInputs(now: DateTime(2026, 11, 25, 9), cost: cost, outdoor: (_) => 0, temp: 5),
      );
      expect(cold.on, isTrue);
      expect(cold.safety, isTrue);
      final manual = decideSwitch(
        c,
        l,
        HeatInputs(
          now: DateTime(2026, 11, 25, 9),
          cost: cost,
          outdoor: (_) => 0,
          temp: 20,
          manualOn: false,
          manualUntil: DateTime(2026, 11, 25, 11),
        ),
      );
      expect(manual.on, isFalse);
      expect(manual.reason, 'manual_off');
    });

    test('a thermostat is a little warmer under the limit and a little cooler over it', () {
      final l = HeatLoad(type: 'ilp', control: 'thermostat', thermostatId: 't', priceLimit: 5.0);
      final under = decideThermostat(c, l, inputs(DateTime(2026, 11, 25, 3)), 21);
      final over = decideThermostat(c, l, inputs(DateTime(2026, 11, 25, 9)), 21);
      expect(under.target! > 21, isTrue);
      expect(over.target! < 21, isTrue);
      expect(under.reason, 'cheap');
      expect(over.reason, 'not_cheap');
    });

    test('the explanation shows the limit itself and how many hours are under it', () {
      final l = HeatLoad(type: 'radiator', tileId: 'x', priceLimit: 5.0);
      final e = explainLoad(c, l, inputs(DateTime(2026, 11, 25, 3, 30)));
      expect(e.limit, 5.0);
      expect(e.limitKind, 'price');
      expect(e.limitHours, dayPrices.where((p) => p / 10 <= 5.0).length);
      expect(e.checks.any((k) => k.id == 'pricelimit'), isTrue);
      expect(e.checks.any((k) => k.id == 'cheapest'), isFalse);
      expect(e.checks.firstWhere((k) => k.id == 'pricelimit').detail(HeatText('fi')), contains('alle rajan tänään'));
      expect(e.checks.any((k) => k.id == 'weather'), isFalse);
    });

    test('the mode is one of three and round-trips; old programs have none of the new keys', () {
      expect(HeatLoad(type: 'radiator').mode, 'hours');
      expect(HeatLoad(type: 'radiator', tempControl: true).mode, 'temp');
      final l = HeatLoad(type: 'radiator', tileId: 'x', priceLimit: 12.5, home: varasto);
      final back = HeatLoad.fromJson(l.toJson());
      expect(back.priceLimit, 12.5);
      expect(back.home, varasto);
      final old = HeatLoad(id: 'a', type: 'concrete_floor', tileId: 'floor', hours: 8).toJson();
      expect(old.containsKey('priceLimit'), isFalse);
      expect(old.containsKey('home'), isFalse);
      // Migration without a change in behaviour: the same decisions as the saved program always made.
      final fromOld = HeatLoad.fromJson(old);
      for (var h = 0; h < 24; h++) {
        final x = inputs(DateTime(2026, 11, 25, h, 20));
        final a = decideSwitch(c, HeatLoad.fromJson(old), x);
        final b = decideSwitch(c, fromOld, x);
        expect((a.on, a.reason), (b.on, b.reason));
      }
      expect(fromOld.mode, 'hours');
    });

    test('applyHeatMode leaves exactly one mode in use', () {
      final l = HeatLoad(type: 'radiator', tileId: 'x', tempControl: true);
      applyHeatMode(l, 'price', limit: 9);
      expect((l.mode, l.tempControl, l.priceLimit), ('price', false, 9));
      applyHeatMode(l, 'temp');
      expect((l.mode, l.tempControl, l.priceLimit), ('temp', true, null));
      applyHeatMode(l, 'hours');
      expect((l.mode, l.template), ('hours', 'cheapest'));
      expect(heatModesFor(HeatLoad(type: 'ilp', control: 'thermostat', thermostatId: 't')), ['hours', 'price']);
      expect(heatModesFor(HeatLoad(type: 'water_heater', tileId: 'x')), ['hours', 'price']);
      expect(heatModesFor(HeatLoad(type: 'radiator', tileId: 'x')), ['hours', 'price', 'temp']);
    });
  });

  group('programs and bridges (R635)', () {
    test('every bridge gets only its own programs; unbound ones go to this device\'s bridge', () async {
      final st = await makeState(twoBridges: true);
      st.smartHeating!.loads[1].home = varasto;
      final mine = SmartHeatingJob.fromConfig(st.config, home: mokki, defaultHome: mokki)!;
      final theirs = SmartHeatingJob.fromConfig(st.config, home: varasto, defaultHome: mokki)!;
      expect([for (final l in mine.config.loads) l.id], ['L1']);
      expect([for (final l in theirs.config.loads) l.id], ['L2']);
      expect(theirs.on.keys, ['L2'], reason: 'only its own device commands go to that bridge');
      expect(mine.on.keys, ['L1']);
      // Without any binding nothing changes: one bridge, all programs, as before.
      final st2 = await makeState();
      expect([for (final l in SmartHeatingJob.fromConfig(st2.config)!.config.loads) l.id], ['L1', 'L2']);
      expect(SmartHeatingJob.fromConfig(st2.config)!.toJson()['config'], isNot(contains('pushedHomes')));
      st.dispose();
      st2.dispose();
    });

    test('a device with a program on another bridge is not run twice', () async {
      final st = await makeState(
        twoBridges: true,
        loads: [
          HeatLoad(id: 'A', type: 'radiator', tileId: 'floor', home: mokki),
          HeatLoad(id: 'B', type: 'radiator', tileId: 'floor', home: varasto),
          HeatLoad(id: 'C', type: 'radiator', tileId: 'pump', home: varasto),
        ],
      );
      final c = st.smartHeating!;
      expect(c.conflictIds, {'B'});
      expect([for (final l in c.loadsFor(varasto)) l.id], ['C']);
      expect([for (final l in c.loadsFor(mokki)) l.id], ['A']);
      expect([for (final l in SmartHeatingJob.fromConfig(st.config)!.config.loads) l.id], ['A', 'C']);
      // Two programs for one device on the same bridge are left as they were.
      final same = SmartHeatingConfig(
        loads: [
          HeatLoad(id: 'X', type: 'radiator', tileId: 'f'),
          HeatLoad(id: 'Y', type: 'radiator', tileId: 'f'),
        ],
      );
      expect(same.conflictIds, isEmpty);
      st.dispose();
    });

    test('the bridge refuses a program that belongs to another bridge', () async {
      final store = MemorySecretStore();
      final b = BridgeCore(
        store: store,
        executor: RemoteExecutor(create: _Quiet.new),
        prices: PriceService(client: MockClient((_) async => http.Response('{}', 500))),
      );
      await b.init(name: 'Koti');
      final st = await makeState();
      st.smartHeating!.notify = false;
      st.smartHeating!.loads[1].home = 'f' * 32;
      st.smartHeating!.loads[0].home = b.home;
      final job = SmartHeatingJob.fromConfig(st.config)!;
      final r = await b.rulesOp({
        'id': 1,
        'op': 'rules',
        'spec': {'heating': job.toJson()},
      });
      expect(r['ok'], isTrue);
      expect([for (final l in b.smart.job!.config.loads) l.id], ['L1']);
      await b.dispose();
      st.dispose();
    });

    test('pushing: this bridge and the other one each get their programs; moving one tells the old bridge', () async {
      final st = await makeState(twoBridges: true);
      final main = <Map<String, dynamic>?>[];
      st.remote.router.client = FakeRemote((op, spec) {
        if (op == 'rules') main.add(spec);
        return {'heating': <String, dynamic>{}};
      });
      final sent = <Map<String, dynamic>?>[];
      st.remote.clientFactory = (p) => FakeRemote((op, spec) {
        expect(p.home, varasto);
        sent.add(spec);
        return {'heating': <String, dynamic>{}};
      });
      st.smartHeating!.loads[1].home = varasto;
      expect(await st.pushRules(), isTrue);
      List ids(Map<String, dynamic>? s) => [for (final l in (s!['heating']['config']['loads'] as List)) l['id']];
      expect(ids(main.single), ['L1']);
      expect(ids(sent.single), ['L2']);
      expect(st.smartHeating!.pushedHomes, {varasto});
      expect(st.heatingPushIssues, isEmpty);
      // Nothing changed: nothing is sent again.
      expect(await st.pushRules(), isFalse);
      expect(sent.length, 1);
      // L2 moves to this device's bridge: the old one is told to stop it (an empty set).
      st.smartHeating!.loads[1].home = mokki;
      await st.pushRules();
      expect(ids(main.last), ['L1', 'L2']);
      expect(ids(sent.last), isEmpty);
      expect(st.smartHeating!.pushedHomes, isEmpty);
      st.dispose();
    });

    test(
      'a bridge that does not answer keeps its change waiting and is retried; the others are not held back',
      () async {
        final st = await makeState(twoBridges: true);
        var online = false;
        var asked = 0;
        st.remote.router.client = FakeRemote((op, spec) => {'heating': <String, dynamic>{}});
        st.remote.clientFactory = (p) => FakeRemote((op, spec) {
          asked++;
          if (!online) throw RemoteUnavailable('bridge_offline');
          return {'heating': <String, dynamic>{}};
        });
        st.smartHeating!.loads[1].home = varasto;
        expect(await st.pushRules(), isTrue, reason: 'this bridge took its programs');
        expect(st.heatingPushIssues.keys, [varasto]);
        expect(asked, 1);
        online = true;
        await st.pushRules();
        expect(st.heatingPushIssues, isEmpty);
        expect(st.smartHeating!.pushedHomes, {varasto});
        st.dispose();
      },
    );

    test('with two bridges an unbound program is bound to the bridge it runs on; with one it stays unbound', () async {
      final st = await makeState(twoBridges: true);
      st.remote.router.client = FakeRemote((op, spec) => {'heating': <String, dynamic>{}});
      st.remote.clientFactory = (p) => FakeRemote((op, spec) => {'heating': <String, dynamic>{}});
      await st.pushRules();
      expect([for (final l in st.smartHeating!.loads) l.home], [mokki, mokki]);
      final one = await makeState();
      one.remote.paired = fakeHome();
      one.remote.router.client = FakeRemote((op, spec) => {'heating': <String, dynamic>{}});
      await one.pushRules();
      expect([for (final l in one.smartHeating!.loads) l.home], [null, null]);
      st.dispose();
      one.dispose();
    });

    test('status per bridge: programs from both, and an offline bridge keeps its last state marked offline', () async {
      final st = await makeState(twoBridges: true);
      st.smartHeating!.loads[0].home = mokki;
      st.smartHeating!.loads[1].home = varasto;
      Map<String, dynamic> status(String id, bool on) => {
        'enabled': true,
        'mode': 'normal',
        'loads': {
          id: {'on': on, 'want': on, 'reason': 'cheap', 'at': DateTime(2026, 11, 25, 12).toIso8601String()},
        },
      };
      st.remote.router.client = FakeRemote((op, spec) => {'bridge': 'Mökki', 'heating': status('L1', false)});
      var varastoUp = true;
      st.remote.clientFactory = (p) => FakeRemote((op, spec) {
        if (!varastoUp) throw RemoteUnavailable('bridge_offline');
        return {'bridge': 'Varasto', 'heating': status('L2', true)};
      });
      await st.refreshHeatingStatus();
      final loads = st.heatingStatus!['loads'] as Map;
      expect(loads.keys.toSet(), {'L1', 'L2'});
      expect((loads['L2'] as Map)['bridge'], 'Varasto');
      expect((loads['L1'] as Map)['bridge'], 'Mökki');
      expect(st.heatingOfflineHomes, isEmpty);
      varastoUp = false;
      await st.refreshHeatingStatus();
      expect(st.heatingOfflineHomes, {varasto});
      final l2 = (st.heatingStatus!['loads'] as Map)['L2'] as Map;
      expect(l2['on'], isTrue, reason: 'last known state is kept');
      expect(l2['error'], 'bridge_offline:Varasto');
      final e = heatExplain(st, st.smartHeating!.loads[1]);
      expect(e.heatError!.kind, HeatErrorKind.bridgeOffline);
      expect(e.heatError!.text(HeatText('fi')), 'Kotisilta Varasto ei ole yhteydessä');
      expect(e.heatError!.steps(HeatText('fi')).length, 3);
      // The state is still the decision / last known one, never a red "no answer".
      expect(e.stateWord(HeatText('fi')), 'PÄÄLLÄ');
      // The program on the bridge that answers is not marked.
      expect(heatExplain(st, st.smartHeating!.loads[0]).hasError, isFalse);
      st.dispose();
    });
  });

  group('screens (R636–R638)', () {
    Future<void> openList(WidgetTester tester, AppState st) async {
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: SmartHeatingPage()),
        ),
      );
      await settle(tester);
    }

    testWidgets('the list: one card per program with mode, setting and state; no bridge line with one bridge', (
      tester,
    ) async {
      await wide(tester);
      final st = await makeState();
      st.smartHeating!.loads[0].hours = 8;
      st.smartHeating!.loads[1].priceLimit = 12.5;
      await openList(tester, st);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('program-L2')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('sh-programs')), findsOneWidget);
      expect(find.byKey(const ValueKey('program-L1')), findsOneWidget);
      expect(find.text('Halvimmat tunnit · 8 h päivässä'), findsOneWidget);
      expect(find.text('Hintaraja · enintään 12,5 c/kWh'), findsOneWidget);
      expect(find.byKey(const ValueKey('program-bridge-L1')), findsNothing);
      expect(find.byKey(const ValueKey('program-add')), findsOneWidget);
      await end(tester);
    });

    testWidgets('two bridges: each program says where it runs; an offline bridge is shown for its programs only', (
      tester,
    ) async {
      await wide(tester);
      final st = await makeState(twoBridges: true);
      st.smartHeating!.loads[0].home = mokki;
      st.smartHeating!.loads[1].home = varasto;
      st.heatingOfflineHomes.add(varasto);
      await openList(tester, st);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('program-L2')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Ajaa: Mökki'), findsOneWidget);
      expect(find.text('Varasto ei ole yhteydessä – ohjelma jatkaa siellä itsenäisesti'), findsOneWidget);
      await end(tester);
    });

    testWidgets('a device that already has a program on another bridge is marked and not run', (tester) async {
      await wide(tester);
      final st = await makeState(
        twoBridges: true,
        loads: [
          HeatLoad(id: 'A', name: 'Eka', type: 'radiator', tileId: 'floor', home: mokki),
          HeatLoad(id: 'B', name: 'Toka', type: 'radiator', tileId: 'floor', home: varasto),
        ],
      );
      await openList(tester, st);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('program-B')),
        300,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.byKey(const ValueKey('program-conflict-B')), findsOneWidget);
      expect(find.byKey(const ValueKey('program-conflict-A')), findsNothing);
      expect(find.text('Ei käytössä'), findsOneWidget);
      await end(tester);
    });

    testWidgets('the wizard: device, mode and one setting, with defaults; the program is created and stored', (
      tester,
    ) async {
      await wide(tester);
      final st = await makeState();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: HeatProgramWizard()),
        ),
      );
      await settle(tester);
      expect(find.byKey(const ValueKey('wiz-title')), findsOneWidget);
      expect(find.text('1/3 · Valitse laite'), findsOneWidget);
      // A device that already has a program cannot be picked a second time.
      expect(
        tester.widget<ListTile>(find.byKey(const ValueKey('wiz-device-tile:floor'))).enabled,
        isFalse,
        reason: 'L1 uses it',
      );
      expect(find.textContaining('Ohjelma on jo: Lattialämmitys'), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('wiz-next'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('wiz-device-tile:pump')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      expect(find.text('2/3 · Valitse ohjaustapa'), findsOneWidget);
      for (final m in ['hours', 'price', 'temp']) {
        expect(find.byKey(ValueKey('wiz-mode-$m')), findsOneWidget);
      }
      await tester.tap(find.byKey(const ValueKey('wiz-mode-price')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      expect(find.text('3/3 · Aseta rajat'), findsOneWidget);
      expect(find.byKey(const ValueKey('load-main')), findsOneWidget);
      expect(find.textContaining('Hintaraja'), findsWidgets);
      expect(find.byKey(const ValueKey('wiz-advanced-hint')), findsOneWidget);
      // Raise the limit one step.
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('load-main')), matching: find.byIcon(Icons.add)));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-create')));
      await settle(tester);
      final made = st.smartHeating!.loads.last;
      expect(st.smartHeating!.loads.length, 3);
      expect((made.tileId, made.mode, made.control, made.home), ('pump', 'price', 'switch', null));
      expect(made.priceLimit, isNotNull);
      expect(made.priceLimit! > 0, isTrue);
      await end(tester);
    });

    testWidgets('the wizard: temperature mode needs a sensor before the program can be created', (tester) async {
      await wide(tester);
      final st = await makeState();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: HeatProgramWizard()),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-device-tile:pump')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-mode-temp')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      expect(find.byKey(const ValueKey('load-main-sensor')), findsOneWidget);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('wiz-create'))).onPressed, isNull);
      await tester.tap(find.byKey(const ValueKey('load-main-sensor')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('sensor-room')));
      await settle(tester);
      expect(tester.widget<FilledButton>(find.byKey(const ValueKey('wiz-create'))).onPressed, isNotNull);
      await end(tester);
    });

    testWidgets('the wizard with two bridges asks which one runs the program and stores it', (tester) async {
      await wide(tester);
      final st = await makeState(twoBridges: true);
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: HeatProgramWizard()),
        ),
      );
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-device-tile:pump')));
      await tester.pump();
      expect(find.byKey(const ValueKey('load-bridge')), findsOneWidget);
      await tester.ensureVisible(find.byKey(const ValueKey('load-bridge')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('load-bridge')));
      await settle(tester);
      await tester.tap(find.text('Varasto').last);
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-next')));
      await settle(tester);
      await tester.tap(find.byKey(const ValueKey('wiz-create')));
      await settle(tester);
      expect(st.smartHeating!.loads.last.home, varasto);
      await end(tester);
    });

    testWidgets('the program page: mode and one main setting first, everything else folded under Edistyneet', (
      tester,
    ) async {
      await wide(tester);
      final st = await makeState();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: HeatLoadPage(loadId: 'L2')),
        ),
      );
      await settle(tester);
      final list = find.byType(Scrollable).first;
      await tester.scrollUntilVisible(find.byKey(const ValueKey('load-program')), 400, scrollable: list);
      expect(find.byKey(const ValueKey('load-mode')), findsOneWidget);
      expect(find.byKey(const ValueKey('load-main')), findsOneWidget);
      // A water heater has no temperature mode.
      expect(find.text('Lämpötilan mukaan'), findsNothing);
      expect(find.byKey(const ValueKey('load-bridge')), findsNothing, reason: 'one bridge: no bridge choice');
      for (final k in ['load-prices', 'load-temps', 'load-delays', 'load-hyst', 'load-minon', 'load-fallback']) {
        expect(find.byKey(ValueKey(k)), findsNothing, reason: '$k is folded');
      }
      // The main setting: hours.
      final before = st.smartHeating!.loads[1].hours;
      await tester.tap(find.descendant(of: find.byKey(const ValueKey('load-main')), matching: find.byIcon(Icons.add)));
      await settle(tester);
      expect(st.smartHeating!.loads[1].hours, (before ?? recommend('water_heater', st.smartHeating!.site).hours) + 1);
      // Price limit: the mode switch keeps one mode, the number is the limit.
      await tester.tap(find.text('Hintaraja'));
      await settle(tester);
      expect(st.smartHeating!.loads[1].mode, 'price');
      expect(st.smartHeating!.loads[1].priceLimit, isNotNull);
      await tester.tap(
        find.descendant(of: find.byKey(const ValueKey('load-main')), matching: find.byIcon(Icons.remove)),
      );
      await settle(tester);
      final lim = st.smartHeating!.loads[1].priceLimit!;
      expect(lim, isNot(heatDefaultLimit(st)));
      await end(tester);
    });

    testWidgets('the program page with two bridges: the bridge can be changed and is stored', (tester) async {
      await wide(tester);
      final st = await makeState(twoBridges: true);
      st.smartHeating!.loads[1].home = mokki;
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: const MaterialApp(home: HeatLoadPage(loadId: 'L2')),
        ),
      );
      await settle(tester);
      await tester.scrollUntilVisible(
        find.byKey(const ValueKey('load-bridge')),
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(find.byKey(const ValueKey('load-bridge')));
      await tester.pump();
      await tester.tap(find.byKey(const ValueKey('load-bridge')));
      await settle(tester);
      await tester.tap(find.text('Varasto').last);
      await settle(tester);
      expect(st.smartHeating!.loads[1].home, varasto);
      await end(tester);
    });

    testWidgets('a program on an offline bridge: the tile warns by bridge name and the dialog gives the steps', (
      tester,
    ) async {
      await wide(tester);
      final st = await makeState(twoBridges: true);
      st.smartHeating!.loads[1].home = varasto;
      st.heatingStatus = {
        'enabled': true,
        'mode': 'normal',
        'loads': {
          'L2': {
            'on': true,
            'want': true,
            'reason': 'cheap',
            'at': DateTime.now().toIso8601String(),
            'error': 'bridge_offline:Varasto',
            'offline': true,
            'bridge': 'Varasto',
            'home': varasto,
          },
        },
      };
      final l = st.smartHeating!.loads[1];
      final e = heatExplain(st, l);
      expect(e.stateWord(HeatText('fi')), 'PÄÄLLÄ');
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            home: Scaffold(
              body: Builder(
                builder: (ctx) => TextButton(onPressed: () => showHeatProblem(ctx, st, l, e), child: const Text('x')),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('x'));
      await settle(tester);
      expect(find.text('Kotisilta Varasto ei ole yhteydessä'), findsOneWidget);
      expect(find.byKey(const ValueKey('heat-step-2')), findsOneWidget);
      expect(find.textContaining('vanha lopettaa sen heti'), findsOneWidget);
      await end(tester);
    });
  });
}

class _Quiet extends Driver {
  _Quiet(super.config);
  @override
  Future<Object?> read(Map<String, dynamic> spec) async => 20.5;
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async => 'ok';
  @override
  Future<String> test() async => 'ok';
}
