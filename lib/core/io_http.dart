/// dart:io [HttpClient] for code that still needs openUrl / a custom WebSocket client.
/// On the web the constructor throws `Platform._version`; use [requireIoHttpClient]
/// so the user sees [webAppOrBridgeFi] instead, or [newHttpClient] for package:http.
library;

import 'dart:io';

import 'package:flutter/foundation.dart' show kIsWeb;

import 'http_client.dart';

/// Returns null in a browser. Safe to call from shared code.
/// [context]: own TLS settings, e.g. a client certificate (Bosch Smart Home).
HttpClient? ioHttpClient({Duration? timeout, bool allowSelfSigned = false, SecurityContext? context}) {
  if (kIsWeb) return null;
  final c = HttpClient(context: context);
  if (timeout != null) c.connectionTimeout = timeout;
  if (allowSelfSigned) c.badCertificateCallback = (_, _, _) => true;
  return c;
}

/// Like [ioHttpClient], but throws a clear [UnsupportedError] in a browser.
HttpClient requireIoHttpClient({Duration? timeout, bool allowSelfSigned = false, SecurityContext? context}) {
  return ioHttpClient(timeout: timeout, allowSelfSigned: allowSelfSigned, context: context) ??
      (throw UnsupportedError(webAppOrBridgeFi));
}
