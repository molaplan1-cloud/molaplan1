/// Connection type `evcharger` (R289): one driver for every built-in EV charger brand.
///
/// read {'ev': 'status' | 'charging' | 'power' | 'session' | 'total' | 'current', 'charger': id}
/// read {'ev': 'chargers'}                         -> [EvCharger.toJson()] (add wizard)
/// read {'ev': 'state', 'charger': id}             -> EvState.toJson()
/// send {'ev': 'start' | 'stop', 'charger': id}
/// send {'ev': 'charge', 'charger': id} value on/off (toggle)
/// send {'ev': 'current', 'charger': id, 'value': '{{value}}'} amps (slider)
library;

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'ev_clouds.dart';
import 'ev_model.dart';
import 'ocpp_server.dart';

const evBrands = <String, (String, String)>{
  'ocpp': ('OCPP 1.6J (paikallinen, mikä tahansa merkki)', 'OCPP 1.6J (local, any brand)'),
  'easee': ('Easee (pilvi)', 'Easee (cloud)'),
  'zaptec': ('Zaptec (pilvi)', 'Zaptec (cloud)'),
  'wallbox': ('Wallbox (pilvi)', 'Wallbox (cloud)'),
};

/// Test hook.
http.Client? evTestClient;

EvBackend createEvBackend(Map<String, dynamic> s) {
  final brand = '${s['brand'] ?? ''}';
  http.Client c() => evTestClient ?? newHttpClient();
  return switch (brand) {
    'ocpp' => OcppBackend(s),
    'easee' => EaseeBackend(s, c()),
    'zaptec' => ZaptecBackend(s, c()),
    'wallbox' => WallboxBackend(s, c()),
    _ => throw DriverException('EV charger: unknown brand "$brand"'),
  };
}

bool _truthy(Object? v) {
  final s = '$v'.toLowerCase();
  return v == true || s == '1' || s == 'true' || s == 'on';
}

class EvChargerDriver extends Driver {
  EvChargerDriver(super.config);

  EvBackend? _b;
  EvBackend get backend => _b ??= createEvBackend(s);
  final Map<String, EvCharger> _chargers = {};
  final Map<String, (DateTime, EvState)> _cache = {};

  Duration get cacheFor => Duration(seconds: s.integer('cacheSeconds', '${s['brand']}' == 'ocpp' ? 1 : 10));

  static const descriptor = DriverDescriptor(
    type: 'evcharger',
    fi: 'Sähköauton laturi (oma integraatio)',
    en: 'EV charger (built-in integration)',
    create: EvChargerDriver.new,
    connectionFields: [
      FieldSpec(
        'brand',
        'Merkki ja yhteystapa',
        'Brand and connection',
        kind: FieldKind.choice,
        options: ['ocpp', 'easee', 'zaptec', 'wallbox'],
        optionLabels: evBrands,
        defaultValue: 'ocpp',
        helpFi: 'OCPP toimii paikallisesti ilman pilveä (laturi ottaa yhteyden tähän sovellukseen tai siltaan).',
        helpEn: 'OCPP works locally without a cloud (the charger connects to this app or the bridge).',
      ),
      FieldSpec(
        'port',
        'OCPP-portti',
        'OCPP port',
        kind: FieldKind.number,
        defaultValue: 9000,
        advanced: true,
        helpFi: 'Portti, jota tämä laite kuuntelee. Laturin osoite: ws://<tämän laitteen IP>:9000/ocpp/',
        helpEn: 'The port this device listens on. Charger URL: ws://<this device IP>:9000/ocpp/',
      ),
      FieldSpec(
        'chargePointId',
        'Laturin tunnus (OCPP)',
        'Charge point id (OCPP)',
        advanced: true,
        helpFi: 'Laturin OCPP-tunnus (charge point id). Tyhjä = ensimmäinen yhteyden ottanut.',
        helpEn: 'The charger\'s OCPP charge point id. Empty = the first one that connects.',
      ),
      FieldSpec(
        'idTag',
        'Tunniste (idTag) etäkäynnistykseen',
        'idTag for remote start',
        advanced: true,
        helpFi: 'Lähetetään RemoteStartTransactionissa. Tyhjä = "molaplan".',
        helpEn: 'Sent with RemoteStartTransaction. Empty = "molaplan".',
      ),
      FieldSpec(
        'username',
        'Käyttäjätunnus / sähköposti (pilvi)',
        'Username / e-mail (cloud)',
        advanced: true,
        helpFi: 'Sama kuin valmistajan sovelluksessa.',
        helpEn: 'Same as in the maker\'s app.',
      ),
      FieldSpec(
        'password',
        'Salasana',
        'Password',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Pilvi: sovelluksen salasana. OCPP: valinnainen Basic auth -salasana. Tallentuu vain tälle laitteelle.',
        helpEn: 'Cloud: the app password. OCPP: optional Basic auth password. Stored on this device only.',
      ),
    ],
    readFields: [
      FieldSpec(
        'ev',
        'Lukema',
        'Reading',
        kind: FieldKind.choice,
        options: ['status', 'charging', 'power', 'session', 'total', 'current'],
        optionLabels: {
          'status': ('Tila', 'Status'),
          'charging': ('Lataa (1/0)', 'Charging (1/0)'),
          'power': ('Latausteho (W)', 'Charging power (W)'),
          'session': ('Tämä lataus (kWh)', 'This session (kWh)'),
          'total': ('Yhteensä (kWh)', 'Total (kWh)'),
          'current': ('Virtaraja (A)', 'Current limit (A)'),
        },
        defaultValue: 'status',
        helpFi: 'Mikä laturin lukema näytetään.',
        helpEn: 'Which charger reading to show.',
      ),
      FieldSpec(
        'charger',
        'Laturin tunnus',
        'Charger id',
        helpFi: 'Tilin laturin tunnus; tyhjä = ainoa laturi.',
        helpEn: 'Charger id in the account; empty = the only charger.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'ev',
        'Komento',
        'Command',
        kind: FieldKind.choice,
        options: ['start', 'stop', 'charge', 'current'],
        optionLabels: {
          'start': ('Aloita lataus', 'Start charging'),
          'stop': ('Lopeta / tauko', 'Stop / pause'),
          'charge': ('Lataus päälle/pois', 'Charging on/off'),
          'current': ('Aseta virtaraja (A)', 'Set current limit (A)'),
        },
        defaultValue: 'start',
        helpFi: 'Aloita, lopeta tai aseta virtaraja.',
        helpEn: 'Start, stop or set the current limit.',
      ),
      FieldSpec(
        'charger',
        'Laturin tunnus',
        'Charger id',
        helpFi: 'Tilin laturin tunnus; tyhjä = ainoa laturi.',
        helpEn: 'Charger id in the account; empty = the only charger.',
      ),
      FieldSpec(
        'value',
        'Arvo ({{value}})',
        'Value ({{value}})',
        defaultValue: '{{value}}',
        helpFi: 'Virtaraja ampeereina; {{value}} = liukusäätimen arvo.',
        helpEn: 'Current limit in amps; {{value}} = the slider value.',
      ),
    ],
  );

  Future<EvCharger> _charger(Map<String, dynamic> spec) async {
    final id = '${spec['charger'] ?? ''}';
    final known = _chargers[id];
    if (known != null) return known;
    if (spec['meta'] is Map && id.isNotEmpty) {
      return _chargers[id] = EvCharger(id: id, name: id, meta: Map<String, dynamic>.from(spec['meta'] as Map));
    }
    for (final c in await backend.chargers()) {
      _chargers[c.id] = c;
    }
    final c = _chargers[id] ?? (id.isEmpty && _chargers.isNotEmpty ? _chargers.values.first : null);
    if (c == null) {
      throw DriverException(
        dtx(
          'Laturia "$id" ei löydy (ei yhteyttä tai poistettu tililtä)',
          'Charger "$id" not found (offline or removed)',
        ),
      );
    }
    if (id.isEmpty) _chargers[''] = c;
    return c;
  }

  Future<EvState> _state(EvCharger c, {bool fresh = false}) async {
    final x = _cache[c.id];
    if (!fresh && x != null && DateTime.now().difference(x.$1) < cacheFor) return x.$2;
    final st = await backend.state(c);
    _cache[c.id] = (DateTime.now(), st);
    return st;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final k = '${spec['ev'] ?? 'status'}';
    if (k == 'chargers') {
      final l = await backend.chargers();
      for (final c in l) {
        _chargers[c.id] = c;
      }
      return [for (final c in l) c.toJson()];
    }
    final c = await _charger(spec);
    final st = await _state(c);
    if (k == 'state') return st.toJson();
    return st.value(k);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final c = await _charger(spec);
    final raw = spec['value'] == null || '${spec['value']}'.contains('{{') ? value : spec['value'];
    switch ('${spec['ev'] ?? ''}') {
      case 'start':
        await backend.start(c);
      case 'stop':
        await backend.stop(c);
      case 'charge':
        _truthy(spec['on'] ?? raw) ? await backend.start(c) : await backend.stop(c);
      case 'current':
        final a = evNum(raw);
        if (a == null) throw DriverException(dtx('Virtaraja puuttuu', 'Current limit missing'));
        final st = _cache[c.id]?.$2;
        final lo = st?.minCurrent ?? 6, hi = st?.maxCurrent ?? 32;
        await backend.setCurrent(c, a.clamp(lo, hi));
      default:
        throw DriverException('EV: unknown command "${spec['ev']}"');
    }
    _cache.remove(c.id);
    return true;
  }

  @override
  Future<String> test() async {
    final l = await backend.chargers();
    if (l.isEmpty) return dtx('Ei latureita', 'No chargers');
    final st = await _state(l.first, fresh: true);
    return '${l.first.name} · ${st.value('status')}';
  }

  @override
  Future<void> dispose() async => _b?.close();
}

/// Tiles for one charger: status, power, session energy, start/stop toggle, current slider;
/// [extras] = total energy (for automations / statistics).
List<TileConfig> evChargerTiles(
  String connId,
  EvCharger c,
  EvState st, {
  required String title,
  String lang = 'fi',
  bool extras = false,
  bool local = false,
}) {
  String t(String fi, String en) => lang == 'fi' ? fi : en;
  final spec = {'charger': c.id, if (c.meta.isNotEmpty) 'meta': c.meta};
  final poll = local ? 5 : 30;
  if (extras) {
    return [
      TileConfig(
        type: TileType.value,
        title: '$title – ${t('ladattu yhteensä', 'total charged')}',
        icon: 'ev',
        unit: 'kWh',
        decimals: 0,
        connectionId: connId,
        pollSeconds: 300,
        display: 'trend',
        read: {'ev': 'total', ...spec},
      ),
    ];
  }
  return [
    TileConfig(
      type: TileType.value,
      title: '$title – ${t('tila', 'status')}',
      icon: 'ev',
      connectionId: connId,
      pollSeconds: poll,
      decimals: 0,
      read: {'ev': 'status', ...spec},
    ),
    TileConfig(
      type: TileType.toggle,
      title: '$title – ${t('lataus', 'charging')}',
      icon: 'ev',
      connectionId: connId,
      pollSeconds: poll,
      confirm: true,
      read: {'ev': 'charging', ...spec},
      onValue: '1',
      onCommand: CommandStep(connectionId: connId, spec: {'ev': 'start', ...spec}),
      offCommand: CommandStep(connectionId: connId, spec: {'ev': 'stop', ...spec}),
    ),
    TileConfig(
      type: TileType.value,
      title: '$title – ${t('latausteho', 'charging power')}',
      icon: 'bolt',
      unit: 'W',
      decimals: 0,
      connectionId: connId,
      pollSeconds: poll,
      display: 'gauge_trend',
      read: {'ev': 'power', ...spec},
    ),
    TileConfig(
      type: TileType.value,
      title: '$title – ${t('tämä lataus', 'this session')}',
      icon: 'battery',
      unit: 'kWh',
      decimals: 1,
      connectionId: connId,
      pollSeconds: 60,
      read: {'ev': 'session', ...spec},
    ),
    TileConfig(
      type: TileType.slider,
      title: '$title – ${t('virtaraja', 'current limit')}',
      icon: 'speed',
      unit: 'A',
      min: st.minCurrent.toDouble(),
      max: st.maxCurrent.toDouble(),
      step: 1,
      decimals: 0,
      connectionId: connId,
      pollSeconds: 60,
      read: {'ev': 'current', ...spec},
      commands: [
        CommandStep(connectionId: connId, spec: {'ev': 'current', 'value': '{{value}}', ...spec}),
      ],
    ),
  ];
}
