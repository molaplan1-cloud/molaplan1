import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client create(Duration connectTimeout, {bool allowSelfSigned = false}) {
  final c = HttpClient()..connectionTimeout = connectTimeout;
  if (allowSelfSigned) c.badCertificateCallback = (_, _, _) => true;
  return IOClient(c);
}
