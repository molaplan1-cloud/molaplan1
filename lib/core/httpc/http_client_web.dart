import 'package:http/browser_client.dart';
import 'package:http/http.dart' as http;

http.Client create(Duration connectTimeout, {bool allowSelfSigned = false}) =>
    BrowserClient();
