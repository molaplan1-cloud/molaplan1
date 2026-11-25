import 'fields.dart';

/// Plain-language help for every driver field + which ones are "advanced".
/// Key: `driver.section.key`, falling back to `*.section.key` and
/// `*.*.key`. Section is conn / read / cmd.
class FieldHelp {
  final String fi;
  final String en;
  final bool advanced;
  const FieldHelp(this.fi, this.en, {this.advanced = false});
}

const _h = <String, FieldHelp>{
  // ---- common
  '*.*.allowSelfSigned': FieldHelp('Vain jos laite käyttää https-osoitetta omalla sertifikaatilla.',
      'Only if the device uses https with its own certificate.',
      advanced: true),
  '*.*.timeoutSec': FieldHelp('Kauanko vastausta odotetaan. Oletus riittää yleensä.', 'How long to wait for an answer.',
      advanced: true),
  '*.*.timeoutMs': FieldHelp('Kauanko vastausta odotetaan millisekunteina (1000 = 1 s).', 'How long to wait, in milliseconds.',
      advanced: true),
  '*.*.headers': FieldHelp('Harvoin tarpeen. Esim. "X-Api-Key: 12345", yksi per rivi.',
      'Rarely needed. E.g. "X-Api-Key: 12345", one per line.',
      advanced: true),
  '*.*.username': FieldHelp('Jätä tyhjäksi, jos laite ei kysy tunnusta.', 'Leave empty if the device has no login.'),
  '*.*.password': FieldHelp('Tallennetaan suojattuun tallennustilaan.', 'Stored in secure storage.'),
  '*.*.token': FieldHelp('Tunnistusavain, jos laite vaatii sellaisen.', 'Access key, if the device requires one.'),
  '*.*.jsonPath': FieldHelp('Mikä kohta vastauksesta näytetään. Esim. "temperature" tai "data.temp". Tyhjä = koko vastaus.',
      'Which part of the reply to show, e.g. "temperature" or "data.temp". Empty = whole reply.'),
  '*.*.regex': FieldHelp('Edistynyt: poimi arvo tekstistä, esim. TEMP=([0-9.]+)', 'Advanced: extract a value with a regex.',
      advanced: true),
  '*.*.auth': FieldHelp('none = ei tunnistusta, basic = tunnus + salasana, bearer = token.',
      'none = no login, basic = username + password, bearer = token.'),
  // ---- http
  'http.conn.baseUrl': FieldHelp('Laitteen osoite selaimessa. Esim. http://192.168.1.50', 'The device address, e.g. http://192.168.1.50'),
  'http.read.method': FieldHelp('Lähes aina GET.', 'Almost always GET.', advanced: true),
  'http.read.path': FieldHelp('Osoitteen loppuosa, josta tila luetaan. Esim. /status', 'Path to read the state from, e.g. /status'),
  'http.read.body': FieldHelp('Vain POST-kyselyille.', 'Only for POST requests.', advanced: true),
  'http.cmd.method': FieldHelp('Useimmat laitteet: GET tai POST. Katso laitteen ohjeesta.', 'Usually GET or POST, see device docs.'),
  'http.cmd.path': FieldHelp('Komennon osoite. {{value}} korvautuu arvolla. Esim. /relay/0?turn=on',
      'Command path. {{value}} is replaced by the value.'),
  'http.cmd.body': FieldHelp('Lähetettävä sisältö (valinnainen). Esim. {"on": true}', 'Request body (optional).'),
  'http.cmd.contentType': FieldHelp('Lähetettävän sisällön tyyppi.', 'Body content type.', advanced: true),
  // ---- mqtt
  'mqtt.conn.host': FieldHelp('MQTT-välittäjän (esim. Mosquitto) IP-osoite. Esim. 192.168.1.10',
      'IP of the MQTT broker (e.g. Mosquitto).'),
  'mqtt.conn.port': FieldHelp('Yleensä 1883 (tai 8883 TLS:llä).', 'Usually 1883 (8883 with TLS).'),
  'mqtt.conn.tls': FieldHelp('Salattu yhteys. Vain jos välittäjä on määritetty TLS:lle.', 'Encrypted connection.', advanced: true),
  'mqtt.conn.websocket': FieldHelp('Vain jos välittäjä tarjoaa MQTT:n websocketin yli.', 'Only for MQTT over websocket.',
      advanced: true),
  'mqtt.conn.clientId': FieldHelp('Jätä tyhjäksi.', 'Leave empty.', advanced: true),
  'mqtt.conn.keepAlive': FieldHelp('Jätä oletukseksi.', 'Leave default.', advanced: true),
  'mqtt.read.topic': FieldHelp('Aihe, johon laite julkaisee tilansa. Esim. koti/olohuone/lampo',
      'Topic the device publishes its state to.'),
  'mqtt.cmd.topic': FieldHelp('Aihe, johon komento lähetetään. Esim. koti/valo/set', 'Topic to send the command to.'),
  'mqtt.cmd.payload': FieldHelp('Lähetettävä viesti. Esim. ON tai {"state":"ON"}. {{value}} = säätimen arvo.',
      'Message to send, e.g. ON. {{value}} = slider value.'),
  'mqtt.cmd.qos': FieldHelp('Jätä 0.', 'Leave 0.', advanced: true),
  'mqtt.cmd.retain': FieldHelp('Välittäjä muistaa viimeisen viestin.', 'Broker keeps the last message.', advanced: true),
  // ---- modbus
  'modbus.conn.host': FieldHelp('IV-koneen tai Modbus-yhdyskäytävän IP-osoite. Esim. 192.168.1.60',
      'IP of the unit or Modbus gateway.'),
  'modbus.conn.port': FieldHelp('Lähes aina 502.', 'Almost always 502.', advanced: true),
  'modbus.conn.unitId': FieldHelp('Laitteen Modbus-osoite, usein 1.', 'Device Modbus address, often 1.'),
  'modbus.read.table': FieldHelp('Katso laitteen Modbus-taulukosta: holding (4x), input (3x), coil (0x) tai discrete (1x).',
      'From the device register table: holding (4x), input (3x), coil (0x), discrete (1x).'),
  'modbus.read.address': FieldHelp('Rekisterin numero. Jos taulukko alkaa 1:stä (esim. 40001), vähennä 1.',
      'Register number. If the table starts at 1 (e.g. 40001), subtract 1.'),
  'modbus.read.dataType': FieldHelp('Yleensä uint16 tai int16 (miinusasteet).', 'Usually uint16 or int16 (negative temps).'),
  'modbus.read.swapWords': FieldHelp('Vain 32-bittisille arvoille, jos luku näyttää väärältä.', 'Only for 32-bit values.',
      advanced: true),
  'modbus.read.scale': FieldHelp('Kerroin. Esim. 0.1 jos laite antaa 215 tarkoittaen 21,5 °C.',
      'Multiplier, e.g. 0.1 if 215 means 21.5 °C.'),
  'modbus.read.offset': FieldHelp('Lisätään kertomisen jälkeen.', 'Added after scaling.', advanced: true),
  'modbus.read.unitId': FieldHelp('Vain jos tämä rekisteri on eri laitteessa.', 'Only if this register is on another device.',
      advanced: true),
  'modbus.cmd.table': FieldHelp('holding = numeroarvo, coil = päälle/pois.', 'holding = number, coil = on/off.'),
  'modbus.cmd.address': FieldHelp('Kirjoitettavan rekisterin numero.', 'Register number to write.'),
  'modbus.cmd.value': FieldHelp('Kirjoitettava arvo. {{value}} = säätimen tai kytkimen arvo.',
      'Value to write. {{value}} = slider/toggle value.'),
  'modbus.cmd.dataType': FieldHelp('Yleensä uint16.', 'Usually uint16.', advanced: true),
  'modbus.cmd.swapWords': FieldHelp('Vain 32-bittisille arvoille.', 'Only for 32-bit values.', advanced: true),
  'modbus.cmd.scale': FieldHelp('Sama kerroin kuin luettaessa (esim. 0.1).', 'Same scale as when reading.'),
  'modbus.cmd.offset': FieldHelp('Sama kuin luettaessa.', 'Same as when reading.', advanced: true),
  'modbus.cmd.unitId': FieldHelp('Vain jos eri laite.', 'Only if another device.', advanced: true),
  // ---- home assistant
  'homeassistant.conn.baseUrl': FieldHelp('Home Assistantin osoite. Esim. http://192.168.1.20:8123',
      'Home Assistant URL, e.g. http://192.168.1.20:8123'),
  'homeassistant.conn.token': FieldHelp('Home Assistant → oma profiili → Turvallisuus → Pitkäikäiset tunnukset → Luo tunnus.',
      'Home Assistant → profile → Security → Long-lived access tokens → Create.'),
  'homeassistant.conn.liveUpdates': FieldHelp('Tila päivittyy heti muutoksesta.', 'State updates instantly.', advanced: true),
  'homeassistant.read.entityId': FieldHelp('Löytyy HA:sta: Asetukset → Laitteet → Entiteetit. Esim. light.olohuone',
      'Find in HA: Settings → Devices → Entities. E.g. light.living_room'),
  'homeassistant.read.attribute': FieldHelp('Esim. current_temperature. Tyhjä = päätila.', 'E.g. current_temperature.',
      advanced: true),
  'homeassistant.cmd.service': FieldHelp('Mitä tehdään. Esim. light.turn_on, switch.toggle, climate.set_temperature',
      'What to do, e.g. light.turn_on'),
  'homeassistant.cmd.entityId': FieldHelp('Mitä laitetta ohjataan. Esim. light.olohuone', 'Which entity to control.'),
  'homeassistant.cmd.data': FieldHelp('Lisätiedot JSONina. Esim. {"temperature": {{value}}}', 'Extra data as JSON.',
      advanced: true),
  // ---- camera
  'camera.conn.baseUrl': FieldHelp('Kameran osoite. Esim. http://192.168.1.70', 'Camera address.'),
  'camera.read.mode': FieldHelp('mjpeg = liikkuva kuva, snapshot = still-kuva välein.', 'mjpeg = live video, snapshot = still images.'),
  'camera.read.path': FieldHelp('ESP32-CAM: :81/stream (video) tai /capture (kuva).', 'ESP32-CAM: :81/stream or /capture.'),
  'camera.read.refreshSeconds': FieldHelp('Kuinka usein still-kuva haetaan.', 'How often a snapshot is fetched.'),
  'camera.cmd.path': FieldHelp('Kameran ohjausosoite, esim. /control?var=led_intensity&val=255', 'Camera control URL.'),
  'camera.cmd.method': FieldHelp('Yleensä GET.', 'Usually GET.', advanced: true),
  // ---- websocket
  'websocket.conn.url': FieldHelp('Esim. ws://192.168.1.80/ws', 'E.g. ws://192.168.1.80/ws'),
  'websocket.conn.onConnect': FieldHelp('Lähetetään heti yhdistettäessä (valinnainen).', 'Sent on connect (optional).',
      advanced: true),
  'websocket.read.filter': FieldHelp('Näytä vain viestit, joissa on tämä teksti.', 'Only messages containing this text.'),
  'websocket.read.request': FieldHelp('Jos laite vastaa vasta kysyttäessä, kirjoita kysely tähän.',
      'If the device answers only when asked, enter the request.',
      advanced: true),
  'websocket.cmd.payload': FieldHelp('Lähetettävä viesti. {{value}} = arvo.', 'Message to send.'),
  // ---- tcp / udp
  '*.conn.host': FieldHelp('Laitteen IP-osoite. Esim. 192.168.1.90', 'Device IP address.'),
  '*.conn.port': FieldHelp('Laitteen portti, katso laitteen ohjeesta.', 'Device port, see device docs.'),
  '*.*.payload': FieldHelp('Lähetettävä teksti. \\r\\n = rivinvaihto. {{value}} = arvo.', 'Text to send. \\r\\n = newline.'),
  '*.*.hex': FieldHelp('Lähetä tavuina, esim. 01 03 00 00', 'Send as bytes, e.g. 01 03 00 00', advanced: true),
  '*.*.expectResponse': FieldHelp('Odotetaanko laitteelta vastausta.', 'Wait for a reply.', advanced: true),
  '*.*.responseHex': FieldHelp('Näytä vastaus tavuina.', 'Show reply as bytes.', advanced: true),
};

FieldHelp? helpFor(String driver, String section, String key) =>
    _h['$driver.$section.$key'] ?? _h['*.$section.$key'] ?? _h['*.*.$key'];

String? helpText(FieldSpec f, String lang, {String? scope}) {
  final own = f.ownHelp(lang);
  if (own != null) return own;
  if (scope == null) return null;
  final p = scope.split('.');
  final h = helpFor(p[0], p[1], f.key);
  if (h == null) return null;
  return lang == 'fi' ? h.fi : h.en;
}

bool isAdvanced(FieldSpec f, {String? scope}) {
  if (f.advanced != null) return f.advanced!;
  if (f.required || scope == null) return false;
  final p = scope.split('.');
  return helpFor(p[0], p[1], f.key)?.advanced ?? false;
}
