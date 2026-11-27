/// R290: TVs and Cast devices in the add-device wizard. One gallery card "TV ja Chromecast"
/// ([MediaChooser]) opens a brand list: Chromecast / Google TV / Android TV (Cast), Samsung, LG and
/// Philips – all local, no cloud. Tiles: status, power, volume, mute, play/pause, stop.
/// R324: + Android TV / Google TV remote (keys, channels, pairing code), Sonos (UPnP) and Roku (ECP).
library;

import '../devices/provider.dart';
import '../models/models.dart';
import 'android_tv.dart';
import 'media_driver.dart';
import 'media_model.dart';
import 'philips_tv.dart';
import 'roku.dart';
import 'sonos.dart';

class MediaProvider extends DeviceProvider {
  MediaProvider({
    required this.id,
    required this.brand,
    required this.fi,
    required this.en,
    required this.descFi,
    required this.descEn,
    required this.keywords,
    this.mdns = const [],
    this.helpFi = '',
    this.helpEn = '',
    this.pairFi = '',
    this.pairEn = '',
    this.creds = const [],
  });

  @override
  final String id;
  final String brand;
  @override
  final String fi, en, descFi, descEn;
  @override
  final List<String> keywords;
  final List<String> mdns;
  final String helpFi, helpEn, pairFi, pairEn;
  final List<CredField> creds;

  @override
  String get category => 'media';
  @override
  List<String> get mdnsTypes => mdns;
  @override
  List<CredField> get credFields => creds;
  @override
  String get addressHelpFi => helpFi;
  @override
  String get addressHelpEn => helpEn;
  @override
  String get pairHelpFi => pairFi;
  @override
  String get pairHelpEn => pairEn;
  @override
  Duration get pairWindow => const Duration(seconds: 40);

  /// Samsung and LG: the TV shows an "allow" prompt – the wizard shows a countdown meanwhile.
  @override
  PairMode get pairMode => brand == 'samsung' || brand == 'lg' ? PairMode.button : PairMode.none;

  @override
  Candidate? fromMdns(String address, String label, String service) {
    final host = hostOf(address);
    if (service.startsWith('_googlecast')) {
      final name = label.replaceAll(RegExp(r'-[0-9a-f]{20,}$'), '').replaceAll('-', ' ');
      return Candidate(provider: id, address: host, id: label, model: 'Cast', name: name);
    }
    if (service.startsWith('_sonos')) {
      // "RINCON_xxxx@Olohuone" or the room name.
      final name = label.contains('@') ? label.split('@').last : label;
      return Candidate(provider: id, address: host, id: label, model: 'Sonos', name: name);
    }
    if (service.startsWith('_airplay')) {
      final l = label.toLowerCase();
      if (brand == 'samsung' && l.contains('samsung') || brand == 'lg' && l.contains('lg')) {
        return Candidate(provider: id, address: host, name: label.replaceAll('[TV] ', ''));
      }
      return null;
    }
    return Candidate(provider: id, address: host, id: label, name: label);
  }

  @override
  Future<List<Candidate>> scan(List<String> locals) async {
    if (brand == 'samsung') {
      return scanSubnet<Candidate>(locals, (client, ip) async {
        final j = await probeJson(client, Uri.parse('http://$ip:8001/api/v2/'));
        final d = j is Map ? j['device'] : null;
        if (d is! Map || !'${d['type'] ?? ''}'.contains('TV')) return null;
        return Candidate(
          provider: id,
          address: ip,
          model: '${d['modelName'] ?? 'Samsung'}',
          name: '${d['name'] ?? 'Samsung TV'}'.replaceAll('[TV] ', ''),
        );
      });
    }
    if (brand == 'roku') {
      return scanSubnet<Candidate>(locals, (client, ip) async {
        final r = await probeRoku(client, ip);
        return r == null ? null : Candidate(provider: id, address: ip, model: r.$2, name: r.$1);
      });
    }
    if (brand == 'sonos') {
      return scanSubnet<Candidate>(locals, (client, ip) async {
        final r = await probeSonos(client, ip);
        return r == null ? null : Candidate(provider: id, address: ip, model: r.$2, name: r.$1);
      });
    }
    if (brand == 'philips') {
      return scanSubnet<Candidate>(locals, (client, ip) async {
        for (final v in const [6, 1]) {
          try {
            final j = await probeJson(client, Uri.parse('http://$ip:1925/$v/system'));
            if (j is Map && j['api_version'] is Map) {
              return Candidate(provider: id, address: ip, model: 'JointSPACE', name: '${j['name'] ?? 'Philips TV'}');
            }
          } catch (_) {}
        }
        return null;
      });
    }
    return const [];
  }

  @override
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async {
    final host = hostOf(c.address);
    var left = pairWindow.inSeconds;
    tick?.call(left);
    var stop = false;
    () async {
      while (!stop && left > 0) {
        await Future<void>.delayed(const Duration(seconds: 1));
        left--;
        if (!stop) tick?.call(left);
      }
    }();
    final d = ctx.driver(_conn(host, c, const {}));
    try {
      final raw = await d.read({'media': 'info'});
      final info = MediaInfo.fromJson(raw is Map ? raw : const {});
      final t = info.extra['token'] ?? info.extra['clientKey'] ?? '';
      return {'token': t.isEmpty ? 'none' : t, if (info.mac.isNotEmpty) 'mac': info.mac, 'name': info.name};
    } catch (e) {
      if (e is MediaPairingNeeded || e is MediaAuthError) throw AddDeviceError(AddProblem.buttonNotPressed, '$e');
      throw explain(e);
    } finally {
      stop = true;
      await d.dispose();
    }
  }

  ConnectionConfig _conn(String host, Candidate c, Map<String, String> creds) {
    final set = <String, dynamic>{'brand': brand, 'address': host};
    final sec = <String, String>{};
    final tok = creds['token'] ?? '';
    if (tok.isNotEmpty && tok != 'none') sec[brand == 'lg' ? 'clientKey' : 'token'] = tok;
    if ((creds['mac'] ?? '').trim().isNotEmpty) set['mac'] = creds['mac']!.trim();
    if ((creds['username'] ?? '').isNotEmpty) set['username'] = creds['username'];
    if ((creds['password'] ?? '').isNotEmpty) sec['password'] = creds['password']!;
    for (final k in const ['atvCert', 'atvKey']) {
      if ((creds[k] ?? '').isNotEmpty) sec[k] = creds[k]!;
    }
    if ((creds['api'] ?? '').isNotEmpty) set['api'] = int.tryParse(creds['api']!) ?? 6;
    if (c.name?.isNotEmpty ?? false) set['name'] = c.name;
    final name = (creds['name'] ?? '').isNotEmpty ? creds['name']! : (c.name?.isNotEmpty == true ? c.name! : fi);
    return ConnectionConfig(name: name, type: 'media', settings: set, secrets: sec);
  }

  @override
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds) async {
    final host = hostOf(c.address);
    if (host.isEmpty) throw AddDeviceError(AddProblem.needsDetails, 'address');
    final cr = Map<String, String>.from(creds);
    if (brand == 'philips') await _philipsAuth(host, cr);
    if (brand == 'androidtv') await _androidTvPair(host, cr);
    final conn = _conn(host, c, cr);
    final d = ctx.driver(conn);
    try {
      MediaInfo info;
      try {
        final raw = await d.read({'media': 'info'});
        info = MediaInfo.fromJson(raw is Map ? raw : const {});
      } catch (e) {
        if (e is MediaPairingNeeded) throw AddDeviceError(AddProblem.buttonNotPressed, '$e');
        if (e is MediaAuthError) throw AddDeviceError(AddProblem.needsPassword, '$e');
        throw explain(e);
      }
      final settings = {...conn.settings};
      final secrets = {...conn.secrets};
      if (info.mac.isNotEmpty && (settings['mac'] ?? '') == '') settings['mac'] = info.mac;
      for (final e in info.extra.entries) {
        if (const {'token', 'clientKey', 'atvCert', 'atvKey'}.contains(e.key)) secrets[e.key] = e.value;
      }
      final name = info.name.isNotEmpty && (c.name?.isEmpty ?? true) ? info.name : conn.name;
      final out = ConnectionConfig(id: conn.id, name: name, type: 'media', settings: settings, secrets: secrets);
      String sub = '';
      try {
        sub = '${await d.read({'media': 'status'})}';
      } catch (_) {}
      return Connected(
        connection: out,
        label: name,
        items: [AddItem(key: 'tv', name: name, kind: 'switch', subtitle: sub)],
        data: {'info': info},
      );
    } finally {
      await d.dispose();
    }
  }

  /// Android TV remote v2: our certificate + the 6-character code shown on the TV.
  Future<void> _androidTvPair(String host, Map<String, String> cr) async {
    if ((cr['atvCert'] ?? '').isNotEmpty && (cr['atvKey'] ?? '').isNotEmpty) return;
    final code = (cr['pin'] ?? '').trim();
    final pending = atvPending[host];
    if (code.isEmpty || pending == null) {
      await atvPending.remove(host)?.close();
      try {
        atvPending[host] = await AtvPairing.start(host);
      } catch (e) {
        throw explain(e);
      }
      throw AddDeviceError(AddProblem.needsDetails, 'Android TV code');
    }
    try {
      await pending.finish(code);
      cr['atvCert'] = pending.cert;
      cr['atvKey'] = pending.key;
      cr.remove('pin');
    } on MediaAuthError catch (e) {
      throw AddDeviceError(AddProblem.wrongPassword, '$e');
    } catch (e) {
      throw explain(e);
    } finally {
      atvPending.remove(host);
      await pending.close();
    }
  }

  /// Philips v6: the TV shows a PIN (needsDetails → the user types it) → digest credentials.
  Future<void> _philipsAuth(String host, Map<String, String> cr) async {
    if ((cr['username'] ?? '').isNotEmpty && (cr['password'] ?? '').isNotEmpty) return;
    final (api, sys) = await PhilipsBackend.detect(host).catchError((Object e) => throw explain(e));
    cr['api'] = '$api';
    if (api < 6 || !PhilipsBackend.needsPairing(sys)) return;
    final pin = (cr['pin'] ?? '').trim();
    if (pin.isEmpty || !philipsPending.containsKey(host)) {
      try {
        await PhilipsBackend.pairRequest(host, api, sys);
      } catch (e) {
        throw explain(e);
      }
      throw AddDeviceError(AddProblem.needsDetails, 'Philips PIN');
    }
    try {
      final (u, p) = await PhilipsBackend.pairGrant(host, pin);
      cr['username'] = u;
      cr['password'] = p;
      cr.remove('pin');
    } on MediaAuthError catch (e) {
      throw AddDeviceError(AddProblem.wrongPassword, '$e');
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
    if (skip.contains('tv')) return const [];
    final info = r.data['info'] as MediaInfo;
    final title = (names['tv']?.trim().isNotEmpty ?? false) ? names['tv']!.trim() : r.label;
    return mediaTiles(r.connection.id, info, title: title, lang: lang);
  }
}

final mediaProviders = <MediaProvider>[
  MediaProvider(
    id: 'media_cast',
    brand: 'cast',
    fi: 'Chromecast / Google TV / Android TV',
    en: 'Chromecast / Google TV / Android TV',
    descFi: 'Chromecast, Google TV, Android TV:t (Sony, Philips, TCL, Xiaomi…) ja Nest-kaiuttimet Cast-yhteydellä: tila, äänenvoimakkuus, tauko ja pysäytys.',
    descEn: 'Chromecast, Google TV, Android TVs (Sony, Philips, TCL, Xiaomi…) and Nest speakers over Cast: status, volume, pause and stop.',
    keywords: const [
      'chromecast',
      'google tv',
      'android tv',
      'cast',
      'nest',
      'sony',
      'bravia',
      'tcl',
      'xiaomi',
      'tv',
      'televisio',
      'kaiutin',
    ],
    mdns: const ['_googlecast._tcp'],
    helpFi: 'Löytyy yleensä itse. Muuten: Google Home -sovellus → laite → Asetukset → Laitteen tiedot → IP-osoite.',
    helpEn: 'Usually found automatically. Otherwise: Google Home app → device → Settings → Device information → IP address.',
  ),
  MediaProvider(
    id: 'media_samsung',
    brand: 'samsung',
    fi: 'Samsung Smart TV (Tizen)',
    en: 'Samsung Smart TV (Tizen)',
    descFi: 'Samsung-televisiot 2016→: virta, äänenvoimakkuus, mykistys ja toisto suoraan kotiverkossa.',
    descEn: 'Samsung TVs 2016→: power, volume, mute and playback straight over the home network.',
    keywords: const ['samsung', 'tizen', 'smart tv', 'qled', 'neo qled', 'the frame', 'tv', 'televisio'],
    mdns: const ['_airplay._tcp'],
    helpFi: 'TV: Asetukset → Yleiset → Verkko → Verkon tila → IP-asetukset. Käynnistystä varten: Yleiset → Verkko → Asiantuntija-asetukset → "Käynnistä mobiililaitteella" päälle.',
    helpEn: 'TV: Settings → General → Network → Network Status → IP Settings. For power on: General → Network → Expert Settings → "Power On with Mobile" on.',
    pairFi: 'Televisioon tulee kysymys "Salli Molaplan?" – valitse kaukosäätimellä Salli.',
    pairEn: 'The TV asks "Allow Molaplan?" – choose Allow with the remote.',
  ),
  MediaProvider(
    id: 'media_lg',
    brand: 'lg',
    fi: 'LG Smart TV (webOS)',
    en: 'LG Smart TV (webOS)',
    descFi: 'LG-televisiot (webOS): virta, äänenvoimakkuus, mykistys, toisto ja avoin sovellus kotiverkossa.',
    descEn: 'LG TVs (webOS): power, volume, mute, playback and the open app over the home network.',
    keywords: const ['lg', 'webos', 'oled', 'nanocell', 'smart tv', 'tv', 'televisio'],
    mdns: const ['_airplay._tcp'],
    helpFi: 'TV: Asetukset → Yleiset → Verkko → Wi-Fi/langallinen → Lisäasetukset. Käynnistystä varten: Yleiset → Laitteet → "Käynnistä Wi-Fin kautta" (Turn on via Wi-Fi) päälle.',
    helpEn: 'TV: Settings → General → Network → Wi-Fi/wired → Advanced. For power on: General → Devices → "Turn on via Wi-Fi" on.',
    pairFi: 'Televisioon tulee yhteyspyyntö – hyväksy se kaukosäätimellä (Hyväksy / Accept).',
    pairEn: 'The TV shows a connection request – accept it with the remote.',
  ),
  MediaProvider(
    id: 'media_philips',
    brand: 'philips',
    fi: 'Philips TV (JointSPACE)',
    en: 'Philips TV (JointSPACE)',
    descFi: 'Philips-televisiot: virta (Android-mallit), äänenvoimakkuus, mykistys ja näppäimet. Android-mallit paritetaan TV:n näyttämällä PIN-koodilla.',
    descEn:
        'Philips TVs: power (Android models), volume, mute and keys. Android models pair with a PIN shown on the TV.',
    keywords: const ['philips', 'jointspace', 'ambilight', 'tv', 'televisio'],
    helpFi: 'TV: Asetukset → Langaton ja verkot → Langallinen tai Wi-Fi → Näytä verkkoasetukset.',
    helpEn: 'TV: Settings → Wireless and networks → Wired or Wi-Fi → View network settings.',
    pairFi: 'Kirjoita televisioon ilmestynyt nelinumeroinen PIN-koodi.',
    pairEn: 'Type the four-digit PIN shown on the TV.',
    creds: const [
      CredField(
        'pin',
        'PIN-koodi televisiosta',
        'PIN from the TV',
        hint: '1234',
        helpFi: 'Näkyy television ruudulla noin minuutin.',
        helpEn: 'Shown on the TV screen for about a minute.',
      ),
    ],
  ),
  MediaProvider(
    id: 'media_androidtv',
    brand: 'androidtv',
    fi: 'Android TV / Google TV (kaukosäädin)',
    en: 'Android TV / Google TV (remote)',
    descFi: 'Sony, Philips, TCL, Xiaomi, Chromecast with Google TV…: virta, äänenvoimakkuus, mykistys, kanavat, nuolinäppäimet ja avoin sovellus. Paritus television näyttämällä koodilla.',
    descEn: 'Sony, Philips, TCL, Xiaomi, Chromecast with Google TV…: power, volume, mute, channels, arrow keys and the open app. Pairs with a code shown on the TV.',
    keywords: const ['android tv', 'google tv', 'kaukosäädin', 'remote', 'sony', 'bravia', 'tcl', 'xiaomi', 'kanava'],
    mdns: const ['_androidtvremote2._tcp'],
    helpFi: 'TV: Asetukset → Verkko ja Internet → (verkko) → IP-osoite. Tai Google Home -sovellus → laite → Laitteen tiedot.',
    helpEn:
        'TV: Settings → Network & Internet → (network) → IP address. Or Google Home app → device → Device information.',
    pairFi: 'Televisioon ilmestyy kuusimerkkinen koodi (numerot ja kirjaimet A–F) – kirjoita se tähän.',
    pairEn: 'The TV shows a six-character code (digits and letters A–F) – type it here.',
    creds: const [
      CredField(
        'pin',
        'Koodi televisiosta',
        'Code from the TV',
        hint: '1A2B3C',
        helpFi: 'Näkyy television ruudulla parituksen ajan.',
        helpEn: 'Shown on the TV screen during pairing.',
      ),
    ],
  ),
  MediaProvider(
    id: 'media_sonos',
    brand: 'sonos',
    fi: 'Sonos',
    en: 'Sonos',
    descFi: 'Sonos-kaiuttimet ja -soundbarit: äänenvoimakkuus, mykistys, toisto/tauko, seuraava ja mitä soi. Suoraan kotiverkossa, ei tiliä.',
    descEn: 'Sonos speakers and soundbars: volume, mute, play/pause, next and now playing. Straight over the home network, no account.',
    keywords: const ['sonos', 'kaiutin', 'speaker', 'soundbar', 'arc', 'beam', 'era', 'one', 'musiikki'],
    mdns: const ['_sonos._tcp'],
    helpFi: 'Sonos-sovellus → Asetukset → Järjestelmä → Tietoja järjestelmästäni → IP-osoite.',
    helpEn: 'Sonos app → Settings → System → About My System → IP address.',
  ),
  MediaProvider(
    id: 'media_roku',
    brand: 'roku',
    fi: 'Roku',
    en: 'Roku',
    descFi: 'Roku-soittimet ja Roku TV:t: näppäimet, ääni +/−, mykistys, toisto/tauko, avoin sovellus; Roku TV:ssä myös virta ja kanavat.',
    descEn: 'Roku players and Roku TVs: keys, volume +/−, mute, play/pause, the open app; on Roku TVs also power and channels.',
    keywords: const ['roku', 'roku tv', 'tcl', 'hisense', 'tv', 'televisio'],
    helpFi: 'Roku: Asetukset → Verkko → Tietoja → IP-osoite. Salli ohjaus: Asetukset → Järjestelmä → Järjestelmän lisäasetukset → Ohjaus mobiilisovelluksilla → Käytössä.',
    helpEn: 'Roku: Settings → Network → About → IP address. Allow control: Settings → System → Advanced system settings → Control by mobile apps → Enabled.',
  ),
];

class MediaChooser extends DeviceProvider {
  @override
  String get id => 'media';
  @override
  String get fi => 'TV ja Chromecast';
  @override
  String get en => 'TV and Chromecast';
  @override
  String get descFi =>
      'Samsung, LG, Philips, Android TV / Google TV, Chromecast, Sonos ja Roku: virta, ääni, kanavat ja toisto.';
  @override
  String get descEn =>
      'Samsung, LG, Philips, Android TV / Google TV, Chromecast, Sonos and Roku: power, volume, channels and playback.';
  @override
  String get category => 'media';
  @override
  List<String> get keywords => ['tv', 'televisio', 'media', for (final p in mediaProviders) ...p.keywords];
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

const mediaNotYet = <(String, String, String)>[
  (
    'Apple TV',
    'Ei vielä omaa integraatiota: Apple TV:n ohjaus vaatii HomeKit-tyyppisen parituksen ja salauksen (SRP, Ed25519, ChaCha20). Nyt: Home Assistantin kautta.',
    'No built-in integration yet: Apple TV control needs HomeKit-style pairing and encryption (SRP, Ed25519, ChaCha20). Today: via Home Assistant.',
  ),
];

MediaProvider? mediaProviderById(String id) => mediaProviders.where((p) => p.id == id).firstOrNull;
