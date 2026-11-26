/// t198u: a generic "ntfy-komentolaite" – any home device (alarm panel, camera NVR, controller…)
/// that takes text commands from one ntfy topic and answers on the same or another topic.
///
/// * Commands are built from a template, by default `{cmd} {pin}`. The PIN is a connection
///   secret (never shown, never sent anywhere else). `{cid}` adds a correlation id and `{value}`
///   the slider / toggle value.
/// * Replies may come on a DIFFERENT topic (e.g. a per-user notification topic that also carries
///   other notifications): they can be filtered by title and by a text pattern, and a JSON reply
///   that echoes `cid` must echo OUR id (so two phones never take each other's replies).
/// * Replies are plain text ("Pihavalo: PÄÄLLÄ, Sireeni: POIS") or JSON (`{"pihavalo":1,…}`):
///   a tile reads its state with a JSON path or a regex (group 1), then the connection's
///   text → state map turns "päällä" / "pois" into on / off.
/// * Rate limits: many devices answer only every N seconds. Commands to one topic are spaced
///   by "minInterval", status replies are shared by all tiles of the connection for
///   "cacheSeconds", and a reply to a switch command updates the shared state at once.
/// * It talks to the ntfy server directly over HTTPS: it works at home and away, no home bridge.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:math';

import '../core/fields.dart';
import '../core/jsonpath.dart';
import '../core/template.dart';
import 'driver.dart';
import 'ntfy_driver.dart';

/// `{cmd} {pin}` → "tila json 1234". Unknown or empty placeholders disappear, spaces collapse.
String buildNtfyCommand(String template, {required String cmd, String pin = '', String cid = '', Object? value}) {
  var t = template.trim().isEmpty ? '{cmd} {pin}' : template;
  if (!t.contains('{cmd}')) t = '{cmd} $t';
  final v = value == null ? '' : (value is bool ? (value ? 'on' : 'off') : '$value');
  final out = t
      .replaceAll('{cmd}', cmd.trim())
      .replaceAll('{pin}', pin.trim())
      .replaceAll('{cid}', cid)
      .replaceAll('{value}', v);
  return out.replaceAll(RegExp(r'[ \t]+'), ' ').trim();
}

/// One "pattern = value" rule of the text → state map.
class NtfyStateRule {
  NtfyStateRule(this.pattern, this.value);
  final RegExp pattern;
  final Object? value;
}

/// Parses rules, one per line or separated by ';':
///   `päällä|on|1 = true` · `pois|off|0 = false` · `hälytys = alarm` · `(?i)virhe.* = error`
/// The pattern is a case-insensitive regex that must match the WHOLE captured text.
/// Values `true` / `false` / numbers become those types; anything else stays text.
List<NtfyStateRule> parseNtfyStateMap(String? text) {
  final out = <NtfyStateRule>[];
  if (text == null) return out;
  for (final raw in text.split(RegExp(r'[\r\n;]+'))) {
    final line = raw.trim();
    if (line.isEmpty || line.startsWith('#')) continue;
    final i = line.lastIndexOf(RegExp(r'=>|='));
    if (i <= 0) continue;
    final pat = line.substring(0, i).trim();
    final rest = line.substring(i).replaceFirst(RegExp(r'^=>|^='), '').trim();
    final Object v = switch (rest.toLowerCase()) {
      'true' => true,
      'false' => false,
      _ => num.tryParse(rest) ?? rest,
    };
    try {
      out.add(NtfyStateRule(RegExp('^(?:$pat)\$', caseSensitive: false), v));
    } on FormatException {
      // A broken rule is skipped (the connection test reports it).
    }
  }
  return out;
}

/// Default map: Finnish + English on/off words, so most devices need no setup.
final defaultNtfyStateMap = parseNtfyStateMap(
  'päällä|paalla|on|1|true|kyllä|auki|aktiivinen|active|enabled|käynnissä = true\n'
  'pois|pois päältä|off|0|false|ei|kiinni|passiivinen|inactive|disabled|seis = false',
);

Object? mapNtfyState(Object? v, List<NtfyStateRule> rules) {
  if (v == null || v is bool) return v;
  final t = '$v'.trim();
  for (final r in rules) {
    if (r.pattern.hasMatch(t)) return r.value;
  }
  return coerce(v);
}

/// The device's payload: JSON when the message text is a JSON object / array, else null.
Object? ntfyJsonPayload(String message) {
  final t = message.trim();
  if (!(t.startsWith('{') || t.startsWith('['))) return null;
  try {
    return jsonDecode(t);
  } catch (_) {
    return null;
  }
}

/// Is [m] the reply we wait for? [title] = substring of the title (case-insensitive),
/// [match] = regex the "title message" text must contain, [cid] = our correlation id.
bool ntfyReplyMatches(NtfyMessage m, {String? title, String? match, String? cid}) {
  if (title != null && title.trim().isNotEmpty && !m.title.toLowerCase().contains(title.trim().toLowerCase())) {
    return false;
  }
  if (match != null && match.trim().isNotEmpty) {
    try {
      if (!RegExp(match, caseSensitive: false, multiLine: true).hasMatch('${m.title}\n${m.message}')) return false;
    } on FormatException {
      return false;
    }
  }
  if (cid != null && cid.isNotEmpty) {
    final j = ntfyJsonPayload(m.message);
    // A JSON reply that names a cid must name ours; replies without one are accepted.
    if (j is Map && j.containsKey('cid') && '${j['cid']}' != cid) return false;
  }
  return true;
}

/// A tile's value from a reply: JSON path (JSON payloads) or regex group 1 (text), then the map.
Object? ntfyStateFrom(NtfyMessage m, Map<String, dynamic> spec, List<NtfyStateRule> rules) {
  final json = ntfyJsonPayload(m.message);
  final path = spec.strOrNull('jsonPath');
  final regex = spec.strOrNull('regex');
  Object? v;
  if (path != null && json != null) {
    v = jsonPathGet(json, path);
  } else if (regex != null) {
    final r = RegExp(regex, caseSensitive: false, multiLine: true).firstMatch(m.message);
    v = r == null ? null : (r.groupCount >= 1 ? r.group(1) : r.group(0));
  } else if (path != null) {
    v = null; // a JSON path on a text reply: the state is unknown
  } else {
    return m.text;
  }
  return mapNtfyState(v, rules);
}

/// An error the device reported: JSON `{ok:false}` / `{error:…}` or text matching [pattern].
String? ntfyDeviceError(NtfyMessage m, String? pattern) {
  final j = ntfyJsonPayload(m.message);
  if (j is Map) {
    if (j['ok'] == false || j['error'] != null) return '${j['error'] ?? j['message'] ?? m.message}';
    return null;
  }
  final p = pattern ?? r'väärä pin|wrong pin|invalid pin|virhe|error|denied|kielletty|ei sallittu';
  if (p.trim().isEmpty) return null;
  try {
    if (RegExp(p, caseSensitive: false).hasMatch(m.message)) return m.text;
  } on FormatException {
    return null;
  }
  return null;
}

class _Shared {
  NtfyMessage? last;
  DateTime? at;
  Future<NtfyMessage>? inFlight;
  DateTime? lastSent;
}

class NtfyDeviceDriver extends NtfyDriver {
  NtfyDeviceDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'ntfy_device',
    fi: 'ntfy-komentolaite (komennot + tila)',
    en: 'ntfy command device (commands + state)',
    create: NtfyDeviceDriver.new,
    connectionFields: [
      FieldSpec(
        'topic',
        'Komentokanava (aihe tai koko osoite)',
        'Command topic (name or full URL)',
        required: true,
        hint: 'https://ntfy.sh/oma-komentoaihe',
        helpFi: 'Aihe, jota kotilaite kuuntelee. Aiheen nimi on kuin salasana: pidä se pitkänä ja satunnaisena.',
        helpEn: 'The topic the home device listens to. The topic name works like a password: keep it long and random.',
      ),
      FieldSpec(
        'replyTopic',
        'Vastauskanava (vapaaehtoinen)',
        'Reply topic (optional)',
        hint: 'oma-ilmoitusaihe',
        helpFi: 'Jos laite vastaa toiseen aiheeseen (esim. henkilökohtaiseen ilmoitusaiheeseen), kirjoita se tähän. Tyhjä = sama kuin komentokanava.',
        helpEn: 'If the device answers on another topic (e.g. your personal notification topic), type it here. Empty = the command topic.',
      ),
      FieldSpec(
        'pin',
        'PIN-koodi (vapaaehtoinen)',
        'PIN code (optional)',
        kind: FieldKind.secret,
        helpFi: 'Tallennetaan salattuna tähän laitteeseen. Lisätään komentoon mallin {pin}-kohtaan.',
        helpEn: 'Stored encrypted on this device. Inserted where the template says {pin}.',
      ),
      FieldSpec(
        'template',
        'Komennon malli',
        'Command template',
        defaultValue: '{cmd} {pin}',
        hint: '{cmd} {pin}',
        helpFi: '{cmd} = painikkeen komento, {pin} = PIN, {cid} = tunniste jonka laite toistaa vastauksessa, {value} = arvo (on/off tai luku). Esim. "{cmd} {pin}" → "pihavalo on 1234".',
        helpEn: '{cmd} = the button\'s command, {pin} = PIN, {cid} = an id the device echoes in its reply, {value} = the value (on/off or a number). E.g. "{cmd} {pin}" → "light on 1234".',
      ),
      FieldSpec(
        'statusCommand',
        'Tilakomento',
        'Status command',
        defaultValue: 'tila',
        hint: 'tila',
        helpFi: 'Komento, johon laite vastaa tilallaan (esim. "tila" tai "tila json"). Kaikki tämän laitteen ruudut käyttävät samaa vastausta.',
        helpEn: 'The command the device answers with its state (e.g. "status" or "status json"). All tiles of this device share the reply.',
      ),
      FieldSpec(
        'replyTitle',
        'Vastauksen otsikko sisältää (vapaaehtoinen)',
        'Reply title contains (optional)',
        hint: 'Kamera valvonta',
        helpFi: 'Vain viestit, joiden otsikossa on tämä teksti, lasketaan vastaukseksi – hyödyllinen, kun vastauskanavalla on muitakin ilmoituksia.',
        helpEn: 'Only messages whose title contains this text count as the reply – useful when the reply topic carries other notifications too.',
      ),
      FieldSpec(
        'replyMatch',
        'Vastauksen tunniste (regex, vapaaehtoinen)',
        'Reply must contain (regex, optional)',
        advanced: true,
        helpFi: 'Säännöllinen lauseke, joka vastauksessa pitää olla (otsikko + viesti).',
        helpEn: 'A regular expression the reply (title + message) must contain.',
      ),
      FieldSpec(
        'stateMap',
        'Tekstin tulkinta tiloiksi',
        'Text to state map',
        kind: FieldKind.multiline,
        advanced: true,
        hint: 'päällä|on = true\npois|off = false',
        helpFi: 'Rivi per sääntö: "kuvio = arvo". Kuvio on regex, jonka pitää vastata koko luettua tekstiä (kirjainkoolla ei väliä). Tyhjä = valmiit suomen- ja englanninkieliset päällä/pois-sanat.',
        helpEn: 'One rule per line: "pattern = value". The pattern is a regex matching the whole captured text (case-insensitive). Empty = built-in Finnish and English on/off words.',
      ),
      FieldSpec(
        'errorMatch',
        'Virhevastaus (regex)',
        'Error reply (regex)',
        advanced: true,
        hint: 'väärä pin|virhe|error',
        helpFi: 'Vastaus, joka tarkoittaa virhettä (näytetään punaisena). Tyhjä = oletus (väärä PIN, virhe, error, denied…). JSON-vastauksessa ok:false tai error-kenttä.',
        helpEn: 'A reply meaning an error (shown in red). Empty = default (wrong PIN, error, denied…). For JSON: ok:false or an error field.',
      ),
      FieldSpec(
        'minInterval',
        'Komentojen väli vähintään (s)',
        'Minimum time between commands (s)',
        kind: FieldKind.number,
        defaultValue: 0,
        helpFi: 'Jos laite vastaa vain esim. 30 sekunnin välein, kirjoita 30: seuraava komento odottaa vuoroaan eikä huku.',
        helpEn: 'If the device answers only e.g. every 30 seconds, type 30: the next command waits its turn instead of being lost.',
      ),
      FieldSpec(
        'replySeconds',
        'Vastauksen odotus (s)',
        'Wait for reply (s)',
        kind: FieldKind.number,
        defaultValue: 45,
        helpFi: 'Kuinka kauan vastausta odotetaan ennen virheilmoitusta.',
        helpEn: 'How long to wait for the reply before showing an error.',
      ),
      FieldSpec(
        'cacheSeconds',
        'Tilavastaus voimassa (s)',
        'Status reply valid for (s)',
        kind: FieldKind.number,
        defaultValue: 30,
        advanced: true,
        helpFi: 'Saman laitteen ruudut käyttävät samaa tilavastausta tämän ajan – laitetta ei kysytä turhaan.',
        helpEn: 'Tiles of the same device share one status reply for this long – the device is not asked needlessly.',
      ),
      FieldSpec(
        'token',
        'Käyttöoikeustunnus (vapaaehtoinen)',
        'Access token (optional)',
        kind: FieldKind.secret,
        hint: 'tk_…',
        helpFi: 'Vain suojatulle aiheelle (ntfy-tili → Access tokens).',
        helpEn: 'Only for a protected topic (ntfy account → Access tokens).',
      ),
      FieldSpec(
        'server',
        'Palvelin',
        'Server',
        defaultValue: 'https://ntfy.sh',
        advanced: true,
        helpFi: 'Oletus on julkinen ntfy.sh. Jos liitit yllä koko osoitteen, palvelin luetaan siitä.',
        helpEn: 'Default is the public ntfy.sh. A full URL above overrides this.',
      ),
    ],
    readFields: [
      FieldSpec(
        'jsonPath',
        'JSON-polku (JSON-vastaus)',
        'JSON path (JSON reply)',
        hint: r'$.pihavalo',
        helpFi: 'Kun laite vastaa JSONilla, esim. \$.pihavalo tai \$.lahdot.sireeni.',
        helpEn: r'When the device answers with JSON, e.g. $.light or $.outputs.siren.',
      ),
      FieldSpec(
        'regex',
        'Tekstistä (regex, ryhmä 1)',
        'From text (regex, group 1)',
        hint: r'pihavalo:\s*(\S+)',
        helpFi: 'Kun vastaus on tekstiä: säännöllinen lauseke, jonka ensimmäinen sulkuryhmä on tila, esim. pihavalo:\\s*(\\S+).',
        helpEn: r'For a text reply: a regular expression whose first group is the state, e.g. light:\s*(\S+).',
      ),
      FieldSpec(
        'command',
        'Tilakomento tälle ruudulle (vapaaehtoinen)',
        'Status command for this tile (optional)',
        advanced: true,
        helpFi: 'Tyhjä = laitteen tilakomento.',
        helpEn: 'Empty = the device\'s status command.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'command',
        'Komento',
        'Command',
        required: true,
        hint: 'pihavalo on',
        helpFi: 'Esim. "pihavalo on". PIN ja muut kohdat lisätään laitteen komentomallin mukaan.',
        helpEn: 'E.g. "light on". The PIN and other parts are added by the device\'s command template.',
      ),
      FieldSpec(
        'waitReply',
        'Odota vastausta',
        'Wait for the reply',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Näyttää laitteen vastauksen (tai selkeän virheen) ruudussa.',
        helpEn: 'Shows the device\'s reply (or a clear error) on the tile.',
      ),
      FieldSpec(
        'showSeconds',
        'Vastaus näkyy ruudussa (s)',
        'Reply stays on the tile (s)',
        kind: FieldKind.number,
        defaultValue: 30,
        advanced: true,
      ),
    ],
  );

  static final _shared = <String, _Shared>{};
  static final _rnd = Random.secure();

  /// Test hook: forget shared state between tests.
  static void resetShared() => _shared.clear();

  _Shared get _sh {
    final (srv, t) = commandTopicPair;
    return _shared.putIfAbsent('$srv/$t', _Shared.new);
  }

  List<NtfyStateRule> get _rules {
    final m = s.strOrNull('stateMap');
    final r = parseNtfyStateMap(m);
    return r.isEmpty ? defaultNtfyStateMap : [...r, ...defaultNtfyStateMap];
  }

  Duration get _wait => Duration(seconds: s.integer('replySeconds', 45).clamp(3, 600));
  Duration get _gap => Duration(seconds: s.integer('minInterval', 0).clamp(0, 3600));

  String _newCid() => List.generate(6, (_) => _rnd.nextInt(16).toRadixString(16)).join();

  /// Builds the text, waits for the device's rate limit, sends and waits for the matching reply.
  Future<NtfyMessage> _ask(String cmd, {Object? value}) async {
    final tpl = s.str('template', '{cmd} {pin}');
    final cid = tpl.contains('{cid}') ? _newCid() : '';
    final text = buildNtfyCommand(tpl, cmd: cmd, pin: s.str('pin'), cid: cid, value: value);
    if (text.isEmpty) throw DriverException(dtx('ntfy: komento puuttuu', 'ntfy: command missing'));
    final sh = _sh;
    // Rate limit: one command per [minInterval] to this device (also across tiles).
    final gap = _gap;
    while (gap > Duration.zero && sh.lastSent != null) {
      final left = sh.lastSent!.add(gap).difference(DateTime.now());
      if (left <= Duration.zero) break;
      await Future<void>.delayed(left);
    }
    sh.lastSent = DateTime.now();
    final wait = _wait;
    final m = await exchange(
      text,
      wait: wait,
      accept: (m) => ntfyReplyMatches(m, title: s.strOrNull('replyTitle'), match: s.strOrNull('replyMatch'), cid: cid),
      timeoutText: (topic, secs) => dtx(
        'Laite ei vastannut $secs sekunnissa (aihe "$topic"). Jos laite vastaa vain tietyin väliajoin, kasvata "Vastauksen odotus" tai "Komentojen väli" -asetusta.',
        'The device did not answer within $secs s (topic "$topic"). If it answers only at intervals, increase "Wait for reply" or "Minimum time between commands".',
      ),
    );
    final err = ntfyDeviceError(m, s.strOrNull('errorMatch'));
    if (err != null) throw DriverException(dtx('Laite vastasi: $err', 'The device answered: $err'));
    return m;
  }

  /// The shared status reply (one request at a time, reused for [cacheSeconds]).
  Future<NtfyMessage> status({String? command, bool fresh = false}) {
    final sh = _sh;
    final ttl = Duration(seconds: s.integer('cacheSeconds', 30).clamp(0, 3600));
    if (!fresh && sh.last != null && sh.at != null && DateTime.now().difference(sh.at!) < ttl) {
      return Future.value(sh.last!);
    }
    return sh.inFlight ??= _ask(command ?? s.str('statusCommand', 'tila'))
        .then((m) {
          sh.last = m;
          sh.at = DateTime.now();
          return m;
        })
        .whenComplete(() => sh.inFlight = null);
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final m = await status(command: spec.strOrNull('command'));
    return ntfyStateFrom(m, spec, _rules);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final cmd = spec.str('command', spec.str('message'));
    if (cmd.trim().isEmpty) throw DriverException(dtx('ntfy: komento puuttuu', 'ntfy: command missing'));
    if (!spec.flag('waitReply', true)) {
      final tpl = s.str('template', '{cmd} {pin}');
      final text = buildNtfyCommand(tpl, cmd: cmd, pin: s.str('pin'), value: value);
      _sh.lastSent = DateTime.now();
      return (await publish(text)).toReply()..['sentOnly'] = true;
    }
    final m = await _ask(cmd, value: value);
    // A reply that carries the state (JSON or a status text) refreshes every tile at once;
    // otherwise the next read asks again.
    final sh = _sh;
    if (ntfyJsonPayload(m.message) is Map) {
      sh.last = m;
      sh.at = DateTime.now();
    } else {
      sh.at = null;
    }
    return m.toReply()..['showSeconds'] = spec.integer('showSeconds', 30);
  }

  @override
  Future<String> test() async {
    final base = await super.test();
    final pin = s.str('pin').isEmpty ? '' : dtx(' PIN on tallennettu.', ' A PIN is stored.');
    return '$base$pin';
  }
}
