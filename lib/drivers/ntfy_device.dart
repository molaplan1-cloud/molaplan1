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
  // A command that places its own PIN / cid ("pihavalo päälle {pin}") is used as is.
  if (cmd.contains('{pin}') || cmd.contains('{cid}')) t = cmd;
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
    // A JSON reply that names a cid must name ours; replies without one (or cid: null) are accepted.
    if (j is Map && j['cid'] != null && '${j['cid']}' != cid) return false;
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
    if (j['ok'] == false || j['error'] != null) return '${j['err'] ?? j['error'] ?? j['message'] ?? m.message}';
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
  /// t235u: when the last status reply really arrived (not reset by commands).
  DateTime? okAt;
  /// t235u: state after a command that was published but not answered: JSON path → (value, when).
  final optimistic = <String, (bool, DateTime)>{};
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
        helpFi: 'Kuinka kauan vastaus näkyy ruudussa. 0 = kunnes painat uudelleen.',
        helpEn: 'How long the reply stays on the tile. 0 = until the next press.',
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
  Future<NtfyMessage> _ask(String cmd, {Object? value, Duration? waitFor}) async {
    final tpl = s.str('template', '{cmd} {pin}');
    final cid = tpl.contains('{cid}') || cmd.contains('{cid}') ? _newCid() : '';
    final text = buildNtfyCommand(tpl, cmd: cmd, pin: s.str('pin'), cid: cid, value: value);
    final usesPin = s.str('pin').isNotEmpty && (tpl.contains('{pin}') || cmd.contains('{pin}'));
    if (text.isEmpty) throw DriverException(dtx('ntfy: komento puuttuu', 'ntfy: command missing'));
    final sh = _sh;
    // Rate limit: one command per [minInterval] to this device (also across tiles).
    // +0.5 s: ntfy delivery jitter must not make two commands arrive closer than the device allows.
    final gap = _gap == Duration.zero ? Duration.zero : _gap + const Duration(milliseconds: 500);
    while (gap > Duration.zero && sh.lastSent != null) {
      final left = sh.lastSent!.add(gap).difference(DateTime.now());
      if (left <= Duration.zero) break;
      await Future<void>.delayed(left);
    }
    sh.lastSent = DateTime.now();
    final wait = waitFor ?? _wait;
    final noTopic = (s.strOrNull('replyTopic') ?? '').trim().isEmpty;
    final m = await exchange(
      text,
      wait: wait,
      accept: (m) => ntfyReplyMatches(m, title: s.strOrNull('replyTitle'), match: s.strOrNull('replyMatch'), cid: cid),
      // t235u: the publish already succeeded here – a missing reply is the device's.
      timeoutText: (topic, secs) => _replyHint(noTopic, usesPin
          ? dtx(
              'Komento lähti, mutta laite ei vastannut $secs s:ssa – onko laite verkossa? Tarkista myös PIN-koodi: moni laite ei vastaa lainkaan väärään PIN-koodiin (aihe "$topic").',
              'The command was sent, but the device did not answer within $secs s – is the device online? Also check the PIN: many devices do not answer a wrong PIN at all (topic "$topic").',
            )
          : dtx(
              'Komento lähti, mutta laite ei vastannut $secs s:ssa – onko laite verkossa? Jos laite vastaa vain tietyin väliajoin, kasvata "Komentojen väli" -asetusta (aihe "$topic").',
              'The command was sent, but the device did not answer within $secs s – is the device online? If it answers only at intervals, increase "Minimum time between commands" (topic "$topic").',
            )),
    );
    // A JSON reply carries the whole state even when the command was refused: share it first.
    if (ntfyJsonPayload(m.message) is Map) {
      sh.last = m;
      sh.at = sh.okAt = DateTime.now();
      sh.optimistic.clear();
    }
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
          sh.at = sh.okAt = DateTime.now();
          sh.optimistic.clear();
          return m;
        })
        .whenComplete(() => sh.inFlight = null);
  }

  /// How long a published-but-unanswered command or the last status keeps the tile without '!'.
  static const staleAfter = Duration(minutes: 15);

  String _replyHint(bool noTopic, String text) => !noTopic
      ? text
      : '$text ${dtx('Jos laite vastaa toiselle kanavalle (esim. ilmoituskanavallesi), aseta se kohtaan "Vastauskanava".', 'If the device replies on another topic (e.g. your notification topic), set it as "Reply topic".')}';

  static String? _pathOf(Map<String, dynamic> spec) => spec.strOrNull('statePath') ?? spec.strOrNull('jsonPath');

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final sh = _sh;
    final path = _pathOf(spec);
    // Exact path (new tiles carry statePath) or the command's first word (older tiles: "sisavalo on").
    (bool, DateTime)? opt;
    if (path != null) {
      opt = sh.optimistic[path];
      if (opt == null) {
        for (final e in sh.optimistic.entries) {
          if (!e.key.startsWith(r'$') && (path.endsWith('.${e.key}') || path == e.key)) opt = e.value;
        }
      }
    }
    final now = DateTime.now();
    try {
      final m = await status(command: spec.strOrNull('command'));
      return ntfyStateFrom(m, spec, _rules);
    } on NtfyNoReply {
      // t235u: no status reply – keep the commanded / last known state for a while instead of '!'.
      if (opt != null && now.difference(opt.$2) < staleAfter) return opt.$1;
      final last = sh.last;
      if (last != null && sh.okAt != null && now.difference(sh.okAt!) < staleAfter) return ntfyStateFrom(last, spec, _rules);
      rethrow;
    }
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final cmd = spec.str('command');
    if (cmd.trim().isEmpty) throw DriverException(dtx('ntfy: komento puuttuu', 'ntfy: command missing'));
    if (!spec.flag('waitReply', true)) {
      final tpl = s.str('template', '{cmd} {pin}');
      final text = buildNtfyCommand(tpl, cmd: cmd, pin: s.str('pin'), value: value);
      _sh.lastSent = DateTime.now();
      final r = (await publish(text)).toReply()..['sentOnly'] = true;
      _remember(spec, value);
      return r;
    }
    // t235u: success = the publish worked. Wait a short while for the device's answer (its JSON
    // state, or an error such as a wrong PIN); no answer is not an error – the state then comes
    // from the next status poll.
    final ack = Duration(seconds: spec.integer('ackSeconds', 10).clamp(2, 120));
    final NtfyMessage m;
    try {
      m = await _ask(cmd, value: value, waitFor: ack < _wait ? ack : _wait);
    } on NtfyNoReply {
      _remember(spec, value);
      return {'ntfy': true, 'sentOnly': true, 'noReply': true};
    }
    // A JSON reply (the state) already refreshed every tile in _ask; after a text reply the
    // next read asks again.
    if (ntfyJsonPayload(m.message) is! Map) {
      _remember(spec, value);
    }
    return m.toReply()..['showSeconds'] = spec.integer('showSeconds', 30);
  }

  /// Remembers the commanded state for the tile's JSON path and asks a fresh status next time.
  void _remember(Map<String, dynamic> spec, Object? value) {
    final sh = _sh;
    sh.at = null;
    final first = spec.str('command').trim().split(RegExp(r'\s+')).first;
    final path = spec.strOrNull('statePath') ?? (first.isEmpty || first.startsWith('{') ? null : first);
    if (path == null || value == null) return;
    final on = value == true || (value is num && value != 0) || isTruthy(value);
    sh.optimistic[path] = (on, DateTime.now());
  }

  @override
  Future<String> test() async {
    final base = await super.test();
    final pin = s.str('pin').isEmpty ? '' : dtx(' PIN on tallennettu.', ' A PIN is stored.');
    return '$base$pin';
  }
}

/// t235u: the setup test's message when the status read failed after the server test passed.
/// A publish failure keeps its own (server) message; a missing reply never blames the service.
String ntfyNoReplyText(Object e, String serverOk) {
  final m = e is DriverException ? e.message : '';
  if (m.startsWith('Komento lähti') || m.startsWith('The command was sent') || m.startsWith('Laite vastasi') || m.startsWith('The device answered')) {
    return m;
  }
  if (e is TimeoutException) {
    return dtx(
      'Komento lähti, mutta laite ei vastannut ajoissa – onko laite verkossa? (ntfy-palvelin toimii.)',
      'The command was sent, but the device did not answer in time – is the device online? (The ntfy server works.)',
    );
  }
  return m.isNotEmpty ? m : '$e';
}
