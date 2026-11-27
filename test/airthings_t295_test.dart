// t295u / R331: Airthings (and other dart:io HttpClient / Platform uses) must not throw
// `Unsupported operation: Platform._version` in the web app. The cloud API is tried via
// package:http (BrowserClient); if CORS or dart:io blocks it, the page shows a calm
// "Toimii sovelluksessa tai kotisillan kautta" — not a listing error.
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:material_ui/material_ui.dart' hide Threshold;
import 'package:molaplan/core/http_client.dart';
import 'package:molaplan/core/io_http.dart';
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/drivers/airthings.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/airthings_page.dart';
import 'package:molaplan/ui/app_scope.dart';

final _origHttp = airthingsHttp;

ConnectionConfig _cloud() => ConnectionConfig(
  name: 'Airthings',
  type: 'airthings',
  settings: {'clientId': 'cid-test'},
  secrets: {'clientSecret': 'sec-test'},
);

void main() {
  setUp(() {
    AirthingsCloudDriver.resetCache();
  });
  tearDown(() {
    airthingsHttp = _origHttp;
    AirthingsCloudDriver.resetCache();
    Plat.debugIsWeb = null;
  });

  test(
    't295u: Platform._version and web CORS failures are transport errors',
    () {
      expect(
        isWebTransportFailure(
          UnsupportedError('Unsupported operation: Platform._version'),
        ),
        isTrue,
      );
      Plat.debugIsWeb = true;
      expect(
        isWebTransportFailure(
          http.ClientException(
            'Failed to fetch',
            Uri.parse('https://ext-api.airthings.com/v1/devices'),
          ),
        ),
        isTrue,
      );
      Plat.debugIsWeb = false;
      expect(
        isWebTransportFailure(
          Exception('Airthings: HTTP 401 – check the client id / secret'),
        ),
        isFalse,
      );
    },
  );

  test('t295u: dart:io HttpClient is not constructed in shared lib code', () {
    final root = Directory('lib');
    expect(root.existsSync(), isTrue);
    final allowed = {
      'lib/core/io_http.dart',
      'lib/core/httpc/http_client_io.dart',
    };
    final hits = <String>[];
    for (final f in root.listSync(recursive: true).whereType<File>()) {
      if (!f.path.endsWith('.dart')) continue;
      final rel = f.path.replaceAll(r'\', '/');
      if (allowed.contains(rel)) continue;
      final lines = f.readAsLinesSync();
      for (var i = 0; i < lines.length; i++) {
        if (RegExp(r'\bHttpClient\(').hasMatch(lines[i])) {
          hits.add('$rel:${i + 1}: ${lines[i].trim()}');
        }
      }
    }
    expect(
      hits,
      isEmpty,
      reason:
          'dart:io HttpClient() must go through newHttpClient / requireIoHttpClient:\n${hits.join('\n')}',
    );
  });

  test('t295u: ioHttpClient is available in the VM apps', () {
    final c = ioHttpClient(timeout: const Duration(seconds: 2));
    expect(c, isNotNull);
    c!.close(force: true);
  });

  test(
    't295u: cloud driver maps Platform._version to AirthingsWebUnavailable',
    () async {
      airthingsHttp = (method, url, headers, body) async {
        throw UnsupportedError('Unsupported operation: Platform._version');
      };
      await expectLater(
        AirthingsCloudDriver(_cloud()).devices(),
        throwsA(isA<AirthingsWebUnavailable>()),
      );
    },
  );

  test('t295u: cloud driver maps a browser CORS failure to AirthingsWebUnavailable', () async {
    Plat.debugIsWeb = true;
    airthingsHttp = (method, url, headers, body) async {
      throw http.ClientException('Failed to fetch', url);
    };
    await expectLater(
      AirthingsCloudDriver(_cloud()).devices(),
      throwsA(isA<AirthingsWebUnavailable>()),
    );
  });

  test('t295u: a real API 401 is still a credential error, not the web-unavailable message', () async {
    airthingsHttp = (method, url, headers, body) async => (401, '');
    await expectLater(
      AirthingsCloudDriver(_cloud()).devices(),
      throwsA(
        predicate(
          (e) =>
              e.toString().contains('HTTP 401') &&
              e is! AirthingsWebUnavailable,
        ),
      ),
    );
  });

  testWidgets(
    't295u: Airthings page shows a calm web message, not Platform._version',
    (tester) async {
      airthingsHttp = (method, url, headers, body) async {
        throw UnsupportedError('Unsupported operation: Platform._version');
      };
      final st = AppState(
        configStore: MemoryConfigStore(),
        secretStore: MemorySecretStore(),
      );
      await st.load();
      await tester.pumpWidget(
        AppScope(
          state: st,
          child: MaterialApp(home: AirthingsDevicesPage(connection: _cloud())),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text(webAppOrBridgeFi), findsOneWidget);
      expect(find.textContaining('Laitteita ei saatu'), findsNothing);
      expect(find.textContaining('Platform._version'), findsNothing);
    },
  );
}
