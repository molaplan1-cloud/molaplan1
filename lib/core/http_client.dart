/// One HTTP client factory for every target (R250, R331): `IOClient` with a connect
/// timeout in the apps, the browser's fetch (`BrowserClient`) in the web app.
/// Never construct dart:io `HttpClient` from shared code — on the web its default
/// User-Agent reads `Platform.version` and throws `Unsupported operation: Platform._version`.
library;

import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:http/http.dart' as http;

import 'httpc/http_client_io.dart'
    if (dart.library.js_interop) 'httpc/http_client_web.dart'
    as impl;
import 'plat.dart';

http.Client newHttpClient({
  Duration connectTimeout = const Duration(seconds: 10),
  bool allowSelfSigned = false,
}) => impl.create(connectTimeout, allowSelfSigned: allowSelfSigned);

/// Shown when a cloud or LAN call cannot run in the browser (no CORS, or dart:io).
const webAppOrBridgeFi = 'Toimii sovelluksessa tai kotisillan kautta';
const webAppOrBridgeEn = 'Works in the app or through a home bridge';

/// True for the dart:io Platform stub error, and (on the web) for CORS / failed fetch.
bool isWebTransportFailure(Object e) {
  final s = e.toString();
  if (s.contains('Platform._version') ||
      s.contains('Unsupported operation: Platform.')) {
    return true;
  }
  final onWeb = kIsWeb || Plat.debugIsWeb == true;
  if (!onWeb) return false;
  final t = s.toLowerCase();
  return e is http.ClientException ||
      t.contains('failed to fetch') ||
      t.contains('xmlhttprequest') ||
      t.contains('clientexception') ||
      t.contains('networkerror') ||
      t.contains('cors') ||
      t.contains('failed host lookup');
}
