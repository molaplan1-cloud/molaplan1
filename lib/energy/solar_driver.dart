/// Connection type `solar` (R288): one driver for every built-in solar inverter / grid meter brand.
///
/// read {'pv': 'pv_power' | 'pv_today' | … }   -> one value from the brand snapshot (see energyKeys)
/// read {'pv': 'info'}                          -> EnergyInfo.toJson() (add wizard)
/// Read-only: inverters are never commanded from the app (no export limit / battery writes).
library;

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../drivers/driver.dart';
import 'energy_model.dart';
import 'http_inverters.dart';
import 'modbus_inverters.dart';

/// Brand / protocol ids → (fi, en).
const solarBrands = <String, (String, String)>{
  'huawei': ('Huawei SUN2000 (Modbus TCP)', 'Huawei SUN2000 (Modbus TCP)'),
  'fronius': ('Fronius (Solar API, paikallinen)', 'Fronius (Solar API, local)'),
  'solaredge': ('SolarEdge (Modbus TCP, paikallinen)', 'SolarEdge (Modbus TCP, local)'),
  'sma': ('SMA (Modbus TCP, paikallinen)', 'SMA (Modbus TCP, local)'),
  'sma_sunspec': ('SMA (SunSpec Modbus)', 'SMA (SunSpec Modbus)'),
  'sma_em': ('SMA Energy Meter / Home Manager (Speedwire)', 'SMA Energy Meter / Home Manager (Speedwire)'),
  'growatt': ('Growatt (Modbus TCP)', 'Growatt (Modbus TCP)'),
  'sunspec': ('Muu SunSpec-invertteri (Modbus TCP)', 'Other SunSpec inverter (Modbus TCP)'),
  'fusionsolar': ('Huawei FusionSolar (pilvi)', 'Huawei FusionSolar (cloud)'),
  'solaredge_cloud': ('SolarEdge monitoring (pilvi)', 'SolarEdge monitoring (cloud)'),
  'growatt_cloud': ('Growatt OpenAPI (pilvi)', 'Growatt OpenAPI (cloud)'),
};

const solarCloudBrands = {'fusionsolar', 'solaredge_cloud', 'growatt_cloud'};

/// Test hook: HTTP backends get this client.
http.Client? solarTestClient;

EnergyBackend createEnergyBackend(Map<String, dynamic> s) {
  final brand = '${s['brand'] ?? ''}';
  http.Client c() => solarTestClient ?? newHttpClient();
  return switch (brand) {
    'huawei' => HuaweiModbusBackend(s),
    'solaredge' || 'sunspec' || 'sma_sunspec' => SunSpecBackend(s),
    'sma' => SmaModbusBackend(s),
    'growatt' => GrowattModbusBackend(s),
    'fronius' => FroniusBackend(s, c()),
    'sma_em' => SmaEnergyMeterBackend(s),
    'fusionsolar' => FusionSolarBackend(s, c()),
    'solaredge_cloud' => SolarEdgeCloudBackend(s, c()),
    'growatt_cloud' => GrowattCloudBackend(s, c()),
    _ => throw DriverException('Solar: unknown brand "$brand"'),
  };
}

class SolarDriver extends Driver {
  SolarDriver(super.config);

  EnergyBackend? _b;
  EnergyBackend get backend => _b ??= createEnergyBackend(s);
  (DateTime, EnergyInfo)? _cache;
  Future<EnergyInfo>? _pending;

  /// Several tiles share one fetch (clouds: SolarEdge allows 300 calls / day).
  Duration get cacheFor =>
      Duration(seconds: s.integer('cacheSeconds', solarCloudBrands.contains('${s['brand']}') ? 240 : 5));

  Future<EnergyInfo> snapshot({bool fresh = false}) async {
    final c = _cache;
    if (!fresh && c != null && DateTime.now().difference(c.$1) < cacheFor) return c.$2;
    final p = _pending ??= backend.read();
    try {
      final v = await p;
      _cache = (DateTime.now(), v);
      return v;
    } finally {
      _pending = null;
    }
  }

  static const descriptor = DriverDescriptor(
    type: 'solar',
    fi: 'Aurinkosähkö / invertteri (oma integraatio)',
    en: 'Solar / inverter (built-in integration)',
    create: SolarDriver.new,
    connectionFields: [
      FieldSpec(
        'brand',
        'Merkki ja yhteystapa',
        'Brand and connection',
        kind: FieldKind.choice,
        options: [
          'huawei',
          'fronius',
          'solaredge',
          'sma',
          'sma_sunspec',
          'sma_em',
          'growatt',
          'sunspec',
          'fusionsolar',
          'solaredge_cloud',
          'growatt_cloud',
        ],
        optionLabels: solarBrands,
        defaultValue: 'huawei',
        helpFi: 'Valmistaja ja yhteystapa. Paikalliset toimivat ilman pilveä ja päivittyvät nopeammin.',
        helpEn: 'Maker and connection type. Local ones work without the cloud and update faster.',
      ),
      FieldSpec(
        'address',
        'IP-osoite (paikalliset)',
        'IP address (local)',
        hint: '192.168.x.x',
        helpFi: 'Invertterin, SDonglen tai mittarin IP-osoite (reitittimen laitelistasta).',
        helpEn: 'IP address of the inverter, SDongle or meter (from the router device list).',
      ),
      FieldSpec(
        'port',
        'Portti',
        'Port',
        kind: FieldKind.number,
        advanced: true,
        helpFi: 'Tyhjä = oletus (Modbus 502, SolarEdge 1502, Huawein invertterin oma wifi 6607).',
        helpEn: 'Empty = default (Modbus 502, SolarEdge 1502, Huawei inverter Wi-Fi 6607).',
      ),
      FieldSpec(
        'unitId',
        'Modbus unit id',
        'Modbus unit id',
        kind: FieldKind.number,
        advanced: true,
        helpFi: 'Tyhjä = oletus (Huawei 1, SolarEdge 1, SMA 3, SMA SunSpec 126, Growatt 1).',
        helpEn: 'Empty = default (Huawei 1, SolarEdge 1, SMA 3, SMA SunSpec 126, Growatt 1).',
      ),
      FieldSpec(
        'serial',
        'Mittarin sarjanumero (SMA Energy Meter)',
        'Meter serial (SMA Energy Meter)',
        advanced: true,
        helpFi: 'Vain jos verkossa on useita SMA-mittareita. Tyhjä = ensimmäinen.',
        helpEn: 'Only if there are several SMA meters on the network. Empty = the first one.',
      ),
      FieldSpec(
        'username',
        'Käyttäjä (FusionSolar API)',
        'User (FusionSolar API)',
        advanced: true,
        helpFi: 'FusionSolarin Northbound-API-käyttäjä (asentaja luo: Järjestelmä → Yritys → Northbound).',
        helpEn: 'FusionSolar Northbound API user (created by the installer: System → Company → Northbound).',
      ),
      FieldSpec(
        'password',
        'Salasana / järjestelmäkoodi',
        'Password / system code',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Tallentuu vain tälle laitteelle / omaan salattuun holviisi.',
        helpEn: 'Stored only on this device / in your own encrypted vault.',
      ),
      FieldSpec(
        'apiKey',
        'API-avain (SolarEdge / Growatt)',
        'API key (SolarEdge / Growatt)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'SolarEdge: monitoring-portaali → Admin → Site Access → API. Growatt: OpenAPI-token.',
        helpEn: 'SolarEdge: monitoring portal → Admin → Site Access → API. Growatt: OpenAPI token.',
      ),
      FieldSpec(
        'siteId',
        'Laitoksen tunnus (pilvi)',
        'Site / plant id (cloud)',
        advanced: true,
        helpFi: 'Tyhjä = tilin ensimmäinen laitos.',
        helpEn: 'Empty = the first site of the account.',
      ),
    ],
    readFields: [
      FieldSpec(
        'pv',
        'Lukema',
        'Reading',
        kind: FieldKind.choice,
        options: [
          'pv_power',
          'pv_today',
          'pv_total',
          'grid_power',
          'grid_import',
          'grid_export',
          'battery_soc',
          'battery_power',
          'load_power',
        ],
        optionLabels: {
          'pv_power': ('Aurinkosähkö nyt (W)', 'Solar power now (W)'),
          'pv_today': ('Tuotto tänään (kWh)', 'Yield today (kWh)'),
          'pv_total': ('Tuotto yhteensä (kWh)', 'Total yield (kWh)'),
          'grid_power': ('Verkko +osto / −myynti (W)', 'Grid +import / −export (W)'),
          'grid_import': ('Ostettu yhteensä (kWh)', 'Imported total (kWh)'),
          'grid_export': ('Myyty yhteensä (kWh)', 'Exported total (kWh)'),
          'battery_soc': ('Akun varaus (%)', 'Battery charge (%)'),
          'battery_power': ('Akku +lataus / −purku (W)', 'Battery +charge / −discharge (W)'),
          'load_power': ('Kodin kulutus (W)', 'Home consumption (W)'),
        },
        defaultValue: 'pv_power',
        helpFi: 'Verkko: positiivinen = ostat verkosta, negatiivinen = myyt ylijäämää.',
        helpEn: 'Grid: positive = buying from the grid, negative = selling surplus.',
      ),
    ],
    commandFields: [],
  );

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final k = '${spec['pv'] ?? 'pv_power'}';
    if (k == 'info') return (await snapshot(fresh: true)).toJson();
    final v = (await snapshot()).values[k];
    if (v == null) {
      throw DriverException(dtx('Laite ei kerro tätä lukemaa ($k)', 'The device does not report this reading ($k)'));
    }
    return v is double ? double.parse(v.toStringAsFixed(3)) : v;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) =>
      throw DriverException(dtx('Invertteriä ei ohjata – vain luku', 'Inverters are read-only'));

  @override
  Future<String> test() async {
    final i = await snapshot(fresh: true);
    final pv = i.values['pv_power'];
    final g = i.values['grid_power'];
    return [
      i.name,
      if (pv != null) '${dtx('tuotto', 'solar')} ${pv.round()} W',
      if (g != null) '${dtx('verkko', 'grid')} ${g.round()} W',
    ].join(' · ');
  }

  @override
  Future<void> dispose() async => _b?.close();
}
