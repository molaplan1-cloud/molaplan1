/// Connection type `heatpump`: one driver for every built-in heat pump brand (t267u–t270u).
///
/// read  {'hp': 'state', 'unit': id, 'meta': {...}}  -> HpState.toJson() (climate tile)
/// read  {'hp': 'value', 'unit': id, 'key': 'outdoor'} -> one reading (value tiles, automations)
/// read  {'hp': 'units'}                               -> [HpUnit.toJson()] (add wizard)
/// send  {'hp': 'set', 'unit': id, 'field': 'target'|'power'|'mode'|'fan', ...} with value
library;

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../drivers/driver.dart';
import '../drivers/http_driver.dart' show makeHttpClient;
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'aircloud.dart';
import 'daikin.dart';
import 'gshp_modbus.dart';
import 'hp_model.dart';
import 'melcloud.dart';
import 'mhi_wfrac.dart';
import 'myuplink.dart';
import 'smartthings.dart';
import 'toshiba.dart';

/// Brand ids → (fi, en) label.
const hpBrands = <String, (String, String)>{
  'daikin': ('Daikin (paikallinen wifi)', 'Daikin (local Wi-Fi)'),
  'mhi': ('Mitsubishi Heavy (Smart M-Air, paikallinen)', 'Mitsubishi Heavy (Smart M-Air, local)'),
  'melcloud': ('Mitsubishi Electric (MELCloud)', 'Mitsubishi Electric (MELCloud)'),
  'toshiba': ('Toshiba (Home AC Control)', 'Toshiba (Home AC Control)'),
  'smartthings': ('Samsung (SmartThings)', 'Samsung (SmartThings)'),
  'aircloud': ('Hitachi (airCloud Go)', 'Hitachi (airCloud Go)'),
  'myuplink': ('NIBE (myUplink-pilvi)', 'NIBE (myUplink cloud)'),
  'gshp_modbus': ('NIBE / Thermia (Modbus TCP, paikallinen)', 'NIBE / Thermia (Modbus TCP, local)'),
};

/// Test hook: backends get this client instead of a real one.
http.Client? hpTestClient;

HpBackend createHpBackend(Map<String, dynamic> s) {
  final brand = '${s['brand'] ?? ''}';
  final selfSigned = brand == 'daikin' || brand == 'mhi';
  final client =
      hpTestClient ?? (selfSigned ? makeHttpClient(true, timeout: const Duration(seconds: 6)) : newHttpClient());
  return switch (brand) {
    'daikin' => DaikinBackend(s, client),
    'mhi' => MhiWfRacBackend(s, client),
    'melcloud' => MelCloudBackend(s, client),
    'toshiba' => ToshibaBackend(s, client),
    'smartthings' => SmartThingsBackend(s, client),
    'aircloud' => AirCloudBackend(s, client),
    'myuplink' => MyUplinkBackend(s, client),
    'gshp_modbus' => GshpModbusBackend(s, client),
    _ => throw DriverException('Heat pump: unknown brand "$brand"'),
  };
}

class HeatPumpDriver extends Driver {
  HeatPumpDriver(super.config);

  HpBackend? _b;
  HpBackend get backend => _b ??= createHpBackend(s);
  final Map<String, HpUnit> _units = {};
  final Map<String, (DateTime, HpState)> _cache = {};

  /// Several tiles of the same unit share one fetch for a few seconds (cloud rate limits).
  Duration get cacheFor => Duration(seconds: s.integer('cacheSeconds', 5));

  static const descriptor = DriverDescriptor(
    type: 'heatpump',
    fi: 'Lämpöpumppu (oma integraatio)',
    en: 'Heat pump (built-in integration)',
    create: HeatPumpDriver.new,
    connectionFields: [
      FieldSpec(
        'brand',
        'Merkki',
        'Brand',
        kind: FieldKind.choice,
        options: ['daikin', 'mhi', 'melcloud', 'toshiba', 'smartthings', 'aircloud', 'myuplink', 'gshp_modbus'],
        optionLabels: hpBrands,
        defaultValue: 'daikin',
        helpFi: 'Valmistaja ja yhteystapa. Paikalliset toimivat ilman pilveä.',
        helpEn: 'Maker and connection type. Local ones work without the cloud.',
      ),
      FieldSpec(
        'address',
        'Laitteen IP-osoite (paikalliset)',
        'Device IP (local brands)',
        hint: '192.168.x.x',
        helpFi: 'Paikallisen laitteen IP-osoite (reitittimen laitelistasta).',
        helpEn: "IP address of a local unit (from your router's device list).",
      ),
      FieldSpec(
        'email',
        'Sähköposti (pilvi)',
        'E-mail (cloud)',
        advanced: true,
        helpFi: 'Valmistajan sovelluksen kirjautumissähköposti (MELCloud, airCloud).',
        helpEn: "The e-mail you sign in to the maker's app with (MELCloud, airCloud).",
      ),
      FieldSpec(
        'username',
        'Käyttäjätunnus (Toshiba)',
        'Username (Toshiba)',
        advanced: true,
        helpFi: 'Toshiba Home AC Control -sovelluksen käyttäjätunnus.',
        helpEn: 'Your Toshiba Home AC Control username.',
      ),
      FieldSpec(
        'password',
        'Salasana',
        'Password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Valmistajan sovelluksen salasana. Tallentuu vain tälle laitteelle / omaan holviisi.',
        helpEn: "The maker's app password. Stored only on this device / in your own vault.",
      ),
      FieldSpec(
        'token',
        'Tunnus (SmartThings token)',
        'Token (SmartThings)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'SmartThingsin henkilökohtainen token (account.smartthings.com/tokens).',
        helpEn: 'SmartThings personal access token (account.smartthings.com/tokens).',
      ),
      FieldSpec(
        'key',
        'Avain (Daikin BRP072C, tarrasta)',
        'Key (Daikin BRP072C, sticker)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'BRP072C-ohjaimen tarrassa oleva avain (key).',
        helpEn: "The key printed on the BRP072C adapter's sticker.",
      ),
      FieldSpec(
        'clientId',
        'Client ID (myUplink)',
        'Client ID (myUplink)',
        advanced: true,
        helpFi: 'Oman sovelluksen Client ID osoitteesta dev.myuplink.com.',
        helpEn: 'Client ID of your own app at dev.myuplink.com.',
      ),
      FieldSpec(
        'clientSecret',
        'Client Secret (myUplink)',
        'Client Secret (myUplink)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Oman sovelluksen Client Secret osoitteesta dev.myuplink.com.',
        helpEn: 'Client Secret of your own app at dev.myuplink.com.',
      ),
      FieldSpec(
        'profile',
        'Rekisterikartta (Modbus)',
        'Register map (Modbus)',
        kind: FieldKind.choice,
        options: ['nibe_s', 'nibe_f', 'thermia_genesis', 'custom'],
        optionLabels: {
          'nibe_s': ('NIBE S-sarja', 'NIBE S-series'),
          'nibe_f': ('NIBE F-sarja + MODBUS 40', 'NIBE F-series + MODBUS 40'),
          'thermia_genesis': ('Thermia Genesis', 'Thermia Genesis'),
          'custom': ('Tuotu rekisterilista', 'Imported register list'),
        },
        defaultValue: 'nibe_s',
        advanced: true,
        helpFi: "Pumpun mallisarja. 'Tuotu rekisterilista' = pumpun oma CSV-vienti.",
        helpEn: "The pump series. 'Imported register list' = the pump's own CSV export.",
      ),
      FieldSpec(
        'port',
        'Portti',
        'Port',
        kind: FieldKind.number,
        advanced: true,
        helpFi: 'Yleensä oletus (Modbus 502, MHI 51443).',
        helpEn: 'Usually the default (Modbus 502, MHI 51443).',
      ),
      FieldSpec(
        'unitId',
        'Modbus unit id',
        'Modbus unit id',
        kind: FieldKind.number,
        defaultValue: 1,
        advanced: true,
        helpFi: 'Modbus-laitteen osoite, yleensä 1.',
        helpEn: 'Modbus unit address, usually 1.',
      ),
      FieldSpec(
        'baseUrl',
        'Palvelimen osoite (vain testaukseen)',
        'Server URL (testing only)',
        advanced: true,
        helpFi: 'Vain testaukseen: korvaa valmistajan palvelimen osoitteen.',
        helpEn: "Testing only: replaces the maker's server address.",
      ),
    ],
    readFields: [
      FieldSpec(
        'hp',
        'Mitä luetaan',
        'What to read',
        kind: FieldKind.choice,
        options: ['state', 'value'],
        optionLabels: {'state': ('Koko tila', 'Full state'), 'value': ('Yksi lukema', 'One reading')},
        defaultValue: 'value',
        helpFi: 'Koko tila (lämpöpumppuruutu) tai yksi lukema.',
        helpEn: 'Full state (heat pump tile) or one reading.',
      ),
      FieldSpec(
        'unit',
        'Sisäyksikön tunnus',
        'Unit id',
        defaultValue: 'main',
        helpFi: "Sisäyksikön tunnus; yhden laitteen tileillä 'main'.",
        helpEn: "Indoor unit id; 'main' for single-unit devices.",
      ),
      FieldSpec(
        'key',
        'Lukema (current, target, outdoor, power…)',
        'Reading (current, target, outdoor, power…)',
        defaultValue: 'current',
        helpFi: 'Mikä lukema: current, target, outdoor, power, supply, hot_water…',
        helpEn: 'Which reading: current, target, outdoor, power, supply, hot_water…',
      ),
    ],
    commandFields: [
      FieldSpec(
        'hp',
        'Komento',
        'Command',
        kind: FieldKind.choice,
        options: ['set'],
        optionLabels: {'set': ('Aseta', 'Set')},
        defaultValue: 'set',
        helpFi: 'Koko tila (lämpöpumppuruutu) tai yksi lukema.',
        helpEn: 'Full state (heat pump tile) or one reading.',
      ),
      FieldSpec(
        'unit',
        'Sisäyksikön tunnus',
        'Unit id',
        defaultValue: 'main',
        helpFi: "Sisäyksikön tunnus; yhden laitteen tileillä 'main'.",
        helpEn: "Indoor unit id; 'main' for single-unit devices.",
      ),
      FieldSpec(
        'field',
        'Mitä asetetaan',
        'What to set',
        kind: FieldKind.choice,
        options: ['target', 'power', 'mode', 'fan'],
        optionLabels: {
          'target': ('Asetusarvo', 'Setpoint'),
          'power': ('Virta', 'Power'),
          'mode': ('Tila', 'Mode'),
          'fan': ('Puhallin', 'Fan'),
        },
        defaultValue: 'target',
        helpFi: 'Asetusarvo, virta, tila tai puhallin.',
        helpEn: 'Setpoint, power, mode or fan.',
      ),
      FieldSpec(
        'value',
        'Arvo ({{value}})',
        'Value ({{value}})',
        defaultValue: '{{value}}',
        helpFi: 'Lähetettävä arvo; {{value}} = ruudun arvo.',
        helpEn: "Value to send; {{value}} = the tile's value.",
      ),
    ],
  );

  Future<HpUnit> _unit(Map<String, dynamic> spec) async {
    final id = '${spec['unit'] ?? 'main'}';
    final known = _units[id];
    if (known != null) return known;
    if (spec['meta'] is Map) {
      return _units[id] = HpUnit(id: id, name: id, meta: Map<String, dynamic>.from(spec['meta'] as Map));
    }
    for (final u in await backend.units()) {
      _units[u.id] = u;
    }
    final u = _units[id] ?? (_units.length == 1 ? _units.values.first : null);
    if (u == null) {
      throw DriverException(
        dtx('Lämpöpumppua "$id" ei löydy enää tililtä', 'Heat pump "$id" is no longer in the account'),
      );
    }
    return u;
  }

  Future<HpState> _state(HpUnit u, {bool fresh = false}) async {
    final c = _cache[u.id];
    if (!fresh && c != null && DateTime.now().difference(c.$1) < cacheFor) return c.$2;
    final st = await backend.state(u);
    _cache[u.id] = (DateTime.now(), st);
    return st;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    switch ('${spec['hp'] ?? 'value'}') {
      case 'units':
        final l = await backend.units();
        for (final u in l) {
          _units[u.id] = u;
        }
        return [for (final u in l) u.toJson()];
      case 'state':
        return (await _state(await _unit(spec))).toJson();
      default:
        final u = await _unit(spec);
        final key = '${spec['key'] ?? 'current'}';
        if (key.startsWith('p:') && backend is MyUplinkBackend) {
          return (backend as MyUplinkBackend).point(u, key.substring(2));
        }
        return (await _state(u)).value(key);
    }
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final u = await _unit(spec);
    final field = '${spec['field'] ?? 'target'}';
    final raw = spec['value'] == null || '${spec['value']}' == '{{value}}' ? value : spec['value'];
    final ch = HpChange();
    switch (field) {
      case 'target':
        final v = hpNum(raw ?? spec['target']);
        if (v == null) throw DriverException(dtx('Asetusarvo puuttuu', 'Setpoint missing'));
        ch.target = v;
      case 'power':
        final on = spec['on'] ?? raw;
        ch.power = on == true || '$on' == '1' || '$on'.toLowerCase() == 'true' || '$on'.toLowerCase() == 'on';
      case 'mode':
        ch.mode = '${spec['mode'] ?? raw}';
      case 'fan':
        ch.fan = '${spec['fan'] ?? raw}';
      default:
        throw DriverException('Heat pump: field $field?');
    }
    final cur = await _state(u, fresh: true).catchError((_) => HpState());
    final next = await backend.apply(u, cur, ch);
    if (next != null) {
      _cache[u.id] = (DateTime.now(), next);
    } else {
      _cache.remove(u.id);
    }
    return raw;
  }

  @override
  Future<String> test() => backend.test();

  @override
  Future<void> dispose() async {
    await _b?.dispose();
    _b = null;
  }
}

/// Climate tile + optional extra tiles for one unit (wizard / provider).
List<TileConfig> heatPumpTiles(
  String connId,
  HpUnit u,
  HpState st, {
  required String title,
  required String lang,
  bool extras = false,
}) {
  String t(String fi, String en) => tr(lang, fi, en);
  final unitSpec = {'unit': u.id, if (u.meta.isNotEmpty) 'meta': u.meta};
  final offset = st.targetKind == 'offset';
  final out = <TileConfig>[
    TileConfig(
      type: TileType.value,
      title: title,
      icon: 'heatpump',
      colSpan: 2,
      unit: offset ? '' : '°C',
      min: st.minTarget,
      max: st.maxTarget,
      step: st.step,
      pollSeconds: u.kind == 'air' ? 30 : 60,
      connectionId: connId,
      read: {'kind': 'climate', 'hp': true, ...unitSpec},
      commands: [
        CommandStep(connectionId: connId, spec: {'hp': 'set', 'field': 'target', 'value': '{{value}}', ...unitSpec}),
      ],
    ),
  ];
  if (!extras) return out;
  if (st.power != null) {
    out.add(
      TileConfig(
        type: TileType.toggle,
        title: '$title – ${t('päällä', 'on')}',
        icon: 'power',
        connectionId: connId,
        pollSeconds: 60,
        read: {'hp': 'value', 'key': 'power', ...unitSpec},
        onValue: '1',
        onCommand: CommandStep(connectionId: connId, spec: {'hp': 'set', 'field': 'power', 'on': true, ...unitSpec}),
        offCommand: CommandStep(connectionId: connId, spec: {'hp': 'set', 'field': 'power', 'on': false, ...unitSpec}),
      ),
    );
  }
  out.add(
    TileConfig(
      type: TileType.slider,
      title: '$title – ${offset ? t('käyrän siirto', 'curve offset') : t('asetus', 'setpoint')}',
      icon: 'thermostat',
      unit: offset ? '' : '°C',
      min: st.minTarget,
      max: st.maxTarget,
      step: st.step,
      decimals: st.step < 1 ? 1 : 0,
      connectionId: connId,
      pollSeconds: 60,
      read: {'hp': 'value', 'key': 'target', ...unitSpec},
      commands: [
        CommandStep(connectionId: connId, spec: {'hp': 'set', 'field': 'target', 'value': '{{value}}', ...unitSpec}),
      ],
    ),
  );
  final names = <String, (String, String)>{
    'outdoor': ('Ulkolämpötila', 'Outdoor temperature'),
    'supply': ('Menovesi', 'Supply'),
    'return': ('Paluuvesi', 'Return'),
    'hot_water': ('Käyttövesi', 'Hot water'),
    'brine_in': ('Keruuliuos sisään', 'Brine in'),
    'brine_out': ('Keruuliuos ulos', 'Brine out'),
    'degree_minutes': ('Astetminuutit', 'Degree minutes'),
    'compressor_hz': ('Kompressori', 'Compressor'),
    'energy_kwh': ('Energia', 'Energy'),
  };
  final keys = [
    if (st.outdoor != null) 'outdoor',
    ...st.extra.keys.where(names.containsKey).where((k) => k != 'outdoor'),
  ];
  for (final k in keys) {
    final n = names[k]!;
    out.add(
      TileConfig(
        type: TileType.value,
        title: '$title – ${t(n.$1, n.$2)}',
        icon: k == 'compressor_hz' ? 'speed' : (k == 'energy_kwh' ? 'bolt' : 'thermostat'),
        unit: switch (k) {
          'compressor_hz' => 'Hz',
          'energy_kwh' => 'kWh',
          'degree_minutes' => '',
          _ => '°C',
        },
        decimals: k == 'degree_minutes' || k == 'compressor_hz' ? 0 : 1,
        connectionId: connId,
        pollSeconds: 60,
        read: {'hp': 'value', 'key': k, ...unitSpec},
      ),
    );
  }
  return out;
}
