/// R288: solar inverters in the add-device wizard. One gallery card "Aurinkosähkö" ([SolarChooser])
/// opens a brand list; each brand is a normal [DeviceProvider]: type the inverter / dongle address
/// (or log in to the optional cloud) → the readings the device reports → one tile per reading
/// (the main ones ticked, the rest offered for automations).
library;

import '../devices/provider.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'energy_model.dart';
import 'http_inverters.dart';

class SolarProvider extends DeviceProvider {
  SolarProvider({
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

  /// Registers / API from the manufacturer's public documentation (false = verify on your model).
  final bool documented;

  @override
  String get category => 'solar';
  @override
  PairMode get pairMode => kind == ProviderKind.cloud ? PairMode.cloudKey : PairMode.none;

  static const _secretKeys = {'password', 'apiKey'};

  /// SMA Energy Meter: no address – listen for its multicast for a few seconds.
  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (brand != 'sma_em' || locals.isEmpty) return const [];
    try {
      final i = await SmaEnergyMeterBackend(const {}).read();
      return [Candidate(provider: id, address: SmaEnergyMeterBackend.group, id: i.serial, name: i.name, model: 'SMA')];
    } catch (_) {
      return const [];
    }
  }

  ConnectionConfig connectionFor(Candidate c, Map<String, String> creds) {
    final set = <String, dynamic>{'brand': brand};
    final sec = <String, String>{};
    if (kind == ProviderKind.local) set['address'] = c.address.trim();
    if (brand == 'sma_em' && c.id.isNotEmpty) set['serial'] = c.id;
    for (final e in creds.entries) {
      if (e.value.trim().isEmpty) continue;
      if (_secretKeys.contains(e.key)) {
        sec[e.key] = e.value.trim();
      } else {
        set[e.key] = e.value.trim();
      }
    }
    return ConnectionConfig(name: fi.split(' (').first, type: 'solar', settings: set, secrets: sec);
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (kind == ProviderKind.cloud) {
      for (final f in credFields.where((f) => !f.optional)) {
        if ((creds[f.key] ?? '').trim().isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'missing ${f.key}');
      }
    }
    final conn = connectionFor(c, creds);
    final d = ctx.driver(conn);
    try {
      EnergyInfo info;
      try {
        final raw = await d.read({'pv': 'info'});
        info = EnergyInfo.fromJson(raw is Map ? raw : const {});
      } catch (e) {
        final s = e.toString();
        if (e is EnergyAuthError || s.contains('HTTP 401') || s.contains('HTTP 403') || s.contains('login failed')) {
          throw AddDeviceError(kind == ProviderKind.cloud ? AddProblem.cloudBadKey : AddProblem.wrongPassword, s);
        }
        if (s.contains('429') || s.contains('rate limit')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        if (s.contains('no inverter') || s.contains('SunS') || s.contains('no Site data')) {
          throw AddDeviceError(AddProblem.notThisBrand, s);
        }
        throw explain(e);
      }
      final keys = [
        for (final k in energyKeys)
          if (info.values[k.$1] != null) k.$1,
      ];
      if (keys.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'no readings');
      final name = info.name.isEmpty ? fi.split(' (').first : info.name;
      final items = [
        for (final k in keys)
          AddItem(
            key: k,
            name: energyTitle(k, name, ctx.lang),
            kind: 'sensor',
            subtitle: _fmt(info.values[k], energyKey(k)!),
            preselect: energyKey(k)!.$7,
            group: energyKey(k)!.$7
                ? tr(ctx.lang, 'Päälukemat', 'Main readings')
                : tr(ctx.lang, 'Lisäruudut automaatioihin', 'Extra tiles for automations'),
          ),
      ];
      return Connected(connection: conn, label: name, items: items, data: {'info': info});
    } finally {
      await d.dispose();
    }
  }

  static String _fmt(num? v, (String, String, String, String, int, String, bool) k) =>
      v == null ? '' : '${v.toStringAsFixed(k.$5)} ${k.$4}';

  @override
  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  }) {
    final info = r.data['info'] as EnergyInfo;
    final name = info.name.isEmpty ? fi.split(' (').first : info.name;
    return [
      for (final k in energyKeys)
        if (info.values[k.$1] != null && !skip.contains(k.$1))
          energyTile(
            r.connection.id,
            k.$1,
            (names[k.$1]?.trim().isNotEmpty ?? false) ? names[k.$1]!.trim() : energyTitle(k.$1, name, lang),
            cloud: kind == ProviderKind.cloud,
          ),
    ];
  }
}

const _ipFi =
    'Löytyy reitittimen laitelistasta tai valmistajan sovelluksesta (laitteen tiedot). Varaa laitteelle kiinteä IP.';
const _ipEn = 'Find it in your router\'s device list or the maker\'s app (device info). Reserve a fixed IP for it.';

const _siteId = CredField(
  'siteId',
  'Laitoksen tunnus (valinnainen)',
  'Site id (optional)',
  optional: true,
  helpFi: 'Tyhjä = tilin ensimmäinen laitos.',
  helpEn: 'Empty = the first site of the account.',
);

final solarProviders = <SolarProvider>[
  SolarProvider(
    id: 'solar_huawei',
    brand: 'huawei',
    fi: 'Huawei SUN2000 (Modbus TCP, paikallinen)',
    en: 'Huawei SUN2000 (Modbus TCP, local)',
    descFi: 'SUN2000-invertteri (myös LUNA2000-akku ja DTSU666-mittari) SDonglen kautta kotiverkossa, ilman pilveä.',
    descEn: 'SUN2000 inverter (incl. LUNA2000 battery and DTSU666 meter) via the SDongle on your network, no cloud.',
    keywords: const ['huawei', 'sun2000', 'sdongle', 'luna2000', 'invertteri', 'inverter', 'aurinkopaneeli', 'solar'],
    addressHelpFi: 'SDonglen IP-osoite. Ota ensin käyttöön FusionSolar-sovelluksessa: Laitekäyttöönotto → Dongle → Modbus TCP = "Ota käyttöön (rajoittamaton)". Ilman donglea: invertterin oma wifi, osoite muodossa 192.168.200.1:6607.',
    addressHelpEn: 'The SDongle IP address. First enable it in the FusionSolar app: Device commissioning → Dongle → Modbus TCP = "Enable (unrestricted)". Without a dongle: the inverter\'s own Wi-Fi, address like 192.168.200.1:6607.',
  ),
  SolarProvider(
    id: 'solar_fusionsolar',
    brand: 'fusionsolar',
    kind: ProviderKind.cloud,
    fi: 'Huawei FusionSolar (pilvi)',
    en: 'Huawei FusionSolar (cloud)',
    descFi: 'Valinnainen: tuotanto FusionSolarin virallisen Northbound-rajapinnan kautta. Päivittyy noin 5 min välein.',
    descEn: 'Optional: production through the official FusionSolar Northbound API. Updates about every 5 minutes.',
    keywords: const ['huawei', 'fusionsolar', 'sun2000', 'aurinkopaneeli', 'solar'],
    credFields: const [
      CredField(
        'username',
        'API-käyttäjä',
        'API user',
        helpFi: 'Northbound-API-käyttäjä (ei sovelluksen tavallinen tunnus). Asentaja tai pääkäyttäjä luo sen: Järjestelmä → Yritys → Northbound-hallinta.',
        helpEn: 'A Northbound API user (not your normal app login). The installer / admin creates it: System → Company → Northbound management.',
      ),
      CredField(
        'password',
        'Järjestelmäkoodi (salasana)',
        'System code (password)',
        secret: true,
        helpFi: 'Tallentuu vain tähän laitteeseen salattuna.',
        helpEn: 'Stored encrypted on this device only.',
      ),
      CredField(
        'address',
        'Palvelin (valinnainen)',
        'Server (optional)',
        optional: true,
        hint: 'eu5.fusionsolar.huawei.com',
        helpFi: 'Selaimen osoiterivin palvelin kun kirjaudut FusionSolariin. Oletus eu5.',
        helpEn: 'The host in your browser address bar when signed in to FusionSolar. Default eu5.',
      ),
    ],
  ),
  SolarProvider(
    id: 'solar_fronius',
    brand: 'fronius',
    fi: 'Fronius (Solar API, paikallinen)',
    en: 'Fronius (Solar API, local)',
    descFi: 'Symo, Primo, Gen24, Tauro – myös Smart Meter ja akku. Valmistajan avoin paikallinen rajapinta, ei pilveä.',
    descEn: 'Symo, Primo, Gen24, Tauro – incl. Smart Meter and battery. The maker\'s open local API, no cloud.',
    keywords: const [
      'fronius',
      'symo',
      'primo',
      'gen24',
      'tauro',
      'datamanager',
      'invertteri',
      'aurinkopaneeli',
      'solar',
    ],
    addressHelpFi: '$_ipFi Gen24: ota Solar API käyttöön invertterin web-sivulta (Viestintä → Solar API).',
    addressHelpEn: '$_ipEn Gen24: enable the Solar API on the inverter web page (Communication → Solar API).',
  ),
  SolarProvider(
    id: 'solar_solaredge',
    brand: 'solaredge',
    fi: 'SolarEdge (Modbus TCP, paikallinen)',
    en: 'SolarEdge (Modbus TCP, local)',
    descFi: 'SolarEdge-invertteri, mittari ja akku SunSpec Modbusilla kotiverkossa (portti 1502).',
    descEn: 'SolarEdge inverter, meter and battery over SunSpec Modbus on your network (port 1502).',
    keywords: const ['solaredge', 'sunspec', 'invertteri', 'inverter', 'aurinkopaneeli', 'solar'],
    addressHelpFi: '$_ipFi Ota Modbus TCP käyttöön SetApp-sovelluksella: Käyttöönotto → Tiedonsiirto → Modbus TCP.',
    addressHelpEn: '$_ipEn Enable Modbus TCP with the SetApp: Commissioning → Communication → Modbus TCP.',
  ),
  SolarProvider(
    id: 'solar_solaredge_cloud',
    brand: 'solaredge_cloud',
    kind: ProviderKind.cloud,
    fi: 'SolarEdge monitoring (pilvi)',
    en: 'SolarEdge monitoring (cloud)',
    descFi:
        'Valinnainen: tuotanto ja energiavirrat SolarEdgen virallisen monitoring-rajapinnan kautta (päivittyy ~5 min).',
    descEn: 'Optional: production and power flow through the official SolarEdge monitoring API (updates ~5 min).',
    keywords: const ['solaredge', 'monitoring', 'aurinkopaneeli', 'solar'],
    credFields: const [
      CredField(
        'apiKey',
        'API-avain',
        'API key',
        secret: true,
        helpFi: 'monitoring.solaredge.com → Admin → Site Access → API Access: hyväksy ehdot ja kopioi avain.',
        helpEn: 'monitoring.solaredge.com → Admin → Site Access → API Access: accept the terms and copy the key.',
      ),
      _siteId,
    ],
  ),
  SolarProvider(
    id: 'solar_sma',
    brand: 'sma',
    fi: 'SMA (Modbus TCP, paikallinen)',
    en: 'SMA (Modbus TCP, local)',
    descFi: 'Sunny Boy, Sunny Tripower, Sunny Boy Storage – SMA:n Modbus-rekisterit kotiverkossa (unit id 3).',
    descEn: 'Sunny Boy, Sunny Tripower, Sunny Boy Storage – SMA Modbus registers on your network (unit id 3).',
    keywords: const ['sma', 'sunny boy', 'tripower', 'sunny island', 'invertteri', 'aurinkopaneeli', 'solar'],
    addressHelpFi:
        '$_ipFi Ota Modbus käyttöön invertterin web-sivulta: Laitteen parametrit → Ulkoinen tiedonsiirto → Modbus TCP-palvelin.',
    addressHelpEn:
        '$_ipEn Enable Modbus on the inverter web page: Device parameters → External communication → Modbus TCP server.',
  ),
  SolarProvider(
    id: 'solar_sma_em',
    brand: 'sma_em',
    fi: 'SMA Energy Meter / Home Manager (Speedwire, paikallinen)',
    en: 'SMA Energy Meter / Home Manager (Speedwire, local)',
    descFi: 'Verkosta osto ja myynti suoraan mittarin Speedwire-lähetyksistä – ei kirjautumista eikä pilveä.',
    descEn: 'Grid import and export straight from the meter\'s Speedwire broadcasts – no login, no cloud.',
    keywords: const ['sma', 'energy meter', 'home manager', 'speedwire', 'emeter', 'sähkömittari'],
    addressHelpFi: 'Mittari löytyy automaattisesti samasta kotiverkosta. Jos haku ei löydä sitä, kirjoita mittarin IP-osoite (luku tulee silti lähetyksistä).',
    addressHelpEn: 'The meter is found automatically on the same home network. If the search misses it, type the meter IP (readings still come from its broadcasts).',
  ),
  SolarProvider(
    id: 'solar_growatt',
    brand: 'growatt',
    documented: false,
    fi: 'Growatt (Modbus TCP, paikallinen)',
    en: 'Growatt (Modbus TCP, local)',
    descFi: 'MIN/MOD/SPH-invertterit RS485→TCP-muuntimen (tai Modbus TCP:tä tukevan ShineLan-X:n) kautta. Tarkista lukemat.',
    descEn: 'MIN/MOD/SPH inverters via an RS485→TCP gateway (or a ShineLan-X with Modbus TCP). Verify the readings.',
    keywords: const ['growatt', 'shinelan', 'shinewifi', 'sph', 'min', 'mod', 'invertteri', 'aurinkopaneeli', 'solar'],
    addressHelpFi: 'RS485→Modbus TCP -muuntimen IP-osoite (esim. Elfin EW11, Waveshare). Kytketään invertterin RS485/COM-liittimeen.',
    addressHelpEn:
        'IP of the RS485→Modbus TCP gateway (e.g. Elfin EW11, Waveshare) wired to the inverter RS485/COM port.',
  ),
  SolarProvider(
    id: 'solar_growatt_cloud',
    brand: 'growatt_cloud',
    kind: ProviderKind.cloud,
    fi: 'Growatt OpenAPI (pilvi)',
    en: 'Growatt OpenAPI (cloud)',
    descFi: 'Valinnainen: tuotanto Growattin OpenAPI:n kautta (ShinePhone/ShineServer-tili). Päivittyy ~5 min.',
    descEn: 'Optional: production through the Growatt OpenAPI (ShinePhone/ShineServer account). Updates ~5 min.',
    keywords: const ['growatt', 'shinephone', 'shineserver', 'openapi', 'aurinkopaneeli', 'solar'],
    credFields: const [
      CredField(
        'apiKey',
        'API-token',
        'API token',
        secret: true,
        helpFi: 'Pyydä token Growattin tuesta tai asentajalta (OpenAPI), tai ShineServerin asetuksista jos se näkyy.',
        helpEn:
            'Ask Growatt support or your installer for an OpenAPI token, or find it in ShineServer settings if shown.',
      ),
      _siteId,
    ],
  ),
  SolarProvider(
    id: 'solar_sunspec',
    brand: 'sunspec',
    fi: 'Muu SunSpec-invertteri (Modbus TCP)',
    en: 'Other SunSpec inverter (Modbus TCP)',
    descFi: 'Kostal, Fronius (Modbus), SMA (SunSpec), ABB/FIMER, Sungrow-mittarit… Mikä tahansa SunSpec-laite.',
    descEn: 'Kostal, Fronius (Modbus), SMA (SunSpec), ABB/FIMER… Any SunSpec device.',
    keywords: const ['sunspec', 'kostal', 'fimer', 'abb', 'modbus', 'invertteri', 'inverter', 'solar'],
    addressHelpFi: '$_ipFi Portti oletuksena 502 – muu portti muodossa 192.168.1.20:1502.',
    addressHelpEn: '$_ipEn Port 502 by default – another port like 192.168.1.20:1502.',
  ),
];

/// One gallery card for all solar inverters; picking it opens the brand list.
class SolarChooser extends DeviceProvider {
  @override
  String get id => 'solar';
  @override
  String get fi => 'Aurinkosähkö';
  @override
  String get en => 'Solar power';
  @override
  String get descFi =>
      'Huawei, Fronius, SolarEdge, SMA, Growatt – tuotanto, verkko ja akku. Paikallisesti, pilvi valinnainen.';
  @override
  String get descEn =>
      'Huawei, Fronius, SolarEdge, SMA, Growatt – production, grid and battery. Local, cloud optional.';
  @override
  String get category => 'solar';
  @override
  List<String> get keywords => [
    'aurinkosähkö',
    'aurinkopaneeli',
    'invertteri',
    'solar',
    'inverter',
    'pv',
    for (final p in solarProviders) ...p.keywords,
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

/// Not built (yet) – shown in the brand list with the reason.
const solarNotYet = <(String, String, String)>[
  (
    'SMA Sunny Portal (pilvi)',
    'Vaatii SMA:n kehittäjärekisteröinnin (OAuth). Käytä paikallista Modbusia tai Energy Meteriä – ne ovat nopeampia.',
    'Needs SMA developer registration (OAuth). Use local Modbus or the Energy Meter – they are faster.',
  ),
  (
    'Sungrow, GoodWe, Solis, Victron…',
    'Ei omaa integraatiota vielä. Toimii nyt Modbus-laitteena omilla rekistereillä tai Home Assistantin kautta.',
    'No built-in integration yet. Works today as a Modbus device with your own registers or via Home Assistant.',
  ),
];

SolarProvider? solarProviderById(String id) => solarProviders.where((p) => p.id == id).firstOrNull;
