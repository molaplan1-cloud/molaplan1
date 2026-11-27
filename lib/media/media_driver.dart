/// Connection type `media` (R290): TVs and Cast devices.
///
/// read {'media': 'status' | 'power' | 'volume' | 'muted' | 'app' | 'title' | 'playing' | 'info'}
/// send {'media': 'power' | 'volume' | 'mute', 'value': '{{value}}'}, {'media': 'key', 'key': 'play' …},
/// {'media': 'channel', 'value': '5'} or {'media': 'launch', 'value': 'app link'} (Android TV)
library;

import '../core/fields.dart';
import '../drivers/driver.dart';
import '../models/models.dart';
import 'android_tv.dart';
import 'cast.dart';
import 'lg_webos.dart';
import 'media_model.dart';
import 'philips_tv.dart';
import 'roku.dart';
import 'samsung_tv.dart';
import 'sonos.dart';

const mediaBrands = <String, (String, String)>{
  'cast': ('Chromecast / Google TV / Android TV (Cast)', 'Chromecast / Google TV / Android TV (Cast)'),
  'samsung': ('Samsung Smart TV (Tizen)', 'Samsung Smart TV (Tizen)'),
  'lg': ('LG Smart TV (webOS)', 'LG Smart TV (webOS)'),
  'philips': ('Philips TV (JointSPACE)', 'Philips TV (JointSPACE)'),
  'androidtv': ('Android TV / Google TV (kaukosäädin)', 'Android TV / Google TV (remote)'),
  'sonos': ('Sonos', 'Sonos'),
  'roku': ('Roku', 'Roku'),
};

/// Test hook: replaces the backend.
MediaBackend Function(Map<String, dynamic> s)? mediaTestBackend;

MediaBackend createMediaBackend(Map<String, dynamic> s) {
  final t = mediaTestBackend;
  if (t != null) return t(s);
  return switch ('${s['brand'] ?? ''}') {
    'cast' => CastBackend(s),
    'samsung' => SamsungBackend(s),
    'lg' => LgBackend(s),
    'philips' => PhilipsBackend(s),
    'androidtv' => AndroidTvBackend(s),
    'sonos' => SonosBackend(s),
    'roku' => RokuBackend(s),
    final b => throw DriverException('Media: unknown brand "$b"'),
  };
}

bool _truthy(Object? v) {
  final s = '$v'.toLowerCase();
  return v == true || s == '1' || s == 'true' || s == 'on';
}

class MediaDriver extends Driver {
  MediaDriver(super.config);

  MediaBackend? _b;
  MediaBackend get backend => _b ??= createMediaBackend(s);
  (DateTime, MediaState)? _cache;
  Future<MediaState>? _pending;

  Future<MediaState> snapshot({bool fresh = false}) async {
    final c = _cache;
    if (!fresh && c != null && DateTime.now().difference(c.$1) < const Duration(seconds: 3)) return c.$2;
    final p = _pending ??= backend.state();
    try {
      final v = await p;
      _cache = (DateTime.now(), v);
      return v;
    } finally {
      _pending = null;
    }
  }

  static const descriptor = DriverDescriptor(
    type: 'media',
    fi: 'Televisio / Chromecast (oma integraatio)',
    en: 'TV / Chromecast (built-in integration)',
    create: MediaDriver.new,
    connectionFields: [
      FieldSpec(
        'brand',
        'Merkki',
        'Brand',
        kind: FieldKind.choice,
        options: ['cast', 'samsung', 'lg', 'philips', 'androidtv', 'sonos', 'roku'],
        optionLabels: mediaBrands,
        defaultValue: 'cast',
        helpFi: 'Android TV:t ja Google TV:t: Cast (tila, ääni, toisto) tai kaukosäädin-yhteys (näppäimet, kanavat, virta; paritus koodilla).',
        helpEn: 'Android TVs and Google TVs: Cast (status, volume, playback) or the remote protocol (keys, channels, power; pairing code).',
      ),
      FieldSpec(
        'address',
        'IP-osoite',
        'IP address',
        hint: '192.168.x.x',
        helpFi: 'Laitteen IP-osoite (reitittimen laitelistasta). Anna reitittimessä kiinteä osoite.',
        helpEn: 'The device IP address (router device list). Reserve a fixed address in the router.',
      ),
      FieldSpec(
        'mac',
        'MAC-osoite (käynnistys)',
        'MAC address (power on)',
        hint: 'AA:BB:CC:DD:EE:FF',
        advanced: true,
        helpFi: 'Wake-on-LAN-käynnistykseen. Täyttyy yleensä itse; TV:n asetuksissa "Käynnistä verkon kautta" päälle.',
        helpEn: 'For Wake-on-LAN power on. Usually filled in automatically; enable "Turn on via network" on the TV.',
      ),
      FieldSpec(
        'api',
        'JointSPACE-versio (Philips)',
        'JointSPACE version (Philips)',
        kind: FieldKind.number,
        advanced: true,
        helpFi: 'Tunnistetaan itse: 6 = Android-TV:t (https 1926), 1 = vanhat (http 1925).',
        helpEn: 'Detected automatically: 6 = Android TVs (https 1926), 1 = older sets (http 1925).',
      ),
      FieldSpec(
        'username',
        'Paritustunnus (Philips)',
        'Pairing id (Philips)',
        advanced: true,
        helpFi: 'Syntyy parituksessa (PIN-koodi televisiosta).',
        helpEn: 'Created during pairing (PIN code from the TV).',
      ),
      FieldSpec(
        'password',
        'Paritusavain (Philips)',
        'Pairing key (Philips)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Syntyy parituksessa. Tallentuu vain tälle laitteelle.',
        helpEn: 'Created during pairing. Stored on this device only.',
      ),
      FieldSpec(
        'token',
        'Yhteystunnus (Samsung)',
        'Access token (Samsung)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Samsung antaa tunnuksen, kun hyväksyt yhteyden televisiosta. Tallentuu vain tälle laitteelle.',
        helpEn: 'Samsung returns it when you allow the connection on the TV. Stored on this device only.',
      ),
      FieldSpec(
        'clientKey',
        'Asiakasavain (LG)',
        'Client key (LG)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'LG antaa avaimen, kun hyväksyt yhteyden televisiosta. Tallentuu vain tälle laitteelle.',
        helpEn: 'LG returns it when you accept the connection on the TV. Stored on this device only.',
      ),
      FieldSpec(
        'atvCert',
        'Asiakasvarmenne (Android TV)',
        'Client certificate (Android TV)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Molaplanin oma varmenne, jonka televisio hyväksyi parituksessa. Tallentuu vain tälle laitteelle.',
        helpEn: "Molaplan's own certificate that the TV accepted during pairing. Stored on this device only.",
      ),
      FieldSpec(
        'atvKey',
        'Asiakasavain (Android TV)',
        'Client key (Android TV)',
        kind: FieldKind.secret,
        advanced: true,
        helpFi: 'Varmenteen yksityinen avain. Tallentuu vain tälle laitteelle.',
        helpEn: "The certificate's private key. Stored on this device only.",
      ),
    ],
    readFields: [
      FieldSpec(
        'media',
        'Lukema',
        'Reading',
        kind: FieldKind.choice,
        options: ['status', 'power', 'volume', 'muted', 'app', 'title', 'playing'],
        optionLabels: {
          'status': ('Tila (teksti)', 'Status (text)'),
          'power': ('Päällä (1/0)', 'On (1/0)'),
          'volume': ('Äänenvoimakkuus (%)', 'Volume (%)'),
          'muted': ('Mykistetty (1/0)', 'Muted (1/0)'),
          'app': ('Sovellus', 'App'),
          'title': ('Toistettava', 'Now playing'),
          'playing': ('Toistaa (1/0)', 'Playing (1/0)'),
        },
        defaultValue: 'status',
        helpFi: 'Chromecast ei kerro virtatilaa; "Päällä" on silloin aina 0.',
        helpEn: 'A Chromecast has no power state; "On" is then always 0.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'media',
        'Komento',
        'Command',
        kind: FieldKind.choice,
        options: ['power', 'volume', 'mute', 'key', 'channel', 'launch'],
        optionLabels: {
          'power': ('Virta päälle/pois (arvo 1/0)', 'Power on/off (value 1/0)'),
          'volume': ('Äänenvoimakkuus (arvo 0–100)', 'Volume (value 0–100)'),
          'mute': ('Mykistys (arvo 1/0)', 'Mute (value 1/0)'),
          'key': ('Näppäin', 'Key'),
          'channel': ('Kanava (arvo = numero)', 'Channel (value = number)'),
          'launch': ('Avaa sovellus (Android TV, arvo = linkki)', 'Open app (Android TV, value = link)'),
        },
        defaultValue: 'key',
        helpFi: 'Arvo tulee kytkimestä tai liukusäätimestä.',
        helpEn: 'The value comes from the toggle or slider.',
      ),
      FieldSpec(
        'key',
        'Näppäin',
        'Key',
        kind: FieldKind.choice,
        options: [
          'playpause',
          'play',
          'pause',
          'stop',
          'next',
          'prev',
          'volup',
          'voldown',
          'mute',
          'chup',
          'chdown',
          'up',
          'down',
          'left',
          'right',
          'ok',
          'home',
          'back',
          'power',
        ],
        optionLabels: {
          'next': ('Seuraava', 'Next'),
          'prev': ('Edellinen', 'Previous'),
          'mute': ('Mykistys päälle/pois', 'Mute on/off'),
          'chup': ('Kanava +', 'Channel +'),
          'chdown': ('Kanava −', 'Channel −'),
          'up': ('Ylös', 'Up'),
          'down': ('Alas', 'Down'),
          'left': ('Vasemmalle', 'Left'),
          'right': ('Oikealle', 'Right'),
          'ok': ('OK', 'OK'),
          'power': ('Virtanäppäin', 'Power key'),
          'playpause': ('Toista / tauko', 'Play / pause'),
          'play': ('Toista', 'Play'),
          'pause': ('Tauko', 'Pause'),
          'stop': ('Pysäytä', 'Stop'),
          'volup': ('Ääni kovemmalle', 'Volume up'),
          'voldown': ('Ääni hiljemmalle', 'Volume down'),
          'home': ('Kotinäkymä', 'Home'),
          'back': ('Takaisin', 'Back'),
        },
        defaultValue: 'playpause',
        helpFi: 'Vain komennolle "Näppäin".',
        helpEn: 'Only for the "Key" command.',
      ),
    ],
  );

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final k = '${spec['media'] ?? 'status'}';
    if (k == 'info') return (await backend.info()).toJson();
    return (await snapshot()).value(k);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final raw = spec['value'] == null || '${spec['value']}'.contains('{{') ? value : spec['value'];
    switch ('${spec['media'] ?? ''}') {
      case 'power':
        await backend.setPower(_truthy(spec['on'] ?? raw));
      case 'volume':
        final v = raw is num ? raw : num.tryParse('$raw');
        if (v == null) throw DriverException(dtx('Äänenvoimakkuus puuttuu', 'Volume missing'));
        await backend.setVolume(v);
      case 'mute':
        await backend.setMuted(_truthy(spec['on'] ?? raw));
      case 'key':
      case 'stop' || 'play' || 'pause' || 'playpause':
        await backend.key('${spec['key'] ?? spec['media']}');
      case 'channel':
        await backend.channel('${spec['channel'] ?? raw ?? ''}');
      case 'launch':
        final b = backend;
        if (b is! AndroidTvBackend) {
          throw DriverException(
            dtx(
              'Sovelluksen avaus toimii vain Android TV -yhteydellä',
              'Open app needs the Android TV remote connection',
            ),
          );
        }
        await b.launch('${spec['link'] ?? raw ?? ''}');
      default:
        throw DriverException('Media: unknown command "${spec['media']}"');
    }
    _cache = null;
    return true;
  }

  @override
  Future<String> test() async {
    final st = await snapshot(fresh: true);
    return [st.status, if (st.volume != null) '${dtx('ääni', 'volume')} ${st.volume} %'].join(' · ');
  }

  @override
  Future<void> dispose() async => _b?.close();
}

/// Tiles for one TV / Cast device.
List<TileConfig> mediaTiles(String connId, MediaInfo info, {required String title, String lang = 'fi'}) {
  String t(String fi, String en) => lang == 'fi' ? fi : en;
  TileConfig button(String fi, String en, String icon, String key) => TileConfig(
    type: TileType.button,
    title: '$title – ${t(fi, en)}',
    icon: icon,
    connectionId: connId,
    commands: [
      CommandStep(connectionId: connId, spec: {'media': 'key', 'key': key}),
    ],
  );
  return [
    TileConfig(
      type: TileType.value,
      title: '$title – ${t('tila', 'status')}',
      icon: 'tv',
      connectionId: connId,
      pollSeconds: 15,
      read: {'media': 'status'},
    ),
    if (info.caps.contains('power'))
      TileConfig(
        type: TileType.toggle,
        title: '$title – ${t('virta', 'power')}',
        icon: 'power',
        connectionId: connId,
        pollSeconds: 15,
        read: {'media': 'power'},
        onValue: '1',
        onCommand: CommandStep(connectionId: connId, spec: {'media': 'power', 'value': '1'}),
        offCommand: CommandStep(connectionId: connId, spec: {'media': 'power', 'value': '0'}),
      ),
    if (info.caps.contains('volume'))
      TileConfig(
        type: TileType.slider,
        title: '$title – ${t('äänenvoimakkuus', 'volume')}',
        icon: 'volume',
        unit: '%',
        min: 0,
        max: 100,
        step: 1,
        decimals: 0,
        connectionId: connId,
        pollSeconds: 15,
        read: {'media': 'volume'},
        commands: [
          CommandStep(connectionId: connId, spec: {'media': 'volume', 'value': '{{value}}'}),
        ],
      ),
    if (info.caps.contains('mute') && !info.caps.contains('volkeys'))
      TileConfig(
        type: TileType.toggle,
        title: '$title – ${t('mykistys', 'mute')}',
        icon: 'volume',
        connectionId: connId,
        pollSeconds: 15,
        read: {'media': 'muted'},
        onValue: '1',
        onCommand: CommandStep(connectionId: connId, spec: {'media': 'mute', 'value': '1'}),
        offCommand: CommandStep(connectionId: connId, spec: {'media': 'mute', 'value': '0'}),
      ),
    if (info.caps.contains('volkeys')) ...[
      button('ääni +', 'volume +', 'volume', 'volup'),
      button('ääni −', 'volume −', 'volume', 'voldown'),
    ],
    if (info.caps.contains('volkeys') && info.caps.contains('mute')) button('mykistys', 'mute', 'volume', 'mute'),
    if (info.caps.contains('playpause')) button('toista / tauko', 'play / pause', 'pause', 'playpause'),
    if (info.caps.contains('stop')) button('pysäytä', 'stop', 'stop', 'stop'),
    if (info.caps.contains('next')) button('seuraava', 'next', 'auto', 'next'),
    if (info.caps.contains('channels')) ...[
      button('kanava +', 'channel +', 'tv', 'chup'),
      button('kanava −', 'channel −', 'tv', 'chdown'),
    ],
  ];
}
