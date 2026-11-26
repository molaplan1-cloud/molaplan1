import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/discovery.dart';
import 'package:molaplan/core/field_help.dart';
import 'package:molaplan/core/fields.dart';
import 'package:molaplan/core/friendly_error.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/drivers/registry.dart';
import 'package:molaplan/main.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/templates/device_templates.dart';
import 'package:molaplan/ui/app_scope.dart';
import 'package:molaplan/ui/error_box.dart';
import 'package:molaplan/ui/spec_form.dart';
import 'package:molaplan/ui/template_gallery.dart';
import 'package:molaplan/ui/theme.dart';

Future<AppState> newState({bool onboarded = false}) async {
  final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
  await st.load();
  if (onboarded) await st.setOnboardingDone(true);
  return st;
}

Map<String, dynamic> sampleInputs(DeviceTemplate t) => {
  for (final f in t.inputs) f.key: f.defaultValue ?? f.hint ?? 'x',
  'address': t.connectionType == 'homeassistant' ? '192.168.1.20' : '192.168.1.50',
  'token': 'tok',
  'profile': 'Airfi',
};

void main() {
  group('friendly errors', () {
    test('network failures become plain Finnish', () {
      final cases = <Object, ErrorKind>{
        const SocketException('No route to host', osError: OSError('No route to host', 113)): ErrorKind.unreachable,
        const SocketException('Connection refused', osError: OSError('Connection refused', 111)): ErrorKind.refused,
        const SocketException("Failed host lookup: 'iv.local'"): ErrorKind.dns,
        TimeoutException('x'): ErrorKind.unreachable,
        DriverException('HTTP 401: Unauthorized'): ErrorKind.auth,
        DriverException('Home Assistant: entity light.x not found'): ErrorKind.notFound,
        DriverException('Modbus exception 2 (function 3)'): ErrorKind.modbusAddress,
        DriverException('Modbus: timeout'): ErrorKind.modbusTimeout,
        DriverException('TCP: no response'): ErrorKind.noResponse,
        const HandshakeException('CERTIFICATE_VERIFY_FAILED'): ErrorKind.tls,
        const FormatException('bad'): ErrorKind.config,
        'Connection missing / Yhteys puuttuu': ErrorKind.missingConnection,
      };
      cases.forEach((e, k) => expect(classifyError(e), k, reason: '$e'));
      final f = friendlyError(const SocketException('No route to host'), 'fi');
      expect(f.title, 'Laitetta ei löydy osoitteesta');
      expect(f.hint, contains('samassa wifissä'));
      expect(friendlyError(const SocketException('No route to host'), 'en').hint, contains('same Wi-Fi'));
    });

    testWidgets('ErrorBox shows title + hint, details folded', (tester) async {
      final st = await newState();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            home: Scaffold(body: ErrorBox(error: const SocketException('Connection refused'))),
          ),
        ),
      );
      expect(find.textContaining('ei vastaa tähän porttiin'), findsOneWidget);
      expect(find.text('Tekniset tiedot'), findsOneWidget);
      expect(find.textContaining('SocketException'), findsNothing);
    });
  });

  group('field help', () {
    test('every driver field has Finnish and English help', () {
      for (final d in driverDescriptors) {
        for (final (section, fields) in [
          ('conn', d.connectionFields),
          ('read', d.readFields),
          ('cmd', d.commandFields),
        ]) {
          for (final f in fields) {
            final scope = '${d.type}.$section';
            expect(helpText(f, 'fi', scope: scope), isNotNull, reason: '$scope.${f.key}');
            expect(helpText(f, 'en', scope: scope), isNotNull, reason: '$scope.${f.key}');
          }
        }
      }
    });
    test('advanced flags', () {
      final m = descriptorFor('modbus');
      FieldSpec rf(String k) => m.readFields.firstWhere((f) => f.key == k);
      expect(isAdvanced(rf('offset'), scope: 'modbus.read'), isTrue);
      expect(isAdvanced(rf('address'), scope: 'modbus.read'), isFalse);
      // required fields are never hidden
      final ha = descriptorFor('homeassistant').connectionFields.firstWhere((f) => f.key == 'token');
      expect(isAdvanced(ha, scope: 'homeassistant.conn'), isFalse);
    });

    testWidgets('SpecForm hides advanced options under Lisäasetukset', (tester) async {
      final st = await newState();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(
            theme: molaplanTheme(),
            home: Scaffold(
              body: SingleChildScrollView(
                child: SpecForm(fields: descriptorFor('modbus').readFields, values: {}, scope: 'modbus.read'),
              ),
            ),
          ),
        ),
      );
      expect(find.text('Lisäasetukset'), findsOneWidget);
      expect(find.text('Siirtymä'), findsNothing);
      expect(find.text('Kerroin'), findsOneWidget);
      expect(find.textContaining('vähennä 1'), findsOneWidget); // help text visible
      await tester.tap(find.text('Lisäasetukset'));
      await tester.pumpAndSettle();
      expect(find.text('Siirtymä'), findsOneWidget);
    });
  });

  group('templates', () {
    test('every template builds consistent connections and tiles', () {
      for (final t in deviceTemplates) {
        final r = t.build(sampleInputs(t), 'fi');
        expect(r.connections, isNotEmpty, reason: t.id);
        final ids = r.connections.map((c) => c.id).toSet();
        for (final tile in r.tiles) {
          if (tile.connectionId != null) expect(ids, contains(tile.connectionId), reason: '${t.id} ${tile.title}');
          for (final s in [tile.onCommand, tile.offCommand, ...tile.commands].whereType<CommandStep>()) {
            expect(ids, contains(s.connectionId), reason: '${t.id} ${tile.title}');
          }
        }
        // Device templates need an address; the ntfy template needs a topic instead.
        expect(
          t.inputs.where((f) => f.required).map((f) => f.key),
          contains(switch (t.id) {
            'ntfy' || 'ntfy_device' => 'topic',
            'electricity_price' => 'zone',
            'airthings' => 'clientId', // cloud only
            'airthings_wave' => 'serial', // Bluetooth
            _ => 'address',
          }),
          reason: t.id,
        );
        // JSON-safe
        jsonEncode(r.tiles.map((x) => x.toJson()).toList());
      }
    });

    test('address normalisation', () {
      expect(normUrl('192.168.1.5'), 'http://192.168.1.5');
      expect(normUrl('https://ha.local:8123/'), 'https://ha.local:8123');
      expect(normHost('http://192.168.1.5:502/x'), '192.168.1.5');
      expect(normHost(' 10.0.0.2 '), '10.0.0.2');
      final ha = templateById('homeassistant')!.build({'address': '192.168.1.20', 'token': 't'}, 'fi');
      expect(ha.connections.single.settings['baseUrl'], 'http://192.168.1.20:8123');
      expect(ha.connections.single.secrets['token'], 't');
    });

    test('IV profiles parse; offsets applied; writable fan becomes a slider', () {
      expect(ivProfiles.length, greaterThanOrEqualTo(5));
      final airfi = ivProfiles.firstWhere((p) => p.id == 'airfi');
      final tiles = airfi.tiles('c', 'fi');
      final supply = tiles.firstWhere((t) => t.title.startsWith('Tuloilma ('));
      expect(supply.read['address'], 5); // 3x00005 → address 5 (AirFi: address = register number)
      expect(supply.read['table'], 'input');
      expect(supply.read['dataType'], 'int16');
      expect(supply.read['scale'], 0.1);
      expect(tiles.where((t) => t.type == TileType.slider), isNotEmpty);
    });

    test('applyTemplate reuses an existing Home Assistant connection', () async {
      final st = await newState();
      await st.applyTemplate(
        templateById('homeassistant')!.build({'address': '192.168.1.20', 'token': 'T', 'light': 'light.a'}, 'fi'),
      );
      await st.applyTemplate(
        templateById('heatpump_ha')!.build({'address': 'http://192.168.1.20:8123', 'entity': 'climate.x'}, 'fi'),
      );
      expect(st.config.connections.length, 1);
      final cid = st.config.connections.single.id;
      final tiles = st.config.dashboards.first.tiles;
      // The HA template itself adds no tiles any more (entities are picked in the HA picker, t108u).
      expect(tiles.length, 1); // t137u: one combined thermostat tile
      expect(tiles.every((t) => t.connectionId == cid), isTrue);
      expect(
        tiles.where((t) => t.commands.isNotEmpty).every((t) => t.commands.every((c) => c.connectionId == cid)),
        isTrue,
      );
      expect(st.config.connections.single.secrets['token'], 'T');
    });
  });

  group('discovery', () {
    test('found devices map to templates and addresses', () {
      const shelly = FoundDevice(
        name: 'shellyplus1pm-a8032ab1._shelly._tcp.local',
        service: '_shelly._tcp',
        host: 'shellyplus1pm-a8032ab1.local',
        ip: '192.168.1.44',
        port: 80,
      );
      const ha = FoundDevice(
        name: 'Koti._home-assistant._tcp.local',
        service: '_home-assistant._tcp',
        host: 'ha.local',
        ip: '192.168.1.20',
        port: 8123,
      );
      const esp = FoundDevice(
        name: 'sauna._esphomelib._tcp.local',
        service: '_esphomelib._tcp',
        host: 'sauna.local',
        ip: '192.168.1.60',
        port: 6053,
      );
      const web = FoundDevice(
        name: 'printer._http._tcp.local',
        service: '_http._tcp',
        host: 'p.local',
        ip: '192.168.1.9',
        port: 8080,
      );
      expect(shelly.kind, 'shelly');
      expect(shelly.address, '192.168.1.44');
      expect(shelly.label, 'shellyplus1pm-a8032ab1');
      expect(ha.address, '192.168.1.20');
      expect(esp.address, '192.168.1.60'); // native API port is not the web port
      expect(web.address, '192.168.1.9:8080');
      expect(deviceMatchesTemplate(shelly, 'shelly'), isTrue);
      expect(deviceMatchesTemplate(ha, 'shelly'), isFalse);
      expect(deviceMatchesTemplate(ha, 'heatpump_ha'), isTrue);
      expect(deviceMatchesTemplate(esp, 'esphome'), isTrue);
    });
  });

  group('onboarding + undo (widgets)', () {
    setUp(() {});
    for (final (w, scale) in [(320.0, 1.0), (360.0, 1.3), (1280.0, 1.0)]) {
      testWidgets('template gallery fits at ${w.toInt()} px, text x$scale', (tester) async {
        tester.view.physicalSize = Size(w, 800);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        final st = await newState(onboarded: true);
        await tester.pumpWidget(
          AppScope(
            state: st,
            child: MaterialApp(
              theme: molaplanTheme(),
              builder: (c, child) => MediaQuery(
                data: MediaQuery.of(c).copyWith(textScaler: TextScaler.linear(scale)),
                child: child!,
              ),
              home: Scaffold(
                body: TemplateGrid(onPick: (_) {}, onManual: () {}),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        for (var i = 0; i < 6; i++) {
          expect(tester.takeException(), isNull);
          await tester.drag(find.byType(CustomScrollView), const Offset(0, -300));
          await tester.pumpAndSettle();
        }
        expect(tester.takeException(), isNull);
      });
    }

    testWidgets('first run: guide → template → tile → done', (tester) async {
      final st = await newState();
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      expect(find.text('Tervetuloa Molaplaniin'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-start')));
      await tester.pumpAndSettle();
      expect(find.text('Lisää ensimmäinen laite'), findsOneWidget);
      expect(find.byKey(const ValueKey('brand-shelly')), findsOneWidget);
      expect(find.byKey(const ValueKey('brand-hue')), findsOneWidget);
      // Simple mode: technical templates (HTTP, MQTT…) are hidden; brands and devices only.
      expect(find.text('Muu wifi-laite (HTTP)'), findsNothing);
      await tester.scrollUntilVisible(find.text('Tasmota-laite'), 200, scrollable: find.byType(Scrollable).last);
      await tester.tap(find.text('Tasmota-laite'));
      await tester.pumpAndSettle();
      // only a few simple fields
      await tester.enterText(find.widgetWithText(TextField, 'Laitteen IP-osoite *'), '192.168.1.77');
      await tester.enterText(find.widgetWithText(TextField, 'Mitä se ohjaa?'), 'Varaaja');
      await tester.pumpAndSettle();
      expect(find.text('Nämä ruudut luodaan'), findsOneWidget);
      expect(find.widgetWithText(CheckboxListTile, 'Varaaja'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('template-add')));
      await tester.pumpAndSettle();
      expect(find.text('Ruudut ovat valmiina'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-next')));
      await tester.pumpAndSettle();
      // v0.3: remote access step
      expect(find.text('Haluatko ohjata kotia myös kodin ulkopuolelta?'), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-pair')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-bridge')), findsOneWidget);
      expect(find.byKey(const ValueKey('remote-guides')), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-remote-next')));
      await tester.pumpAndSettle();
      expect(find.text('Valmista!'), findsOneWidget);
      await tester.tap(find.byKey(const ValueKey('onboarding-done')));
      await tester.pumpAndSettle();
      expect(st.config.onboardingDone, isTrue);
      expect(st.config.connections.single.settings['baseUrl'], 'http://192.168.1.77');
      expect(find.text('Varaaja'), findsWidgets);
      await tester.pumpWidget(const SizedBox());
    });

    testWidgets('skip guide marks it done; Settings re-opens it', (tester) async {
      final st = await newState();
      tester.view.physicalSize = const Size(1000, 1600);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('onboarding-skip')));
      await tester.pumpAndSettle();
      expect(st.config.onboardingDone, isTrue);
      expect(find.byKey(const ValueKey('empty-add-device')), findsOneWidget);
      await tester.tap(find.text('Asetukset'));
      await tester.pumpAndSettle();
      // t162u: Ulkoasu made the page longer.
      await tester.scrollUntilVisible(find.byKey(const ValueKey('settings-onboarding')), 200, scrollable: find.byType(Scrollable).first);
      await tester.tap(find.byKey(const ValueKey('settings-onboarding')));
      await tester.pumpAndSettle();
      expect(find.text('Tervetuloa Molaplaniin'), findsOneWidget);
    });

    testWidgets('deleting a tile asks first and can be undone', (tester) async {
      final st = await newState(onboarded: true);
      final d = st.config.dashboards.first;
      await st.upsertTile(d, TileConfig(type: TileType.toggle, title: 'Valot'));
      await st.upsertTile(d, TileConfig(type: TileType.toggle, title: 'Pumppu'));
      tester.view.physicalSize = const Size(600, 1000);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await tester.pumpWidget(MolaplanApp(state: st));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('control-menu')));
      await tester.pumpAndSettle();
      await tester.tap(find.byKey(const ValueKey('control-edit')));
      await tester.pumpAndSettle();
      await tester.tap(find.descendant(of: find.byType(Wrap), matching: find.byIcon(Icons.delete_outline)).last);
      await tester.pumpAndSettle();
      expect(find.text('Poistetaanko ruutu?'), findsOneWidget);
      await tester.tap(find.widgetWithText(FilledButton, 'Poista'));
      await tester.pumpAndSettle();
      expect(d.tiles.map((t) => t.title), ['Valot']);
      await tester.tap(find.text('Kumoa'));
      await tester.pumpAndSettle();
      expect(d.tiles.map((t) => t.title), ['Valot', 'Pumppu']);
      await tester.pumpWidget(const SizedBox());
    });
  });
}
