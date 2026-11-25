import 'dart:async';

enum ErrorKind {
  dns,
  unreachable,
  refused,
  tls,
  auth,
  notFound,
  deviceError,
  modbusAddress,
  modbusFunction,
  modbusValue,
  modbusTimeout,
  noResponse,
  config,
  missingConnection,
  unknown,
}

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

ErrorKind classifyError(Object e) {
  final s = e.toString().toLowerCase();
  bool any(List<String> xs) => xs.any(s.contains);
  if (s.contains('connection missing') || s.contains('yhteys puuttuu')) return ErrorKind.missingConnection;
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
  if (any(['handshake', 'certificate', 'wrong version number', 'tlsv1'])) return ErrorKind.tls;
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
  final fi = lang == 'fi';
  final tech = e.toString().replaceFirst('Exception: ', '');
  final k = classifyError(e);
  String t(String a, String b) => fi ? a : b;
  switch (k) {
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
    case ErrorKind.unknown:
      return FriendlyError(
        k,
        t('Jokin meni pieleen', 'Something went wrong'),
        t('Tarkista asetukset ja yritä uudelleen.', 'Check the settings and try again.'),
        tech,
      );
  }
}
