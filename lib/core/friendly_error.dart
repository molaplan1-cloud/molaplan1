import 'dart:async';

import '../l10n/l10n.dart';

enum ErrorKind {
  dns,
  unreachable,
  refused,
  tls,
  auth,
  notFound,
  deviceError,
  wrongProtocol,
  modbusAddress,
  modbusFunction,
  modbusValue,
  modbusTimeout,
  modbusPortClosed,
  modbusHostUnreachable,
  modbusConnectTimeout,
  modbusGateway,
  modbusBlocked,
  modbusNoHost,
  modbusBusy,
  noResponse,
  config,
  missingConnection,
  remoteBridgeOffline,
  remoteNoInternet,
  remoteNotPaired,
  remoteTimeout,
  pairBadCode,
  pairRejected,
  pairTampered,
  pairTimeout,
  cloudOffline,
  cloudService,
  cloudAuth,
  unknown,
}

/// Connection types that are internet services, never devices on the home network (t151u):
/// their errors never get LAN / IP / "turn on remote access" hints.
const cloudConnectionTypes = {'price', 'weather', 'shelly_cloud', 'ntfy', 'airthings'};

/// Plain service names for [cloudConnectionTypes].
(String, String) cloudServiceName(String type) => switch (type) {
  'price' => ('Hintapalvelu', 'The price service'),
  'weather' => ('Sääpalvelu', 'The weather service'),
  'shelly_cloud' => ('Shelly Cloud', 'Shelly Cloud'),
  'ntfy' => ('ntfy-palvelin', 'The ntfy server'),
  'airthings' => ('Airthings-pilvi', 'The Airthings cloud'),
  _ => ('Palvelu', 'The service'),
};

/// A failed internet service (price, weather, Shelly Cloud, ntfy): offline, service down or a
/// rejected login. [tech] keeps the exact reason (every source tried) for "Tekniset tiedot".
class CloudError implements Exception {
  const CloudError(this.kind, this.serviceFi, this.serviceEn, this.tech, {this.fallbackTried = false});
  final ErrorKind kind;
  final String serviceFi, serviceEn, tech;

  /// Backup sources were tried too (price).
  final bool fallbackTried;

  /// Prefix keeps the kind when only the text survives (tile errors, bridge answers).
  @override
  String toString() => '${kind.name}: $serviceEn: $tech';
}

/// For a cloud connection [type]: network / HTTP / login failures become a [CloudError]; errors
/// that already explain themselves (e.g. "device offline in Shelly Cloud") are kept.
Object cloudMapped(Object e, String type) {
  if (!cloudConnectionTypes.contains(type) || e is CloudError || e is PlainError) return e;
  final low = e.toString().toLowerCase();
  if (low.contains('device offline') ||
      low.contains('not found in shelly cloud') ||
      low.contains('not available through')) {
    return e;
  }
  final k = classifyError(e);
  if (awayKinds.contains(k) ||
      k == ErrorKind.deviceError ||
      k == ErrorKind.tls ||
      k == ErrorKind.auth ||
      k == ErrorKind.unknown) {
    final (fi, en) = cloudServiceName(type);
    return cloudErrorFrom(e, fi, en);
  }
  return e;
}

/// Maps any failure of an internet service to a [CloudError] (no network → cloudOffline,
/// a rejected login → cloudAuth, everything else – timeouts, 5xx, 429, odd data → cloudService).
CloudError cloudErrorFrom(Object e, String serviceFi, String serviceEn, {bool fallbackTried = false}) {
  if (e is CloudError) return e;
  final s = e.toString().toLowerCase();
  final tech = e.toString().replaceFirst('Exception: ', '');
  bool any(List<String> xs) => xs.any(s.contains);
  final kind =
      any([
        'failed host lookup',
        'no address associated',
        'name or service not known',
        'nodename nor servname',
        'no such host',
        'errno = 11001',
        'network is unreachable',
        'network is down',
        'errno = 101',
        'errno = 10051',
        'errno = 10065',
        'no internet',
      ])
      ? ErrorKind.cloudOffline
      : (any([' 401', ' 403', 'unauthorized', 'invalid token', 'forbidden', 'wrong_credentials'])
            ? ErrorKind.cloudAuth
            : ErrorKind.cloudService);
  return CloudError(kind, serviceFi, serviceEn, tech, fallbackTried: fallbackTried);
}

/// Errors that mean "can't reach the device from here" – remote access would help.
const awayKinds = {
  ErrorKind.dns,
  ErrorKind.unreachable,
  ErrorKind.refused,
  ErrorKind.modbusTimeout,
  ErrorKind.modbusHostUnreachable,
  ErrorKind.modbusConnectTimeout,
  ErrorKind.noResponse,
};

/// A plain-language explanation of a failure, for people who are not techies.
class FriendlyError {
  final ErrorKind kind;
  final String title;
  final String hint;
  final String technical;
  const FriendlyError(this.kind, this.title, this.hint, this.technical);
  @override
  String toString() => '$title. $hint';
}

/// An error that already carries plain-language wording (e.g. the Home Assistant setup probe).
class PlainError implements Exception {
  const PlainError(this.kind, this.titleFi, this.titleEn, this.hintFi, this.hintEn, this.tech);
  final ErrorKind kind;
  final String titleFi, titleEn, hintFi, hintEn, tech;
  @override
  String toString() => '$titleFi ($tech)';
}

ErrorKind classifyError(Object e) {
  if (e is PlainError) return e.kind;
  if (e is CloudError) return e.kind;
  final s = e.toString().toLowerCase();
  for (final k in const [ErrorKind.cloudOffline, ErrorKind.cloudService, ErrorKind.cloudAuth]) {
    if (s.startsWith('${k.name.toLowerCase()}: ')) return k;
  }
  bool any(List<String> xs) => xs.any(s.contains);
  if (s.contains('connection missing') || s.contains('yhteys puuttuu')) return ErrorKind.missingConnection;
  if (s.startsWith('remote: ')) {
    if (s.contains('bridge_offline')) return ErrorKind.remoteBridgeOffline;
    if (s.contains('not_paired')) return ErrorKind.remoteNotPaired;
    if (s.contains('timeout')) return ErrorKind.remoteTimeout;
    return ErrorKind.remoteNoInternet;
  }
  if (s.startsWith('pairing failed: ')) {
    if (any(['unknown_code', 'bad_code', 'expired', 'bad_request'])) return ErrorKind.pairBadCode;
    if (s.contains('rejected')) return ErrorKind.pairRejected;
    if (s.contains('tampered')) return ErrorKind.pairTampered;
    if (s.contains('timeout')) return ErrorKind.pairTimeout;
    if (s.contains('bridge_offline')) return ErrorKind.remoteBridgeOffline;
    return ErrorKind.remoteNoInternet;
  }
  if (s.contains('modbus: blocked until')) return ErrorKind.modbusBlocked;
  if (s.contains('modbus: no host')) return ErrorKind.modbusNoHost;
  if (s.contains('modbus: closed') ||
      (s.contains('modbus') && (s.contains('connection reset') || s.contains('reset by peer')))) {
    return ErrorKind.modbusBusy;
  }
  if (s.contains('modbus tcp: port closed')) return ErrorKind.modbusPortClosed;
  if (s.contains('modbus tcp: host unreachable')) return ErrorKind.modbusHostUnreachable;
  if (s.contains('modbus tcp: connect timeout') || s.contains('modbus tcp: cannot connect')) {
    return ErrorKind.modbusConnectTimeout;
  }
  if (s.contains('modbus exception 10') || s.contains('modbus exception 11')) return ErrorKind.modbusGateway;
  if (s.contains('modbus exception 2')) return ErrorKind.modbusAddress;
  if (s.contains('modbus exception 1')) return ErrorKind.modbusFunction;
  if (s.contains('modbus exception 3')) return ErrorKind.modbusValue;
  if (s.contains('modbus: timeout')) return ErrorKind.modbusTimeout;
  if (any([
    'failed host lookup',
    'no address associated',
    'name or service not known',
    'nodename nor servname',
    'cannot resolve',
    'no such host',
    'errno = 11001',
  ])) {
    return ErrorKind.dns;
  }
  // Something answered, but not with HTTP (e.g. https server asked over http, or not a web server).
  if (any([
    'invalid response line',
    'invalid response status',
    'invalid http',
    'connection closed before full header',
    'wrong version number',
  ])) {
    return ErrorKind.wrongProtocol;
  }
  if (any(['handshake', 'certificate', 'tlsv1'])) return ErrorKind.tls;
  if (any(['connection refused', 'errno = 111', 'errno = 10061', 'actively refused'])) return ErrorKind.refused;
  if (any([
    ' 401',
    ' 403',
    'unauthorized',
    'invalid token',
    'badusernameorpassword',
    'notauthorized',
    'bad user name',
    'forbidden',
  ])) {
    return ErrorKind.auth;
  }
  if (any([
    'no route to host',
    'network is unreachable',
    'host is unreachable',
    'errno = 113',
    'errno = 101',
    'errno = 10065',
    'errno = 10051',
    'errno = 10060',
    'timed out',
    'timeout',
    'connection attempt cancelled',
    'semaphore timeout',
    'network is down',
  ])) {
    return ErrorKind.unreachable;
  }
  if (e is TimeoutException) return ErrorKind.unreachable;
  if (any([' 404', 'not found'])) return ErrorKind.notFound;
  if (RegExp(r'http 5\d\d').hasMatch(s)) return ErrorKind.deviceError;
  if (any(['no response', 'stream ended'])) return ErrorKind.noResponse;
  if (e is FormatException ||
      any([
        'formatexception',
        'not a number',
        'must be domain.service',
        'invalid argument',
        'no host specified',
        'unsupported scheme',
      ])) {
    return ErrorKind.config;
  }
  return ErrorKind.unknown;
}

FriendlyError friendlyError(Object e, String lang) {
  final tech = e.toString().replaceFirst('Exception: ', '');
  final k = classifyError(e);
  String t(String a, String b) => tr(lang, a, b);
  if (e is PlainError) return FriendlyError(k, t(e.titleFi, e.titleEn), t(e.hintFi, e.hintEn), e.tech);
  final c = e is CloudError ? e : null;
  // One placeholder for both languages (the l10n extractor matches them by expression).
  final svc = t(c?.serviceFi ?? 'Palvelu', c?.serviceEn ?? 'The service');
  final cloudTech = c?.tech ?? tech;
  switch (k) {
    case ErrorKind.cloudOffline:
      return FriendlyError(
        k,
        t('Ei nettiyhteyttä', 'No internet connection'),
        t(
          '$svc on internetissä, eikä siihen saatu yhteyttä. Tarkista tämän laitteen nettiyhteys. Viimeisimmät tiedot näytetään, kun niitä on.',
          '$svc is on the internet and could not be reached. Check this device\'s internet connection. The latest data is shown when available.',
        ),
        cloudTech,
      );
    case ErrorKind.cloudService:
      return FriendlyError(
        k,
        c?.fallbackTried == true
            ? t('$svc ei vastaa, yritetään varalähdettä', '$svc is not answering, trying a backup source')
            : t('$svc ei vastaa', '$svc is not answering'),
        c?.fallbackTried == true
            ? t(
                'Myöskään varalähteistä ei saatu tietoja juuri nyt. Vika on todennäköisesti palveluissa, ei kotiverkossasi. Yritetään automaattisesti uudelleen.',
                'The backup sources did not answer right now either. The problem is most likely at the services, not your home network. Retrying automatically.',
              )
            : t(
                'Palvelussa on häiriö. Vika on todennäköisesti palvelussa, ei kotiverkossasi. Yritetään automaattisesti uudelleen.',
                'The service has a problem, most likely at the service and not your home network. Retrying automatically.',
              ),
        cloudTech,
      );
    case ErrorKind.cloudAuth:
      return FriendlyError(
        k,
        t('Kirjautuminen palveluun ei onnistunut', 'Signing in to the service failed'),
        t('Tarkista palvelun tunnus, avain tai token ($svc).', 'Check the account, key or token for $svc.'),
        cloudTech,
      );
    case ErrorKind.wrongProtocol:
      return FriendlyError(
        k,
        t(
          'Osoitteessa ei vastaa odotettu laite – tarkista osoite (http vai https?)',
          'The expected device does not answer at this address – check it (http or https?)',
        ),
        t(
          'Osoitteessa vastaa jokin, mutta ei odotetulla tavalla. Kokeile https:// tai http:// osoitteen alkuun ja tarkista portti.',
          'Something answers, but not as expected. Try https:// or http:// in front and check the port.',
        ),
        tech,
      );
    case ErrorKind.dns:
      return FriendlyError(
        k,
        t('Osoitetta ei löydy', 'Address not found'),
        t(
          'Tarkista osoitteen kirjoitusasu. Kokeile IP-osoitetta (esim. 192.168.1.50) nimen sijaan.',
          'Check the spelling. Try the IP address (e.g. 192.168.1.50) instead of a name.',
        ),
        tech,
      );
    case ErrorKind.unreachable:
      return FriendlyError(
        k,
        t('Laitetta ei löydy osoitteesta', 'Device not found at this address'),
        t(
          'Tarkista että laite on päällä ja että puhelin tai PC on samassa wifissä. Tarkista myös IP-osoite – se voi vaihtua, joten varaa laitteelle kiinteä osoite reitittimestä.',
          'Check that the device is on and that your phone or PC is on the same Wi-Fi. Also check the IP address – it can change, so reserve a fixed address in your router.',
        ),
        tech,
      );
    case ErrorKind.refused:
      return FriendlyError(
        k,
        t('Laite löytyi, mutta ei vastaa tähän porttiin', 'Device found but the port is closed'),
        t(
          'Tarkista portin numero ja että palvelu (esim. web-käyttöliittymä, MQTT tai Modbus TCP) on laitteessa päällä.',
          'Check the port number and that the service (web UI, MQTT or Modbus TCP) is enabled on the device.',
        ),
        tech,
      );
    case ErrorKind.tls:
      return FriendlyError(
        k,
        t('Suojattu yhteys (https) epäonnistui', 'Secure connection (https) failed'),
        t(
          'Kokeile osoitetta http:// -alkuisena, tai Lisäasetuksista "Salli itse allekirjoitettu sertifikaatti".',
          'Try http:// instead, or enable "Allow self-signed certificate" under Advanced.',
        ),
        tech,
      );
    case ErrorKind.auth:
      return FriendlyError(
        k,
        t('Tunnus, salasana tai token ei kelpaa', 'Login, password or token rejected'),
        t(
          'Tarkista tunnukset. Home Assistantissa voit luoda uuden pitkäikäisen tunnuksen omasta profiilista.',
          'Check the credentials. In Home Assistant you can create a new long-lived token in your profile.',
        ),
        tech,
      );
    case ErrorKind.notFound:
      return FriendlyError(
        k,
        t('Laite vastasi, mutta kohdetta ei löytynyt', 'Device answered but the item was not found'),
        t(
          'Tarkista polku tai entiteetin nimi (esim. light.olohuone). Isot ja pienet kirjaimet ovat merkitseviä.',
          'Check the path or entity name (e.g. light.living_room).',
        ),
        tech,
      );
    case ErrorKind.deviceError:
      return FriendlyError(
        k,
        t('Laitteessa tapahtui virhe', 'The device reported an error'),
        t(
          'Komento tai kysely ei kelvannut laitteelle. Tarkista polku ja lähetettävä sisältö.',
          'Check the path and payload.',
        ),
        tech,
      );
    case ErrorKind.modbusAddress:
      return FriendlyError(
        k,
        t('Laite ei tunne tätä rekisteriä', 'Unknown register on the device'),
        t(
          'Tarkista rekisterin numero laitteen Modbus-taulukosta. Jos taulukko alkaa 1:stä (esim. 40001), vähennä 1. Tarkista myös holding/input-valinta.',
          'Check the register number. If the table starts at 1 (e.g. 40001), subtract 1. Also check holding vs input.',
        ),
        tech,
      );
    case ErrorKind.modbusFunction:
      return FriendlyError(
        k,
        t('Laite ei tue tätä rekisterityyppiä', 'Register type not supported'),
        t('Kokeile toista rekisterityyppiä (holding ↔ input).', 'Try the other register type (holding ↔ input).'),
        tech,
      );
    case ErrorKind.modbusValue:
      return FriendlyError(
        k,
        t('Laite ei hyväksynyt arvoa', 'Value rejected by the device'),
        t(
          'Arvo on luultavasti sallitun alueen ulkopuolella. Tarkista myös kerroin.',
          'The value is probably out of range. Check the scale too.',
        ),
        tech,
      );
    case ErrorKind.modbusPortClosed:
      return FriendlyError(
        k,
        t('Laite löytyi, mutta Modbus TCP ei ole päällä', 'Device found, but Modbus TCP is off'),
        t(
          'Osoitteessa on laite, mutta se ei ota vastaan Modbus-yhteyttä tähän porttiin. Laita Modbus TCP päälle laitteen asetuksista (usein valikossa Verkko / Modbus / Etäohjaus) ja tarkista portti (yleensä 502). Voit myös painaa "Skannaa Modbus". Jos laite toimii Home Assistantissa, sillä voi olla jo yhteys (moni laite sallii vain yhden) – lue arvot HA:n kautta.',
          'There is a device at this address, but it does not accept Modbus on this port. Turn on Modbus TCP in the device settings (often under Network / Modbus / Remote control) and check the port (usually 502). You can also tap "Scan Modbus". If the device works in Home Assistant, it may already have a connection (many allow only one) – read the values through HA.',
        ),
        tech,
      );
    case ErrorKind.modbusBlocked:
      final at = RegExp(r'blocked until (\d\d:\d\d)').firstMatch(tech)?.group(1) ?? '';
      return FriendlyError(
        k,
        t('Laite on estotilassa, yritetään uudelleen klo $at', 'The device is in lockout, retrying at $at'),
        t(
          'Laite ei vastannut, joten sitä ei kysytä hetkeen – moni laite menee estotilaan, jos sitä kysytään liian usein. Tauko pitenee 30 sekunnista 5 minuuttiin. Jos laitteella on jo yhteys (esim. Home Assistant), lue arvot HA:n kautta. Lukuvälin ja tauot voi muuttaa yhteyden kohdasta Edistyneet.',
          'The device did not answer, so it is left alone for a while – many devices lock out clients that poll too often. The pause grows from 30 seconds to 5 minutes. If the device already has a connection (e.g. Home Assistant), read the values through HA. The read interval and pauses are under Advanced in the connection.',
        ),
        tech,
      );
    case ErrorKind.modbusNoHost:
      return FriendlyError(
        k,
        t('Laitteen osoite puuttuu', 'The device address is missing'),
        t(
          'Avaa yhteys ja anna laitteen IP-osoite, tai paina "Skannaa Modbus", niin sovellus etsii laitteen verkosta.',
          'Open the connection and enter the device IP address, or tap "Scan Modbus" to find the device on the network.',
        ),
        tech,
      );
    case ErrorKind.modbusBusy:
      return FriendlyError(
        k,
        t('Laitteella voi olla jo yhteys', 'The device may already have a connection'),
        t(
          'Laite katkaisi Modbus-yhteyden heti. Moni laite sallii vain yhden Modbus TCP -yhteyden kerrallaan. Jos laite on jo Home Assistantissa (esim. modbus.yaml), lue arvot HA:n kautta.',
          'The device dropped the Modbus connection right away. Many devices allow only one Modbus TCP connection at a time. If the device is already in Home Assistant (e.g. modbus.yaml), read the values through HA.',
        ),
        tech,
      );
    case ErrorKind.modbusHostUnreachable:
      return FriendlyError(
        k,
        t('Osoitteessa ei ole laitetta', 'Nothing at this address'),
        t(
          'Tähän IP-osoitteeseen ei saatu yhteyttä. Tarkista että laite on päällä ja samassa verkossa, ja että IP-osoite on oikein (se voi vaihtua – varaa reitittimestä kiinteä osoite). "Skannaa Modbus" etsii laitteet verkosta.',
          'Nothing answered at this IP address. Check that the device is on and in the same network and that the IP is right (it can change – reserve a fixed address in the router). "Scan Modbus" finds devices on the network.',
        ),
        tech,
      );
    case ErrorKind.modbusConnectTimeout:
      return FriendlyError(
        k,
        t('Modbus-laite ei vastannut ajoissa', 'The Modbus device did not answer in time'),
        t(
          'Yhteyttä porttiin ei saatu muodostettua. Yleisimmät syyt: väärä IP-osoite, laite on toisessa verkossa (vieras-wifi), Modbus TCP ei ole päällä tai palomuuri estää portin. Tarkista osoite ja portti tai paina "Skannaa Modbus".',
          'Could not open the port. Most common causes: wrong IP, the device is in another network (guest Wi-Fi), Modbus TCP is off or a firewall blocks the port. Check the address and port or tap "Scan Modbus".',
        ),
        tech,
      );
    case ErrorKind.modbusGateway:
      return FriendlyError(
        k,
        t('Yhdyskäytävä ei tavoita laitetta tällä unit id:llä', 'The gateway cannot reach a device with this unit id'),
        t(
          'Modbus-yhdyskäytävä vastasi, mutta sen takana ei ole laitetta tällä osoitteella (unit id). Tarkista laitteen Modbus-osoite (usein 1) sekä sarjaportin nopeus ja pariteetti. "Skannaa Modbus" kokeilee osoitteet 1–247.',
          'The Modbus gateway answered, but no device with this unit id is behind it. Check the device\'s Modbus address (often 1) and the serial speed and parity. "Scan Modbus" tries addresses 1–247.',
        ),
        tech,
      );
    case ErrorKind.modbusTimeout:
      return FriendlyError(
        k,
        t('Laite ei vastannut Modbus-kyselyyn', 'No Modbus reply'),
        t(
          'Yhteys aukesi, mutta vastausta ei tullut. Tarkista laitteen osoite (unit id, usein 1) ja yhdyskäytävän sarjaportin asetukset.',
          'Connected but no reply. Check the unit id (often 1) and the gateway serial settings.',
        ),
        tech,
      );
    case ErrorKind.noResponse:
      return FriendlyError(
        k,
        t('Laite ei vastannut', 'No reply from the device'),
        t(
          'Yhteys toimi, mutta vastausta ei tullut ajoissa. Tarkista lähetettävä viesti.',
          'Connected but no reply in time. Check the message.',
        ),
        tech,
      );
    case ErrorKind.config:
      return FriendlyError(
        k,
        t('Asetuksissa on virhe', 'There is a mistake in the settings'),
        t(
          'Tarkista kentät, esim. että osoite alkaa http:// ja että numerot ovat numeroita.',
          'Check the fields, e.g. that the address starts with http:// and numbers are numbers.',
        ),
        tech,
      );
    case ErrorKind.missingConnection:
      return FriendlyError(
        k,
        t('Ruudulta puuttuu laite', 'This tile has no device'),
        t(
          'Avaa muokkaus (kynä) ja valitse ruudulle laite.',
          'Open edit mode (pencil) and choose a device for the tile.',
        ),
        tech,
      );
    case ErrorKind.remoteBridgeOffline:
      return FriendlyError(
        k,
        t('Kotisilta ei ole päällä', 'The home bridge is off'),
        t(
          'Etäyhteys kulkee kotona olevan sillan (tabletti tai PC) kautta. Tarkista että se on päällä, Molaplan on auki ja sillä on netti.',
          'Remote access goes through the bridge at home (tablet or PC). Check that it is on, Molaplan is open and it has internet.',
        ),
        tech,
      );
    case ErrorKind.remoteNoInternet:
      return FriendlyError(
        k,
        t('Ei nettiyhteyttä', 'No internet connection'),
        t(
          'Laitteesi ei saa yhteyttä Molaplanin etäpalveluun. Tarkista mobiilidata tai wifi.',
          'Your device cannot reach the Molaplan remote service. Check mobile data or Wi-Fi.',
        ),
        tech,
      );
    case ErrorKind.remoteNotPaired:
      return FriendlyError(
        k,
        t('Etäyhteys on poistettu', 'Remote access was removed'),
        t(
          'Tämä laite on poistettu kotisillalta. Yhdistä uudelleen: Asetukset → Etäyhteys.',
          'This device was removed on the home bridge. Pair again: Settings → Remote access.',
        ),
        tech,
      );
    case ErrorKind.remoteTimeout:
      return FriendlyError(
        k,
        t('Kotisilta ei vastannut ajoissa', 'The home bridge did not answer in time'),
        t(
          'Yhteys voi olla hidas. Yritä hetken päästä uudelleen.',
          'The connection may be slow. Try again in a moment.',
        ),
        tech,
      );
    case ErrorKind.pairBadCode:
      return FriendlyError(
        k,
        t('Koodi ei kelpaa', 'The code is not valid'),
        t(
          'Tarkista 6 numeroa kotisillan näytöltä. Koodi on voimassa 10 minuuttia ja kelpaa kerran – paina tarvittaessa sillalla "Yhdistä puhelin" uudelleen.',
          'Check the 6 digits on the bridge screen. A code is valid for 10 minutes and works once – press "Pair a phone" on the bridge again if needed.',
        ),
        tech,
      );
    case ErrorKind.pairRejected:
      return FriendlyError(
        k,
        t('Kotisilta ei hyväksynyt laitetta', 'The bridge did not accept this device'),
        t(
          'Kun yhdistät koodilla, sillan näytölle tulee kysymys – paina siellä "Hyväksy". Tai skannaa QR-koodi, silloin hyväksyntää ei tarvita.',
          'When pairing with the code, the bridge asks for confirmation – press "Accept" there. Or scan the QR code, then no confirmation is needed.',
        ),
        tech,
      );
    case ErrorKind.pairTampered:
      return FriendlyError(
        k,
        t('Turvatarkistus epäonnistui', 'Security check failed'),
        t(
          'Yhteyttä ei voitu varmistaa turvalliseksi, joten sitä ei otettu käyttöön. Yritä uudelleen QR-koodilla.',
          'The connection could not be verified as safe, so it was not used. Try again with the QR code.',
        ),
        tech,
      );
    case ErrorKind.pairTimeout:
      return FriendlyError(
        k,
        t('Kotisilta ei vastannut', 'The bridge did not answer'),
        t(
          'Hyväksy laite sillan näytöllä 3 minuutin sisällä, tai skannaa QR-koodi.',
          'Accept the device on the bridge screen within 3 minutes, or scan the QR code.',
        ),
        tech,
      );
    case ErrorKind.unknown:
      return FriendlyError(
        k,
        t('Yhteys ei onnistunut', 'The connection did not work'),
        t(
          'Tarkista osoite ja asetukset ja yritä uudelleen. Tarkempi syy näkyy teknisissä tiedoissa.',
          'Check the address and settings and try again. The technical details show the exact reason.',
        ),
        tech,
      );
  }
}
