import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// R561: user-facing copy must not refer to the owner's test setup.
void main() {
  test('l10n, help and website copy stay generic (R560, R561)', () {
    final root = Directory.current;
    final script = File('${root.path}/tool/l10n/check_generic_copy.py');
    expect(script.existsSync(), isTrue, reason: 'missing ${script.path}');
    final result = Process.runSync(
      'python3',
      [script.path],
      workingDirectory: root.path,
    );
    if (result.exitCode != 0) {
      fail(
        'Banned test-setup phrasing in user-facing text (R560):\n'
        '${result.stdout}\n${result.stderr}',
      );
    }
  });
}
