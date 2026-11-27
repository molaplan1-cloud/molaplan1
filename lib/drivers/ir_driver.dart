import 'dart:async';
import 'dart:convert';
import 'dart:io';
import '../core/io_http.dart';

import 'package:http/http.dart' as http;

import '../core/fields.dart';
import '../models/models.dart';
import 'driver.dart';
import 'http_driver.dart' show makeHttpClient;
import 'mqtt_driver.dart';
import '../l10n/l10n.dart';

/// One air-conditioner brand in the picker, mapped to Tasmota IRhvac vendor names
/// (IRremoteESP8266 protocol names). [alt] = other protocols the same brand uses.
class IrBrand {
  const IrBrand(this.label, this.vendor, [this.alt = const [], this.minTemp = 16, this.maxTemp = 31]);
  final String label;
  final String vendor;
  final List<String> alt;

  /// Setpoint range of the brand's remote (heat mode); the slider uses it (v0.8.0 brand presets).
  final num minTemp;
  final num maxTemp;
}

const irBrands = <IrBrand>[
  IrBrand('Mitsubishi Electric', 'MITSUBISHI_AC', ['MITSUBISHI112', 'MITSUBISHI136'], 10, 31),
  IrBrand('Mitsubishi Heavy', 'MITSUBISHI_HEAVY_152', ['MITSUBISHI_HEAVY_88']),
  IrBrand('Panasonic', 'PANASONIC_AC', ['PANASONIC_AC32'], 16, 30),
  IrBrand('Daikin', 'DAIKIN', ['DAIKIN2', 'DAIKIN216', 'DAIKIN160', 'DAIKIN176', 'DAIKIN128', 'DAIKIN152'], 10, 30),
  IrBrand('Toshiba', 'TOSHIBA_AC', ['COOLIX'], 17, 30),
  IrBrand('LG', 'LG', ['LG2']),
  IrBrand('Samsung', 'SAMSUNG_AC'),
  IrBrand('Fujitsu', 'FUJITSU_AC', [], 10, 30),
  IrBrand('Hitachi', 'HITACHI_AC', ['HITACHI_AC1', 'HITACHI_AC344', 'HITACHI_AC424']),
  IrBrand('Gree', 'GREE', ['KELVINATOR']),
  IrBrand('Midea', 'MIDEA', ['COOLIX']),
  IrBrand('Haier', 'HAIER_AC', ['HAIER_AC_YRW02', 'HAIER_AC176']),
  IrBrand('Electrolux', 'COOLIX', ['MIDEA', 'ELECTRA_AC']),
  IrBrand('Sharp', 'SHARP_AC'),
  IrBrand('Carrier', 'CARRIER_AC64', ['CARRIER_AC']),
  IrBrand('AUX / Electra', 'ELECTRA_AC'),
  IrBrand('Whirlpool', 'WHIRLPOOL_AC'),
  IrBrand('Bosch', 'BOSCH144', ['COOLIX']),
  IrBrand('TCL', 'TCL112AC'),
  IrBrand('Hisense / Kelon', 'KELON', ['COOLIX']),
  IrBrand('Argo', 'ARGO'),
  IrBrand('Vestel', 'VESTEL_AC'),
];

IrBrand? irBrandByLabel(String label) => irBrands.where((b) => b.label == label).firstOrNull;

const irModes = ['off', 'auto', 'heat', 'cool', 'dry', 'fan'];
const irFans = ['auto', 'min', 'low', 'medium', 'high', 'max'];

String irModeFi(String m) =>
    const {
      'off': 'Pois',
      'auto': 'Automaatti',
      'heat': 'Lämmitys',
      'cool': 'Jäähdytys',
      'dry': 'Kuivaus',
      'fan': 'Puhallin',
    }[m] ??
    m;

String irModeEn(String m) =>
    const {'off': 'Off', 'auto': 'Auto', 'heat': 'Heat', 'cool': 'Cool', 'dry': 'Dry', 'fan': 'Fan'}[m] ?? m;

/// The assumed state of the heat pump. IR is one-way: this is what we last SENT.
class IrState {
  IrState({
    this.power = false,
    this.mode = 'heat',
    this.temp = 22,
    this.fan = 'auto',
    this.swing = false,
    this.vane = 'auto',
    this.sentAt,
  });
  bool power;
  String mode;
  num temp;
  String fan;
  bool swing;

  /// Fixed louver position when not swinging: auto (the unit decides), highest … lowest.
  String vane;

  /// When this state was last sent (IR is one-way: this is all we know).
  DateTime? sentAt;

  IrState copy() => IrState(power: power, mode: mode, temp: temp, fan: fan, swing: swing, vane: vane, sentAt: sentAt);

  Map<String, dynamic> toJson() => {
    'power': power,
    'mode': mode,
    'temp': temp,
    'fan': fan,
    'swing': swing,
    'vane': vane,
    if (sentAt != null) 'sentAt': sentAt!.millisecondsSinceEpoch,
  };

  static IrState fromJson(Map j) => IrState(
    power: j['power'] == true,
    mode: '${j['mode'] ?? 'heat'}',
    temp: (j['temp'] as num?) ?? 22,
    fan: '${j['fan'] ?? 'auto'}',
    swing: j['swing'] == true,
    vane: '${j['vane'] ?? 'auto'}',
    sentAt: j['sentAt'] is int ? DateTime.fromMillisecondsSinceEpoch(j['sentAt'] as int) : null,
  );

  /// Tasmota IRhvac JSON (https://tasmota.github.io/docs/Tasmota-IR/#sending-irhvac-commands).
  Map<String, dynamic> irhvac(String vendor, {String? model}) => {
    'Vendor': vendor,
    if (model != null && model.isNotEmpty) 'Model': int.tryParse(model) ?? model,
    'Power': power ? 'On' : 'Off',
    'Mode': _cap(power ? mode : 'off'),
    'Celsius': 'On',
    'Temp': temp,
    'FanSpeed': _cap(fan),
    'SwingV': swing ? 'Auto' : (vane == 'auto' ? 'Off' : _cap(vane)),
    'SwingH': 'Off',
  };

  String summary(String lang) {
    if (!power) return tr(lang, 'Pois päältä', 'Off');
    final m = tr(lang, irModeFi(mode), irModeEn(mode));
    final f = tr(lang, 'puhallin $fan', 'fan $fan');
    final v = swing
        ? tr(lang, ', suuntaus', ', swing')
        : vane == 'auto'
        ? ''
        : tr(lang, ', siivekkeet ${irVaneFi(vane)}', ', vane ${irVaneEn(vane)}');
    return '$m ${_fmt(temp)} °C, $f$v';
  }

  /// "lähetetty klo 10.41" (today) / "lähetetty 25.11. klo 10.41".
  String sentText(String lang, [DateTime? now]) {
    final t = sentAt;
    if (t == null) return tr(lang, 'ei vielä lähetetty', 'not sent yet');
    final n = now ?? DateTime.now();
    final hm = '${t.hour}.${t.minute.toString().padLeft(2, '0')}';
    final today = t.year == n.year && t.month == n.month && t.day == n.day;
    return today
        ? tr(lang, 'lähetetty klo $hm', 'sent at $hm')
        : tr(lang, 'lähetetty ${t.day}.${t.month}. klo $hm', 'sent ${t.day}.${t.month}. at $hm');
  }
}

const irVanes = ['auto', 'highest', 'high', 'middle', 'low', 'lowest'];
String irVaneFi(String v) =>
    const {
      'auto': 'automaatti',
      'highest': 'ylös',
      'high': 'ylhäälle',
      'middle': 'keskelle',
      'low': 'alhaalle',
      'lowest': 'alas',
    }[v] ??
    v;
String irVaneEn(String v) =>
    const {
      'auto': 'auto',
      'highest': 'highest',
      'high': 'high',
      'middle': 'middle',
      'low': 'low',
      'lowest': 'lowest',
    }[v] ??
    v;

String _cap(String s) => s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);
String _fmt(num n) => n == n.roundToDouble() ? n.toInt().toString() : n.toString();

/// A remote-control code captured with the blaster's IR receiver.
class IrCode {
  IrCode({required this.protocol, this.bits, this.data, this.raw, this.text, this.rf = false, this.pulse});

  /// RF433 code (Tasmota RfReceived / RfSend) instead of infrared.
  final bool rf;
  final int? pulse;
  final String protocol;
  final int? bits;
  final String? data;

  /// Raw timings "9000,4500,560,…" (Tasmota with SetOption58 1) or ESPHome Pronto data.
  final String? raw;

  /// What the receiver printed (shown to the user).
  final String? text;

  bool get known => protocol.isNotEmpty && protocol != 'UNKNOWN' && data != null;

  /// Payload for Tasmota `RfSend`.
  String get rfsend =>
      jsonEncode({'Data': data, 'Bits': bits ?? 24, 'Protocol': int.tryParse(protocol) ?? 1, 'Pulse': pulse ?? 350});

  /// Tile command spec that replays this code.
  Map<String, dynamic> get command => rf ? {'rf': rfsend} : {'code': irsend};

  /// Payload for Tasmota `IRsend`.
  String get irsend {
    if (known) return jsonEncode({'Protocol': protocol, 'Bits': bits ?? 0, 'Data': data});
    if (raw != null && raw!.isNotEmpty) return '0,$raw';
    throw DriverException(
      dtx(
        'Koodia ei tunnistettu eikä raakadataa tullut. Ota Tasmotassa käyttöön raakadata (SetOption58 1) ja yritä uudelleen.',
        'Unknown code without raw data. Enable raw data in Tasmota (SetOption58 1) and try again.',
      ),
    );
  }

  String describe() => rf
      ? 'RF433 $data ($bits bit, protokolla $protocol, pulssi $pulse)'
      : known
      ? '$protocol, $bits bit, $data'
      : (text ?? raw ?? protocol);

  Map<String, dynamic> toJson() => {
    if (rf) 'rf': true,
    'pulse': ?pulse,
    'protocol': protocol,
    if (bits != null) 'bits': bits,
    if (data != null) 'data': data,
    if (raw != null) 'raw': raw,
    if (text != null) 'text': text,
  };

  /// From a Tasmota `{"RfReceived":{…}}` message (RF433 receiver, e.g. Athom IR & RF controller).
  static IrCode? fromTasmotaRf(Object? j) {
    if (j is! Map || j['RfReceived'] is! Map) return null;
    final r = j['RfReceived'] as Map;
    return IrCode(
      rf: true,
      protocol: '${r['Protocol'] ?? 1}',
      bits: (r['Bits'] as num?)?.toInt(),
      data: r['Data']?.toString(),
      pulse: (r['Pulse'] as num?)?.toInt(),
      text: jsonEncode(r),
    );
  }

  /// From a Tasmota `{"IrReceived":{…}}` message.
  static IrCode? fromTasmota(Object? j) {
    if (j is! Map) return null;
    final r = j['IrReceived'];
    if (r is! Map) return null;
    final raw = r['RawData'];
    return IrCode(
      protocol: '${r['Protocol'] ?? 'UNKNOWN'}',
      bits: (r['Bits'] as num?)?.toInt(),
      data: r['Data']?.toString(),
      raw: raw is List ? raw.join(',') : raw?.toString(),
      text: jsonEncode(r),
    );
  }

  /// From an ESPHome remote_receiver dump log line, e.g. "Received Pronto: data=0000 006D …"
  /// or "Received NEC: address=0x4004, command=0x0100".
  static IrCode? fromEsphomeLog(String line) {
    final m = RegExp(r'Received (\w+): (.*)$').firstMatch(line.trim());
    if (m == null) return null;
    final proto = m.group(1)!;
    final rest = m.group(2)!.trim();
    if (proto.toLowerCase() == 'pronto') {
      return IrCode(protocol: 'PRONTO', raw: rest.replaceFirst(RegExp(r'^data=\s*'), ''), text: line.trim());
    }
    return IrCode(protocol: proto.toUpperCase(), text: '$proto: $rest');
  }
}

/// Finds every `{"IrReceived":{…}}` (or with [rf] `{"RfReceived":{…}}`) object in free text (Tasmota web console log).
List<IrCode> irCodesInText(String text, {bool rf = false}) {
  final out = <IrCode>[];
  final tag = rf ? '{"RfReceived"' : '{"IrReceived"';
  var i = text.indexOf(tag);
  while (i >= 0) {
    var depth = 0;
    var end = -1;
    var inStr = false;
    for (var k = i; k < text.length; k++) {
      final ch = text[k];
      if (inStr) {
        if (ch == '\\') {
          k++;
        } else if (ch == '"') {
          inStr = false;
        }
        continue;
      }
      if (ch == '"') inStr = true;
      if (ch == '{') depth++;
      if (ch == '}' && --depth == 0) {
        end = k;
        break;
      }
    }
    if (end < 0) break;
    try {
      final j = jsonDecode(text.substring(i, end + 1));
      final c = rf ? IrCode.fromTasmotaRf(j) : IrCode.fromTasmota(j);
      if (c != null) out.add(c);
    } catch (_) {}
    i = text.indexOf(tag, end);
  }
  return out;
}

/// Small MQTT surface the IR driver needs (replaceable in tests).
abstract class IrMqtt {
  Future<void> publish(String topic, String payload);
  Stream<String> listen(String topic);
  Future<void> dispose();
}

class _DriverMqtt implements IrMqtt {
  _DriverMqtt(this.d);
  final MqttDriver d;
  @override
  Future<void> publish(String topic, String payload) => d.send({'topic': topic, 'payload': payload});
  @override
  Stream<String> listen(String topic) => d.watch({'topic': topic})!.map((v) => '${v ?? ''}');
  @override
  Future<void> dispose() => d.dispose();
}

/// IR blaster for an air heat pump. Transports:
/// * `tasmota_http` / `tasmota_mqtt` – Tasmota (tasmota-ir build): `IRhvac` for the full state,
///   `IRsend` for learned codes, `IrReceived` for learning.
/// * `esphome` – ESPHome `climate_ir` platform via the web_server REST API (state lives on the device);
///   learned codes are sent by pressing an ESPHome template button.
/// * `http` / `mqtt` – any other blaster: URL / payload templates with {{power}} {{mode}} {{temp}}
///   {{fan}} {{swing}} {{vendor}} {{json}}.
///
/// Command spec: {'set': 'power'|'temp'|'mode'|'fan'|'swing', 'to': fixed value} (value from the tile otherwise),
/// `{'code': IRsend payload}` or `{'button': esphome button id}`, `{'learn': seconds}`.
/// Read spec: {'field': 'power'|'temp'|'mode'|'fan'|'swing'|'summary'|'room'}.
class IrDriver extends Driver {
  IrDriver(super.config, {IrMqtt? mqtt, http.Client? client}) : _mqttOverride = mqtt, _clientOverride = client;

  static const descriptor = DriverDescriptor(
    type: 'ir',
    fi: 'IR-lähetin (ilmalämpöpumppu)',
    en: 'IR blaster (heat pump)',
    connectionFields: [
      FieldSpec(
        'transport',
        'Lähettimen ohjelmisto',
        'Blaster firmware',
        kind: FieldKind.choice,
        options: ['tasmota_http', 'tasmota_mqtt', 'esphome', 'http', 'mqtt'],
        optionLabels: {
          'tasmota_http': ('Tasmota (HTTP)', 'Tasmota (HTTP)'),
          'tasmota_mqtt': ('Tasmota (MQTT)', 'Tasmota (MQTT)'),
          'esphome': ('ESPHome', 'ESPHome'),
          'http': ('Oma HTTP', 'Custom HTTP'),
          'mqtt': ('Oma MQTT', 'Custom MQTT'),
        },
        defaultValue: 'tasmota_http',
        helpFi: 'tasmota_http = Tasmota (tasmota-ir) suoraan IP-osoitteella. tasmota_mqtt = Tasmota MQTT-välittäjän kautta. esphome = ESPHome climate_ir. http/mqtt = muu lähetin omilla osoitteilla.',
        helpEn: 'tasmota_http = Tasmota (tasmota-ir) by IP. tasmota_mqtt = Tasmota via an MQTT broker. esphome = ESPHome climate_ir. http/mqtt = other blaster with your own templates.',
      ),
      FieldSpec(
        'baseUrl',
        'Lähettimen osoite',
        'Blaster address',
        hint: 'http://192.168.x.x',
        helpFi: 'IR-lähettimen IP-osoite (Tasmota tai ESPHome). Löytyy reitittimen laitelistasta.',
        helpEn: 'IP address of the IR blaster (Tasmota or ESPHome).',
      ),
      FieldSpec(
        'vendor',
        'Merkin IR-protokolla',
        'Brand IR protocol',
        hint: 'MITSUBISHI_AC',
        helpFi: 'Tasmotan IRhvac-valmistajanimi, esim. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. Jos laite ei reagoi, kokeile saman merkin toista protokollaa.',
        helpEn: 'Tasmota IRhvac vendor, e.g. MITSUBISHI_AC, PANASONIC_AC, DAIKIN. If nothing happens, try another protocol of the same brand.',
      ),
      FieldSpec(
        'model',
        'Malli (valinnainen)',
        'Model (optional)',
        advanced: true,
        helpFi: 'IRhvac Model -numero joillekin merkeille (esim. Panasonic). Jätä tyhjäksi, jos et tiedä.',
        helpEn: 'IRhvac Model number for some brands. Leave empty if unsure.',
      ),
      FieldSpec(
        'topic',
        'Tasmotan aihe (topic)',
        'Tasmota topic',
        hint: 'tasmota_ir',
        helpFi: 'Vain MQTT: Tasmotan asetuksista (Configuration → MQTT → Topic). Komennot menevät aiheeseen cmnd/<aihe>/IRhvac.',
        helpEn: 'MQTT only: from Tasmota (Configuration → MQTT → Topic).',
      ),
      FieldSpec(
        'host',
        'MQTT-välittäjän osoite',
        'MQTT broker address',
        hint: '192.168.x.x',
        helpFi: 'Vain MQTT: kone, jolla Mosquitto pyörii (usein Home Assistant -kone).',
        helpEn: 'MQTT only: the machine running the broker.',
      ),
      FieldSpec('port', 'MQTT-portti', 'MQTT port', kind: FieldKind.number, defaultValue: 1883, advanced: true),
      FieldSpec(
        'username',
        'Tunnus',
        'Username',
        helpFi: 'MQTT-tunnus tai Tasmotan web-tunnus (admin).',
        helpEn: 'MQTT or web user.',
      ),
      FieldSpec(
        'password',
        'Salasana',
        'Password',
        kind: FieldKind.secret,
        helpFi: 'Jätä tyhjäksi, jos ei tarvita.',
        helpEn: 'Leave empty if not needed.',
      ),
      FieldSpec(
        'entity',
        'ESPHome-ilmastoinnin tunnus',
        'ESPHome climate id',
        hint: 'ilmalampopumppu',
        helpFi: 'Vain ESPHome: climate-entiteetin nimi pienillä kirjaimilla ja alaviivoilla (esim. "Ilmalämpöpumppu" → ilmalampopumppu).',
        helpEn: 'ESPHome only: the climate object id.',
      ),
      FieldSpec(
        'url',
        'Komennon osoite (muu lähetin)',
        'Command URL (other blaster)',
        advanced: true,
        hint: 'http://192.168.x.x/ac?power={{power}}&mode={{mode}}&temp={{temp}}',
        helpFi: 'Vain http: osoite, johon koko tila lähetetään. Paikkamerkit: {{power}} {{mode}} {{temp}} {{fan}} {{swing}} {{vendor}} {{json}}.',
        helpEn: 'http only: URL that receives the full state. Placeholders as listed.',
      ),
      FieldSpec(
        'payload',
        'Viestin pohja (muu lähetin)',
        'Payload template (other blaster)',
        kind: FieldKind.multiline,
        advanced: true,
        helpFi: 'http (POST-runko) tai mqtt (viesti). Tyhjä = IRhvac-JSON ({{json}}).',
        helpEn: 'http body or mqtt payload. Empty = IRhvac JSON ({{json}}).',
      ),
    ],
    readFields: [
      FieldSpec(
        'field',
        'Mitä näytetään',
        'What to show',
        kind: FieldKind.choice,
        options: ['summary', 'power', 'temp', 'mode', 'fan', 'swing', 'vane', 'sent', 'room'],
        optionLabels: {
          'summary': ('Yhteenveto', 'Summary'),
          'power': ('Virta', 'Power'),
          'temp': ('Asetuslämpö', 'Set temperature'),
          'mode': ('Tila', 'Mode'),
          'fan': ('Puhallin', 'Fan'),
          'swing': ('Suuntaus', 'Swing'),
          'vane': ('Siivekkeet', 'Vane'),
          'sent': ('Lähetysaika', 'Sent at'),
          'room': ('Huonelämpö', 'Room temperature'),
        },
        defaultValue: 'summary',
        helpFi:
            'summary = koko tila tekstinä. room = lähettimen lämpöanturi (jos on). Muut = viimeksi lähetetty asetus.',
        helpEn: 'summary = full state as text. room = the blaster\'s temperature sensor. Others = last sent setting.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'set',
        'Mitä muutetaan',
        'What to change',
        kind: FieldKind.choice,
        options: ['power', 'temp', 'mode', 'fan', 'swing', 'vane'],
        optionLabels: {
          'power': ('Virta', 'Power'),
          'temp': ('Asetuslämpö', 'Set temperature'),
          'mode': ('Tila', 'Mode'),
          'fan': ('Puhallin', 'Fan'),
          'swing': ('Suuntaus', 'Swing'),
          'vane': ('Siivekkeet', 'Vane'),
        },
        helpFi: 'Koko tila lähetetään aina kerralla (IR toimii niin). Arvo tulee ruudusta tai kentästä "Arvo".',
        helpEn: 'The whole state is always sent at once. The value comes from the tile or "Value".',
      ),
      FieldSpec(
        'to',
        'Arvo',
        'Value',
        helpFi: 'Esim. heat, cool, auto, dry, fan (tila) tai on/off. Tyhjä = ruudun arvo.',
        helpEn: 'E.g. heat, cool, auto, dry, fan or on/off. Empty = tile value.',
      ),
      FieldSpec(
        'code',
        'Opeteltu koodi',
        'Learned code',
        kind: FieldKind.multiline,
        helpFi: 'Täyttyy itse, kun tallennat opetellun kaukosäätimen napin. Lähetetään Tasmotan IRsend-komennolla.',
        helpEn: 'Filled when you save a learned remote button. Sent with Tasmota IRsend.',
      ),
      FieldSpec(
        'button',
        'ESPHome-painike',
        'ESPHome button',
        helpFi: 'Vain ESPHome: painikkeen tunnus, jonka teit opetellulle koodille.',
        helpEn: 'ESPHome only: id of the template button for a learned code.',
      ),
    ],
    create: IrDriver.new,
  );

  /// Assumed states survive driver re-creation (config edits) within the app run.
  static final _states = <String, IrState>{};
  static void resetStates() => _states.clear();

  /// v0.8.0: the last-sent state survives app restarts (AppState stores it).
  static void Function(Map<String, dynamic> all)? persist;
  static void restoreStates(Map<String, dynamic> all) {
    for (final e in all.entries) {
      if (e.value is Map) _states[e.key] = IrState.fromJson(e.value as Map);
    }
  }

  static Map<String, dynamic> statesJson() => {for (final e in _states.entries) e.key: e.value.toJson()};

  /// v0.8.0: room temperature from another tile (any sensor tile), by tile id.
  static Object? Function(String tileId)? tileValue;

  final IrMqtt? _mqttOverride;
  IrMqtt? _mqtt;
  final http.Client? _clientOverride;
  http.Client? _client;
  final _changes = StreamController<IrState>.broadcast();

  String get transport => s.str('transport', 'tasmota_http');
  bool get isTasmota => transport.startsWith('tasmota');
  bool get usesMqtt => transport == 'tasmota_mqtt' || transport == 'mqtt';
  IrState get state => _states.putIfAbsent(config.id, IrState.new);
  String get vendor => s.str('vendor', 'MITSUBISHI_AC');
  String get _base {
    var b = s.str('baseUrl').trim();
    if (b.isNotEmpty && !b.contains('://')) b = 'http://$b';
    while (b.endsWith('/')) {
      b = b.substring(0, b.length - 1);
    }
    return b;
  }

  String get _topic => s.str('topic', 'tasmota_ir');

  http.Client get client => _clientOverride ?? (_client ??= makeHttpClient(false, timeout: const Duration(seconds: 8)));

  IrMqtt get mqtt {
    final o = _mqttOverride;
    if (o != null) return o;
    return _mqtt ??= _DriverMqtt(
      MqttDriver(
        ConnectionConfig(
          id: '${config.id}-mqtt',
          name: config.name,
          type: 'mqtt',
          settings: {
            'host': s.str('host'),
            'port': s.integer('port', 1883),
            if (s.strOrNull('username') != null) 'username': s.str('username'),
          },
          secrets: {if (s.strOrNull('password') != null) 'password': s.str('password')},
        ),
      ),
    );
  }

  // ------------------------------------------------------------ Tasmota

  String get _auth {
    final pw = s.strOrNull('password');
    if (pw == null) return '';
    return '&user=${Uri.encodeQueryComponent(s.str('username', 'admin'))}&password=${Uri.encodeQueryComponent(pw)}';
  }

  /// Runs one Tasmota console command (HTTP `/cm` or MQTT `cmnd/<topic>/<cmd>`).
  Future<String> tasmota(String cmd, String arg) async {
    if (transport == 'tasmota_mqtt') {
      await mqtt.publish('cmnd/$_topic/$cmd', arg);
      return '';
    }
    if (_base.isEmpty) throw DriverException(dtx('Lähettimen osoite puuttuu.', 'Blaster address missing.'));
    final q = Uri.encodeQueryComponent(arg.isEmpty ? cmd : '$cmd $arg').replaceAll('+', '%20');
    final r = await client.get(Uri.parse('$_base/cm?cmnd=$q$_auth'));
    if (r.statusCode == 401) {
      throw DriverException(
        dtx('Tasmota pyytää salasanaa – lisää web-salasana yhteyden asetuksiin.', 'Tasmota needs the web password.'),
      );
    }
    if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}');
    final body = utf8.decode(r.bodyBytes, allowMalformed: true);
    if (body.contains('"Command":"Unknown"') || body.contains('"Command":"Error"')) {
      throw DriverException(
        cmd.startsWith('IR')
            ? dtx(
                'Tasmota ei tunne komentoa $cmd. Asenna lähettimeen tasmota-ir-versio (sisältää ilmalämpöpumppujen protokollat).',
                'Tasmota does not know $cmd. Install the tasmota-ir build.',
              )
            : dtx('Tasmota hylkäsi komennon: $body', 'Tasmota rejected the command: $body'),
      );
    }
    if (body.contains('"IRHVAC":"Wrong') || body.contains('Wrong Vendor')) {
      throw DriverException(
        dtx(
          'Tasmota ei tunne merkin protokollaa "$vendor". Valitse toinen merkki/protokolla.',
          'Unknown vendor "$vendor".',
        ),
      );
    }
    return body;
  }

  // ------------------------------------------------------------ ESPHome

  static const _espMode = {
    'off': 'OFF',
    'auto': 'HEAT_COOL',
    'heat': 'HEAT',
    'cool': 'COOL',
    'dry': 'DRY',
    'fan': 'FAN_ONLY',
  };
  static const _espFan = {
    'auto': 'AUTO',
    'min': 'QUIET',
    'low': 'LOW',
    'medium': 'MEDIUM',
    'high': 'HIGH',
    'max': 'HIGH',
  };

  String get _entity => s.str('entity');

  Future<Map<String, dynamic>> _espRead() async {
    final r = await client.get(Uri.parse('$_base/climate/${Uri.encodeComponent(_entity)}'));
    if (r.statusCode == 404) {
      throw DriverException(
        dtx(
          'ESPHome ei löytänyt ilmastointia "$_entity". Tarkista tunnus (web_server-sivulta).',
          'ESPHome climate "$_entity" not found.',
        ),
      );
    }
    if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}');
    final j = jsonDecode(utf8.decode(r.bodyBytes));
    if (j is! Map<String, dynamic>) throw DriverException('ESPHome: ?');
    // Mirror the device state (climate_ir keeps it on the device).
    final st = state;
    final mode = '${j['mode'] ?? ''}'.toUpperCase();
    final m = _espMode.entries.where((e) => e.value == mode).firstOrNull?.key;
    if (m != null) {
      st.power = m != 'off';
      if (m != 'off') st.mode = m;
    }
    final t = j['target_temperature'];
    if (t is num) st.temp = t;
    final f = '${j['fan_mode'] ?? ''}'.toUpperCase();
    final fk = _espFan.entries.where((e) => e.value == f).firstOrNull?.key;
    if (fk != null) st.fan = fk;
    if (j['swing_mode'] != null) st.swing = '${j['swing_mode']}'.toUpperCase() != 'OFF';
    return j;
  }

  Future<void> _espSet(IrState st) async {
    final q = {
      'mode': st.power ? _espMode[st.mode] ?? 'HEAT' : 'OFF',
      'target_temperature': _fmt(st.temp),
      'fan_mode': _espFan[st.fan] ?? 'AUTO',
      'swing_mode': st.swing ? 'VERTICAL' : 'OFF',
    };
    final r = await client.post(
      Uri.parse('$_base/climate/${Uri.encodeComponent(_entity)}/set').replace(queryParameters: q),
    );
    if (r.statusCode >= 400) throw DriverException('ESPHome HTTP ${r.statusCode}');
  }

  // ------------------------------------------------------------ generic

  String _fill(String t, IrState st) {
    final json = jsonEncode(st.irhvac(vendor, model: s.strOrNull('model')));
    return t
        .replaceAll('{{power}}', st.power ? 'on' : 'off')
        .replaceAll('{{mode}}', st.power ? st.mode : 'off')
        .replaceAll('{{temp}}', _fmt(st.temp))
        .replaceAll('{{fan}}', st.fan)
        .replaceAll('{{swing}}', st.swing ? 'on' : 'off')
        .replaceAll('{{vendor}}', vendor)
        .replaceAll('{{json}}', json);
  }

  // ------------------------------------------------------------ state

  Future<void> _transmit(IrState st) async {
    final model = s.strOrNull('model');
    switch (transport) {
      case 'tasmota_http':
      case 'tasmota_mqtt':
        await tasmota('IRhvac', jsonEncode(st.irhvac(vendor, model: model)));
      case 'esphome':
        await _espSet(st);
      case 'mqtt':
        final payload = s.str('payload', '{{json}}');
        await mqtt.publish(_fill(s.str('topic'), st), _fill(payload, st));
      default:
        final url = s.str('url');
        if (url.isEmpty) throw DriverException(dtx('Komennon osoite puuttuu.', 'Command URL missing.'));
        final body = s.strOrNull('payload');
        final u = Uri.parse(_fill(url, st));
        final r = body == null ? await client.get(u) : await client.post(u, body: _fill(body, st));
        if (r.statusCode >= 400) throw DriverException('HTTP ${r.statusCode}');
    }
  }

  /// Applies one change to the assumed state and sends the FULL state.
  Future<IrState> apply(String what, Object? value) async {
    final next = state.copy();
    final v = value;
    switch (what) {
      case 'power':
        next.power = _truthy(v);
      case 'temp':
        final n = v is num ? v : num.tryParse('$v');
        if (n == null) throw DriverException(dtx('Lämpötila puuttuu.', 'Temperature missing.'));
        next.temp = n.clamp(s.dbl('minTemp', 16), s.dbl('maxTemp', 31));
      case 'mode':
        final m = '$v'.toLowerCase();
        if (!irModes.contains(m)) throw DriverException('mode: $v');
        if (m == 'off') {
          next.power = false;
        } else {
          next.mode = m;
          next.power = true; // choosing a mode switches the pump on
        }
      case 'fan':
        if (v is num) {
          next.fan = irFans[v.round().clamp(0, irFans.length - 1)];
        } else {
          final f = '$v'.toLowerCase();
          if (!irFans.contains(f)) throw DriverException('fan: $v');
          next.fan = f;
        }
      case 'swing':
        next.swing = _truthy(v);
      case 'vane':
        final x = v is num ? irVanes[v.round().clamp(0, irVanes.length - 1)] : '$v'.toLowerCase();
        if (!irVanes.contains(x)) throw DriverException('vane: $v');
        next.vane = x;
        next.swing = false; // a fixed position stops the swing
      default:
        throw DriverException('set: $what');
    }
    await _transmit(next);
    next.sentAt = DateTime.now();
    _states[config.id] = next;
    persist?.call(statesJson());
    _changes.add(next);
    return next;
  }

  static bool _truthy(Object? v) {
    if (v is bool) return v;
    if (v is num) return v != 0;
    return const {'on', 'true', '1', 'yes', 'päällä', 'paalla'}.contains('$v'.trim().toLowerCase());
  }

  Object? _field(String f, IrState st) {
    switch (f) {
      case 'power':
        return st.power ? 'on' : 'off';
      case 'temp':
        return st.temp;
      case 'mode':
        return tr(driverLang, irModeFi(st.power ? st.mode : 'off'), irModeEn(st.power ? st.mode : 'off'));
      case 'fan':
        return irFans.indexOf(st.fan);
      case 'swing':
        return st.swing ? 'on' : 'off';
      case 'vane':
        return irVanes.indexOf(st.vane);
      case 'sent':
        return st.sentText(driverLang);
      default:
        return st.summary(driverLang);
    }
  }

  /// Summary tile: what was sent, when, and the room temperature from a linked sensor tile.
  Object? _summary(Map<String, dynamic> spec, IrState st) {
    final parts = [st.summary(driverLang)];
    final room = spec.strOrNull('roomTile');
    if (room != null) {
      final v = tileValue?.call(room);
      final n = v is num ? v : num.tryParse('$v'.replaceAll(',', '.'));
      if (n != null) parts.add(tr(driverLang, 'huone ${_fmt(n)} °C', 'room ${_fmt(n)} °C'));
    }
    parts.add(st.sentText(driverLang));
    return parts.join(' · ');
  }

  static final _tempRe = RegExp(r'"Temperature"\s*:\s*(-?\d+(?:\.\d+)?)');

  Future<Object?> _room() async {
    switch (transport) {
      case 'tasmota_http':
        final body = await tasmota('Status', '8');
        final m = _tempRe.firstMatch(body);
        if (m == null) {
          throw DriverException(
            dtx(
              'Lähettimessä ei ole lämpöanturia (Status 8 ei kertonut lämpötilaa).',
              'No temperature sensor on the blaster.',
            ),
          );
        }
        return num.parse(m.group(1)!);
      case 'tasmota_mqtt':
        final first = mqtt.listen('tele/$_topic/SENSOR').map((p) => _tempRe.firstMatch(p)).where((m) => m != null);
        final m = await first.first.timeout(
          const Duration(seconds: 15),
          onTimeout: () =>
              throw DriverException(dtx('Lämpötilaa ei tullut (tele/$_topic/SENSOR).', 'No temperature received.')),
        );
        return num.parse(m!.group(1)!);
      case 'esphome':
        final j = await _espRead();
        return j['current_temperature'];
      default:
        throw DriverException(
          dtx('Huonelämpö vain Tasmota/ESPHome-lähettimistä.', 'Room temperature only from Tasmota/ESPHome.'),
        );
    }
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final f = spec.str('field', 'summary');
    if (f == 'room') {
      final linked = spec.strOrNull('roomTile');
      if (linked != null) return tileValue?.call(linked);
      return _room();
    }
    if (transport == 'esphome') await _espRead();
    if (f == 'summary' && transport != 'esphome') return _summary(spec, state);
    return _field(f, state);
  }

  @override
  Stream<Object?>? watch(Map<String, dynamic> spec) {
    final f = spec.str('field', 'summary');
    if (f == 'room' && transport == 'tasmota_mqtt') {
      return mqtt
          .listen('tele/$_topic/SENSOR')
          .map((p) => _tempRe.firstMatch(p))
          .where((m) => m != null)
          .map((m) => num.parse(m!.group(1)!));
    }
    if (f == 'room' || transport == 'esphome') return null; // polled
    // Assumed state: current value now, then every change made through any tile.
    late StreamController<Object?> out;
    StreamSubscription? sub;
    out = StreamController<Object?>(
      onListen: () {
        Object? val(IrState st) => f == 'summary' ? _summary(spec, st) : _field(f, st);
        out.add(val(state));
        sub = _changes.stream.listen((st) => out.add(val(st)));
      },
      onCancel: () => sub?.cancel(),
    );
    return out.stream;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final learn = spec['learn'];
    if (learn != null) {
      final c = await this.learn(
        Duration(seconds: (learn is num ? learn : num.tryParse('$learn') ?? 30).toInt()),
        rf: spec['kind'] == 'rf',
      );
      return c.toJson();
    }
    final rfCode = spec.strOrNull('rf');
    if (rfCode != null) {
      if (!isTasmota) throw DriverException(dtx('RF433-koodeja voi lähettää vain Tasmotalla.', 'RF433 needs Tasmota.'));
      await tasmota('RfSend', rfCode);
      return null;
    }
    final code = spec.strOrNull('code');
    if (code != null) {
      if (!isTasmota) {
        throw DriverException(dtx('Opeteltuja koodeja voi lähettää vain Tasmotalla.', 'Learned codes need Tasmota.'));
      }
      await tasmota('IRsend', code);
      return null;
    }
    final button = spec.strOrNull('button');
    if (button != null) {
      final r = await client.post(Uri.parse('$_base/button/${Uri.encodeComponent(button)}/press'));
      if (r.statusCode >= 400) {
        throw DriverException(
          dtx(
            'ESPHome-painiketta "$button" ei löytynyt (HTTP ${r.statusCode}).',
            'ESPHome button "$button" not found.',
          ),
        );
      }
      return null;
    }
    final what = spec.str('set');
    final to = spec.strOrNull('to');
    await apply(what, to ?? value);
    return null;
  }

  // ------------------------------------------------------------ learning

  /// Waits for the next code from the blaster's IR receiver (point the remote at it and press a button).
  Future<IrCode> learn(
    Duration timeout, {
    Duration pollEvery = const Duration(milliseconds: 700),
    bool rf = false,
  }) async {
    final fail = DriverException(
      dtx(
        'Koodia ei tullut ${timeout.inSeconds} sekunnissa. Osoita kaukosäätimellä suoraan lähettimeen (alle 1 m) ja paina nappia uudelleen. Tarkista, että lähettimessä on IR-vastaanotin.',
        'No code within ${timeout.inSeconds} s. Point the remote straight at the blaster (under 1 m) and press again.',
      ),
    );
    switch (transport) {
      case 'tasmota_mqtt':
        final sub = mqtt.listen('tele/$_topic/RESULT');
        // Raw timings for unknown protocols (harmless setting).
        if (!rf) unawaited(tasmota('SetOption58', '1').catchError((_) => ''));
        return sub
            .map((p) => irCodesInText(p, rf: rf))
            .where((l) => l.isNotEmpty)
            .map((l) => l.first)
            .first
            .timeout(timeout, onTimeout: () => throw fail);
      case 'tasmota_http':
        if (!rf) await tasmota('SetOption58', '1');
        return _learnHttp(timeout, pollEvery, fail, rf);
      case 'esphome':
        if (rf) throw DriverException(dtx('RF433-opettelu toimii Tasmotalla.', 'RF433 learning needs Tasmota.'));
        return _learnEsphome(timeout, fail);
      default:
        throw DriverException(
          dtx('Opettelu toimii Tasmota- ja ESPHome-lähettimillä.', 'Learning works with Tasmota and ESPHome blasters.'),
        );
    }
  }

  /// Tasmota web console log: `GET /cs?c2=<index>` returns new log lines since index.
  Future<IrCode> _learnHttp(Duration timeout, Duration every, Exception fail, bool rf) async {
    final until = DateTime.now().add(timeout);
    var idx = 0;
    var first = true;
    while (DateTime.now().isBefore(until)) {
      final r = await client.get(Uri.parse('$_base/cs?c2=$idx$_auth'));
      final body = utf8.decode(r.bodyBytes, allowMalformed: true);
      final head = RegExp(r'^\s*(\d+)').firstMatch(body);
      if (head != null) idx = int.parse(head.group(1)!);
      if (!first) {
        final codes = irCodesInText(body, rf: rf);
        if (codes.isNotEmpty) return codes.last;
      }
      first = false; // skip what was in the log before we started
      await Future<void>.delayed(every);
    }
    throw fail;
  }

  /// ESPHome web_server /events (SSE) includes log lines; remote_receiver dump prints "Received …".
  Future<IrCode> _learnEsphome(Duration timeout, Exception fail) async {
    final hc = requireIoHttpClient(timeout: const Duration(seconds: 8));
    try {
      final req = await hc.getUrl(Uri.parse('$_base/events'));
      req.headers.set('Accept', 'text/event-stream');
      final res = await req.close();
      final done = Completer<IrCode>();
      final sub = res
          .transform(utf8.decoder)
          .transform(const LineSplitter())
          .listen(
            (line) {
              if (!line.startsWith('data:') || done.isCompleted) return;
              final c = IrCode.fromEsphomeLog(line.substring(5).replaceAll(RegExp(r'\x1b\[[0-9;]*m'), ''));
              if (c != null) done.complete(c);
            },
            onError: (Object e) {
              if (!done.isCompleted) done.completeError(e);
            },
          );
      try {
        return await done.future.timeout(timeout, onTimeout: () => throw fail);
      } finally {
        unawaited(sub.cancel());
      }
    } finally {
      hc.close(force: true);
    }
  }

  @override
  Future<String> test() async {
    switch (transport) {
      case 'tasmota_http':
        final body = await tasmota('Status', '0');
        final ver = RegExp(r'"Version"\s*:\s*"([^"]+)"').firstMatch(body)?.group(1) ?? '?';
        final ir = ver.toLowerCase().contains('ir');
        return dtx(
          '✓ Tasmota vastasi (versio $ver). Testattiin: Status 0 osoitteessa $_base. ${ir ? 'IR-versio löytyi.' : 'Huom: versio ei näytä tasmota-ir:ltä – IRhvac voi puuttua.'} Lämpöpumpulle ei lähetetty mitään.',
          '✓ Tasmota answered (version $ver). Tested: Status 0 at $_base. Nothing was sent to the heat pump.',
        );
      case 'tasmota_mqtt':
        final got = mqtt.listen('stat/$_topic/STATUS').first.timeout(const Duration(seconds: 8));
        await tasmota('Status', '0');
        try {
          await got;
        } on TimeoutException {
          throw DriverException(
            dtx(
              'MQTT-välittäjä toimii, mutta Tasmota "$_topic" ei vastannut. Tarkista aihe.',
              'Broker OK but Tasmota "$_topic" did not answer.',
            ),
          );
        }
        return dtx(
          '✓ Tasmota "$_topic" vastasi MQTT:n kautta. Lämpöpumpulle ei lähetetty mitään.',
          '✓ Tasmota "$_topic" answered via MQTT. Nothing sent to the heat pump.',
        );
      case 'esphome':
        final j = await _espRead();
        return dtx(
          '✓ ESPHome-ilmastointi "$_entity" löytyi (tila ${j['mode'] ?? '?'}). Testattiin: GET $_base/climate/$_entity. Mitään ei lähetetty.',
          '✓ ESPHome climate "$_entity" found. Nothing was sent.',
        );
      default:
        return dtx(
          'Muulle lähettimelle ei ole testiä: IR on yksisuuntainen. Paina virtaruutua ja katso, reagoiko lämpöpumppu.',
          'No test for other blasters: IR is one-way. Press the power tile and watch the heat pump.',
        );
    }
  }

  @override
  Future<void> dispose() async {
    _client?.close();
    await _mqtt?.dispose();
    await _changes.close();
  }
}

/// One climate entity found on an ESPHome device.
class EsphomeClimate {
  EsphomeClimate(this.id, this.name, {this.mode, this.current});
  final String id;
  final String name;
  final String? mode;
  final num? current;
}

/// Lists the climate entities of an ESPHome device: its web_server `/events` stream sends the state of
/// every entity right after connecting (ids `climate-<object_id>`, newer versions `climate/<name>`).
Future<List<EsphomeClimate>> discoverEsphomeClimates(
  String address, {
  Duration wait = const Duration(seconds: 4),
}) async {
  var base = address.trim();
  if (!base.contains('://')) base = 'http://$base';
  while (base.endsWith('/')) {
    base = base.substring(0, base.length - 1);
  }
  final hc = requireIoHttpClient(timeout: const Duration(seconds: 6));
  final found = <String, EsphomeClimate>{};
  try {
    final req = await hc.getUrl(Uri.parse('$base/events')).timeout(const Duration(seconds: 6));
    req.headers.set('Accept', 'text/event-stream');
    final res = await req.close().timeout(const Duration(seconds: 6));
    if (res.statusCode != 200) {
      throw DriverException(
        dtx(
          'Laite vastasi HTTP ${res.statusCode}. Onko ESPHome-asetuksissa web_server päällä?',
          'Device answered HTTP ${res.statusCode}. Is web_server enabled in ESPHome?',
        ),
      );
    }
    final done = Completer<void>();
    final sub = res.transform(utf8.decoder).transform(const LineSplitter()).listen((line) {
      if (!line.startsWith('data:')) return;
      try {
        final j = jsonDecode(line.substring(5).trim());
        if (j is! Map) return;
        final m = RegExp(r'^climate[-/](.+)$').firstMatch('${j['id'] ?? ''}');
        if (m == null) return;
        final id = m.group(1)!;
        found[id] = EsphomeClimate(
          id,
          '${j['name'] ?? id}',
          mode: j['mode']?.toString(),
          current: j['current_temperature'] is num ? j['current_temperature'] as num : null,
        );
      } catch (_) {}
    }, onDone: () => done.isCompleted ? null : done.complete());
    await done.future.timeout(wait, onTimeout: () {});
    unawaited(sub.cancel());
  } on DriverException {
    rethrow;
  } on TimeoutException {
    throw DriverException(dtx('Laite ei vastannut osoitteessa $base.', 'No answer from $base.'));
  } on SocketException {
    throw DriverException(
      dtx('Laitetta ei tavoitettu osoitteessa $base. Tarkista IP-osoite.', 'Could not reach $base.'),
    );
  } finally {
    hc.close(force: true);
  }
  return found.values.toList();
}
