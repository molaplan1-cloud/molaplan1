// R251: the browser secret store (run with `flutter test --platform chrome test/web`).
@TestOn('browser')
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/core/plat.dart';
import 'package:molaplan/state/web/secret_store_web.dart';
import 'package:web/web.dart' as web;

void main() {
  test('Plat in a browser', () {
    expect(Plat.isWeb, isTrue);
    expect(Plat.isAndroid || Plat.isWindows || Plat.isFlutterTest, isFalse);
  });

  test('values are encrypted at rest, round-trip, delete, wipe', () async {
    final s = WebSecretStore();
    await s.write('molaplan.account.v1', 'salainen-arvo-123');
    final raw = web.window.localStorage.getItem('molaplan.s.molaplan.account.v1')!;
    expect(raw.contains('salainen'), isFalse);
    expect(await s.read('molaplan.account.v1'), 'salainen-arvo-123');
    // A second instance (page reload) opens it with the same non-extractable key.
    expect(await WebSecretStore().read('molaplan.account.v1'), 'salainen-arvo-123');
    await s.delete('molaplan.account.v1');
    expect(await s.read('molaplan.account.v1'), isNull);
    await s.write('x', 'y');
    await WebSecretStore.wipe();
    expect(web.window.localStorage.getItem('molaplan.s.x'), isNull);
  });
}
