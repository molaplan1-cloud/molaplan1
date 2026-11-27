/// Heat pump brands in the add-device wizard (t267u–t270u). One card "Lämpöpumppu" in the
/// gallery ([HeatPumpChooser]) opens a brand list; each brand is a normal [DeviceProvider]:
/// find (Daikin UDP / MHI mDNS) or type the address / log in to the cloud → list the indoor units
/// → one climate tile per unit (extra tiles for automations are offered unticked).
library;

import '../devices/provider.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'daikin.dart';
import 'hp_driver.dart';
import 'hp_model.dart';
import 'mhi_wfrac.dart';

class HeatPumpProvider extends DeviceProvider {
  HeatPumpProvider({
    required this.id,
    required this.brand,
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.keywords,
    this.kind = ProviderKind.local,
    this.credFields = const [],
    this.addressHelpFi = '',
    this.addressHelpEn = '',
    this.settings = const {},
    this.mdnsTypes = const [],
    this.untested = true,
    this.documented = true,
  });

  @override
  final String id;
  final String brand;
  @override
  final String fi, en, descFi, descEn;
  @override
  final List<String> keywords;
  @override
  final ProviderKind kind;
  @override
  final List<CredField> credFields;
  @override
  final String addressHelpFi, addressHelpEn;
  @override
  final List<String> mdnsTypes;

  /// Fixed connection settings (Modbus register map…).
  final Map<String, dynamic> settings;

  /// Not tried on a real unit yet (shown in the brand list).
  final bool untested;

  /// Register map / API from the manufacturer's documentation (false = community sources, verify).
  final bool documented;

  @override
  String get category => 'climate';
  @override
  PairMode get pairMode => kind == ProviderKind.cloud ? PairMode.cloudKey : PairMode.none;

  static const _secretKeys = {'password', 'token', 'key', 'clientSecret'};

  @override
  Candidate? fromMdns(String address, String label, String service) =>
      Candidate(provider: id, address: address, id: label, name: label.isEmpty ? fi : label);

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (brand != 'daikin' || locals.isEmpty) return const [];
    try {
      final found = await discoverDaikin();
      return [for (final (a, n, mac) in found) Candidate(provider: id, address: a, id: mac, name: n, model: 'Daikin')];
    } catch (_) {
      return const [];
    }
  }

  ConnectionConfig _conn(Candidate c, Map<String, String> creds) {
    final set = <String, dynamic>{'brand': brand, ...settings};
    final sec = <String, String>{};
    if (kind == ProviderKind.local) set['address'] = c.address.trim();
    for (final e in creds.entries) {
      if (e.value.trim().isEmpty || e.key == 'server') continue;
      if (_secretKeys.contains(e.key)) {
        sec[e.key] = e.value.trim();
      } else {
        set[e.key] = e.value.trim();
      }
    }
    if (brand == 'mhi') {
      set['operatorId'] ??= mhiNewId(16);
      set['deviceId'] ??= mhiNewId(8);
      set['timezone'] ??= 'UTC';
    }
    if (brand == 'daikin' && (sec['key'] ?? '').isNotEmpty) {
      set['uuid'] ??= mhiNewId(16);
      set['variant'] = 'brp072c';
    }
    if (brand == 'toshiba') set['clientId'] ??= mhiNewId(8);
    return ConnectionConfig(name: fi.split(' (').first, type: 'heatpump', settings: set, secrets: sec);
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (kind == ProviderKind.cloud) {
      for (final f in credFields.where((f) => !f.optional)) {
        if ((creds[f.key] ?? '').trim().isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'missing ${f.key}');
      }
    }
    final conn = _conn(c, creds);
    final d = ctx.driver(conn);
    try {
      List units;
      try {
        final v = await d.read({'hp': 'units'});
        units = v is List ? v : const [];
      } catch (e) {
        final s = e.toString();
        if (e is HpAuthError || s.contains('HTTP 401') || s.contains('HTTP 403')) {
          if (kind == ProviderKind.cloud) throw AddDeviceError(AddProblem.cloudBadKey, s);
          // Daikin BRP072C: needs the key from the sticker.
          if (brand == 'daikin' && (creds['key'] ?? '').isEmpty) throw AddDeviceError(AddProblem.needsDetails, s);
          throw AddDeviceError(AddProblem.wrongPassword, s);
        }
        if (s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        if (brand == 'daikin' && s.contains('No Daikin adapter') && (creds['key'] ?? '').isEmpty) {
          throw AddDeviceError(AddProblem.notThisBrand, s);
        }
        throw explain(e);
      }
      if (units.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'units');
      final us = [for (final u in units) HpUnit.fromJson(u as Map)];
      final states = <String, HpState>{};
      for (final u in us) {
        try {
          final raw = await d.read({'hp': 'state', 'unit': u.id, if (u.meta.isNotEmpty) 'meta': u.meta});
          states[u.id] = stateFromJson(raw is Map ? raw : const {});
        } catch (_) {
          states[u.id] = HpState();
        }
      }
      final items = <AddItem>[];
      for (final u in us) {
        final st = states[u.id]!;
        items.add(
          AddItem(
            key: u.id,
            name: u.name,
            kind: 'climate',
            subtitle: [
              if (u.model.isNotEmpty) u.model,
              if (st.current != null) '${st.current} °C',
            ].join(' · '),
          ),
        );
        items.add(
          AddItem(
            key: '${u.id}#extra',
            name: u.name,
            kind: 'sensor',
            preselect: false,
            group: tr(ctx.lang, 'Lisäruudut automaatioihin', 'Extra tiles for automations'),
          ),
        );
      }
      return Connected(
        connection: conn,
        label: fi,
        items: items,
        data: {'units': us, 'states': states},
      );
    } finally {
      await d.dispose();
    }
  }

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final us = (r.data['units'] as List).cast<HpUnit>();
    final states = (r.data['states'] as Map).cast<String, HpState>();
    final out = <TileConfig>[];
    for (final u in us) {
      final st = states[u.id] ?? HpState();
      final title = (names[u.id]?.trim().isNotEmpty ?? false) ? names[u.id]!.trim() : u.name;
      if (!skip.contains(u.id)) out.addAll(heatPumpTiles(r.connection.id, u, st, title: title, lang: lang));
      final ek = '${u.id}#extra';
      if (!skip.contains(ek)) {
        final t2 = (names[ek]?.trim().isNotEmpty ?? false) ? names[ek]!.trim() : u.name;
        out.addAll(heatPumpTiles(r.connection.id, u, st, title: t2, lang: lang, extras: true).skip(1));
      }
    }
    return out;
  }
}


HpState stateFromJson(Map m) {
  double? d(Object? v) => hpNum(v);
  return HpState(
    power: m['power'] is bool ? m['power'] as bool : null,
    mode: '${m['rawMode'] ?? m['mode'] ?? ''}',
    target: d(m['target']),
    current: d(m['current']),
    outdoor: d(m['outdoor']),
    humidity: d(m['humidity']),
    fan: '${m['fan'] ?? ''}',
    modes: [for (final x in (m['modes'] as List? ?? const [])) '$x'],
    fans: [for (final x in (m['fans'] as List? ?? const [])) '$x'],
    minTarget: d(m['min']) ?? 16,
    maxTarget: d(m['max']) ?? 31,
    step: d(m['step']) ?? 0.5,
    targetKind: '${m['targetKind'] ?? 'temp'}',
    action: '${m['action'] ?? ''}',
    extra: {
      for (final e in ((m['extra'] as Map?) ?? const {}).entries)
        if (hpNum(e.value) != null) '${e.key}': hpNum(e.value)!,
    },
    online: m['online'] != false,
  );
}

const _ipFi = 'Löytyy reitittimen laitelistasta tai valmistajan sovelluksesta (laitteen tiedot).';
const _ipEn = 'Find it in your router\'s device list or the maker\'s app (device info).';

final heatPumpProviders = <HeatPumpProvider>[
  HeatPumpProvider(
    id: 'hp_daikin',
    brand: 'daikin',
    fi: 'Daikin (wifi, paikallinen)',
    en: 'Daikin (Wi-Fi, local)',
    descFi: 'Daikin-ilmalämpöpumppu wifi-ohjaimella (BRP069, BRP072C, Airbase). Toimii ilman pilveä, haetaan verkosta.',
    descEn: 'Daikin with a Wi-Fi adapter (BRP069, BRP072C, Airbase). Works without the cloud; found on the network.',
    keywords: const ['daikin', 'brp069', 'brp072', 'airbase', 'ilmalämpöpumppu', 'heat pump', 'ac'],
    addressHelpFi: _ipFi,
    addressHelpEn: _ipEn,
    credFields: const [
      CredField(
        'key',
        'Avain (key) – vain BRP072C',
        'Key – BRP072C only',
        secret: true,
        optional: true,
        hint: '1234567890123',
        helpFi: 'Uudemmissa BRP072C-ohjaimissa 13-numeroinen avain on ohjaimen tarrassa. Vanhemmat eivät tarvitse sitä.',
        helpEn: 'Newer BRP072C adapters: the 13-digit key is on the adapter sticker. Older ones need none.',
      ),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_mhi',
    brand: 'mhi',
    fi: 'Mitsubishi Heavy (Smart M-Air, paikallinen)',
    en: 'Mitsubishi Heavy (Smart M-Air, local)',
    descFi: 'MHI-ilmalämpöpumppu WF-RAC-wifimoduulilla (Smart M-Air -sovellus). Paikallinen ohjaus ilman pilveä.',
    descEn: 'MHI heat pump with the WF-RAC Wi-Fi module (Smart M-Air app). Local control, no cloud.',
    keywords: const ['mitsubishi heavy', 'mhi', 'smart m-air', 'wf-rac', 'srk', 'ilmalämpöpumppu'],
    mdnsTypes: const ['_beaver._tcp'],
    addressHelpFi: _ipFi,
    addressHelpEn: _ipEn,
  ),
  HeatPumpProvider(
    id: 'hp_melcloud',
    brand: 'melcloud',
    kind: ProviderKind.cloud,
    fi: 'Mitsubishi Electric (MELCloud)',
    en: 'Mitsubishi Electric (MELCloud)',
    descFi: 'Ilmalämpöpumput ja Ecodan-ilma-vesipumput MELCloud-tilin kautta, mistä tahansa.',
    descEn: 'Air-to-air and Ecodan air-to-water pumps through your MELCloud account, from anywhere.',
    keywords: const ['mitsubishi electric', 'melcloud', 'ecodan', 'mitsubishi', 'ilmalämpöpumppu'],
    credFields: const [
      CredField('email', 'MELCloud-sähköposti', 'MELCloud e-mail', helpFi: 'Sama kuin MELCloud-sovelluksessa.', helpEn: 'Same as in the MELCloud app.'),
      CredField('password', 'MELCloud-salasana', 'MELCloud password', secret: true, helpFi: 'Tallentuu vain tähän laitteeseen salattuna.', helpEn: 'Stored encrypted on this device only.'),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_toshiba',
    brand: 'toshiba',
    kind: ProviderKind.cloud,
    fi: 'Toshiba (Home AC Control)',
    en: 'Toshiba (Home AC Control)',
    descFi: 'Toshiban wifi-ilmalämpöpumput Toshiba Home AC Control -tilin kautta.',
    descEn: 'Toshiba Wi-Fi heat pumps through your Toshiba Home AC Control account.',
    keywords: const ['toshiba', 'home ac control', 'ilmalämpöpumppu'],
    credFields: const [
      CredField('username', 'Toshiba-käyttäjätunnus', 'Toshiba username', helpFi: 'Sama kuin Toshiba Home AC Control -sovelluksessa.', helpEn: 'Same as in the Toshiba app.'),
      CredField('password', 'Salasana', 'Password', secret: true),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_smartthings',
    brand: 'smartthings',
    kind: ProviderKind.cloud,
    fi: 'Samsung (SmartThings)',
    en: 'Samsung (SmartThings)',
    descFi: 'Samsungin wifi-ilmalämpöpumput SmartThingsin virallisen rajapinnan kautta.',
    descEn: 'Samsung Wi-Fi heat pumps through the official SmartThings API.',
    keywords: const ['samsung', 'smartthings', 'windfree', 'ilmalämpöpumppu'],
    credFields: const [
      CredField(
        'token',
        'SmartThings-tunnus (token)',
        'SmartThings token',
        secret: true,
        helpFi: 'Luo osoitteessa account.smartthings.com/tokens: valitse "Devices" (lue ja ohjaa). Huom: Samsung rajoittaa uudet tunnukset 24 tuntiin.',
        helpEn: 'Create one at account.smartthings.com/tokens with the Devices scopes. Note: Samsung limits new tokens to 24 hours.',
      ),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_aircloud',
    brand: 'aircloud',
    kind: ProviderKind.cloud,
    fi: 'Hitachi (airCloud Go)',
    en: 'Hitachi (airCloud Go)',
    descFi: 'Hitachin ilmalämpöpumput airCloud Go -tilin kautta.',
    descEn: 'Hitachi heat pumps through your airCloud Go account.',
    keywords: const ['hitachi', 'aircloud', 'aircloud go', 'ilmalämpöpumppu'],
    documented: false,
    credFields: const [
      CredField('email', 'airCloud-sähköposti', 'airCloud e-mail'),
      CredField('password', 'Salasana', 'Password', secret: true),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_myuplink',
    brand: 'myuplink',
    kind: ProviderKind.cloud,
    fi: 'NIBE (myUplink-pilvi)',
    en: 'NIBE (myUplink cloud)',
    descFi: 'NIBE-maalämpö- ja poistoilmapumput myUplinkin virallisen rajapinnan kautta (myös CTC, Høiax…).',
    descEn: 'NIBE ground-source and exhaust-air pumps through the official myUplink API (also CTC, Høiax…).',
    keywords: const ['nibe', 'myuplink', 'uplink', 'maalämpö', 'ctc', 'poistoilma'],
    credFields: const [
      CredField(
        'clientId',
        'Client ID',
        'Client ID',
        helpFi: 'Kirjaudu dev.myuplink.com → Applications → Create (Callback URL voi olla esim. https://molaplan.com). Kopioi Client Identifier.',
        helpEn: 'Sign in at dev.myuplink.com → Applications → Create. Copy the Client Identifier.',
      ),
      CredField('clientSecret', 'Client Secret', 'Client Secret', secret: true, helpFi: 'Samalta sivulta.', helpEn: 'From the same page.'),
    ],
  ),
  HeatPumpProvider(
    id: 'hp_nibe_s',
    brand: 'gshp_modbus',
    settings: const {'profile': 'nibe_s'},
    fi: 'NIBE S-sarja (Modbus TCP, paikallinen)',
    en: 'NIBE S-series (Modbus TCP, local)',
    descFi: 'S1155, S1255, SMO S40… Ota Modbus TCP käyttöön pumpun valikosta 7.5.9. Ei pilveä.',
    descEn: 'S1155, S1255, SMO S40… Enable Modbus TCP in the pump menu 7.5.9. No cloud.',
    keywords: const ['nibe', 's1155', 's1255', 'modbus', 'maalämpö'],
    addressHelpFi: 'Pumpun IP-osoite: valikko 3.1.13 (Yhteydet) tai reitittimen laitelista.',
    addressHelpEn: 'The pump\'s IP: menu 3.1.13 (Connections) or your router\'s device list.',
  ),
  HeatPumpProvider(
    id: 'hp_nibe_f',
    brand: 'gshp_modbus',
    settings: const {'profile': 'nibe_f'},
    documented: false,
    fi: 'NIBE F-sarja + MODBUS 40 (paikallinen)',
    en: 'NIBE F-series + MODBUS 40 (local)',
    descFi: 'F1145/F1155/F1255/F750/SMO + MODBUS 40 -lisävaruste ja RS485→TCP-muunnin. Tarkista rekisterit.',
    descEn: 'F-series / SMO with the MODBUS 40 accessory and an RS485→TCP gateway. Verify the registers.',
    keywords: const ['nibe', 'f1145', 'f1155', 'f1255', 'f750', 'modbus 40', 'maalämpö'],
    addressHelpFi: 'RS485→Modbus TCP -muuntimen IP-osoite.',
    addressHelpEn: 'IP address of the RS485→Modbus TCP gateway.',
  ),
  HeatPumpProvider(
    id: 'hp_thermia',
    brand: 'gshp_modbus',
    settings: const {'profile': 'thermia_genesis'},
    fi: 'Thermia (Modbus TCP, paikallinen)',
    en: 'Thermia (Modbus TCP, local)',
    descFi: 'Thermia Atlas, Calibra, Diplomat Inverter, Mega (Genesis). Modbus TCP: Asetukset → BMS.',
    descEn: 'Thermia Atlas, Calibra, Diplomat Inverter, Mega (Genesis). Modbus TCP: Settings → BMS.',
    keywords: const ['thermia', 'calibra', 'atlas', 'diplomat', 'mega', 'genesis', 'modbus', 'maalämpö'],
    addressHelpFi: 'Pumpun IP-osoite (näytöltä tai reitittimestä).',
    addressHelpEn: 'The pump\'s IP address (display or router).',
  ),
];

/// One gallery card for all heat pumps; picking it opens the brand list.
class HeatPumpChooser extends DeviceProvider {
  @override
  String get id => 'heatpump';
  @override
  String get fi => 'Lämpöpumppu';
  @override
  String get en => 'Heat pump';
  @override
  String get descFi => 'Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia – tai mikä tahansa IR-kaukosäätimellä.';
  @override
  String get descEn => 'Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia – or any with an IR remote.';
  @override
  String get category => 'climate';
  @override
  List<String> get keywords => [
    'lämpöpumppu',
    'ilmalämpöpumppu',
    'maalämpö',
    'heat pump',
    'ilp',
    'mlp',
    for (final p in heatPumpProviders) ...p.keywords,
  ];
  @override
  PairMode get pairMode => PairMode.none;
  @override
  String get addressHelpFi => '';
  @override
  String get addressHelpEn => '';
  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) =>
      throw UnsupportedError('pick a brand first');
  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) => const [];
}

/// Not built (yet) – shown in the brand list with the reason and what works today.
class HpNotYet {
  const HpNotYet(this.name, this.fi, this.en, {this.template});
  final String name, fi, en;
  final String? template;
}

const heatPumpNotYet = <HpNotYet>[
  HpNotYet(
    'Panasonic (Comfort Cloud), LG (ThinQ), Gree, Midea, Fujitsu…',
    'Ei omaa integraatiota vielä. Toimii nyt IR-ohjaimella (Tasmota/ESPHome) tai Home Assistantin kautta.',
    'No built-in integration yet. Works today with an IR blaster (Tasmota/ESPHome) or via Home Assistant.',
    template: 'heatpump_ir',
  ),
  HpNotYet(
    'Daikin Onecta (uusi pilvi / BRP069C4x ≥ 2.8)',
    'Onecta-pilvi vaatii Daikinin kehittäjäsopimuksen. Uusimmat ohjaimet eivät enää vastaa paikalliseen rajapintaan – käytä IR-ohjainta.',
    'The Onecta cloud needs a Daikin developer agreement. The newest adapters no longer answer the local API – use IR.',
    template: 'heatpump_ir',
  ),
  HpNotYet(
    'Thermia Online (pilvi)',
    'Epävirallinen ja usein muuttuva kirjautuminen (Azure B2C) – ei vielä. Genesis-pumput toimivat paikallisesti Modbusilla.',
    'Unofficial, frequently changing login (Azure B2C) – not yet. Genesis pumps work locally over Modbus.',
  ),
  HpNotYet(
    'Hitachi Yutaki (ilma-vesi)',
    'Vaatii Modbus-yhdyskäytävän (ATW-MBS-02) – tulossa myöhemmin. Nyt: Modbus-laite omilla rekistereillä.',
    'Needs the Modbus gateway (ATW-MBS-02) – later. Today: a Modbus device with your own registers.',
    template: 'modbus_iv',
  ),
  HpNotYet(
    'Mitsubishi Heavy (pilvi), Samsung (paikallinen)',
    'MHI toimii paikallisesti (Smart M-Air). Samsungin paikallinen rajapinta vaatii laitekohtaisen varmenteen – käytä SmartThingsiä.',
    'MHI works locally (Smart M-Air). Samsung\'s local API needs a per-device certificate – use SmartThings.',
  ),
];

/// Used by tests: a provider by id.
HeatPumpProvider? heatPumpProviderById(String id) => heatPumpProviders.where((p) => p.id == id).firstOrNull;

