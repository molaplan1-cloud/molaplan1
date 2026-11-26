/// One HTTP client factory for every target (R250): `IOClient` with a connect timeout in the
/// apps, the browser's fetch (`BrowserClient`, streams responses) in the web app.
library;

import 'package:http/http.dart' as http;

import 'httpc/http_client_io.dart' if (dart.library.js_interop) 'httpc/http_client_web.dart' as impl;

http.Client newHttpClient({Duration connectTimeout = const Duration(seconds: 10)}) => impl.create(connectTimeout);
