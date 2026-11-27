import 'dart:async';
import 'package:http/http.dart' as http;
import 'dart:convert';

import '../core/fields.dart';
import 'driver.dart';
import '../core/http_client.dart';

/// One ntfy message (https://docs.ntfy.sh/subscribe/api/).
class NtfyMessage {
  NtfyMessage({required this.id, required this.time, required this.message, this.title = '', this.topic = ''});
  final String id;
  final int time; // unix seconds
  final String message;
  final String title;
  final String topic;

  static NtfyMessage? fromJson(Object? j) {
    if (j is! Map || j['event'] != 'message') return null;
    return NtfyMessage(
      id: '${j['id'] ?? ''}',
      time: (j['time'] as num?)?.toInt() ?? 0,
      message: '${j['message'] ?? ''}',
      title: '${j['title'] ?? ''}',
      topic: '${j['topic'] ?? ''}',
    );
  }

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(time * 1000);

  String get hhmm => '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}';

  /// What a tile shows: "title: message" (or just the message).
  String get text => title.isEmpty ? message : '$title: $message';

  Map<String, dynamic> toReply() => {'ntfy': true, 'id': id, 'title': title, 'message': message, 'time': time};
}

/// "https://ntfy.sh/topic" or "topic" (+ server) -> (server, topic).
(String, String) parseNtfyTopic(String input, String server) {
  var t = input.trim();
  var srv = server.trim().isEmpty ? 'https://ntfy.sh' : server.trim();
  if (t.contains('://')) {
    final u = Uri.parse(t);
    srv = '${u.scheme}://${u.authority}';
    t = u.pathSegments.where((p) => p.isNotEmpty).lastOrNull ?? '';
  } else if (t.contains('/')) {
    // "ntfy.sh/topic"
    final i = t.lastIndexOf('/');
    srv = 'https://${t.substring(0, i)}';
    t = t.substring(i + 1);
  }
  if (!srv.contains('://')) srv = 'https://$srv';
  return (srv.replaceAll(RegExp(r'/+$'), ''), t);
}

/// ntfy: send a command as a message, wait for the home device's reply on the same
/// (or a separate) topic, and show the latest messages of a topic.
class NtfyDriver extends Driver {
  NtfyDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'ntfy',
    fi: 'ntfy (viestikanava / komennot)',
    en: 'ntfy (message channel / commands)',
    create: NtfyDriver.new,
    connectionFields: [
      FieldSpec(
        'topic',
        'Komentokanava (aihe tai koko osoite)',
        'Command topic (name or full URL)',
        required: true,
        hint: 'https://ntfy.sh/oma-aihe',
        helpFi: 'Aihe, johon komennot lähetetään. Voit liittää koko osoitteen, esim. https://ntfy.sh/oma-aihe – sama osoite jota iPhonen pikakomento käyttää. Aiheen nimi on kuin salasana: pidä se pitkänä ja satunnaisena.',
        helpEn: 'Topic the commands are sent to. You can paste the full URL, e.g. https://ntfy.sh/my-topic – the same one your iPhone Shortcut uses. The topic name works like a password: keep it long and random.',
      ),
      FieldSpec(
        'replyTopic',
        'Vastauskanava (vapaaehtoinen)',
        'Reply topic (optional)',
        hint: 'oma-aihe-vastaus',
        helpFi: 'Jos kotilaite vastaa eri aiheeseen, kirjoita se tähän. Jätä tyhjäksi, jos vastaus tulee samaan aiheeseen – silloin oma lähetetty komento ohitetaan ja seuraava viesti näytetään vastauksena.',
        helpEn: 'If the home device replies on another topic, type it here. Leave empty if the reply comes on the same topic – our own command is then ignored and the next message is shown as the reply.',
      ),
      FieldSpec(
        'token',
        'Käyttöoikeustunnus (vapaaehtoinen)',
        'Access token (optional)',
        kind: FieldKind.secret,
        hint: 'tk_…',
        helpFi: 'Tarvitaan vain, jos aihe on suojattu (ntfy-tili → Access tokens). Julkiseen aiheeseen jätä tyhjäksi.',
        helpEn: 'Only needed for a protected topic (ntfy account → Access tokens). Leave empty for a public topic.',
      ),
      FieldSpec(
        'server',
        'Palvelin',
        'Server',
        defaultValue: 'https://ntfy.sh',
        hint: 'https://ntfy.sh',
        helpFi: 'Oletus on julkinen ntfy.sh. Vaihda vain, jos käytät omaa ntfy-palvelinta. Jos liitit yllä koko osoitteen, palvelin luetaan siitä.',
        helpEn: 'Default is the public ntfy.sh. Change only for your own ntfy server. A full URL above overrides this.',
        advanced: true,
      ),
    ],
    readFields: [
      FieldSpec(
        'mode',
        'Näytä',
        'Show',
        kind: FieldKind.choice,
        options: ['latest', 'log'],
        optionLabels: {'latest': ('Viimeisin viesti', 'Latest message'), 'log': ('Viestiloki', 'Message log')},
        defaultValue: 'latest',
        helpFi: 'latest = viimeisin viesti, log = useita viimeisimpiä viestejä allekkain (uusin ylimpänä).',
        helpEn: 'latest = the newest message, log = several recent messages (newest first).',
      ),
      FieldSpec(
        'topic',
        'Aihe (vapaaehtoinen)',
        'Topic (optional)',
        helpFi: 'Mistä aiheesta viestit luetaan. Tyhjä = yhteyden vastauskanava (tai komentokanava, jos vastauskanavaa ei ole).',
        helpEn: 'Topic to read. Empty = the connection\'s reply topic (or the command topic).',
      ),
      FieldSpec(
        'count',
        'Viestien määrä (log)',
        'Number of messages (log)',
        kind: FieldKind.number,
        defaultValue: 5,
        helpFi: 'Montako viimeisintä viestiä näytetään log-tilassa.',
        helpEn: 'How many recent messages the log shows.',
      ),
      FieldSpec(
        'since',
        'Kuinka kaukaa',
        'How far back',
        defaultValue: '12h',
        hint: '12h',
        helpFi: 'Esim. 30m, 12h tai 2d. Julkinen ntfy.sh säilyttää viestejä noin 12 tuntia.',
        helpEn: 'E.g. 30m, 12h or 2d. The public ntfy.sh keeps messages for about 12 hours.',
      ),
    ],
    commandFields: [
      FieldSpec(
        'message',
        'Komento (lähetettävä teksti)',
        'Command (text to send)',
        required: true,
        hint: 'päivitä',
        helpFi: 'Teksti joka lähetetään, esim. "päivitä". Jos PIN kysytään, se lisätään perään välilyönnillä: "päivitä 1234".',
        helpEn: 'The text to send, e.g. "update". With a PIN it is appended after a space: "update 1234".',
      ),
      FieldSpec(
        'askPin',
        'Kysy PIN painettaessa',
        'Ask for a PIN on press',
        kind: FieldKind.boolean,
        defaultValue: false,
        helpFi: 'Kysyy PIN-koodin (piilotettuna) joka painalluksella ja lisää sen komennon perään. PIN-koodia ei tallenneta, ellet itse valitse "Muista tällä laitteella".',
        helpEn: 'Asks for a PIN (hidden) on every press and appends it to the command. The PIN is not stored unless you choose "Remember on this device".',
      ),
      FieldSpec(
        'waitReply',
        'Odota vastausta',
        'Wait for the reply',
        kind: FieldKind.boolean,
        defaultValue: true,
        helpFi: 'Kuuntelee kotilaitteen vastausta ja näyttää sen tässä ruudussa (ja ilmoituksena, jos sovellus on taustalla).',
        helpEn: 'Listens for the home device\'s reply and shows it in this tile (and as a notification when the app is in the background).',
      ),
      FieldSpec(
        'replySeconds',
        'Vastauksen odotus (s)',
        'Wait for reply (s)',
        kind: FieldKind.number,
        defaultValue: 30,
        helpFi: 'Kuinka kauan vastausta odotetaan, ennen kuin kerrotaan ettei vastausta tullut.',
        helpEn: 'How long to wait before saying that no reply came.',
      ),
      FieldSpec(
        'showSeconds',
        'Vastaus näkyy ruudussa (s)',
        'Reply stays on the tile (s)',
        kind: FieldKind.number,
        defaultValue: 60,
        helpFi: 'Kuinka kauan vastaus näkyy ruudussa. 0 = kunnes painat uudelleen.',
        helpEn: 'How long the reply stays on the tile. 0 = until the next press.',
      ),
      FieldSpec(
        'title',
        'Viestin otsikko (vapaaehtoinen)',
        'Message title (optional)',
        helpFi: 'ntfy-viestin otsikko. Yleensä tyhjä – jätä tyhjäksi, ellei kotilaite sitä vaadi.',
        helpEn: 'ntfy message title. Usually empty.',
        advanced: true,
      ),
    ],
  );

  final http.Client _client = newHttpClient();

  (String, String) get _cmd => parseNtfyTopic(s.str('topic'), s.str('server'));
  (String, String) get replyTopicPair => _replyTopic();
  (String, String) get commandTopicPair => _cmd;
  (String, String) _replyTopic([String? override]) {
    final r = override ?? s.strOrNull('replyTopic');
    return r == null || r.trim().isEmpty ? _cmd : parseNtfyTopic(r, _cmd.$1);
  }

  Map<String, String> get _authHeaders {
    final t = s.strOrNull('token');
    return t == null ? const {} : {'Authorization': 'Bearer $t'};
  }

  static String _httpError(int code, String body, String topic) {
    if (code == 401 || code == 403) {
      return dtx(
        'ntfy: aihe "$topic" on suojattu (HTTP $code). Lisää käyttöoikeustunnus (tk_…) yhteyden asetuksiin.',
        'ntfy: topic "$topic" is protected (HTTP $code). Add an access token (tk_…) to the connection.',
      );
    }
    if (code == 429) return ntfyQuotaText(null);
    return 'ntfy: HTTP $code ${body.length > 120 ? body.substring(0, 120) : body}';
  }

  /// t246u: the server refused messages from this network (HTTP 429, e.g. ntfy.sh's 250 messages
  /// per public IP): no new publishes to it until then – every refused try only delays the refill.
  static final quotaUntil = <String, DateTime>{};
  static final quotaFullAt = <String, DateTime>{};

  /// Waits after a 429 before the next try (one message refills about every 3 min on ntfy.sh).
  static Duration quotaPause = const Duration(minutes: 3);

  /// Publishes [text]; returns the stored message (id, time).
  Future<NtfyMessage> publish(String text, {String? title}) async {
    final (srv, topic) = _cmd;
    if (topic.isEmpty) throw DriverException(dtx('ntfy: komentokanava puuttuu', 'ntfy: command topic missing'));
    final until = quotaUntil[srv];
    if (until != null && DateTime.now().isBefore(until)) throw NtfyQuotaFull(ntfyQuotaText(quotaFullAt[srv]));
    final req = http.Request('POST', Uri.parse('$srv/$topic'))
      ..headers.addAll(_authHeaders)
      ..headers['Content-Type'] = 'text/plain; charset=utf-8'
      ..bodyBytes = utf8.encode(text);
    if (title != null && title.isNotEmpty) req.headers['Title'] = title;
    final res = await http.Response.fromStream(await _client.send(req).timeout(const Duration(seconds: 15)))
        .timeout(const Duration(seconds: 15));
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode == 429) {
      final full = await _quotaFullAt(srv);
      quotaUntil[srv] = DateTime.now().add(quotaPause);
      if (full != null) quotaFullAt[srv] = full;
      throw NtfyQuotaFull(ntfyQuotaText(full));
    }
    if (res.statusCode >= 300) throw DriverException(_httpError(res.statusCode, body, topic));
    quotaUntil.remove(srv);
    try {
      return NtfyMessage.fromJson(jsonDecode(body)) ??
          NtfyMessage(id: '', time: DateTime.now().millisecondsSinceEpoch ~/ 1000, message: text);
    } catch (_) {
      return NtfyMessage(id: '', time: DateTime.now().millisecondsSinceEpoch ~/ 1000, message: text);
    }
  }

  /// When the server's message quota for this network is full again (`GET /v1/account`, read only).
  Future<DateTime?> _quotaFullAt(String srv) async {
    try {
      final res = await _client
          .get(Uri.parse('$srv/v1/account'), headers: _authHeaders)
          .timeout(const Duration(seconds: 8));
      final j = jsonDecode(utf8.decode(res.bodyBytes, allowMalformed: true));
      final stats = j is Map ? j['stats'] : null;
      final at = stats is Map ? stats['reset_at'] : null;
      return at is num && at > 0 ? DateTime.fromMillisecondsSinceEpoch(at.toInt() * 1000) : null;
    } catch (_) {
      return null;
    }
  }

  /// Recent messages (oldest first) via `GET <topic>/json?poll=1&since=…`.
  Future<List<NtfyMessage>> poll({String? topic, String since = '12h'}) async {
    final (srv, t) = _replyTopic(topic);
    final res = await _client
        .get(Uri.parse('$srv/$t/json?poll=1&since=${Uri.encodeQueryComponent(since)}'), headers: _authHeaders)
        .timeout(const Duration(seconds: 20));
    final body = utf8.decode(res.bodyBytes, allowMalformed: true);
    if (res.statusCode >= 300) throw DriverException(_httpError(res.statusCode, body, t));
    return [
      for (final line in const LineSplitter().convert(body))
        if (line.trim().isNotEmpty) ?NtfyMessage.fromJson(_tryJson(line)),
    ];
  }

  static Object? _tryJson(String s) {
    try {
      return jsonDecode(s);
    } catch (_) {
      return null;
    }
  }

  /// Live JSON stream of messages on [topic] (reply topic when omitted). Reconnects with
  /// backoff and `since=<last id>` so a server that closes the stream (~3 min on
  /// ntfy.molaplan.com) does not drop messages. Cancel the subscription to stop.
  Stream<NtfyMessage> subscribe({String? topic, String? since}) {
    late StreamController<NtfyMessage> ctl;
    var stopped = false;
    String? last = since;
    Future<void> loop() async {
      var backoff = 2;
      while (!stopped) {
        try {
          final (srv, t) = _replyTopic(topic);
          if (t.isEmpty) break;
          final id = last;
          final q = (id == null || id.isEmpty) ? '' : '?since=${Uri.encodeQueryComponent(id)}';
          final req = http.Request('GET', Uri.parse('$srv/$t/json$q'))..headers.addAll(_authHeaders);
          final res = await _client.send(req);
          if (res.statusCode >= 300) {
            throw DriverException(_httpError(res.statusCode, await utf8.decodeStream(res.stream), t));
          }
          backoff = 2;
          await for (final line in res.stream.transform(utf8.decoder).transform(const LineSplitter())) {
            if (stopped) break;
            if (line.trim().isEmpty) continue;
            final j = _tryJson(line);
            final m = NtfyMessage.fromJson(j);
            if (m == null) continue;
            last = m.id.isEmpty ? last : m.id;
            if (!ctl.isClosed) ctl.add(m);
          }
        } catch (_) {
          if (stopped) break;
        }
        if (stopped) break;
        await Future<void>.delayed(Duration(seconds: backoff));
        backoff = (backoff * 2).clamp(2, 60);
      }
    }

    ctl = StreamController<NtfyMessage>(
      onListen: () => unawaited(loop()),
      onCancel: () {
        stopped = true;
      },
    );
    return ctl.stream;
  }

  /// Sends [text] and waits for the first message on the reply topic that is not our own.
  /// Subscribes first (only new messages, after ntfy's "open" event), then publishes, so
  /// older messages and other devices' earlier commands are never mistaken for the reply.
  Future<NtfyMessage> command(String text, {String? title, Duration wait = const Duration(seconds: 30)}) =>
      exchange(text, title: title, wait: wait);

  /// [command] with a filter: [accept] decides whether a (non-echo) message is the reply –
  /// e.g. the right title or the echoed correlation id on a shared notification topic (t198u).
  /// [timeoutText] replaces the default "no reply" explanation.
  Future<NtfyMessage> exchange(
    String text, {
    String? title,
    Duration wait = const Duration(seconds: 30),
    bool Function(NtfyMessage m)? accept,
    String Function(String topic, int seconds)? timeoutText,
  }) async {
    final (srv, t) = _replyTopic();
    final req = http.Request('GET', Uri.parse('$srv/$t/json'))..headers.addAll(_authHeaders);
    final res = await _client.send(req).timeout(const Duration(seconds: 15));
    if (res.statusCode >= 300) {
      throw DriverException(_httpError(res.statusCode, await utf8.decodeStream(res.stream), t));
    }
    final opened = Completer<void>();
    final got = <NtfyMessage>[];
    final reply = Completer<NtfyMessage>();
    // t241u: an error before anyone awaits (driver disposed mid-request) must not go unhandled.
    reply.future.then((_) {}, onError: (Object _) {});
    opened.future.then((_) {}, onError: (Object _) {});
    NtfyMessage? sent;
    void check() {
      final me = sent;
      if (me == null || reply.isCompleted) return;
      for (final m in got) {
        final echo = (me.id.isNotEmpty && m.id == me.id) || (me.id.isEmpty && m.message == text);
        if (echo) continue;
        // Same topic without a filter: the first other message is the reply (as before).
        if (accept == null) return reply.complete(m);
        if (accept(m)) return reply.complete(m);
      }
    }

    final sub = res.stream
        .transform(utf8.decoder)
        .transform(const LineSplitter())
        .listen(
          (line) {
            final j = _tryJson(line);
            if (j is Map && j['event'] == 'open' && !opened.isCompleted) opened.complete();
            final m = NtfyMessage.fromJson(j);
            if (m == null) return;
            got.add(m);
            check();
          },
          onError: (Object e) {
            if (!opened.isCompleted) opened.completeError(e);
            if (!reply.isCompleted) reply.completeError(e);
          },
          onDone: () {
            if (!reply.isCompleted) {
              reply.completeError(
                DriverException(
                  dtx('ntfy: yhteys katkesi ennen vastausta', 'ntfy: connection closed before the reply'),
                ),
              );
            }
          },
        );
    try {
      await opened.future.timeout(const Duration(seconds: 10), onTimeout: () {});
      sent = await publish(text, title: title);
      check();
      return await reply.future.timeout(
        wait,
        onTimeout: () => throw NtfyNoReply(
          timeoutText?.call(t, wait.inSeconds) ??
              dtx(
                'Komento lähetettiin, mutta vastausta ei tullut ${wait.inSeconds} sekunnissa. Tarkista, että kotilaite on päällä ja kuuntelee aihetta "$t".',
                'The command was sent, but no reply came within ${wait.inSeconds} s. Check that the home device is on and listens to "$t".',
              ),
        ),
      );
    } finally {
      // Not awaited: cancelling a live HTTP stream can take until the socket closes.
      unawaited(sub.cancel());
    }
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final topic = spec.strOrNull('topic');
    final msgs = await poll(topic: topic, since: spec.str('since', '12h'));
    if (spec.str('mode', 'latest') == 'log') {
      final n = spec.integer('count', 5).clamp(1, 50);
      final last = msgs.reversed.take(n);
      if (last.isEmpty) return dtx('(ei viestejä)', '(no messages)');
      return [for (final m in last) '${m.hhmm}  ${m.text}'].join('\n');
    }
    return msgs.isEmpty ? null : msgs.last.text;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    var text = spec.str('message');
    if (spec.flag('askPin') && value != null && '$value'.isNotEmpty) text = '$text $value';
    if (text.trim().isEmpty) throw DriverException(dtx('ntfy: komennon teksti puuttuu', 'ntfy: command text missing'));
    final title = spec.strOrNull('title');
    if (!spec.flag('waitReply', true)) return (await publish(text, title: title)).toReply()..['sentOnly'] = true;
    final m = await command(
      text,
      title: title,
      wait: Duration(seconds: spec.integer('replySeconds', 30).clamp(3, 600)),
    );
    return m.toReply()..['showSeconds'] = spec.integer('showSeconds', 60);
  }

  @override
  Future<String> test() async {
    final (srv, t) = _cmd;
    final (rs, rt) = _replyTopic();
    final msgs = await poll(since: '1h');
    final reply = rt == t && rs == srv ? '' : dtx(' Vastauskanava: $rt.', ' Reply topic: $rt.');
    return dtx(
      '✓ ntfy-palvelin $srv vastasi ja aihe "$t" on luettavissa (${msgs.length} viestiä viimeisen tunnin aikana).$reply Testi ei lähettänyt komentoa – paina ruutua kokeillaksesi.',
      '✓ ntfy server $srv answered and topic "$t" is readable (${msgs.length} messages in the last hour).$reply No command was sent – tap the tile to try.',
    );
  }

  @override
  Future<void> dispose() async => _client.close();
}

/// t246u: HTTP 429 from the ntfy server: this network's message quota is used up.
class NtfyQuotaFull extends DriverException {
  NtfyQuotaFull(super.message);
}

String _hhmm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}.${t.minute.toString().padLeft(2, '0')}';

String ntfyQuotaText(DateTime? fullAt) => dtx(
  'ntfy: viestiraja täynnä (HTTP 429). Palvelin ei ota vastaan enempää viestejä tästä verkosta (ntfy.sh: 250 viestiä / 12 h saman julkisen IP-osoitteen kaikilta laitteilta, myös laitteen omat vastaukset). Uusia viestejä vapautuu muutaman minuutin välein${fullAt == null ? '' : ', koko kiintiö noin klo ${_hhmm(fullAt.toLocal())}'}.',
  'ntfy: message limit reached (HTTP 429). The server takes no more messages from this network (ntfy.sh: 250 messages / 12 h for all devices behind the same public IP, the device\'s own replies too). New messages free up every few minutes${fullAt == null ? '' : ', the full quota around ${_hhmm(fullAt.toLocal())}'}.',
);

/// The text of [ntfyQuotaText] (any language).
bool isNtfyQuota(String msg) =>
    msg.startsWith('ntfy: viestiraja täynnä') || msg.startsWith('ntfy: message limit reached');
