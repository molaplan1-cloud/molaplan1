/// R289: EV chargers in the add-device wizard. One gallery card "Sähköauton laturi"
/// ([ChargerChooser]) opens a brand list: local OCPP 1.6J (any brand) first, then the optional
/// Easee / Zaptec / Wallbox clouds. Each charger gets status, start/stop, power, session energy and a
/// current limit slider.
library;

import '../devices/provider.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import 'ev_driver.dart';
import 'ev_model.dart';
import 'ocpp_server.dart';

class EvChargerProvider extends DeviceProvider {
  EvChargerProvider({
    required this.id,
    required this.brand,
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.keywords,
    this.kind = ProviderKind.cloud,
    this.credFields = const [],
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
  final bool documented;

  /// This device's LAN address (for the OCPP URL in the help text), learnt from the scan.
  static String? myIp;

  @override
  String get addressHelpFi => brand == 'ocpp'
      ? 'Aseta laturin asennussovelluksessa OCPP-osoitteeksi (backend / central system URL) ws://${myIp ?? '<tämän laitteen IP>'}:9000/ocpp/ – laturi ilmestyy listaan, kun se ottaa yhteyden. Voit myös kirjoittaa laturin IP-osoitteen. Pidä Molaplan auki tai käytä kotisiltaa (aina päällä oleva PC).'
      : '';
  @override
  String get addressHelpEn => brand == 'ocpp'
      ? 'In the charger\'s installer app set the OCPP backend / central system URL to ws://${myIp ?? '<this device IP>'}:9000/ocpp/ – the charger appears in the list once it connects. You can also type the charger\'s IP. Keep Molaplan open or use the home bridge (an always-on PC).'
      : '';

  @override
  String get category => 'ev';
  @override
  PairMode get pairMode => kind == ProviderKind.cloud ? PairMode.cloudKey : PairMode.none;

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (brand != 'ocpp' || locals.isEmpty) return const [];
    myIp = locals.first;
    try {
      final srv = await OcppServer.start();
      if (srv.points.isEmpty) {
        try {
          await srv.changes.first.timeout(const Duration(seconds: 4));
        } catch (_) {}
      }
      return [
        for (final p in srv.points.values)
          Candidate(
            provider: id,
            address: p.remote,
            id: p.id,
            name: [p.vendor, p.model].where((x) => x.isNotEmpty).join(' ').trim().isEmpty
                ? p.id
                : '${p.vendor} ${p.model}'.trim(),
            model: 'OCPP',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  ConnectionConfig connectionFor(Candidate c, Map<String, String> creds) {
    final set = <String, dynamic>{'brand': brand};
    final sec = <String, String>{};
    if (brand == 'ocpp' && c.id.isNotEmpty) set['chargePointId'] = c.id;
    for (final e in creds.entries) {
      if (e.value.trim().isEmpty) continue;
      if (e.key == 'password') {
        sec[e.key] = e.value.trim();
      } else {
        set[e.key] = e.value.trim();
      }
    }
    return ConnectionConfig(name: fi.split(' (').first, type: 'evcharger', settings: set, secrets: sec);
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    if (kind == ProviderKind.cloud) {
      for (final f in credFields.where((f) => !f.optional)) {
        if ((creds[f.key] ?? '').trim().isEmpty) throw AddDeviceError(AddProblem.cloudBadKey, 'missing ${f.key}');
      }
    }
    var conn = connectionFor(c, creds);
    var d = ctx.driver(conn);
    try {
      List<EvCharger> list;
      try {
        final v = await d.read({'ev': 'chargers'});
        list = [for (final x in (v is List ? v : const [])) EvCharger.fromJson(x as Map)];
      } catch (e) {
        final s = e.toString();
        if (e is EvAuthError || s.contains('login failed') || s.contains('HTTP 401') || s.contains('HTTP 403')) {
          throw AddDeviceError(AddProblem.cloudBadKey, s);
        }
        if (s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        throw explain(e);
      }
      // OCPP typed address: the charger connecting from that IP (if several).
      if (brand == 'ocpp' && c.id.isEmpty && list.length > 1) {
        final srv = await OcppServer.start();
        final m = srv.points.values.where((p) => p.remote == c.address.trim()).firstOrNull;
        if (m != null) list = list.where((x) => x.id == m.id).toList();
      }
      if (list.isEmpty) throw AddDeviceError(AddProblem.nothingToAdd, 'chargers');
      if (brand == 'ocpp' && conn.settings['chargePointId'] == null && list.length == 1) {
        await d.dispose();
        conn = ConnectionConfig(
          id: conn.id,
          name: conn.name,
          type: conn.type,
          settings: {...conn.settings, 'chargePointId': list.first.id},
          secrets: conn.secrets,
        );
        d = ctx.driver(conn);
      }
      final states = <String, EvState>{};
      for (final ch in list) {
        try {
          final raw = await d.read({'ev': 'state', 'charger': ch.id, if (ch.meta.isNotEmpty) 'meta': ch.meta});
          states[ch.id] = EvState.fromJson(raw is Map ? raw : const {});
        } catch (_) {
          states[ch.id] = EvState();
        }
      }
      final items = <AddItem>[];
      for (final ch in list) {
        final st = states[ch.id]!;
        items.add(
          AddItem(
            key: ch.id,
            name: ch.name,
            kind: 'switch',
            subtitle: tr(ctx.lang, evStatusText[st.status]!.$1, evStatusText[st.status]!.$2),
          ),
        );
        items.add(
          AddItem(
            key: '${ch.id}#extra',
            name: ch.name,
            kind: 'sensor',
            preselect: false,
            group: tr(ctx.lang, 'Lisäruudut automaatioihin', 'Extra tiles for automations'),
          ),
        );
      }
      return Connected(
        connection: conn,
        label: fi.split(' (').first,
        items: items,
        data: {'chargers': list, 'states': states},
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
    final list = (r.data['chargers'] as List).cast<EvCharger>();
    final states = (r.data['states'] as Map).cast<String, EvState>();
    final out = <TileConfig>[];
    for (final ch in list) {
      final st = states[ch.id] ?? EvState();
      final title = (names[ch.id]?.trim().isNotEmpty ?? false) ? names[ch.id]!.trim() : ch.name;
      if (!skip.contains(ch.id)) {
        out.addAll(evChargerTiles(r.connection.id, ch, st, title: title, lang: lang, local: brand == 'ocpp'));
      }
      final ek = '${ch.id}#extra';
      if (!skip.contains(ek)) {
        final t2 = (names[ek]?.trim().isNotEmpty ?? false) ? names[ek]!.trim() : ch.name;
        out.addAll(evChargerTiles(r.connection.id, ch, st, title: t2, lang: lang, extras: true));
      }
    }
    return out;
  }
}

const _user = CredField(
  'username',
  'Sähköposti / käyttäjätunnus',
  'E-mail / username',
  helpFi: 'Sama kuin valmistajan sovelluksessa.',
  helpEn: 'Same as in the maker\'s app.',
);
const _pass = CredField(
  'password',
  'Salasana',
  'Password',
  secret: true,
  helpFi: 'Tallentuu vain tähän laitteeseen salattuna.',
  helpEn: 'Stored encrypted on this device only.',
);

final evChargerProviders = <EvChargerProvider>[
  EvChargerProvider(
    id: 'ev_ocpp',
    brand: 'ocpp',
    kind: ProviderKind.local,
    fi: 'OCPP 1.6J (paikallinen, mikä tahansa merkki)',
    en: 'OCPP 1.6J (local, any brand)',
    descFi: 'Wallbox, Alfen, ABB, go-e, Etrel, Easee/Zaptec (OCPP päälle)… Laturi ottaa yhteyden suoraan Molaplaniin – ei pilveä.',
    descEn: 'Wallbox, Alfen, ABB, go-e, Etrel, Easee/Zaptec (OCPP on)… The charger connects straight to Molaplan – no cloud.',
    keywords: const [
      'ocpp',
      'ocpp 1.6',
      'laturi',
      'latausasema',
      'charger',
      'alfen',
      'abb',
      'go-e',
      'etrel',
      'wallbox',
      'sähköauto',
      'ev',
    ],
    credFields: const [
      CredField(
        'password',
        'OCPP-salasana (valinnainen)',
        'OCPP password (optional)',
        secret: true,
        optional: true,
        helpFi: 'Jos laturissa on asetettu Basic auth -salasana. Yleensä tyhjä.',
        helpEn: 'If the charger has a Basic auth password set. Usually empty.',
      ),
    ],
  ),
  EvChargerProvider(
    id: 'ev_easee',
    brand: 'easee',
    fi: 'Easee (pilvi)',
    en: 'Easee (cloud)',
    descFi: 'Easee Home / Charge / One Easee-tilin kautta: tila, aloitus/lopetus ja virtaraja.',
    descEn: 'Easee Home / Charge / One through your Easee account: status, start/stop and current limit.',
    keywords: const ['easee', 'easee home', 'easee one', 'laturi', 'charger', 'sähköauto', 'ev'],
    credFields: const [
      CredField(
        'username',
        'Easee-sähköposti tai puhelin',
        'Easee e-mail or phone',
        helpFi: 'Sama kuin Easee-sovelluksessa (puhelin muodossa +358…).',
        helpEn: 'Same as in the Easee app (phone as +358…).',
      ),
      _pass,
    ],
  ),
  EvChargerProvider(
    id: 'ev_zaptec',
    brand: 'zaptec',
    fi: 'Zaptec (pilvi)',
    en: 'Zaptec (cloud)',
    descFi: 'Zaptec Go / Home / Pro Zaptec-tilin kautta. Aloitus/tauko vaatii omistajan oikeudet.',
    descEn: 'Zaptec Go / Home / Pro through your Zaptec account. Start/pause needs owner rights.',
    keywords: const ['zaptec', 'zaptec go', 'zaptec pro', 'laturi', 'charger', 'sähköauto', 'ev'],
    credFields: const [_user, _pass],
  ),
  EvChargerProvider(
    id: 'ev_wallbox',
    brand: 'wallbox',
    documented: false,
    fi: 'Wallbox (pilvi)',
    en: 'Wallbox (cloud)',
    descFi: 'Pulsar, Commander, Copper myWallbox-tilin kautta. Paikallisesti: valitse OCPP.',
    descEn: 'Pulsar, Commander, Copper through your myWallbox account. Locally: pick OCPP.',
    keywords: const ['wallbox', 'pulsar', 'commander', 'copper', 'mywallbox', 'laturi', 'charger', 'sähköauto', 'ev'],
    credFields: const [_user, _pass],
  ),
];

class ChargerChooser extends DeviceProvider {
  @override
  String get id => 'evcharger';
  @override
  String get fi => 'Sähköauton laturi';
  @override
  String get en => 'EV charger';
  @override
  String get descFi =>
      'Easee, Zaptec, Wallbox – tai mikä tahansa OCPP-laturi paikallisesti. Lataus ylijäämällä tai halvalla.';
  @override
  String get descEn => 'Easee, Zaptec, Wallbox – or any OCPP charger locally. Charge on surplus or when cheap.';
  @override
  String get category => 'ev';
  @override
  List<String> get keywords => [
    'sähköauto',
    'laturi',
    'latausasema',
    'ev',
    'charger',
    'wallbox',
    for (final p in evChargerProviders) ...p.keywords,
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

const evNotYet = <(String, String, String)>[
  (
    'Wallbox paikallisesti, Tesla Wall Connector, Ohme, Pod Point…',
    'Wallbox toimii paikallisesti OCPP:llä. Muut: OCPP jos laturi tukee, muuten Home Assistantin kautta.',
    'Wallbox works locally with OCPP. Others: OCPP if supported, otherwise via Home Assistant.',
  ),
  (
    'OCPP 2.0.1',
    'Tulossa myöhemmin. Useimmat laturit tukevat myös 1.6J:tä.',
    'Later. Most chargers also support 1.6J.',
  ),
];

EvChargerProvider? evProviderById(String id) => evChargerProviders.where((p) => p.id == id).firstOrNull;
