import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

import '../core/fields.dart';
import '../core/template.dart';
import 'digest_auth.dart';
import 'driver.dart';

http.Client makeHttpClient(bool allowSelfSigned, {Duration? timeout}) {
  final c = HttpClient();
  if (timeout != null) c.connectionTimeout = timeout;
  if (allowSelfSigned) c.badCertificateCallback = (_, _, _) => true;
  return IOClient(c);
}

Uri joinUrl(String base, String path) {
  if (path.startsWith('http://') || path.startsWith('https://')) return Uri.parse(path);
  if (base.isEmpty) return Uri.parse(path);
  final b = base.endsWith('/') ? base.substring(0, base.length - 1) : base;
  final p = path.isEmpty ? '' : (path.startsWith('/') ? path : '/$path');
  return Uri.parse('$b$p');
}

Map<String, String> authHeaders(Map<String, dynamic> s) {
  final h = <String, String>{};
  switch (s.str('auth', 'none')) {
    case 'basic':
      h['Authorization'] = 'Basic ${base64Encode(utf8.encode('${s.str('username')}:${s.str('password')}'))}';
    case 'bearer':
      h['Authorization'] = 'Bearer ${s.str('token')}';
  }
  return h;
}

class HttpDriver extends Driver {
  HttpDriver(super.config);
  http.Client? _client;
  http.Client get client => _client ??= makeHttpClient(s.flag('allowSelfSigned'), timeout: _timeout);
  Duration get _timeout => Duration(seconds: s.integer('timeoutSec', 10));

  static const descriptor = DriverDescriptor(
    type: 'http',
    fi: 'HTTP / REST',
    en: 'HTTP / REST',
    create: HttpDriver.new,
    connectionFields: [
      FieldSpec('baseUrl', 'Perusosoite', 'Base URL', hint: 'http://192.168.1.50', required: true),
      FieldSpec(
        'auth',
        'Tunnistus',
        'Authentication',
        kind: FieldKind.choice,
        options: ['none', 'basic', 'digest', 'bearer'],
        defaultValue: 'none',
      ),
      FieldSpec('username', 'Käyttäjätunnus', 'Username'),
      FieldSpec('password', 'Salasana', 'Password', kind: FieldKind.secret),
      FieldSpec('token', 'Token', 'Token', kind: FieldKind.secret),
      FieldSpec(
        'headers',
        'Lisäotsakkeet (Nimi: arvo / rivi)',
        'Extra headers (Name: value per line)',
        kind: FieldKind.multiline,
      ),
      FieldSpec(
        'allowSelfSigned',
        'Salli itse allekirjoitettu sertifikaatti',
        'Allow self-signed certificate',
        kind: FieldKind.boolean,
      ),
      FieldSpec('timeoutSec', 'Aikakatkaisu (s)', 'Timeout (s)', kind: FieldKind.number, defaultValue: 10),
    ],
    readFields: [
      FieldSpec(
        'method',
        'Metodi',
        'Method',
        kind: FieldKind.choice,
        options: ['GET', 'POST', 'PUT'],
        defaultValue: 'GET',
      ),
      FieldSpec('path', 'Polku', 'Path', hint: '/api/status'),
      FieldSpec('body', 'Runko', 'Body', kind: FieldKind.multiline),
      FieldSpec('jsonPath', 'JSON-polku', 'JSON path', hint: r'$.data.temperature'),
      FieldSpec('regex', 'Regex (ryhmä 1)', 'Regex (group 1)'),
    ],
    commandFields: [
      FieldSpec(
        'method',
        'Metodi',
        'Method',
        kind: FieldKind.choice,
        options: ['POST', 'GET', 'PUT', 'PATCH', 'DELETE'],
        defaultValue: 'POST',
      ),
      FieldSpec('path', 'Polku', 'Path', hint: '/api/relay?state={{value}}'),
      FieldSpec('body', 'Runko ({{value}} = arvo)', 'Body ({{value}} = value)', kind: FieldKind.multiline),
      FieldSpec('contentType', 'Content-Type', 'Content-Type', defaultValue: 'application/json'),
    ],
  );

  DigestChallenge? _digest;
  int _nc = 0;

  Future<http.Response> _request(Map<String, dynamic> spec, Object? value, String defMethod) async {
    final method = spec.str('method', defMethod).toUpperCase();
    // {{token}} in a path = the connection's secret token (e.g. the Hue bridge username).
    final url = joinUrl(s.str('baseUrl'), applyTemplate(spec.str('path').replaceAll('{{token}}', s.str('token')), value));
    final uri = url.hasQuery ? '${url.path.isEmpty ? '/' : url.path}?${url.query}' : (url.path.isEmpty ? '/' : url.path);
    http.Request build() {
      final req = http.Request(method, url);
      req.headers.addAll(authHeaders(s));
      if (_digest != null) {
        req.headers['Authorization'] = digestAuthorization(
          ch: _digest!,
          username: s.str('username', 'admin'),
          password: s.str('password'),
          method: method,
          uri: uri,
          nc: ++_nc,
        );
      }
      req.headers.addAll(parseHeaders(s.strOrNull('headers')));
      req.headers.addAll(parseHeaders(spec.strOrNull('headers')));
      final body = spec.strOrNull('body');
      if (body != null && method != 'GET') {
        req.headers['Content-Type'] = spec.str('contentType', 'application/json');
        req.body = applyTemplate(body, value);
      }
      return req;
    }

    Future<http.Response> go() async =>
        http.Response.fromStream(await client.send(build()).timeout(_timeout)).timeout(_timeout);
    var resp = await go();
    // Digest (Shelly Gen2+): answer the challenge once (also when the nonce went stale).
    final wantsDigest = s.str('auth') == 'digest' || (s.str('password').isNotEmpty && s.str('auth', 'none') != 'bearer');
    if (resp.statusCode == 401 && wantsDigest) {
      final ch = DigestChallenge.parse(resp.headers['www-authenticate']);
      if (ch != null) {
        _digest = ch;
        _nc = 0;
        resp = await go();
      }
    }
    if (resp.statusCode >= 400) {
      throw DriverException('HTTP ${resp.statusCode}: ${_short(resp.body)}');
    }
    return resp;
  }

  String _short(String s) => s.length > 120 ? '${s.substring(0, 120)}…' : s;

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final r = await _request(spec, null, 'GET');
    return extractValue(r.body, spec);
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final r = await _request(spec, value, 'POST');
    return r.body;
  }

  @override
  /// Says exactly what was tested: one GET to the base address, nothing is switched.
  Future<String> test() async {
    final url = joinUrl(s.str('baseUrl'), '');
    final sw = Stopwatch()..start();
    final r = await _request({'method': 'GET', 'path': ''}, null, 'GET');
    final ms = sw.elapsedMilliseconds;
    final what = dtx(
      'Testattiin: GET $url (perusosoite, ${r.bodyBytes.length} tavua, $ms ms).',
      'Tested: GET $url (base address, ${r.bodyBytes.length} bytes, $ms ms).',
    );
    final note = dtx(
      'Komentoja ei lähetetty eikä ruutujen polkuja testattu.',
      'No commands were sent and tile paths were not tested.',
    );
    final code = r.statusCode;
    if (code == 401 || code == 403) {
      throw DriverException(dtx(
        'HTTP $code: laite vastasi, mutta ei hyväksynyt kirjautumista. Tarkista käyttäjätunnus, salasana tai token. $what',
        'HTTP $code: the device answered but refused the login. Check username, password or token. $what',
      ));
    }
    if (code >= 500) {
      throw DriverException(dtx(
        'HTTP $code: laite vastasi virheellä (palvelinvirhe). $what',
        'HTTP $code: the device answered with a server error. $what',
      ));
    }
    if (code == 404) {
      return dtx(
        '✓ Laite vastasi osoitteessa $url (HTTP 404: perusosoitteessa ei ole sivua – se on normaalia monille laitteille). Yhteys toimii. $note',
        '✓ The device answered at $url (HTTP 404: no page at the base address – normal for many devices). The connection works. $note',
      );
    }
    return dtx('✓ Yhteys toimii: HTTP $code. $what $note', '✓ Connection works: HTTP $code. $what $note');
  }

  @override
  Future<void> dispose() async => _client?.close();
}
