import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/automation/script_lang.dart';

Future<Object?> run(String src, {ScriptLimits limits = const ScriptLimits(), Map<String, ScriptFn>? fns}) =>
    ScriptRun(fns ?? {}, limits: limits).run(src);

void main() {
  test('arithmetic, precedence, strings, comparisons', () async {
    expect(await run('return 1 + 2 * 3 - 4 / 2'), 5);
    expect(await run('return (1 + 2) * 3 % 4'), 1);
    expect(await run('return "a" .. 1 .. "b" .. 2.5'), 'a1b2.5');
    expect(await run('return -2 * -3'), 6);
    expect(await run('return 3 >= 3 and 2 ~= 3 and not (1 == 2)'), true);
    expect(await run('return nil or "x"'), 'x');
    expect(await run('return false and error()'), false); // short circuit
    expect(await run('return "b" > "a"'), true);
    expect(await run('return tonumber("4,5") + 1'), 5.5);
    expect(await run('return round(2.345, 2)'), 2.35);
    expect(await run('return max(3, 9, 1) - min(3, 9, 1)'), 8);
  });

  test('variables, scopes, if/elseif/else, loops, break', () async {
    expect(
      await run('''
local s = 0
for i = 1, 10 do
  if i % 2 == 0 then s = s + i elseif i == 5 then s = s + 100 else s = s end
end
return s'''),
      130,
    );
    expect(await run('local n = 0 while true do n = n + 1 if n >= 7 then break end end return n'), 7);
    expect(await run('local n = 10 repeat n = n - 3 until n < 0 return n'), -2);
    expect(await run('for i = 10, 1, -3 do x = i end return x'), 1);
    expect(await run('do_it = 1 if true then local do_it = 2 end return do_it'), 1);
  });

  test('host functions get evaluated args and can be async', () async {
    final calls = <String>[];
    final r = await run(
      'on("Valo") set("Valo", 40 + 2) return get("Valo")',
      fns: {
        'on': (a) => calls.add('on ${a.first}'),
        'set': (a) async {
          calls.add('set ${a[0]} ${a[1]}');
          return null;
        },
        'get': (a) async => 42,
      },
    );
    expect(r, 42);
    expect(calls, ['on Valo', 'set Valo 42']);
  });

  test('sandbox: step budget stops endless loops; no unknown functions', () async {
    await expectLater(
      run('while true do end', limits: const ScriptLimits(steps: 5000)),
      throwsA(isA<ScriptError>().having((e) => e.message, 'msg', contains('askelta'))),
    );
    await expectLater(
      run('local f = io_open("x")'),
      throwsA(isA<ScriptError>().having((e) => e.toString(), 'msg', contains("tuntematon funktio 'io_open'"))),
    );
    await expectLater(run('wait(9999)'), throwsA(isA<ScriptError>()));
  });

  test('cancel stops a waiting script', () async {
    final c = ScriptCancel();
    final f = ScriptRun({}, cancel: c).run('wait(5) on()');
    await Future<void>.delayed(const Duration(milliseconds: 100));
    c.cancel();
    await expectLater(f, throwsA(isA<ScriptError>().having((e) => e.message, 'm', 'pysäytetty')));
  });

  test('syntax errors carry line numbers', () {
    expect(() => checkScript('local a = 1\nif a then\n  x = 2\n'), throwsA(predicate((e) => '$e'.contains('Rivi 4'))));
    expect(() => checkScript('x = "kesken'), throwsA(isA<ScriptError>()));
    expect(() => checkScript('x = 1 +'), throwsA(isA<ScriptError>()));
    checkScript('-- kommentti\nlocal a = 1; a = a + 1');
  });
}
