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
  unknown,
}

/// Errors that mean "can't reach the device from here" – remote access would help.
const awayKinds = {
  ErrorKind.dns,
  ErrorKind.unreachable,
  ErrorKind.refused,
  ErrorKind.modbusTimeout,
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
  final s = e.toString().toLowerCase();
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
  switch (k) {
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
