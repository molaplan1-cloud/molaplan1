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
import 'inventor_tuya.dart';
import 'mhi_wfrac.dart';
import 'midea_lan.dart';
import '../tuya/tuya_discovery.dart';

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

  static const _secretKeys = {'password', 'localKey', 'token', 'key', 'clientSecret', 'gatewayPassword', 'privatePassword'};

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
    setpoints: {
      for (final e in ((m['setpoints'] as Map?) ?? const {}).entries)
        if (e.value is List) '${e.key}': [for (final x in e.value as List) hpNum(x) ?? 0],
    },
    switches: [for (final x in (m['switches'] as List? ?? const [])) '$x'],
    online: m['online'] != false,
  );
}

const _ipFi = 'Löytyy reitittimen laitelistasta tai valmistajan sovelluksesta (laitteen tiedot).';
const _ipEn = 'Find it in your router\'s device list or the maker\'s app (device info).';

// ---------------------------------------------------------------- Inventor (t326u, R570–R579)

/// Seconds the Midea / Tuya UDP searches listen (tests shorten it).
int inventorDiscoverSeconds = 4;

/// Inventor A/C with the INVmate II module (EU-OSK105 …) – Midea LAN protocol V2 / V3.
class InventorMideaProvider extends HeatPumpProvider {
  InventorMideaProvider()
    : super(
        id: 'hp_inventor_midea',
        brand: 'inventor_midea',
        fi: 'Inventor ilmalämpöpumppu (INVmate II, paikallinen)',
        en: 'Inventor air conditioner (INVmate II, local)',
        descFi:
            'Inventor-ilmalämpöpumput, joita ohjataan INVmate II -sovelluksella (wifi-moduuli EU-OSK105 tms.). Sama Midea LAN -protokolla toimii myös Midea-, Comfee- ja muissa Midean valmistamissa laitteissa. Paikallinen, ei pilveä.',
        descEn:
            'Inventor air conditioners controlled with the INVmate II app (Wi-Fi module EU-OSK105 or similar). The same Midea LAN protocol also works for Midea, Comfee and other Midea-built units. Local, no cloud.',
        keywords: const [
          'inventor', 'invmate', 'invmate ii', 'osk105', 'eu-osk105', 'midea', 'comfee', 'midea lan', 'ilmalämpöpumppu', 'ilmastointi', 'air conditioner', 'a/c', 'klima', 'heat pump', //
        ],
        addressHelpFi: 'Laitteen IP-osoite reitittimen laitelistasta (nimi usein "midea_ac_…"). Haku löytää sen yleensä itse.',
        addressHelpEn: 'The unit\'s IP from your router\'s device list (often named "midea_ac_…"). The search normally finds it by itself.',
        credFields: const [
          CredField(
            'token',
            'Token (vain V3-laitteet)',
            'Token (V3 units only)',
            secret: true,
            optional: true,
            hint: '128 heksamerkkiä',
            helpFi: 'Uudemmat laitteet (V3) tarvitsevat laitekohtaisen tokenin ja keyn. Jos et tiedä niitä, kirjoita alle oma Midea NetHome Plus -tilisi, niin ne haetaan kerran.',
            helpEn: 'Newer units (V3) need a per-device token and key. If you do not have them, enter your own Midea NetHome Plus account below and they are fetched once.',
          ),
          CredField(
            'key',
            'Key (vain V3-laitteet)',
            'Key (V3 units only)',
            secret: true,
            optional: true,
            hint: '64 heksamerkkiä',
            helpFi: 'Tokenin pari.',
            helpEn: 'The token\'s partner.',
          ),
          CredField(
            'account',
            'NetHome Plus -tili (sähköposti, vain V3)',
            'NetHome Plus account (e-mail, V3 only)',
            optional: true,
            helpFi: 'Ilmainen tili NetHome Plus -sovelluksessa (Midea). Käytetään vain tokenin ja keyn hakuun kerran; salasanaa ei tallenneta.',
            helpEn: 'A free account in the NetHome Plus app (Midea). Used only to fetch the token and key once; the password is not stored.',
          ),
          CredField(
            'password',
            'NetHome Plus -salasana',
            'NetHome Plus password',
            secret: true,
            optional: true,
            helpFi: 'Vain avainten hakuun. Ei tallennu laitteen asetuksiin.',
            helpEn: 'Only to fetch the keys. Not saved in the connection.',
          ),
        ],
      );

  @override
  String get pairHelpFi =>
      'Tämä laite (V3) tarvitsee laitekohtaisen tokenin ja keyn. Syötä ne, tai syötä oma Midea NetHome Plus -tilisi (sähköposti ja salasana), niin Molaplan hakee ne kerran Mideen pilvestä. Jos tili hylättiin, tarkista tunnukset. Tokenia ja keytä ei lähetetä Molaplanin palvelimille.';
  @override
  String get pairHelpEn =>
      'This unit (V3) needs a per-device token and key. Enter them, or enter your own Midea NetHome Plus account (e-mail and password) and Molaplan fetches them once from the Midea cloud. If the account was rejected, check the details. The token and key never go to Molaplan\'s servers.';

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (locals.isEmpty) return const [];
    try {
      final found = await discoverMidea(wait: Duration(seconds: inventorDiscoverSeconds));
      return [
        for (final x in found)
          if (x.isAirConditioner)
            Candidate(
              provider: id,
              address: x.ip,
              id: '${x.id}@${x.version}@${x.port}',
              model: 'Midea LAN V${x.version}',
              name: x.sn.length >= 4 ? 'A/C …${x.sn.substring(x.sn.length - 4)}' : 'A/C ${x.ip}',
            ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    var devId = '', version = '', port = '';
    final parts = c.id.split('@');
    if (parts.length >= 2 && int.tryParse(parts[0]) != null) {
      devId = parts[0];
      version = parts[1];
      port = parts.length > 2 ? parts[2] : '';
    }
    final probeConn = ConnectionConfig(name: 'probe', type: 'heatpump', settings: {'brand': brand, 'address': c.address.trim()});
    if (devId.isEmpty) {
      // Typed address: ask the unit who it is.
      final d = ctx.driver(probeConn);
      try {
        final r = await d.read({'hp': 'probe'});
        final m = (r is List ? r : const []).whereType<Map>().firstOrNull;
        if (m == null) throw AddDeviceError(AddProblem.unreachable, 'no answer to the Midea search');
        if ('${m['type']}' != '${0xAC}') throw AddDeviceError(AddProblem.notThisBrand, 'Midea type ${m['type']}');
        devId = '${m['id']}';
        version = '${m['version']}';
        port = '${m['port']}';
      } catch (e) {
        if (e is AddDeviceError) rethrow;
        throw explain(e);
      } finally {
        await d.dispose();
      }
    }
    final out = Map<String, String>.of(creds)
      ..['deviceId'] = devId
      ..['protocol'] = version == '3' ? '3' : '2'
      ..['port'] = port.isEmpty ? '6444' : port;
    if (version == '3') {
      final haveKeys = (creds['token'] ?? '').trim().isNotEmpty && (creds['key'] ?? '').trim().isNotEmpty;
      if (!haveKeys) {
        final acc = (creds['account'] ?? '').trim(), pw = (creds['password'] ?? '').trim();
        if (acc.isEmpty || pw.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'token + key');
        final d = ctx.driver(probeConn);
        try {
          final r = await d.read({'hp': 'midea_token', 'account': acc, 'password': pw, 'id': devId});
          if (r is Map) {
            out['token'] = '${r['token']}';
            out['key'] = '${r['key']}';
          }
        } catch (e) {
          final s = e.toString();
          if (e is MideaCloudError || s.contains('Midea cloud')) throw AddDeviceError(AddProblem.needsDetails, s);
          throw explain(e);
        } finally {
          await d.dispose();
        }
      }
    }
    out
      ..remove('account')
      ..remove('password');
    try {
      return await super.connect(ctx, c, out);
    } on AddDeviceError catch (e) {
      if (version == '3' && e.detail.contains('token')) throw AddDeviceError(AddProblem.needsDetails, e.detail);
      rethrow;
    }
  }
}

/// Inventor A/C with the "Inventor Control" app – a white-label Tuya app (LAN protocol).
class InventorTuyaProvider extends HeatPumpProvider {
  InventorTuyaProvider()
    : super(
        id: 'hp_inventor_tuya',
        brand: 'inventor_tuya',
        fi: 'Inventor ilmalämpöpumppu (Inventor Control, paikallinen)',
        en: 'Inventor air conditioner (Inventor Control, local)',
        descFi:
            'Inventor-ilmalämpöpumput, joita ohjataan Inventor Control -sovelluksella (malleja mm. Leon, Legend, Comfort, Supreme, Vero). Sovellus on Tuya-pohjainen; ohjaus kotiverkossa ilman pilveä. Tarvitsee laitteen paikallisen avaimen kerran.',
        descEn:
            'Inventor air conditioners controlled with the Inventor Control app (e.g. Leon, Legend, Comfort, Supreme, Vero). The app is Tuya-based; control on your home network without the cloud. Needs the unit\'s local key once.',
        keywords: const [
          'inventor', 'inventor control', 'leon', 'legend', 'supreme', 'vero', 'comfort', 'tuya', 'smart life', 'ilmalämpöpumppu', 'ilmastointi', 'air conditioner', 'a/c', 'klima', 'heat pump', //
        ],
        addressHelpFi: 'Laitteen IP-osoite reitittimen laitelistasta. Haku löytää sen yleensä itse.',
        addressHelpEn: 'The unit\'s IP from your router\'s device list. The search normally finds it by itself.',
        credFields: const [
          CredField(
            'localKey',
            'Paikallinen avain (local key)',
            'Local key',
            secret: true,
            optional: true,
            hint: '16 merkkiä',
            helpFi: '16 merkin avain. Jos et tiedä sitä, täytä alla oma Tuya-kehittäjäprojektisi tunnukset, niin se haetaan kerran. Uusimmat Inventor Control -laitteet eivät aina yhdisty Tuya-sovellukseen – silloin avain pitää hakea muulla tavalla (ohje: docs/INVENTOR.md).',
            helpEn: 'A 16-character key. If you do not have it, fill in your own Tuya developer project below and it is fetched once. The newest Inventor Control units cannot always be linked to the Tuya app – then the key has to be obtained another way (see docs/INVENTOR.md).',
          ),
          CredField(
            'deviceId',
            'Laitteen tunnus (Device ID)',
            'Device ID',
            optional: true,
            helpFi: 'Täytetään automaattisesti, jos laite löytyi verkosta.',
            helpEn: 'Filled in automatically when the unit was found on the network.',
          ),
          CredField(
            'version',
            'Protokollaversio',
            'Protocol version',
            optional: true,
            hint: '3.3',
            helpFi: '3.3, 3.4 tai 3.5. Jos jätät tyhjäksi, kokeillaan kaikki.',
            helpEn: '3.3, 3.4 or 3.5. If left empty all are tried.',
          ),
          CredField(
            'accessId',
            'Tuya Access ID (avaimen hakuun)',
            'Tuya Access ID (to fetch the key)',
            optional: true,
            helpFi: 'Oma ilmainen Tuya-kehittäjäprojekti (iot.tuya.com → Cloud → Create Cloud Project → Devices → Link App Account). Sovellukseksi käy Tuya Smart / Smart Life, johon laite on lisätty.',
            helpEn: 'Your own free Tuya developer project (iot.tuya.com → Cloud → Create Cloud Project → Devices → Link App Account). Use the Tuya Smart / Smart Life app the unit was added to.',
          ),
          CredField('accessSecret', 'Tuya Access Secret', 'Tuya Access Secret', secret: true, optional: true, helpFi: 'Samalta projektin sivulta. Ei tallennu.', helpEn: 'From the same project page. Not saved.'),
          CredField('region', 'Tuya-alue (eu, us, cn, in)', 'Tuya region (eu, us, cn, in)', optional: true, hint: 'eu', helpFi: 'Projektin data center, Euroopassa yleensä eu.', helpEn: 'The project\'s data center, usually eu in Europe.'),
        ],
      );

  @override
  String get pairHelpFi =>
      'Tarvitaan laitteen paikallinen avain (local key, 16 merkkiä) – kirjoita se, tai täytä oman ilmaisen Tuya-kehittäjäprojektisi Access ID ja Secret, niin avain haetaan kerran. Jos avain ei kelvannut, tarkista se ja laitteen tunnus. Avain ei mene Molaplanin palvelimille.';
  @override
  String get pairHelpEn =>
      'The unit\'s local key (16 characters) is needed – type it, or fill in the Access ID and Secret of your own free Tuya developer project and the key is fetched once. If the key was rejected, check it and the device id. The key never goes to Molaplan\'s servers.';

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (locals.isEmpty) return const [];
    try {
      final found = await discoverTuya(wait: Duration(seconds: inventorDiscoverSeconds));
      return [
        for (final x in found)
          Candidate(
            provider: id,
            address: x.ip,
            id: '${x.id}@${x.version}',
            model: 'Tuya ${x.version}',
            name: inventorTuyaProducts.contains(x.productKey) ? 'Inventor A/C (Tuya)' : 'Tuya ${x.id}',
          ),
      ];
    } catch (_) {
      return const [];
    }
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final parts = c.id.split('@');
    var devId = (creds['deviceId'] ?? '').trim();
    if (devId.isEmpty) devId = parts.first;
    var version = (creds['version'] ?? '').trim();
    if (version.isEmpty && parts.length > 1) version = parts[1];
    var key = (creds['localKey'] ?? '').trim();
    final accessId = (creds['accessId'] ?? '').trim(), secret = (creds['accessSecret'] ?? '').trim();
    if (key.isEmpty && accessId.isNotEmpty && secret.isNotEmpty) {
      var region = (creds['region'] ?? '').trim().toLowerCase();
      if (region.isEmpty) region = 'eu';
      final tc = ConnectionConfig(
        name: 'Tuya',
        type: 'tuya',
        settings: {'region': region, 'accessId': accessId, 'devices': <Map<String, dynamic>>[], 'push': false},
        secrets: {'accessSecret': secret},
      );
      final d = ctx.driver(tc);
      try {
        final r = await d.send({'op': 'cloud_devices', 'deviceId': devId});
        final list = (r is List ? r : const []).whereType<Map>().where((x) => x['sub'] != true && '${x['key'] ?? ''}'.length == 16).toList();
        Map? hit = list.where((x) => devId.isNotEmpty && '${x['id']}' == devId).firstOrNull;
        hit ??= list.where((x) => '${x['category']}' == 'kt').length == 1 ? list.firstWhere((x) => '${x['category']}' == 'kt') : null;
        if (hit == null) throw AddDeviceError(AddProblem.needsDetails, 'device id: no matching device in the Tuya project');
        key = '${hit['key']}';
        if (devId.isEmpty) devId = '${hit['id']}';
      } catch (e) {
        if (e is AddDeviceError) rethrow;
        final s = e.toString();
        if (s.contains('sign invalid') || s.contains('clientId is invalid') || s.contains('1004') || s.contains('No permission')) {
          throw AddDeviceError(AddProblem.needsDetails, s);
        }
        if (s.contains('frequently') || s.contains('429')) throw AddDeviceError(AddProblem.cloudRateLimit, s);
        throw explain(e);
      } finally {
        await d.dispose();
      }
    }
    if (key.length != 16 || devId.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'local key / device id');
    AddDeviceError? last;
    for (final v in version.isEmpty ? const ['3.3', '3.4', '3.5'] : [version]) {
      final out = Map<String, String>.of(creds)
        ..['deviceId'] = devId
        ..['version'] = v
        ..['localKey'] = key
        ..remove('accessId')
        ..remove('accessSecret')
        ..remove('region');
      try {
        return await super.connect(ctx, c, out);
      } on AddDeviceError catch (e) {
        last = e;
        if (e.problem == AddProblem.nothingToAdd) rethrow;
      }
    }
    throw last!.problem == AddProblem.unknown ? AddDeviceError(AddProblem.needsDetails, last.detail) : last;
  }
}

/// Inventor air-to-water pumps through the wired controller's RS-485 Modbus port.
class InventorAtwProvider extends HeatPumpProvider {
  InventorAtwProvider()
    : super(
        id: 'hp_inventor_atw',
        brand: 'inventor_atw',
        fi: 'Inventor ilma-vesilämpöpumppu (Modbus RS-485)',
        en: 'Inventor air-to-water heat pump (Modbus RS-485)',
        descFi:
            'Inventor-ilma-vesilämpöpumput (monoblock-sarjat ja hydromoduulit). Ohjaus pumpun langallisen ohjaimen RS-485-liitännän (H1/H2) kautta halvalla RS-485–Ethernet/wifi-muuntimella: tila, tavoitelämpötila, käyttövesi, menovesi, ulkolämpötila. Paikallinen, ei pilveä.',
        descEn:
            'Inventor air-to-water heat pumps (monoblock series and hydro modules). Control through the RS-485 port (H1/H2) of the pump\'s wired controller with a cheap RS-485–Ethernet/Wi-Fi converter: mode, setpoint, hot water, water and outdoor temperature. Local, no cloud.',
        keywords: const [
          'inventor', 'matrix', 'evo', 'monoblock', 'hydro', 'ilma-vesi', 'ilma-vesilämpöpumppu', 'air to water', 'air-to-water', 'modbus', 'rs485', 'rs-485', 'käyttövesi', 'dhw', 'heat pump', 'lämpöpumppu', //
        ],
        addressHelpFi: 'RS-485–Modbus-muuntimen IP-osoite (esim. Waveshare, Elfin EW11, USR-TCP232). Sitä ei löydy haulla – kirjoita osoite.',
        addressHelpEn: 'IP of the RS-485–Modbus converter (e.g. Waveshare, Elfin EW11, USR-TCP232). It cannot be searched – type the address.',
        credFields: const [
          CredField(
            'port',
            'Portti',
            'Port',
            optional: true,
            hint: '502',
            helpFi: 'Muuntimen Modbus-portti, yleensä 502 (joillain 8899 tai 23).',
            helpEn: 'The converter\'s Modbus port, usually 502 (some use 8899 or 23).',
          ),
          CredField(
            'unitId',
            'Pumpun Modbus-osoite',
            'Pump Modbus address',
            optional: true,
            hint: '1',
            helpFi: 'Sama kuin hydromoduulin DIP-kytkimillä asetettu osoite, oletus 1.',
            helpEn: 'The address set with the DIP switches of the hydraulic module, default 1.',
          ),
          CredField(
            'framing',
            'Muuntimen tila (tcp / rtu)',
            'Converter mode (tcp / rtu)',
            optional: true,
            hint: 'tcp',
            helpFi: 'Jätä tyhjäksi: kokeillaan sekä Modbus TCP että läpinäkyvä RTU. Muuntimen asetus 9600 baud, 8 databittiä, ei pariteettia, 1 stop-bitti.',
            helpEn: 'Leave empty: both Modbus TCP and transparent RTU are tried. Set the converter to 9600 baud, 8 data bits, no parity, 1 stop bit.',
          ),
        ],
      );

  @override
  String get pairHelpFi =>
      'Pumppu ei vastannut oletusasetuksilla (portti 502, Modbus-osoite 1, sekä Modbus TCP että läpinäkyvä RTU). Tarkista muuntimen IP-osoite ja kirjoita alle muuntimen portti, pumpun Modbus-osoite (hydromoduulin DIP-kytkimet) ja tila, jos ne poikkeavat. RS-485: A/B langallisen ohjaimen H1/H2-liittimiin, 9600 baud, 8 databittiä, ei pariteettia, 1 stop-bitti.';
  @override
  String get pairHelpEn =>
      'The pump did not answer with the defaults (port 502, Modbus address 1, both Modbus TCP and transparent RTU). Check the converter\'s IP and type below the converter\'s port, the pump\'s Modbus address (DIP switches of the hydraulic module) and mode if they differ. RS-485: A/B to the wired controller\'s H1/H2 terminals, 9600 baud, 8 data bits, no parity, 1 stop bit.';

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final given = (creds['framing'] ?? '').trim().toLowerCase();
    final typed = ['port', 'unitId', 'framing'].any((k) => (creds[k] ?? '').trim().isNotEmpty);
    AddDeviceError? last;
    for (final f in given == 'tcp' || given == 'rtu' ? [given] : const ['tcp', 'rtu']) {
      try {
        return await super.connect(ctx, c, {...creds, 'framing': f});
      } on AddDeviceError catch (e) {
        last = e;
        if (e.problem == AddProblem.nothingToAdd) rethrow;
      }
    }
    // First try without any typed setting: show the port / address / mode fields.
    if (!typed && (last!.problem == AddProblem.unreachable || last.problem == AddProblem.unknown)) {
      throw AddDeviceError(AddProblem.needsDetails, last.detail);
    }
    throw last!;
  }
}

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
  // R545 (t322u): Bosch / Buderus / Junkers / IVT heating with a KM50/KM100/KM200/KM300 gateway.
  HeatPumpProvider(
    id: 'hp_bosch_km200',
    brand: 'km200',
    documented: false,
    fi: 'Bosch / Buderus lämmitys (KM200-yhdyskäytävä, paikallinen)',
    en: 'Bosch / Buderus heating (KM200 gateway, local)',
    descFi:
        'Kaasu-/öljykattilat ja lämpöpumput, joissa on Logamatic web KM50/KM100/KM200/KM300 -yhdyskäytävä (Bosch, Buderus, Junkers, IVT). Paikallinen, ei pilveä eikä maksuja.',
    descEn:
        'Boilers and heat pumps with a Logamatic web KM50/KM100/KM200/KM300 gateway (Bosch, Buderus, Junkers, IVT). Local, no cloud, no fees.',
    keywords: const ['bosch', 'buderus', 'junkers', 'ivt', 'km200', 'km100', 'km50', 'km300', 'logamatic', 'easycontrol', 'mydevice', 'kattila', 'boiler', 'lämmitys'],
    addressHelpFi: 'KM-yhdyskäytävän IP-osoite reitittimen laitelistasta (nimi usein "KM200" tai sarjanumero).',
    addressHelpEn: "The KM gateway's IP from your router's device list (often named \"KM200\" or its serial).",
    credFields: const [
      CredField(
        'gatewayPassword',
        'Yhdyskäytävän salasana',
        'Gateway password',
        secret: true,
        hint: 'xxxx-xxxx-xxxx-xxxx',
        helpFi: 'Yhdyskäytävän tarrassa tai lämmityslaitteen valikossa: Info → Internet → Kirjautumistiedot.',
        helpEn: 'On the gateway sticker or in the boiler menu: Info → Internet → Login data.',
      ),
      CredField(
        'privatePassword',
        'Oma salasana',
        'Private password',
        secret: true,
        helpFi: 'Salasana, jonka asetit valmistajan sovelluksessa (MyDevice, EasyControl tai Buderus-sovellus).',
        helpEn: "The password you set in the maker's app (MyDevice, EasyControl or the Buderus app).",
      ),
    ],
  ),
  // R570–R579 (t326u): Inventor.
  InventorMideaProvider(),
  InventorTuyaProvider(),
  InventorAtwProvider(),
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
  String get descFi => 'Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia, Inventor – tai mikä tahansa IR-kaukosäätimellä.';
  @override
  String get descEn => 'Daikin, Mitsubishi, Toshiba, Samsung, Hitachi, NIBE, Thermia, Inventor – or any with an IR remote.';
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
    'Bosch EasyControl CT200, HomeCom Easy, K30/K40 RF (Compress-lämpöpumput, Condens-kattilat)',
    'Ei virallista julkista rajapintaa: Boschin pilveen pääsee vain matkimalla Boschin omaa sovellusta (SingleKey ID), mikä voi rikkoa käyttöehtoja ja lakata toimimasta. Nyt: Home Assistantin Bosch-integraation kautta, tai KM200-yhdyskäytävällä paikallisesti jos laitteessa on sellainen.',
    'No official public API: the Bosch cloud is only reachable by imitating Bosch\'s own app (SingleKey ID), which may break the terms and stop working. Today: via Home Assistant\'s Bosch integration, or locally with a KM200 gateway if the unit has one.',
    template: 'homeassistant',
  ),
  HpNotYet(
    'Panasonic (Comfort Cloud), LG (ThinQ), Gree, Fujitsu…',
    'Ei omaa integraatiota vielä. Toimii nyt IR-ohjaimella (Tasmota/ESPHome) tai Home Assistantin kautta. Midean valmistamat laitteet (Midea, Comfee, Inventor…) toimivat "Inventor INVmate II" -valinnalla.',
    'No built-in integration yet. Works today with an IR blaster (Tasmota/ESPHome) or via Home Assistant. Midea-built units (Midea, Comfee, Inventor…) work with the "Inventor INVmate II" entry.',
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

