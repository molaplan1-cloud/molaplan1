/// R610–R619 (t331u): the 'Tilannekuva' of smart heating – what a heating device does now and WHY,
/// every rule with its state, the price against its limit, temperature against its limits, the next
/// change, and human-readable errors. Pure Dart: the home bridge builds the explanation next to the
/// decision (so the app shows the same state with the app closed), and the app builds the same
/// explanation locally as a preview when no bridge answers.
library;

import 'dart:math' as math;

import '../l10n/l10n.dart';
import 'smart_heating.dart';

// ------------------------------------------------------------------ text

/// Language-aware text helper: `t(fi, en)` picks the language, [n] formats numbers.
class HeatText {
  const HeatText(this.lang);
  final String lang;

  String t(String fi, String en) => tr(lang, fi, en);

  /// A number with [d] decimals and the language's decimal mark.
  String n(num v, [int d = 1]) {
    final s = v.toStringAsFixed(d);
    final x = d > 0 && s.endsWith('0' * d) ? s.substring(0, s.length - d - 1) : s;
    return lang == 'fi' || lang == 'sv' || lang == 'et' || lang == 'es' ? x.replaceFirst('.', ',') : x;
  }

  /// Local clock time 13.00 (Finnish style, 24 h).
  String hm(DateTime d) => '${d.hour.toString().padLeft(2, '0')}.${d.minute.toString().padLeft(2, '0')}';

  /// '2 h 15 min' / '40 min'.
  String span(Duration d) {
    final m = d.inMinutes;
    if (m < 1) return t('alle minuutti', 'under a minute');
    final h = m ~/ 60;
    final r = m % 60;
    if (h == 0) return '$m min';
    return r == 0 ? '$h h' : '$h h $r min';
  }
}

// ------------------------------------------------------------------ errors (R614)

enum HeatErrorKind { timeout, refused, unreachable, dns, auth, notFound, deviceError, noCommand, bridgeOffline, other }

/// A failure of a heating device or sensor in plain words; [raw] is kept for 'Tekniset tiedot'.
class HeatError {
  const HeatError(this.kind, this.raw, {this.seconds, this.status});
  final HeatErrorKind kind;
  final String raw;

  /// Timeout length when the failure says it.
  final int? seconds;

  /// HTTP status when the failure carries one.
  final int? status;

  /// 'Laite ei vastaa (aikakatkaisu 10 s)'.
  String text(HeatText x, {String subject = ''}) {
    final what = subject.isEmpty ? x.t('Laite', 'The device') : subject;
    return switch (kind) {
      HeatErrorKind.timeout =>
        seconds == null
            ? x.t('$what ei vastaa (yhteys aikakatkaistiin)', '$what is not responding (the connection timed out)')
            : x.t('$what ei vastaa (aikakatkaisu $seconds s)', '$what is not responding (timeout $seconds s)'),
      HeatErrorKind.refused => x.t(
        '$what ei ota yhteyttä vastaan (yhteys evätty)',
        '$what refuses the connection (connection refused)',
      ),
      HeatErrorKind.unreachable => x.t(
        '$what ei ole tavoitettavissa (verkkoyhteyttä ei ole)',
        '$what cannot be reached (no network route)',
      ),
      HeatErrorKind.dns => x.t('$what: osoitetta ei löydy', '$what: the address cannot be found'),
      HeatErrorKind.auth => x.t(
        '$what hylkäsi tunnuksen (HTTP ${status ?? 401})',
        '$what rejected the login (HTTP ${status ?? 401})',
      ),
      HeatErrorKind.notFound => x.t(
        '$what: osoite ei kelpaa (HTTP ${status ?? 404})',
        '$what: the address is not valid (HTTP ${status ?? 404})',
      ),
      HeatErrorKind.deviceError => x.t(
        '$what vastasi virheellä (HTTP ${status ?? 500})',
        '$what answered with an error (HTTP ${status ?? 500})',
      ),
      HeatErrorKind.noCommand => x.t('Laitteelle ei ole päälle/pois-komentoa', 'The device has no on/off command'),
      HeatErrorKind.bridgeOffline =>
        bridgeName.isEmpty
            ? x.t('Kotisilta ei ole yhteydessä', 'The home bridge is offline')
            : x.t('Kotisilta $bridgeName ei ole yhteydessä', 'The home bridge $bridgeName is offline'),
      HeatErrorKind.other => x.t('Ohjaus ei onnistunut', 'The control did not work'),
    };
  }

  /// R636: the bridge that does not answer ('bridge_offline:' and the name).
  String get bridgeName =>
      kind == HeatErrorKind.bridgeOffline && raw.contains(':') ? raw.substring(raw.indexOf(':') + 1) : '';

  /// t335u: why it fails, in one sentence. [elsewhere]: the home bridge is on another network than this
  /// device (this device can reach the device, the bridge cannot).
  String why(HeatText x, {bool elsewhere = false, String subject = ''}) {
    final what = subject.isEmpty ? x.t('laite', 'the device') : subject;
    final net =
        kind == HeatErrorKind.timeout ||
        kind == HeatErrorKind.unreachable ||
        kind == HeatErrorKind.refused ||
        kind == HeatErrorKind.dns;
    if (net && elsewhere) {
      return x.t(
        'Kotisilta ei pääse osoitteeseen, jossa $what on: se on todennäköisesti toisessa verkossa kuin $what. Tämä laite pääsee siihen, siksi muut ruudut toimivat.',
        'The home bridge cannot reach the address of $what: it is most likely on another network than $what. This device can reach it, which is why the other tiles work.',
      );
    }
    return switch (kind) {
      HeatErrorKind.bridgeOffline => x.t(
        'Tämä ohjelma ajetaan kotisillalla, johon sovellus ei nyt saa yhteyttä. Ohjelma jatkaa siellä itsenäisesti viimeisten asetusten mukaan, mutta tilaa ei voi nyt päivittää eikä asetusten muutoksia viedä sinne.',
        'This program runs on a home bridge the app cannot reach right now. It keeps running there on its last settings, but its state cannot be refreshed and setting changes cannot be sent.',
      ),
      HeatErrorKind.timeout || HeatErrorKind.unreachable || HeatErrorKind.refused || HeatErrorKind.dns => x.t(
        'Kotisilta ei saanut yhteyttä laitteeseen $what. Se on pois päältä, poissa verkosta tai kotisilta on eri verkossa.',
        'The home bridge could not connect to $what. It is switched off, off the network, or the bridge is on another network.',
      ),
      _ => text(x, subject: subject),
    };
  }

  /// t335u: numbered steps to fix it.
  List<String> steps(HeatText x, {bool elsewhere = false}) {
    switch (kind) {
      case HeatErrorKind.timeout:
      case HeatErrorKind.unreachable:
      case HeatErrorKind.refused:
      case HeatErrorKind.dns:
        return [
          if (elsewhere) ...[
            x.t(
              'Aseta kotisilta samaan verkkoon laitteen kanssa: avaa Molaplan aina päällä olevalla laitteella, joka on laitteen verkossa (esim. kotona oleva PC tai tabletti), ja valitse Asetukset → Etäkäyttö → Käytä tätä laitetta kotisiltana. Pariuta puhelin ja PC sen jälkeen uudelleen.',
              'Put the home bridge on the same network as the device: open Molaplan on an always-on device in the device\'s network (e.g. a PC or tablet at home) and choose Settings → Remote access → Use this device as the home bridge. Then pair your phone and PC with it again.',
            ),
            x.t(
              'Tai ohjaa laitetta sellaisella yhteydellä, jonka kotisilta tavoittaa mistä tahansa (esim. valmistajan pilvi, kuten Shelly Cloud).',
              'Or control the device through a connection the bridge can reach from anywhere (for example the maker\'s cloud, like Shelly Cloud).',
            ),
          ] else ...[
            x.t(
              'Tarkista, että laite on päällä ja sen virta- ja Wi-Fi-valo palaa.',
              'Check that the device is switched on and its power and Wi-Fi light is on.',
            ),
            x.t(
              'Tarkista, että laite ja kotisilta ovat samassa verkossa (osoitteiden kolme ensimmäistä numeroa ovat samat).',
              'Check that the device and the home bridge are on the same network (the first three numbers of their addresses are the same).',
            ),
            x.t(
              'Jos laitteen osoite on vaihtunut, päivitä se yhteyden asetuksista.',
              'If the device\'s address has changed, update it in the connection settings.',
            ),
          ],
          x.t(
            'Älykäs lämmitys yrittää uudelleen minuutin välein. Siihen asti rele pysyy viimeisessä tilassaan eikä lämmitys ohjaudu.',
            'Smart heating retries every minute. Until then the relay stays in its last state and the heating is not controlled.',
          ),
        ];
      case HeatErrorKind.bridgeOffline:
        return [
          x.t(
            'Tarkista, että kotisiltana toimiva laite on päällä, siinä on Molaplan käynnissä ja se on verkossa.',
            'Check that the device acting as the home bridge is on, Molaplan is running on it, and it is online.',
          ),
          x.t(
            'Ohjelma ei lopeta: kotisilta noudattaa viimeksi saamiaan asetuksia, kunnes yhteys palaa.',
            'The program does not stop: the bridge follows the last settings it received until the connection is back.',
          ),
          x.t(
            'Kun yhteys palaa, tämä laite lähettää odottavat muutokset automaattisesti. Jos siirsit ohjelman toiselle kotisillalle, vanha lopettaa sen heti kun se on taas yhteydessä.',
            'When the connection is back, this device sends any waiting changes automatically. If you moved the program to another bridge, the old one stops it as soon as it is online again.',
          ),
        ];
      case HeatErrorKind.auth:
        return [
          x.t(
            'Avaa laitteen yhteys ja tarkista käyttäjätunnus ja salasana.',
            'Open the device connection and check the username and password.',
          ),
        ];
      case HeatErrorKind.notFound:
      case HeatErrorKind.noCommand:
        return [
          x.t(
            'Avaa releen ruutu ja tarkista osoite sekä päälle/pois-komennot.',
            'Open the relay tile and check its address and on/off commands.',
          ),
        ];
      case HeatErrorKind.deviceError:
        return [
          x.t('Käynnistä laite uudelleen (virta pois ja päälle).', 'Restart the device (power off and on).'),
          x.t(
            'Jos virhe jatkuu, tarkista laitteen asetukset ja ohjelmisto.',
            'If the error continues, check the device settings and firmware.',
          ),
        ];
      case HeatErrorKind.other:
        return [x.t('Katso tarkempi syy kohdasta Tekniset tiedot.', 'See the exact reason under Technical details.')];
    }
  }

  /// What the user can do about it.
  String hint(HeatText x) => switch (kind) {
    HeatErrorKind.timeout || HeatErrorKind.unreachable || HeatErrorKind.refused || HeatErrorKind.dns => x.t(
      'Tarkista, että laite on päällä ja samassa verkossa kotisillan kanssa. Älykäs lämmitys yrittää uudelleen minuutin välein; kunnes se onnistuu, laite jää nykyiseen tilaansa.',
      'Check that the device is on and on the same network as the home bridge. Smart heating retries every minute; until it works the device stays in its current state.',
    ),
    HeatErrorKind.bridgeOffline => x.t(
      'Ohjelma jatkaa kotisillalla itsenäisesti. Tarkista, että kotisilta on päällä ja verkossa.',
      'The program keeps running on the bridge by itself. Check that the bridge is on and online.',
    ),
    HeatErrorKind.auth => x.t(
      'Tarkista laitteen salasana yhteyden asetuksista.',
      'Check the device password in the connection settings.',
    ),
    HeatErrorKind.notFound || HeatErrorKind.noCommand => x.t(
      'Tarkista laitteen osoite ja komento ruudun asetuksista.',
      'Check the device address and command in the tile settings.',
    ),
    HeatErrorKind.deviceError => x.t(
      'Laite vastasi mutta ei hyväksynyt komentoa. Kokeile käynnistää laite uudelleen.',
      'The device answered but did not accept the command. Try restarting the device.',
    ),
    HeatErrorKind.other => x.t(
      'Katso tarkempi syy kohdasta Tekniset tiedot.',
      'See the exact reason under Technical details.',
    ),
  };
}

/// Maps a raw failure text (TimeoutException, SocketException, HTTP errors…) to a [HeatError].
HeatError classifyHeatError(String raw) {
  final s = raw.toLowerCase();
  final to = RegExp(r'timeoutexception after (\d+):(\d+):(\d+)').firstMatch(s);
  if (to != null) {
    final secs = int.parse(to.group(1)!) * 3600 + int.parse(to.group(2)!) * 60 + int.parse(to.group(3)!);
    return HeatError(HeatErrorKind.timeout, raw, seconds: secs == 0 ? null : secs);
  }
  if (s == 'no command') return HeatError(HeatErrorKind.noCommand, raw);
  if (s.startsWith('bridge_offline')) return HeatError(HeatErrorKind.bridgeOffline, raw);
  final http = RegExp(r'(?:http|status)[ :=]*([45]\d\d)\b|\b([45]\d\d) (?:unauthorized|forbidden|not found|internal)')
      .firstMatch(s);
  if (http != null) {
    final code = int.parse(http.group(1) ?? http.group(2)!);
    if (code == 401 || code == 403) return HeatError(HeatErrorKind.auth, raw, status: code);
    if (code == 404) return HeatError(HeatErrorKind.notFound, raw, status: code);
    return HeatError(HeatErrorKind.deviceError, raw, status: code);
  }
  bool any(List<String> xs) => xs.any(s.contains);
  if (any(['failed host lookup', 'no address associated', 'name or service not known', 'nodename nor servname'])) {
    return HeatError(HeatErrorKind.dns, raw);
  }
  if (any(['connection refused', 'errno = 111', 'errno = 61', 'errno = 10061'])) {
    return HeatError(HeatErrorKind.refused, raw);
  }
  if (any([
    'no route to host',
    'network is unreachable',
    'host is down',
    'errno = 113',
    'errno = 101',
    'errno = 10051',
    'errno = 10065',
  ])) {
    return HeatError(HeatErrorKind.unreachable, raw);
  }
  if (any(['timed out', 'timeout', 'future not completed', 'errno = 110', 'errno = 10060'])) {
    return HeatError(HeatErrorKind.timeout, raw);
  }
  return HeatError(HeatErrorKind.other, raw);
}

// ------------------------------------------------------------------ checks

/// One rule of the decision. [state]: 'active' (decides now) · 'pass' (checked, does not apply) ·
/// 'inactive' (not in use) · 'unknown' (cannot be checked now, e.g. no sensor).
class HeatCheck {
  const HeatCheck(this.id, this.state, [this.p = const {}]);
  final String id;
  final String state;
  final Map<String, Object?> p;

  double? _d(String k) => (p[k] as num?)?.toDouble();

  Map<String, dynamic> toJson() => {'id': id, 'state': state, if (p.isNotEmpty) 'p': p};

  factory HeatCheck.fromJson(Map<String, dynamic> j) =>
      HeatCheck('${j['id']}', '${j['state']}', j['p'] is Map ? Map<String, Object?>.from(j['p'] as Map) : const {});

  /// Short name of the rule.
  String title(HeatText x) => switch (id) {
    'frost' => x.t('Jäätymissuoja', 'Frost protection'),
    'min_temp' => x.t('Vähimmäislämpötila', 'Minimum temperature'),
    'manual' => x.t('Manuaalinen ohitus', 'Manual override'),
    'fireplace' => x.t('Takka-tila', 'Fireplace mode'),
    'holiday' => x.t('Lomatila', 'Holiday mode'),
    'temp' => x.t('Lämpötilaohjaus', 'Temperature control'),
    'shift' => x.t('Hinta siirtää tavoitetta', 'Price shifts the setpoint'),
    'warm' => x.t('Huone riittävän lämmin', 'Room warm enough'),
    'cheapest' => x.t('Halvimmat tunnit', 'Cheapest hours'),
    'legionella' => x.t('Legionellasuoja', 'Legionella protection'),
    'pricelimit' => x.t('Hintaraja', 'Price limit'),
    'skip' => x.t('Kalleimpien tuntien ohitus', 'Skipping expensive hours'),
    'weather' => x.t('Sääennuste', 'Weather forecast'),
    'max_off' => x.t('Pisin tauko', 'Longest break'),
    'min_on' => x.t('Vähimmäisaika päällä', 'Minimum on time'),
    'min_off' => x.t('Vähimmäisaika pois', 'Minimum off time'),
    'noprice' => x.t('Hintatiedot', 'Price data'),
    'sensor' => x.t('Lämpöanturi', 'Temperature sensor'),
    'device' => x.t('Laite', 'Device'),
    _ => id,
  };

  /// What the rule says now, in one line.
  String detail(HeatText x) {
    String n(String k, [int d = 1]) => _d(k) == null ? '–' : x.n(_d(k)!, d);
    final st = state;
    switch (id) {
      case 'frost':
        if (st == 'inactive') return x.t('Ei käytössä', 'Not in use');
        if (st == 'unknown') return x.t('Ei lämpötilaa – ei voi tarkistaa', 'No temperature – cannot be checked');
        return st == 'active'
            ? x.t(
                '${n('temp')} °C on alle ${n('limit')} °C – lämmitys päällä',
                '${n('temp')} °C is below ${n('limit')} °C – heating on',
              )
            : x.t('${n('temp')} °C, raja ${n('limit')} °C', '${n('temp')} °C, limit ${n('limit')} °C');
      case 'min_temp':
        if (st == 'unknown') return x.t('Ei lämpötilaa – ei voi tarkistaa', 'No temperature – cannot be checked');
        return st == 'active'
            ? x.t(
                '${n('temp')} °C on alle ${n('limit')} °C – lämmitys päällä',
                '${n('temp')} °C is below ${n('limit')} °C – heating on',
              )
            : x.t('${n('temp')} °C, raja ${n('limit')} °C', '${n('temp')} °C, limit ${n('limit')} °C');
      case 'manual':
        if (st != 'active') return x.t('Ei käytössä', 'Not in use');
        final span = x.span(Duration(minutes: (p['left'] as num?)?.toInt() ?? 0));
        return p['on'] == true
            ? x.t('Päällä $span (asti ${p['untilHm']})', 'On for $span (until ${p['untilHm']})')
            : x.t('Pois $span (asti ${p['untilHm']})', 'Off for $span (until ${p['untilHm']})');
      case 'fireplace':
        return st == 'active'
            ? x.t('Takka lämmittää: sähkölämmitystä vähennetään', 'The fireplace heats: electric heating is reduced')
            : x.t('Ei käytössä', 'Not in use');
      case 'holiday':
        if (st == 'active') {
          return x.t('Poissa: pidetään ${n('keep')} °C', 'Away: keeping ${n('keep')} °C');
        }
        return st == 'inactive' ? x.t('Ei käytössä', 'Not in use') : x.t('Ei voimassa nyt', 'Not in force now');
      case 'temp':
        if (st == 'unknown') {
          return x.t(
            'Anturi ei vastaa – ${_fallbackText(x, '${p['fallback']}')}',
            'The sensor is not answering – ${_fallbackText(x, '${p['fallback']}')}',
          );
        }
        return x.t(
          '${n('temp')} °C, tavoite ${n('setpoint')} °C ± ${n('half')} °C (päällä alle ${n('onBelow')}, pois yli ${n('offAbove')} °C)',
          '${n('temp')} °C, setpoint ${n('setpoint')} °C ± ${n('half')} °C (on below ${n('onBelow')}, off above ${n('offAbove')} °C)',
        );
      case 'shift':
        if (st == 'inactive') return x.t('Ei käytössä', 'Not in use');
        final sh = _d('shift') ?? 0;
        if (sh == 0) return x.t('Ei muutosta tällä tunnilla', 'No change in this hour');
        return sh > 0
            ? x.t('Halpa tunti: tavoite +${n('shift')} °C', 'Cheap hour: setpoint +${n('shift')} °C')
            : x.t('Kallis tunti: tavoite ${n('shift')} °C', 'Expensive hour: setpoint ${n('shift')} °C');
      case 'warm':
        return st == 'active'
            ? x.t('${n('temp')} °C ≥ ${n('cap')} °C – ei lämmitetä', '${n('temp')} °C ≥ ${n('cap')} °C – not heating')
            : (st == 'unknown'
                  ? x.t('Ei lämpötilaa – ei voi tarkistaa', 'No temperature – cannot be checked')
                  : x.t('${n('temp')} °C, yläraja ${n('cap')} °C', '${n('temp')} °C, upper limit ${n('cap')} °C'));
      case 'cheapest':
        if (st == 'unknown') return x.t('Ei hintoja', 'No prices');
        final hit = p['hit'] == true;
        final fits = _d('price') != null && _d('limit') != null && ((_d('price')! <= _d('limit')!) == hit);
        final sym = fits ? (hit ? '≤' : '>') : ',';
        return x.t(
          '${p['n']} halvinta tuntia päivässä: nyt ${n('price')} c/kWh $sym raja ${n('limit')} c',
          '${p['n']} cheapest hours a day: now ${n('price')} c/kWh $sym limit ${n('limit')} c',
        );
      case 'pricelimit':
        if (st == 'unknown') return x.t('Ei hintoja', 'No prices');
        final hit = p['hit'] == true;
        final fits = _d('price') != null && _d('limit') != null && ((_d('price')! <= _d('limit')!) == hit);
        final sym = fits ? (hit ? '≤' : '>') : ',';
        return x.t(
          'Nyt ${n('price')} c/kWh $sym raja ${n('limit')} c · ${p['n']} h alle rajan tänään',
          'Now ${n('price')} c/kWh $sym limit ${n('limit')} c · ${p['n']} h under the limit today',
        );
      case 'skip':
        if (st == 'unknown') return x.t('Ei hintoja', 'No prices');
        final hit = p['hit'] == true;
        final fits = _d('price') != null && _d('limit') != null && ((_d('price')! >= _d('limit')!) == hit);
        final sym = fits ? (hit ? '≥' : '<') : ',';
        return x.t(
          '${p['n']} kalleinta tuntia ohitetaan: nyt ${n('price')} c/kWh $sym raja ${n('limit')} c',
          '${p['n']} most expensive hours skipped: now ${n('price')} c/kWh $sym limit ${n('limit')} c',
        );
      case 'weather':
        if (st == 'unknown') return x.t('Ei ennustetta', 'No forecast');
        return x.t(
          'Ennuste keskimäärin ${n('avg')} °C → ${p['hours']} lämmitystuntia päivässä',
          'Forecast ${n('avg')} °C on average → ${p['hours']} heating hours a day',
        );
      case 'max_off':
        return st == 'active'
            ? x.t('Pois ollut liian pitkään – lämmitetään tunti', 'Off for too long – heating for an hour')
            : x.t('Enintään ${n('hours')} h kerrallaan pois', 'Off for at most ${n('hours')} h at a time');
      case 'min_on':
      case 'min_off':
        if (st == 'inactive') return x.t('Ei rajoitusta', 'No limit');
        return st == 'active'
            ? x.t('Odottaa: vähintään ${p['minutes']} min', 'Waiting: at least ${p['minutes']} min')
            : x.t('Vähintään ${p['minutes']} min', 'At least ${p['minutes']} min');
      case 'noprice':
        return st == 'active'
            ? x.t('Hintoja ei ole – lämmitys toimii tavallisesti', 'No prices – heating runs normally')
            : x.t('Hinnat saatu', 'Prices available');
      case 'sensor':
        return switch (st) {
          'inactive' => x.t('Ei anturia valittu', 'No sensor chosen'),
          'unknown' => x.t('Ei vastaa', 'Not answering'),
          _ => x.t('Vastaa: ${n('temp')} °C', 'Answering: ${n('temp')} °C'),
        };
      case 'device':
        return st == 'active' ? x.t('Ei vastaa', 'Not responding') : x.t('Vastaa', 'Responding');
    }
    return '';
  }
}

String _fallbackText(HeatText x, String f) => switch (f) {
  'on' => x.t('lämmitys pidetään päällä', 'heating is kept on'),
  'off' => x.t('lämmitys pidetään pois', 'heating is kept off'),
  _ => x.t('noudatetaan hintaohjausta', 'following the price schedule'),
};

// ------------------------------------------------------------------ explanation

class HeatExplanation {
  HeatExplanation({
    required this.loadId,
    required this.control,
    required this.template,
    this.enabled = true,
    this.mode = 'normal',
    this.modeUntil,
    this.on,
    this.want,
    this.changedAt,
    this.target,
    this.reason = '',
    this.safety = false,
    this.fallback = false,
    this.temp,
    this.setpoint,
    this.comfort,
    this.shift = 0,
    this.hysteresis,
    this.tempControl = false,
    this.minTemp,
    this.frostTemp,
    this.maxTemp,
    this.sensor = 'none',
    this.price,
    this.limit,
    this.limitKind,
    this.limitHours,
    this.nextAt,
    this.nextOn,
    this.nextAuto = false,
    this.error,
    this.errorAt,
    this.sensorError,
    this.preview = false,
    this.maxOffHours,
    this.minOnMinutes = 0,
    this.minOffMinutes = 0,
    this.storage = false,
    this.fallbackRule = 'price',
    this.checks = const [],
    this.dhw = false,
    this.waterTarget,
    this.waterMin,
    this.costToday,
    this.heatHoursToday,
    this.powerKw,
    this.nextSetpoint,
    this.nextWhy,
    this.priceNext,
    this.outdoorNow,
    this.outdoorNext,
    this.slotMinutes = 60,
    this.plan = const [],
  });

  final String loadId;

  /// 'switch' | 'thermostat'
  final String control;
  final String template;
  final bool enabled;

  /// 'normal' | 'holiday' | 'fireplace' | 'manual' | 'off'
  final String mode;
  final DateTime? modeUntil;

  /// The relay state last confirmed by a command that went through (null = never confirmed).
  final bool? on;

  /// What the rules decide now (t335u). Known even when the device does not answer.
  final bool? want;

  /// When the relay last changed by a command that went through.
  final DateTime? changedAt;
  final double? target;
  final String reason;
  final bool safety;
  final bool fallback;
  final double? temp;
  final double? setpoint;
  final double? comfort;
  final double shift;
  final double? hysteresis;
  final bool tempControl;
  final double? minTemp;
  final double? frostTemp;
  final double? maxTemp;

  /// 'none' | 'ok' | 'offline'
  final String sensor;
  final double? price;
  final double? limit;

  /// 'cheap' (on at or below the limit) | 'skip' (off at or above it)
  final String? limitKind;
  final int? limitHours;
  final DateTime? nextAt;

  /// State after [nextAt] (null = back to the automatic rules).
  final bool? nextOn;

  /// The next change depends on the temperature, not on the clock.
  final bool nextAuto;
  final String? error;
  final DateTime? errorAt;
  final String? sensorError;

  /// Built locally, no live state from the home bridge.
  final bool preview;
  final double? maxOffHours;
  final int minOnMinutes;
  final int minOffMinutes;

  /// A storing heater (concrete floor / water): expensive hours can be skipped without a chill.
  final bool storage;

  /// What a silent sensor does: 'price' | 'on' | 'off'.
  final String fallbackRule;
  final List<HeatCheck> checks;

  /// R720: a domestic hot water program.
  final bool dhw;
  final double? waterTarget;
  final double? waterMin;

  /// Estimated cost (euros) and heated hours of today's cycle (DHW, when power is set).
  final double? costToday;
  final double? heatHoursToday;
  final double? powerKw;

  /// R725: the setpoint / target after [nextAt], and why it changes (price_up / price_down /
  /// weather_warm / weather_cool / cheap / not_cheap / legionella / ready).
  final double? nextSetpoint;
  final String? nextWhy;
  final double? priceNext;
  final double? outdoorNow;
  final double? outdoorNext;
  final int slotMinutes;

  /// Planned ON periods (today and tomorrow when known).
  final List<(DateTime, DateTime)> plan;

  bool get hasError => error != null && error!.isNotEmpty;
  HeatError? get heatError => hasError ? classifyHeatError(error!) : null;
  bool get sensorOffline => sensor == 'offline';

  /// PÄÄLLÄ / POIS (null = unknown). Thermostat loads: heating when the target is above the room.
  bool? get heating => control == 'thermostat' ? (target != null && temp != null ? target! > temp! : null) : on;

  Map<String, dynamic> toJson() => {
    'loadId': loadId,
    'control': control,
    'template': template,
    'enabled': enabled,
    'mode': mode,
    if (modeUntil != null) 'modeUntil': modeUntil!.millisecondsSinceEpoch,
    'on': ?on,
    'want': ?want,
    if (changedAt != null) 'changedAt': changedAt!.millisecondsSinceEpoch,
    'target': ?target,
    'reason': reason,
    if (safety) 'safety': true,
    if (fallback) 'fallback': true,
    'temp': ?temp,
    'setpoint': ?setpoint,
    'comfort': ?comfort,
    if (shift != 0) 'shift': shift,
    'hysteresis': ?hysteresis,
    if (tempControl) 'tempControl': true,
    'minTemp': ?minTemp,
    'frostTemp': ?frostTemp,
    'maxTemp': ?maxTemp,
    'sensor': sensor,
    'price': ?price,
    'limit': ?limit,
    'limitKind': ?limitKind,
    'limitHours': ?limitHours,
    if (nextAt != null) 'nextAt': nextAt!.millisecondsSinceEpoch,
    'nextOn': ?nextOn,
    if (nextAuto) 'nextAuto': true,
    'error': ?error,
    if (errorAt != null) 'errorAt': errorAt!.millisecondsSinceEpoch,
    'sensorError': ?sensorError,
    'maxOffHours': ?maxOffHours,
    if (minOnMinutes != 0) 'minOn': minOnMinutes,
    if (minOffMinutes != 0) 'minOff': minOffMinutes,
    if (storage) 'storage': true,
    if (fallbackRule != 'price') 'fallbackRule': fallbackRule,
    'checks': [for (final c in checks) c.toJson()],
    if (dhw) 'dhw': true,
    'waterTarget': ?waterTarget,
    'waterMin': ?waterMin,
    'costToday': ?costToday,
    'heatHoursToday': ?heatHoursToday,
    'powerKw': ?powerKw,
    'nextSetpoint': ?nextSetpoint,
    'nextWhy': ?nextWhy,
    'priceNext': ?priceNext,
    'outdoorNow': ?outdoorNow,
    'outdoorNext': ?outdoorNext,
    if (slotMinutes != 60) 'slotMinutes': slotMinutes,
    if (plan.isNotEmpty)
      'plan': [
        for (final p in plan) [p.$1.millisecondsSinceEpoch, p.$2.millisecondsSinceEpoch],
      ],
  };

  factory HeatExplanation.fromJson(Map<String, dynamic> j) {
    DateTime? t(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    double? d(String k) => (j[k] as num?)?.toDouble();
    return HeatExplanation(
      loadId: '${j['loadId']}',
      control: '${j['control'] ?? 'switch'}',
      template: '${j['template'] ?? ''}',
      enabled: j['enabled'] != false,
      mode: '${j['mode'] ?? 'normal'}',
      modeUntil: t(j['modeUntil']),
      on: j['on'] as bool?,
      want: j['want'] as bool?,
      changedAt: t(j['changedAt']),
      target: d('target'),
      reason: '${j['reason'] ?? ''}',
      safety: j['safety'] == true,
      fallback: j['fallback'] == true,
      temp: d('temp'),
      setpoint: d('setpoint'),
      comfort: d('comfort'),
      shift: d('shift') ?? 0,
      hysteresis: d('hysteresis'),
      tempControl: j['tempControl'] == true,
      minTemp: d('minTemp'),
      frostTemp: d('frostTemp'),
      maxTemp: d('maxTemp'),
      sensor: '${j['sensor'] ?? 'none'}',
      price: d('price'),
      limit: d('limit'),
      limitKind: j['limitKind'] as String?,
      limitHours: (j['limitHours'] as num?)?.toInt(),
      nextAt: t(j['nextAt']),
      nextOn: j['nextOn'] as bool?,
      nextAuto: j['nextAuto'] == true,
      error: j['error'] == null ? null : '${j['error']}',
      errorAt: t(j['errorAt']),
      sensorError: j['sensorError'] == null ? null : '${j['sensorError']}',
      maxOffHours: d('maxOffHours'),
      minOnMinutes: (j['minOn'] as num?)?.toInt() ?? 0,
      minOffMinutes: (j['minOff'] as num?)?.toInt() ?? 0,
      storage: j['storage'] == true,
      fallbackRule: '${j['fallbackRule'] ?? 'price'}',
      checks: [
        for (final c in (j['checks'] as List? ?? const []))
          if (c is Map) HeatCheck.fromJson(Map<String, dynamic>.from(c)),
      ],
      dhw: j['dhw'] == true,
      waterTarget: d('waterTarget'),
      waterMin: d('waterMin'),
      costToday: d('costToday'),
      heatHoursToday: d('heatHoursToday'),
      powerKw: d('powerKw'),
      nextSetpoint: d('nextSetpoint'),
      nextWhy: j['nextWhy'] as String?,
      priceNext: d('priceNext'),
      outdoorNow: d('outdoorNow'),
      outdoorNext: d('outdoorNext'),
      slotMinutes: (j['slotMinutes'] as num?)?.toInt() ?? 60,
      plan: [
        for (final p in (j['plan'] as List? ?? const []))
          if (p is List && p.length >= 2)
            (
              DateTime.fromMillisecondsSinceEpoch((p[0] as num).toInt()),
              DateTime.fromMillisecondsSinceEpoch((p[1] as num).toInt()),
            ),
      ],
    );
  }

  // ---- texts

  /// The state to show big (t335u): the confirmed relay state, else the decision. A device that does
  /// not answer never replaces it; null only when neither is known.
  bool? get shownOn => control == 'thermostat' ? heating : (on ?? want);

  /// The shown state is what the rules want and the relay confirmed (or nothing contradicts it).
  bool get confirmed => control == 'thermostat' || (on != null && (want == null || on == want) && !hasError);

  /// Big word of the tile: PÄÄLLÄ / POIS, or a calm 'Tila tuntematon' when nothing is known.
  String stateWord(HeatText x) {
    if (!enabled || mode == 'off') return x.t('POIS KÄYTÖSTÄ', 'DISABLED');
    if (control == 'thermostat') {
      return target == null ? '–' : x.t('Tavoite ${x.n(target!)} °C', 'Target ${x.n(target!)} °C');
    }
    final s = shownOn;
    if (s == null) return hasError ? x.t('Tila tuntematon', 'State unknown') : '–';
    return s ? x.t('PÄÄLLÄ', 'ON') : x.t('POIS', 'OFF');
  }

  /// Small line under the big word when the device did not confirm it (null = nothing to add):
  /// the state is a decision or the last known one, with its age.
  String? stateNote(HeatText x, {DateTime? now}) {
    if (control == 'thermostat' || !enabled || mode == 'off' || !hasError) return null;
    final t = now ?? DateTime.now();
    String age(DateTime d) {
      final m = t.difference(d).inMinutes;
      return m < 1
          ? x.t('juuri äsken', 'just now')
          : x.t('${x.span(Duration(minutes: m))} sitten', '${x.span(Duration(minutes: m))} ago');
    }

    String word(bool v) => v ? x.t('päällä', 'on') : x.t('pois', 'off');
    if (on == null) {
      return want == null
          ? x.t('Laite ei ole vastannut, tilaa ei tiedetä', 'The device has not answered, its state is not known')
          : x.t(
              'Päätös: ${word(want!)} – laite ei ole vahvistanut sitä',
              'Decision: ${word(want!)} – the device has not confirmed it',
            );
    }
    final since = changedAt;
    final last = since == null
        ? ''
        : x.t(' (klo ${x.hm(since)}, ${age(since)})', ' (at ${x.hm(since)}, ${age(since)})');
    if (want != null && want != on) {
      return x.t(
        'Viimeksi ohjattu: ${word(on!)}$last – päätös ${word(want!)} ei mennyt perille',
        'Last set: ${word(on!)}$last – the decision ${word(want!)} did not get through',
      );
    }
    return x.t('Viimeksi ohjattu: ${word(on!)}$last', 'Last set: ${word(on!)}$last');
  }

  /// One plain sentence: why the device is on or off now.
  String reasonText(HeatText x, {DateTime? now}) {
    String n(num? v, [int d = 1]) => v == null ? '–' : x.n(v, d);
    if (!enabled) return x.t('Ohjaus on pois käytöstä', 'Control is switched off');
    if (mode == 'off') return x.t('Älykäs lämmitys on pois päältä', 'Smart heating is off');
    final fb = fallback
        ? x.t('Anturi ei vastaa – noudatetaan hintaohjausta: ', 'Sensor not answering – following the price schedule: ')
        : '';
    final limitS = limit == null ? '' : n(limit);
    switch (reason) {
      case 'frost':
        return x.t(
          'Jäätymissuoja: ${n(temp)} °C on alle ${n(frostTemp)} °C',
          'Frost protection: ${n(temp)} °C is below ${n(frostTemp)} °C',
        );
      case 'min_temp':
        return dhw
            ? x.t(
                'Käyttövesi ${n(temp)} °C alle minimin ${n(waterMin ?? minTemp)} °C – lämmitetään hinnasta riippumatta',
                'Hot water ${n(temp)} °C is below the minimum ${n(waterMin ?? minTemp)} °C – heating regardless of the price',
              )
            : x.t(
                'Lämpötila ${n(temp)} °C alle minimin ${n(minTemp)} °C',
                'Temperature ${n(temp)} °C below the minimum ${n(minTemp)} °C',
              );
      case 'manual_on':
      case 'manual_off':
        final left = modeUntil?.difference(now ?? DateTime.now());
        final s = left == null || left.isNegative ? '' : ' ${x.span(left)}';
        return reason == 'manual_on'
            ? x.t('Manuaalinen ohitus: päällä$s', 'Manual override: on$s')
            : x.t('Manuaalinen ohitus: pois$s', 'Manual override: off$s');
      case 'fireplace':
        return x.t('Takka-tila: sähkölämmitystä vähennetään', 'Fireplace mode: electric heating is reduced');
      case 'holiday':
        return control == 'thermostat' || temp != null
            ? x.t('Lomatila: huone pidetään viileämpänä', 'Holiday mode: the room is kept cooler')
            : x.t('Lomatila', 'Holiday mode');
      case 'holiday_return':
        return x.t('Lomatila: lämmitetään paluuta varten', 'Holiday mode: heating for your return');
      case 'warm':
        return x.t(
          'Tarpeeksi lämmin (${n(temp)} °C ≥ ${n(maxTemp)} °C)',
          'Warm enough (${n(temp)} °C ≥ ${n(maxTemp)} °C)',
        );
      case 'legionella':
        return x.t(
          'Legionellasuoja: vesi lämmitetään vähintään 60 °C:een',
          'Legionella protection: the water is heated to at least 60 °C',
        );
      case 'cheap':
        final within = price != null && limit != null && price! <= limit!;
        return '$fb${within ? x.t('Halpa tunti (${n(price)} c/kWh ≤ raja $limitS c)', 'Cheap hour (${n(price)} c/kWh ≤ limit $limitS c)') : x.t('Lämmitetään, ettei tauko veny liian pitkäksi (${n(price)} c/kWh)', 'Heating so that the break does not get too long (${n(price)} c/kWh)')}';
      case 'not_cheap':
        final above = price != null && limit != null && price! > limit!;
        final cmp = above
            ? (x.t('${n(price)} c/kWh > raja $limitS c', '${n(price)} c/kWh > limit $limitS c'))
            : '${n(price)} c/kWh';
        final store = dhw
            ? x.t('Kallis tunti – varaaja riittää ($cmp)', 'Expensive hour – the tank is enough ($cmp)')
            : (storage
                  ? x.t(
                      'Kallis tunti – varaava lattia riittää ($cmp)',
                      'Expensive hour – the storing floor is enough ($cmp)',
                    )
                  : x.t('Ei halpa tunti – odottaa ($cmp)', 'Not a cheap hour – waiting ($cmp)'));
        return '$fb$store';
      case 'expensive':
        final cmp = x.t('${n(price)} c/kWh ≥ raja $limitS c', '${n(price)} c/kWh ≥ limit $limitS c');
        final store = dhw
            ? x.t('Kallis tunti – varaaja riittää ($cmp)', 'Expensive hour – the tank is enough ($cmp)')
            : (storage
                  ? x.t(
                      'Kallis tunti – varaava lattia riittää ($cmp)',
                      'Expensive hour – the storing floor is enough ($cmp)',
                    )
                  : x.t('Kallis tunti ohitetaan ($cmp)', 'Expensive hour skipped ($cmp)'));
        return '$fb$store';
      case 'normal':
        return '$fb${x.t('Normaali lämmitys', 'Normal heating')}${price == null ? '' : ' (${n(price)} c/kWh)'}';
      case 'noprice':
        return x.t('Ei hintatietoa – lämmitys toimii tavallisesti', 'No price data – heating runs normally');
      case 'temp_heat':
        return x.t(
          'Lämpötila ${n(temp)} °C alle tavoitteen ${n(setpoint)} °C – lämmitetään',
          'Temperature ${n(temp)} °C is below the setpoint ${n(setpoint)} °C – heating',
        );
      case 'temp_reached':
        return dhw
            ? x.t(
                'Käyttövesi ${n(temp)} °C on tavoitteessa (${n(waterTarget ?? setpoint)} °C) – tauko',
                'Hot water ${n(temp)} °C has reached the target (${n(waterTarget ?? setpoint)} °C) – pausing',
              )
            : x.t(
                'Tavoite ${n(setpoint)} °C saavutettu (${n(temp)} °C)',
                'Setpoint ${n(setpoint)} °C reached (${n(temp)} °C)',
              );
      case 'temp_hold_on':
        return x.t(
          'Lämmitetään, kunnes ${n((setpoint ?? 0) + (hysteresis ?? 0) / 2)} °C',
          'Heating until ${n((setpoint ?? 0) + (hysteresis ?? 0) / 2)} °C',
        );
      case 'temp_hold_off':
        return x.t(
          'Pois, kunnes lämpötila laskee alle ${n((setpoint ?? 0) - (hysteresis ?? 0) / 2)} °C',
          'Off until the temperature drops below ${n((setpoint ?? 0) - (hysteresis ?? 0) / 2)} °C',
        );
      case 'fallback_on':
        return x.t('Anturi ei vastaa – lämmitys pidetään päällä', 'Sensor not answering – heating is kept on');
      case 'fallback_off':
        return x.t('Anturi ei vastaa – lämmitys pidetään pois', 'Sensor not answering – heating is kept off');
      case 'max_off':
        return x.t(
          'Turvaraja: pois liian pitkään – lämmitetään tunti',
          'Safety limit: off for too long – heating for an hour',
        );
      case 'min_on':
        return x.t('Pidetään päällä: vähimmäisaika ei ole täynnä', 'Kept on: the minimum on time is not over');
      case 'min_off':
        return x.t('Pidetään pois: vähimmäisaika ei ole täynnä', 'Kept off: the minimum off time is not over');
      case 'preheat':
        return x.t('Esilämmitys ennen kallista tai kylmää jaksoa', 'Pre-heating before an expensive or cold spell');
      case 'coast':
        return x.t('Säästö kalliina aikana', 'Saving while expensive');
    }
    return reason.isEmpty ? x.t('Ei tietoa vielä', 'No information yet') : reason;
  }

  /// '13.00 pois' / 'palaa automaattiseen' / null.
  String? nextText(HeatText x) {
    if (nextAuto && nextAt == null) {
      return x.t('Seuraava muutos riippuu lämpötilasta', 'The next change depends on the temperature');
    }
    if (nextAt == null) return null;
    final when = x.hm(nextAt!);
    if (nextOn == null) return x.t('Automaattinen ohjaus jatkuu klo $when', 'Automatic control resumes at $when');
    return nextOn!
        ? x.t('Seuraavaksi päälle klo $when', 'Next on at $when')
        : x.t('Seuraavaksi pois klo $when', 'Next off at $when');
  }

  String _whyPhrase(HeatText x) {
    String n(num? v, [int d = 1]) => v == null ? '–' : x.n(v, d);
    final rise = (priceNext ?? 0) - (price ?? 0);
    return switch (nextWhy) {
      'price_up' => x.t('hinta nousee ${n(rise.abs())} c', 'the price rises ${n(rise.abs())} c'),
      'price_down' => x.t('hinta laskee ${n(rise.abs())} c', 'the price falls ${n(rise.abs())} c'),
      'weather_warm' => x.t('sää lämpenee', 'the weather warms'),
      'weather_cool' => x.t('sää kylmenee', 'the weather cools'),
      'cheap' => x.t('halvin tunti', 'a cheap hour'),
      'not_cheap' => x.t('kallis tunti', 'an expensive hour'),
      'legionella' => x.t('legionellasuoja', 'legionella protection'),
      'ready' => x.t('valmis tähän kelloon', 'ready by this time'),
      'temp_reached' => x.t('tavoite saavutettu', 'the target is reached'),
      'min_temp' => x.t('alle minimin', 'below the minimum'),
      _ => reasonText(x).split('–').first.trim().toLowerCase(),
    };
  }

  /// R725: the line at the top of the page – the value now, what it changes to and when, and why.
  String? headline(HeatText x) {
    String n(num? v, [int d = 1]) => v == null ? '–' : x.n(v, d);
    final when = nextAt == null ? null : x.hm(nextAt!);
    final sp = control == 'thermostat' || tempControl || control == 'setpoint' || dhw
        ? (setpoint ?? target ?? comfort)
        : null;
    if (sp != null && nextSetpoint != null && when != null && (sp - nextSetpoint!).abs() >= 0.25) {
      return x.t(
        'Asetusarvo nyt ${n(sp)} °C → ${n(nextSetpoint)} °C klo $when (${_whyPhrase(x)})',
        'Setpoint now ${n(sp)} °C → ${n(nextSetpoint)} °C at $when (${_whyPhrase(x)})',
      );
    }
    if (when != null && nextOn != null) {
      final nowW = shownOn == true ? x.t('päällä', 'on') : x.t('pois', 'off');
      final nextW = nextOn! ? x.t('päällä', 'on') : x.t('pois', 'off');
      return x.t('Nyt $nowW → $nextW klo $when (${_whyPhrase(x)})', 'Now $nowW → $nextW at $when (${_whyPhrase(x)})');
    }
    return nextText(x);
  }

  /// A short weather-effect line, or null when there is no forecast.
  String? weatherLine(HeatText x) {
    String n(num? v, [int d = 1]) => v == null ? '–' : x.n(v, d);
    if (outdoorNow == null) return null;
    if (outdoorNext != null && nextAt != null && (outdoorNow! - outdoorNext!).abs() >= 1) {
      final warmer = outdoorNext! > outdoorNow!;
      return warmer
          ? x.t(
              'Sää: ulkona nyt ${n(outdoorNow)} °C → ${n(outdoorNext)} °C klo ${x.hm(nextAt!)} (lämpenee, lämmitystarve laskee)',
              'Weather: outside now ${n(outdoorNow)} °C → ${n(outdoorNext)} °C at ${x.hm(nextAt!)} (warming, the heat demand falls)',
            )
          : x.t(
              'Sää: ulkona nyt ${n(outdoorNow)} °C → ${n(outdoorNext)} °C klo ${x.hm(nextAt!)} (kylmenee, lämmitystarve nousee)',
              'Weather: outside now ${n(outdoorNow)} °C → ${n(outdoorNext)} °C at ${x.hm(nextAt!)} (cooling, the heat demand rises)',
            );
    }
    return x.t('Sää: ulkona nyt ${n(outdoorNow)} °C', 'Weather: outside now ${n(outdoorNow)} °C');
  }

  String _hmRange(HeatText x, DateTime a, DateTime b) {
    if (slotMinutes < 60 || a.minute != 0 || b.minute != 0) {
      return '${x.hm(a)}–${x.hm(b)}';
    }
    return '${a.hour.toString().padLeft(2, '0')}–${b.hour.toString().padLeft(2, '0')}';
  }

  /// Upcoming heating periods, e.g. '23–02, 04–06'.
  String? nextHoursText(HeatText x, {DateTime? now}) {
    final t = now ?? DateTime.now();
    final ahead = [
      for (final p in plan)
        if (p.$2.isAfter(t)) (p.$1.isBefore(t) ? t : p.$1, p.$2),
    ];
    if (ahead.isEmpty) return null;
    return ahead.take(6).map((p) => _hmRange(x, p.$1, p.$2)).join(', ');
  }

  /// 'Tänään n. 1,20 € (3 h)' – only when the power or the hours are known.
  String? costTodayText(HeatText x) {
    String n(num? v, [int d = 1]) => v == null ? '–' : x.n(v, d);
    if (heatHoursToday == null) return null;
    if (costToday == null) {
      return x.t('${n(heatHoursToday)} h tänään', '${n(heatHoursToday)} h today');
    }
    return x.t(
      'Tänään n. ${n(costToday, 2)} € (${n(heatHoursToday)} h)',
      'Today about ${n(costToday, 2)} € (${n(heatHoursToday)} h)',
    );
  }

  /// Consequence + what to do when the sensor is silent (R615).
  String? sensorWarning(HeatText x) {
    if (!sensorOffline) return null;
    if (dhw) {
      return '${x.t('Lämpöanturi ei vastaa.', 'The temperature sensor is not answering.')} '
          '${x.t('Käyttövesi noudattaa kellonaikaa, kunnes anturi vastaa. Alle minimin ei voida lämmittää hinnasta riippumatta.', 'Hot water follows the clock until the sensor answers. It cannot be force-heated below the minimum.')} '
          '${x.t('Tarkista anturin paristo ja verkkoyhteys tai valitse toinen anturi.', 'Check the sensor battery and network, or choose another sensor.')}';
    }
    final what = tempControl
        ? x.t(
            'Lämpötilaohjaus ja turvarajat (jäätymissuoja, vähimmäislämpötila) eivät ole käytössä, ja ${_fallbackText(x, fallbackRule)}.',
            'Temperature control and the safety limits (frost protection, minimum temperature) are off, and ${_fallbackText(x, fallbackRule)}.',
          )
        : x.t(
            'Turvarajat (jäätymissuoja, vähimmäislämpötila) eivät ole käytössä, ja lämmitys noudattaa hintaohjausta.',
            'The safety limits (frost protection, minimum temperature) are off, and heating follows the price schedule.',
          );
    return '${x.t('Lämpöanturi ei vastaa.', 'The temperature sensor is not answering.')} $what '
        '${x.t('Tarkista anturin paristo ja verkkoyhteys tai valitse toinen anturi.', 'Check the sensor battery and network, or choose another sensor.')}';
  }
}

// ------------------------------------------------------------------ builder

/// Builds the explanation of [l]. [st] is the live state (null = no bridge answered: a preview from
/// the same rules). [thermoSetpoint] is the Molaplan thermostat's own setpoint (thermostat loads).
HeatExplanation explainLoad(
  SmartHeatingConfig c,
  HeatLoad l,
  HeatInputs x, {
  LoadStatus? st,
  ManualOverride? manual,
  double? thermoSetpoint,
  bool sensorChosen = false,
  bool preview = false,
}) {
  final rec = recommend(l.type, c.site, control: l.control);
  final template = l.template ?? rec.template;
  final space = l.info.space;
  final thermo = l.control == 'thermostat';
  final now = x.now;
  var s = st ?? LoadStatus();
  var temp = s.temp ?? x.temp;
  // Without live state the decision is made here from the same rules.
  var isPreview = preview || st == null || s.reason.isEmpty;
  var on = s.on;
  bool? want = s.want;
  var target = s.target;
  var reason = s.reason;
  var safety = s.safety;
  var fallback = s.fallback;
  var setpoint = s.setpoint;
  var shift = s.shift;
  if (isPreview) {
    final xi = HeatInputs(
      now: now,
      cost: x.cost,
      outdoor: x.outdoor,
      temp: temp,
      holiday: x.holiday,
      holidayEnd: x.holidayEnd,
      fireplace: x.fireplace,
      manualOn: manual != null && manual.activeAt(now) ? manual.on : null,
      manualUntil: manual?.until,
      lastOn: s.on,
      slotMinutes: x.slotMinutes,
    );
    if (thermo) {
      final d = decideThermostat(c, l, xi, thermoSetpoint ?? l.comfort);
      target = d.target;
      reason = d.reason;
      safety = d.safety;
    } else {
      final d = decideSwitch(c, l, xi);
      on = d.on;
      want = d.on;
      reason = d.reason;
      safety = d.safety;
      fallback = d.fallback;
      setpoint = d.setpoint;
      shift = d.shift;
    }
  }
  if (!isPreview && !thermo && want == null && on == null) {
    // An older home bridge does not report its decision: rebuild it here from the same rules, so the
    // tile can show it even when the device never answered.
    final xi = HeatInputs(
      now: now,
      cost: x.cost,
      outdoor: x.outdoor,
      temp: temp,
      holiday: x.holiday,
      holidayEnd: x.holidayEnd,
      fireplace: x.fireplace,
      manualOn: manual != null && manual.activeAt(now) ? manual.on : null,
      manualUntil: manual?.until,
      slotMinutes: x.slotMinutes,
    );
    want = decideSwitch(c, l, xi).on;
  }
  final sensorState = st != null && s.reason.isNotEmpty
      ? s.sensor
      : (sensorChosen ? (temp == null ? 'offline' : 'ok') : 'none');
  if (preview && temp == null && sensorState != 'offline') fallback = false;
  final manualNow = manual != null && manual.activeAt(now) ? manual : null;
  final mode = !c.enabled
      ? 'off'
      : manualNow != null
      ? 'manual'
      : x.fireplace
      ? 'fireplace'
      : (x.holiday ? 'holiday' : 'normal');
  final modeUntil = switch (mode) {
    'manual' => manualNow!.until,
    'holiday' => c.holiday.to,
    _ => null,
  };

  // ---- price against its limit
  final day = dayCosts(now, x.cost, slotMinutes: x.slotMinutes);
  final hour = slotOf(now, x.slotMinutes);
  final price = x.cost(hour);
  double? limit;
  String? limitKind;
  int? limitHours;
  if (day != null) {
    final skip = template == 'skip_expensive' && !l.tempControl && l.priceLimit == null;
    final maxOff = l.maxOffHours ?? c.safety.maxOffHours ?? rec.maxOff;
    if (skip) {
      final kHours = ((l.skipHours ?? rec.skipHours) * (x.holiday ? 2 : 1)).clamp(1, 24);
      final k = slotsFromHours(kHours, x.slotMinutes).clamp(1, day.length);
      final chosen = expensiveHours(day, k, maxRun: maxOff * (60 / x.slotMinutes));
      final costs = [
        for (final e in day)
          if (chosen.contains(e.$1)) e.$2,
      ];
      // The price from which an hour is skipped (the cheapest of the skipped hours).
      limit = costs.isEmpty ? null : costs.reduce(math.min);
      limitKind = 'skip';
      limitHours = kHours;
    } else if (l.priceLimit != null) {
      // R634: the price limit itself; the hours of the day at or under it.
      limit = l.priceLimit;
      limitKind = 'price';
      limitHours = math.max(1, (day.where((e) => e.$2 <= l.priceLimit!).length * x.slotMinutes / 60).round());
    } else {
      var nHours = thermo ? loadHours(l, c.site, 'cheapest', x) : loadHours(l, c.site, template, x);
      if (x.holiday && space) nHours = (nHours / 2).ceil();
      final n = slotsFromHours(nHours, x.slotMinutes).clamp(1, day.length);
      final asc = [for (final e in day) e.$2]..sort();
      // The n-th cheapest price: slots at or below it are the cheap ones.
      limit = asc[n - 1];
      limitKind = 'cheap';
      limitHours = nHours;
    }
  }

  // ---- next change from the price plan (the sensor is not known ahead)
  final plan = s.plan.isNotEmpty
      ? s.plan
      : heatPlan(c, l, x, from: DateTime(now.year, now.month, now.day), to: DateTime(now.year, now.month, now.day + 2));
  DateTime? nextAt;
  bool? nextOn;
  var nextAuto = false;
  if (manualNow != null) {
    nextAt = manualNow.until;
  } else if (l.tempControl && sensorState == 'ok' && !thermo && !l.isDhw) {
    nextAuto = true;
  } else {
    for (final p in plan) {
      if (!now.isBefore(p.$1) && now.isBefore(p.$2)) {
        nextAt = p.$2;
        nextOn = false;
        break;
      }
      if (p.$1.isAfter(now)) {
        nextAt = p.$1;
        nextOn = true;
        break;
      }
    }
  }

  // R725: the next setpoint / why (price or weather), walking one slot ahead of the change.
  double? nextSetpoint;
  String? nextWhy;
  double? priceNext;
  final outdoorNow = x.outdoor(now);
  double? outdoorNext;
  if (nextAt != null) {
    priceNext = x.cost(nextAt);
    outdoorNext = x.outdoor(nextAt);
    final xi = HeatInputs(
      now: nextAt,
      cost: x.cost,
      outdoor: x.outdoor,
      temp: temp,
      holiday: c.holiday.activeAt(nextAt),
      holidayEnd: c.holiday.to ?? x.holidayEnd,
      fireplace: x.fireplace,
      slotMinutes: x.slotMinutes,
    );
    final d = thermo ? decideThermostat(c, l, xi, thermoSetpoint ?? l.comfort) : decideSwitch(c, l, xi);
    nextSetpoint = d.setpoint ?? d.target;
    if ((priceNext ?? 0) - (price ?? 0) >= 0.5) {
      nextWhy = 'price_up';
    } else if ((price ?? 0) - (priceNext ?? 0) >= 0.5) {
      nextWhy = 'price_down';
    } else if (outdoorNow != null && outdoorNext != null && outdoorNext - outdoorNow >= 2) {
      nextWhy = 'weather_warm';
    } else if (outdoorNow != null && outdoorNext != null && outdoorNow - outdoorNext >= 2) {
      nextWhy = 'weather_cool';
    } else {
      nextWhy = d.reason;
    }
  }

  double? heatHoursToday;
  double? costToday;
  if (l.isDhw) {
    final est = dhwCostEstimate(c, l, x);
    heatHoursToday = est.$1;
    costToday = est.$2;
  }

  // ---- checks
  final checks = <HeatCheck>[];
  if (l.isDhw) {
    checks.add(
      HeatCheck(
        'min_temp',
        l.waterMin == null || temp == null ? 'unknown' : (reason == 'min_temp' ? 'active' : 'pass'),
        {'temp': temp, 'limit': l.waterMin},
      ),
    );
    checks.add(
      HeatCheck('legionella', l.legionellaWeekday == null ? 'inactive' : (reason == 'legionella' ? 'active' : 'pass'), {
        'weekday': l.legionellaWeekday,
        'hour': l.legionellaHour,
        'temp': l.legionellaTemp,
      }),
    );
  }
  final safetyOn = space && !thermo;
  if (safetyOn || thermo) {
    checks.add(
      HeatCheck(
        'frost',
        !c.safety.frost ? 'inactive' : (temp == null ? 'unknown' : (reason == 'frost' ? 'active' : 'pass')),
        {'temp': temp, 'limit': c.safety.frostTemp},
      ),
    );
    checks.add(
      HeatCheck('min_temp', temp == null ? 'unknown' : (reason == 'min_temp' ? 'active' : 'pass'), {
        'temp': temp,
        'limit': c.safety.minTemp,
      }),
    );
  }
  final manualLeft = manualNow?.until.difference(now).inMinutes ?? 0;
  checks.add(
    HeatCheck('manual', manualNow != null ? 'active' : 'inactive', {
      if (manualNow != null) ...{
        'on': manualNow.on,
        'left': manualLeft,
        'untilHm':
            '${manualNow.until.hour.toString().padLeft(2, '0')}.${manualNow.until.minute.toString().padLeft(2, '0')}',
      },
    }),
  );
  if (c.site.fireplace) {
    checks.add(HeatCheck('fireplace', x.fireplace && l.followsFireplace ? 'active' : 'inactive'));
  }
  checks.add(
    HeatCheck(
      'holiday',
      x.holiday ? (reason.startsWith('holiday') ? 'active' : 'pass') : (c.holiday.on ? 'pass' : 'inactive'),
      {'keep': (c.holiday.temp > c.safety.minTemp ? c.holiday.temp : c.safety.minTemp)},
    ),
  );
  if (!thermo && l.tempControl && space) {
    final sp = setpoint ?? (l.comfort + shift);
    final half = l.hysteresis / 2;
    checks.add(
      HeatCheck('temp', sensorState != 'ok' ? 'unknown' : (reason.startsWith('temp_') ? 'active' : 'pass'), {
        'temp': temp,
        'setpoint': sp,
        'half': half,
        'onBelow': sp - half,
        'offAbove': sp + half,
        'fallback': l.fallback,
      }),
    );
    checks.add(
      HeatCheck('shift', l.expensiveDrop == 0 && l.cheapBoost == 0 ? 'inactive' : (shift != 0 ? 'active' : 'pass'), {
        'shift': shift,
      }),
    );
  } else if (!thermo && space) {
    final cap = l.comfort + c.site.swing;
    checks.add(
      HeatCheck('warm', sensorState != 'ok' ? 'unknown' : (reason == 'warm' ? 'active' : 'pass'), {
        'temp': temp,
        'cap': cap,
      }),
    );
  }
  if (!(l.tempControl && space && sensorState == 'ok' && !thermo)) {
    final hasDay = day != null;
    if (template == 'skip_expensive' && l.priceLimit == null) {
      checks.add(
        HeatCheck('skip', !hasDay ? 'unknown' : ((reason == 'expensive' || reason == 'normal') ? 'active' : 'pass'), {
          'price': price,
          'limit': limit,
          'n': limitHours,
          'hit': reason == 'expensive',
        }),
      );
    } else if (l.priceLimit != null) {
      checks.add(
        HeatCheck(
          'pricelimit',
          !hasDay ? 'unknown' : ((reason == 'cheap' || reason == 'not_cheap') ? 'active' : 'pass'),
          {'price': price, 'limit': limit, 'n': limitHours, 'hit': reason == 'cheap'},
        ),
      );
    } else {
      checks.add(
        HeatCheck(
          'cheapest',
          !hasDay ? 'unknown' : ((reason == 'cheap' || reason == 'not_cheap') ? 'active' : 'pass'),
          {'price': price, 'limit': limit, 'n': limitHours, 'hit': reason == 'cheap'},
        ),
      );
    }
    if (template == 'weather' && space && l.priceLimit == null) {
      final temps = [for (var h = 0; h < 24; h++) x.outdoor(DateTime(now.year, now.month, now.day, h))]
          .whereType<double>()
          .toList();
      final avg = temps.isEmpty ? null : temps.reduce((a, b) => a + b) / temps.length;
      checks.add(
        HeatCheck('weather', avg == null ? 'unknown' : 'active', {
          'avg': avg,
          'hours': thermo ? null : loadHours(l, c.site, template, x),
        }),
      );
    }
  }
  checks.add(HeatCheck('noprice', day == null ? 'active' : 'pass'));
  if (!thermo) {
    final maxOff = l.maxOffHours ?? c.safety.maxOffHours ?? rec.maxOff;
    checks.add(HeatCheck('max_off', reason == 'max_off' ? 'active' : 'pass', {'hours': maxOff}));
    checks.add(
      HeatCheck('min_on', l.minOnMinutes == 0 ? 'inactive' : (reason == 'min_on' ? 'active' : 'pass'), {
        'minutes': l.minOnMinutes,
      }),
    );
    checks.add(
      HeatCheck('min_off', l.minOffMinutes == 0 ? 'inactive' : (reason == 'min_off' ? 'active' : 'pass'), {
        'minutes': l.minOffMinutes,
      }),
    );
  }
  checks.add(
    HeatCheck('sensor', sensorState == 'none' ? 'inactive' : (sensorState == 'ok' ? 'pass' : 'unknown'), {
      'temp': temp,
    }),
  );
  if (s.error != null) checks.add(const HeatCheck('device', 'active'));

  return HeatExplanation(
    loadId: l.id,
    control: l.control,
    template: template,
    enabled: l.enabled,
    mode: mode,
    modeUntil: modeUntil,
    on: on,
    want: want,
    changedAt: s.changedAt,
    target: target,
    reason: reason,
    safety: safety,
    fallback: fallback,
    temp: temp,
    setpoint: setpoint,
    comfort: thermo ? (thermoSetpoint ?? l.comfort) : l.comfort,
    shift: shift,
    hysteresis: l.hysteresis,
    tempControl: l.tempControl && !thermo,
    minTemp: c.safety.minTemp,
    frostTemp: c.safety.frost ? c.safety.frostTemp : null,
    maxTemp: l.comfort + c.site.swing,
    sensor: sensorState,
    price: price,
    limit: limit,
    limitKind: limitKind,
    limitHours: limitHours,
    nextAt: nextAt,
    nextOn: nextOn,
    nextAuto: nextAuto,
    error: s.error,
    errorAt: s.errorAt,
    sensorError: s.sensorError,
    preview: isPreview && (preview || st == null),
    maxOffHours: l.maxOffHours ?? c.safety.maxOffHours ?? rec.maxOff,
    minOnMinutes: l.minOnMinutes,
    minOffMinutes: l.minOffMinutes,
    storage: l.type == 'concrete_floor' || l.type == 'water_heater',
    fallbackRule: l.fallback,
    checks: checks,
    dhw: l.isDhw,
    waterTarget: l.waterTarget,
    waterMin: l.waterMin,
    costToday: costToday,
    heatHoursToday: heatHoursToday,
    powerKw: l.powerKw,
    nextSetpoint: nextSetpoint,
    nextWhy: nextWhy,
    priceNext: priceNext,
    outdoorNow: outdoorNow,
    outdoorNext: outdoorNext,
    slotMinutes: x.slotMinutes,
    plan: plan,
  );
}
