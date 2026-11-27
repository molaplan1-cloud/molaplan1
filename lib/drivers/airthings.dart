/// t159u: Airthings air-quality monitors, for everyone.
/// - Wi-Fi models (View Plus, View Radon, View Pollution, Hub with Wave sensors) have no
///   local API: they are read from the official Airthings Consumer API with the user's own
///   client id + secret (OAuth2 client credentials, created at dashboard.airthings.com).
///   Account-based discovery: GET /v1/devices, values from /v1/locations/{id}/latest-samples
///   (one request per location, not per device) – polled gently, ≥ 5 min (devices sample
///   every 5 min; the consumer quota is about 120 requests / hour).
/// - Wave models (Wave, Wave Plus, Wave Mini, Wave Radon / Wave 2) are Bluetooth only: read
///   over BLE on Android (this device or the home bridge) with the GATT layouts Airthings
///   publishes (github.com/Airthings/waveplus-reader, wave-reader, wave-mini-reader).
library;

import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../core/http_client.dart';
import '../models/models.dart';
import 'driver.dart';

// ---------------------------------------------------------------- sensors

/// Sensor key (Airthings API name) → (fi, en, unit, icon, decimals).
const airthingsSensors = <String, (String, String, String, String, int)>{
  'radonShortTermAvg': ('Radon', 'Radon', 'Bq/m³', 'radon', 0),
  'radonLongTermAvg': ('Radon (pitkä aika)', 'Radon (long term)', 'Bq/m³', 'radon', 0),
  'co2': ('Hiilidioksidi', 'CO₂', 'ppm', 'co2', 0),
  'voc': ('VOC', 'VOC', 'ppb', 'air_quality', 0),
  'temp': ('Lämpötila', 'Temperature', '°C', 'thermostat', 1),
  'humidity': ('Kosteus', 'Humidity', '%', 'humidity', 0),
  'pressure': ('Ilmanpaine', 'Pressure', 'hPa', 'speed', 0),
  'pm25': ('Pienhiukkaset PM2.5', 'PM2.5', 'µg/m³', 'air_quality', 0),
  'pm1': ('Pienhiukkaset PM1', 'PM1', 'µg/m³', 'air_quality', 0),
  'battery': ('Akku', 'Battery', '%', 'battery', 0),
};

/// WHO radon reference levels: < 100 Bq/m³ good, 100–300 act, > 300 high.
const radonWhoGood = 100, radonWhoHigh = 300;

/// Radon tile colours: green < 100, amber 100–300, red ≥ 300 Bq/m³ (WHO).
List<Threshold> radonThresholds() => [
  Threshold(0, 0xFF4CAF50),
  Threshold(radonWhoGood.toDouble(), 0xFFFFB300),
  Threshold(radonWhoHigh.toDouble(), 0xFFE53935),
];

/// Tiles for one Airthings device (cloud or Bluetooth connection [cid]).
List<TileConfig> airthingsTiles(String cid, String serial, Iterable<String> sensors, String lang, {String name = ''}) {
  final tiles = <TileConfig>[];
  for (final key in sensors) {
    final m = airthingsSensors[key];
    if (m == null) continue;
    final title = name.isEmpty ? (lang == 'fi' ? m.$1 : m.$2) : '$name ${lang == 'fi' ? m.$1 : m.$2}';
    final radon = key.startsWith('radon');
    tiles.add(
      TileConfig(
        type: TileType.value,
        title: title,
        icon: m.$4,
        unit: m.$3,
        decimals: m.$5,
        connectionId: cid,
        read: {'serial': serial, 'sensor': key},
        pollSeconds: 300,
        display: radon || key == 'co2' ? 'trend' : 'auto',
        thresholds: radon
            ? radonThresholds()
            : (key == 'co2'
                  ? [Threshold(0, 0xFF4CAF50), Threshold(1000, 0xFFFFB300), Threshold(1500, 0xFFE53935)]
                  : null),
      ),
    );
  }
  return tiles;
}

/// Sensors of a Bluetooth Wave model.
List<String> waveSensors(String serial) => switch (serial.length >= 4 ? serial.substring(0, 4) : '') {
  '2930' => ['radonShortTermAvg', 'radonLongTermAvg', 'co2', 'voc', 'temp', 'humidity', 'pressure'],
  '2950' => ['radonShortTermAvg', 'radonLongTermAvg', 'temp', 'humidity'],
  '2920' => ['temp', 'humidity', 'pressure', 'voc'],
  '2900' => ['radonShortTermAvg', 'radonLongTermAvg', 'temp', 'humidity'],
  _ => ['radonShortTermAvg', 'temp', 'humidity'],
};

String airthingsModel(String serial) {
  final p = serial.length >= 4 ? serial.substring(0, 4) : serial;
  return switch (p) {
    '2900' => 'Wave (1st gen)',
    '2920' => 'Wave Mini',
    '2930' => 'Wave Plus',
    '2950' => 'Wave Radon',
    '2960' => 'View Plus',
    '2969' => 'View Plus',
    '2980' => 'View Pollution',
    '2989' => 'View Radon',
    '3210' => 'Wave Enhance',
    '3220' => 'Wave Enhance',
    '2820' => 'Hub',
    _ => 'Airthings',
  };
}

/// Wave models read over Bluetooth (serial prefix).
bool airthingsIsBle(String serial) => const ['2900', '2920', '2930', '2950'].any(serial.startsWith);

// ---------------------------------------------------------------- cloud

class AirthingsDevice {
  AirthingsDevice(this.serial, this.type, this.sensors, {this.name = '', this.locationId});
  final String serial, type, name;
  final List<String> sensors;
  final String? locationId;
  String get model => airthingsModel(serial);
}

/// Parses GET /v1/devices.
List<AirthingsDevice> parseAirthingsDevices(Object? j) {
  final list = j is Map ? (j['devices'] as List? ?? const []) : (j is List ? j : const []);
  return [
    for (final d in list.whereType<Map>())
      AirthingsDevice(
        '${d['id'] ?? d['serialNumber'] ?? ''}',
        '${d['deviceType'] ?? ''}',
        [for (final s in (d['sensors'] as List? ?? const [])) '$s'],
        name: '${(d['segment'] as Map?)?['name'] ?? (d['location'] as Map?)?['name'] ?? ''}',
        locationId: (d['location'] as Map?)?['id'] as String?,
      ),
  ];
}

/// Parses latest samples: either {data:{…}} (one device) or {devices:[{id, data}]}
/// (one location) → serial → values.
Map<String, Map<String, num>> parseAirthingsSamples(Object? j, {String? serial}) {
  Map<String, num> nums(Object? m) => {
    for (final e in (m is Map ? m : const {}).entries)
      if (e.value is num) '${e.key}': e.value as num,
  };
  final out = <String, Map<String, num>>{};
  if (j is Map && j['devices'] is List) {
    for (final d in (j['devices'] as List).whereType<Map>()) {
      out['${d['id'] ?? d['serialNumber']}'] = nums(d['data']);
    }
  } else if (j is Map && j['data'] is Map && serial != null) {
    out[serial] = nums(j['data']);
  }
  return out;
}

/// Test hook / transport: (method, url, headers, body) → (status, body text).
typedef AirthingsHttp = Future<(int, String)> Function(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
);

Future<(int, String)> _defaultHttp(String method, Uri url, Map<String, String> headers, String? body) async {
  // package:http: IOClient in the apps, BrowserClient on the web (R331). dart:io HttpClient
  // throws `Unsupported operation: Platform._version` in a browser.
  final c = newHttpClient(connectTimeout: const Duration(seconds: 15));
  try {
    final req = http.Request(method, url)..headers.addAll(headers);
    if (body != null) req.body = body;
    final res = await c.send(req).timeout(const Duration(seconds: 20));
    return (res.statusCode, await res.stream.bytesToString());
  } finally {
    c.close();
  }
}

AirthingsHttp airthingsHttp = _defaultHttp;

/// Cloud API (or dart:io) cannot be used from this browser; use the app or a home bridge.
class AirthingsWebUnavailable implements Exception {
  const AirthingsWebUnavailable();
  static const fi = webAppOrBridgeFi;
  static const en = webAppOrBridgeEn;
  @override
  String toString() => fi;
}

Future<(int, String)> _callAirthingsHttp(
  String method,
  Uri url,
  Map<String, String> headers,
  String? body,
) async {
  try {
    return await airthingsHttp(method, url, headers, body);
  } catch (e) {
    if (e is AirthingsWebUnavailable) rethrow;
    if (isWebTransportFailure(e)) throw const AirthingsWebUnavailable();
    rethrow;
  }
}

/// Clock hook for tests.
DateTime Function() airthingsClock = DateTime.now;

class AirthingsCloudDriver extends Driver {
  AirthingsCloudDriver(super.config);

  static const tokenUrl = 'https://accounts-api.airthings.com/v1/token';
  static const apiBase = 'https://ext-api.airthings.com/v1';

  static const descriptor = DriverDescriptor(
    type: 'airthings',
    fi: 'Airthings (pilvi)',
    en: 'Airthings (cloud)',
    create: AirthingsCloudDriver.new,
    connectionFields: [
      FieldSpec(
        'clientId',
        'Client ID',
        'Client ID',
        required: true,
        helpFi: 'dashboard.airthings.com → Integrations → API → Create client (Client credentials).',
        helpEn: 'dashboard.airthings.com → Integrations → API → Create client (Client credentials).',
      ),
      FieldSpec(
        'clientSecret',
        'Client secret',
        'Client secret',
        kind: FieldKind.secret,
        required: true,
        helpFi: 'Näkyy samassa paikassa kuin Client ID. Pidä se salassa.',
        helpEn: 'Shown next to the Client ID. Keep it secret.',
      ),
      FieldSpec(
        'pollMinutes',
        'Päivitysväli (min)',
        'Update interval (min)',
        kind: FieldKind.number,
        defaultValue: 5,
        advanced: true,
        helpFi: 'Mittarit päivittävät arvot 5 minuutin välein; tiheämpi kysely ei tuo uutta tietoa.',
        helpEn: 'The monitors update every 5 minutes; asking more often brings nothing new.',
      ),
    ],
    readFields: [
      FieldSpec(
        'serial',
        'Sarjanumero',
        'Serial number',
        required: true,
        helpFi: 'Mittarin sarjanumero (10 numeroa) – täyttyy itse, kun lisäät mittarin listasta.',
        helpEn: 'The monitor\'s serial number (10 digits) – filled in when you add it from the list.',
      ),
      FieldSpec(
        'sensor',
        'Mittaus',
        'Measurement',
        kind: FieldKind.choice,
        options: [
          'radonShortTermAvg',
          'radonLongTermAvg',
          'co2',
          'voc',
          'temp',
          'humidity',
          'pressure',
          'pm25',
          'pm1',
          'battery',
        ],
        defaultValue: 'radonShortTermAvg',
        optionLabels: {
          'radonShortTermAvg': ('Radon (lyhyt keskiarvo)', 'Radon (short-term)'),
          'radonLongTermAvg': ('Radon (pitkä keskiarvo)', 'Radon (long-term)'),
          'co2': ('Hiilidioksidi', 'CO₂'),
          'voc': ('VOC', 'VOC'),
          'temp': ('Lämpötila', 'Temperature'),
          'humidity': ('Kosteus', 'Humidity'),
          'pressure': ('Ilmanpaine', 'Pressure'),
          'pm25': ('Pienhiukkaset PM2.5', 'PM2.5'),
          'pm1': ('Pienhiukkaset PM1', 'PM1'),
          'battery': ('Akku', 'Battery'),
        },
        helpFi: 'Mikä mittauksen arvo ruudussa näkyy (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, akku %).',
        helpEn: 'Which measurement the tile shows (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, battery %).',
      ),
    ],
    commandFields: [],
  );

  // Shared by every connection with the same client id: one token, one cache.
  static final _tokens = <String, (String, DateTime)>{};
  static final _samples = <String, (Map<String, Map<String, num>>, DateTime)>{};
  static final _inflight = <String, Future<Map<String, Map<String, num>>>>{};
  static List<AirthingsDevice>? _devicesCache;

  String get _cid => s.str('clientId').trim();
  Duration get _interval => Duration(minutes: s.integer('pollMinutes', 5).clamp(5, 120));

  Future<String> _token() async {
    final t = _tokens[_cid];
    if (t != null && airthingsClock().isBefore(t.$2)) return t.$1;
    final (code, body) = await _callAirthingsHttp(
      'POST',
      Uri.parse(tokenUrl),
      {'Content-Type': 'application/json'},
      jsonEncode({
        'grant_type': 'client_credentials',
        'client_id': _cid,
        'client_secret': s.str('clientSecret').trim(),
        'scope': ['read:device:current_values'],
      }),
    );
    if (code == 400 || code == 401 || code == 403) {
      throw DriverException('Airthings: HTTP $code – check the client id / secret');
    }
    if (code != 200) throw DriverException('Airthings: token HTTP $code');
    final j = jsonDecode(body) as Map;
    final exp = (j['expires_in'] as num?)?.toInt() ?? 3600;
    final tok = '${j['access_token']}';
    _tokens[_cid] = (tok, airthingsClock().add(Duration(seconds: exp - 60)));
    return tok;
  }

  Future<Object?> _get(String path) async {
    final (code, body) = await _callAirthingsHttp('GET', Uri.parse('$apiBase$path'), {
      'Authorization': 'Bearer ${await _token()}',
    }, null);
    if (code == 401) {
      _tokens.remove(_cid);
      throw DriverException('Airthings: HTTP 401 – check the client id / secret');
    }
    if (code == 429) throw DriverException('Airthings: HTTP 429 rate limit');
    if (code != 200) throw DriverException('Airthings: HTTP $code');
    return jsonDecode(body);
  }

  /// Account-based discovery: every device the client can see.
  Future<List<AirthingsDevice>> devices() async => _devicesCache = parseAirthingsDevices(await _get('/devices'));

  /// Latest values of all devices: one request per location, cached for the interval.
  Future<Map<String, Map<String, num>>> samples({bool force = false}) {
    final hit = _samples[_cid];
    if (!force && hit != null && airthingsClock().difference(hit.$2) < _interval) return Future.value(hit.$1);
    return _inflight[_cid] ??= () async {
      try {
        final devs = _devicesCache ?? await devices();
        final out = <String, Map<String, num>>{};
        final locs = {for (final d in devs) ?d.locationId};
        for (final l in locs) {
          out.addAll(parseAirthingsSamples(await _get('/locations/$l/latest-samples')));
        }
        // Devices without a location: one request each.
        for (final d in devs.where((d) => d.locationId == null)) {
          out.addAll(parseAirthingsSamples(await _get('/devices/${d.serial}/latest-samples'), serial: d.serial));
        }
        _samples[_cid] = (out, airthingsClock());
        return out;
      } finally {
        _inflight.remove(_cid);
      }
    }();
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final all = await samples();
    final v = all[spec.str('serial')];
    if (v == null) throw DriverException('Airthings: device ${spec.str('serial')} not found in the account');
    return v[spec.str('sensor', 'radonShortTermAvg')];
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => throw DriverException('Airthings: read only');

  @override
  Future<String> test() async {
    final d = await devices();
    return 'OK, ${d.length} ${d.length == 1 ? 'device' : 'devices'}';
  }

  /// Test hook.
  static void resetCache() {
    _tokens.clear();
    _samples.clear();
    _inflight.clear();
    _devicesCache = null;
  }
}

// ---------------------------------------------------------------- Bluetooth (Wave)

/// GATT layouts published by Airthings.
class WaveGatt {
  const WaveGatt(this.service, this.characteristic);
  final String service, characteristic;
}

const waveGatt = {
  '2930': WaveGatt('b42e1c08-ade7-11e4-89d3-123b93f75cba', 'b42e2a68-ade7-11e4-89d3-123b93f75cba'), // Wave Plus
  '2950': WaveGatt(
    'b42e4a8e-ade7-11e4-89d3-123b93f75cba',
    'b42e4dcc-ade7-11e4-89d3-123b93f75cba',
  ), // Wave Radon / Wave 2
  '2920': WaveGatt('b42e3882-ade7-11e4-89d3-123b93f75cba', 'b42e3b98-ade7-11e4-89d3-123b93f75cba'), // Wave Mini
};

/// Wave 1st gen: separate characteristics (temperature 0x2A6E, humidity 0x2A6F, radon).
const wave1Radon24h = 'b42e01aa-ade7-11e4-89d3-123b93f75cba';
const wave1RadonLong = 'b42e0a4c-ade7-11e4-89d3-123b93f75cba';

/// Airthings Bluetooth company id (manufacturer data); the first 4 bytes are the serial (LE).
const airthingsCompanyId = 0x0334;

String? waveSerialFromManufacturerData(List<int> data) {
  if (data.length < 4) return null;
  final b = ByteData.sublistView(Uint8List.fromList(data));
  return '${b.getUint32(0, Endian.little)}';
}

/// Decodes the current-values characteristic of a Wave Plus / Wave Radon (struct
/// '<BBBBHHHHHHHH') or a Wave Mini ('<HHHHHHLL') into Airthings sensor names.
Map<String, num> parseWaveValues(String model, List<int> raw) {
  final b = ByteData.sublistView(Uint8List.fromList(raw));
  num? radon(int v) => v > 16383 ? null : v; // 0xFFFF etc. = not ready yet
  if (model == '2920') {
    if (raw.length < 12) throw const FormatException('Wave Mini: short value');
    return {
      'temp': double.parse(((b.getUint16(0, Endian.little) / 100) - 273.15).toStringAsFixed(2)), // Kelvin ×100
      'pressure': b.getUint16(2, Endian.little) / 50,
      'humidity': b.getUint16(4, Endian.little) / 100,
      'voc': b.getUint16(6, Endian.little),
    };
  }
  if (raw.length < 16) throw const FormatException('Wave: short value');
  if (raw[0] != 1) throw FormatException('Wave: unknown layout version ${raw[0]}');
  final out = <String, num>{
    'humidity': raw[1] / 2,
    'radonShortTermAvg': ?radon(b.getUint16(4, Endian.little)),
    'radonLongTermAvg': ?radon(b.getUint16(6, Endian.little)),
    'temp': b.getUint16(8, Endian.little) / 100,
  };
  if (model == '2930' && raw.length >= 16) {
    out['pressure'] = b.getUint16(10, Endian.little) / 50;
    out['co2'] = b.getUint16(12, Endian.little);
    out['voc'] = b.getUint16(14, Endian.little);
  }
  return out;
}

/// BLE transport (Android): reads one characteristic of the device with [serial].
/// Replaced in tests; the default lives in airthings_ble.dart (flutter_blue_plus).
Future<List<int>> Function(String serial, String service, String characteristic)? waveBleRead;

class AirthingsBleDriver extends Driver {
  AirthingsBleDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'airthings_ble',
    fi: 'Airthings Wave (Bluetooth)',
    en: 'Airthings Wave (Bluetooth)',
    create: AirthingsBleDriver.new,
    connectionFields: [
      FieldSpec(
        'serial',
        'Sarjanumero',
        'Serial number',
        required: true,
        helpFi: 'Mittarin takana tai pohjassa (10 numeroa, esim. 2930xxxxxx).',
        helpEn: 'On the back or bottom of the monitor (10 digits, e.g. 2930xxxxxx).',
      ),
    ],
    readFields: [
      FieldSpec(
        'sensor',
        'Mittaus',
        'Measurement',
        kind: FieldKind.choice,
        options: ['radonShortTermAvg', 'radonLongTermAvg', 'co2', 'voc', 'temp', 'humidity', 'pressure'],
        defaultValue: 'radonShortTermAvg',
        optionLabels: {
          'radonShortTermAvg': ('Radon (lyhyt keskiarvo)', 'Radon (short-term)'),
          'radonLongTermAvg': ('Radon (pitkä keskiarvo)', 'Radon (long-term)'),
          'co2': ('Hiilidioksidi', 'CO₂'),
          'voc': ('VOC', 'VOC'),
          'temp': ('Lämpötila', 'Temperature'),
          'humidity': ('Kosteus', 'Humidity'),
          'pressure': ('Ilmanpaine', 'Pressure'),
          'pm25': ('Pienhiukkaset PM2.5', 'PM2.5'),
          'pm1': ('Pienhiukkaset PM1', 'PM1'),
          'battery': ('Akku', 'Battery'),
        },
        helpFi: 'Mikä mittauksen arvo ruudussa näkyy (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, akku %).',
        helpEn: 'Which measurement the tile shows (radon Bq/m³, CO₂ ppm, VOC ppb, °C, %, hPa, µg/m³, battery %).',
      ),
    ],
    commandFields: [],
  );

  static final _cache = <String, (Map<String, num>, DateTime)>{};

  Future<Map<String, num>> values() async {
    final serial = s.str('serial').trim();
    final hit = _cache[serial];
    // BLE reads drain the battery: at most every 5 minutes (the device samples that often).
    if (hit != null && airthingsClock().difference(hit.$2) < const Duration(minutes: 5)) return hit.$1;
    final read = waveBleRead;
    if (read == null) {
      throw DriverException(
        'Airthings BLE: Bluetooth not available here – lue mittari Android-laitteella tai kotisillan kautta / '
        'read it on an Android device or through the home bridge',
      );
    }
    final model = serial.length >= 4 ? serial.substring(0, 4) : '';
    final Map<String, num> v;
    if (model == '2900') {
      final svc = 'b42e1f6e-ade7-11e4-89d3-123b93f75cba';
      final t = ByteData.sublistView(
        Uint8List.fromList(await read(serial, svc, '00002a6e-0000-1000-8000-00805f9b34fb')),
      );
      final h = ByteData.sublistView(
        Uint8List.fromList(await read(serial, svc, '00002a6f-0000-1000-8000-00805f9b34fb')),
      );
      final r = ByteData.sublistView(Uint8List.fromList(await read(serial, svc, wave1Radon24h)));
      final rl = ByteData.sublistView(Uint8List.fromList(await read(serial, svc, wave1RadonLong)));
      v = {
        'temp': t.getInt16(0, Endian.little) / 100,
        'humidity': h.getUint16(0, Endian.little) / 100,
        'radonShortTermAvg': r.getUint16(0, Endian.little),
        'radonLongTermAvg': rl.getUint16(0, Endian.little),
      };
    } else {
      final g = waveGatt[model];
      if (g == null) throw DriverException('Airthings BLE: unknown model $model');
      v = parseWaveValues(model, await read(serial, g.service, g.characteristic));
    }
    _cache[serial] = (v, airthingsClock());
    return v;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async => (await values())[spec.str('sensor', 'radonShortTermAvg')];

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => throw DriverException('Airthings: read only');

  @override
  Future<String> test() async {
    final v = await values();
    return 'OK, ${v.length} values';
  }

  static void resetCache() => _cache.clear();
}
