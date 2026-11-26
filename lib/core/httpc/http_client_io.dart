import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:http/io_client.dart';

http.Client create(Duration connectTimeout) => IOClient(HttpClient()..connectionTimeout = connectTimeout);
