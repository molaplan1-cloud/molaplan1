/// "Molaplan-skripti" (t136u): a small Lua-like language for advanced scripts, interpreted in
/// Dart. Sandboxed: no files, no network, no imports – only the Molaplan API functions given by
/// the host ([ScriptApi]). Every run has a step budget, a total time limit and can be cancelled.
///
///   local t = temp()
///   if t < -10 and not isOn("Lämmitin") then
///     on("Lämmitin")
///     notify("Pakkasta " .. t .. " °C – lämmitin päälle")
///   end
///   for i = 1, 3 do toggle("Eteinen"); wait(1) end
library;

import 'dart:async';

class ScriptError implements Exception {
  ScriptError(this.message, [this.line]);
  final String message;
  final int? line;
  @override
  String toString() => line == null ? message : 'Rivi $line: $message';
}

/// Host functions. Each gets evaluated arguments and returns a value (num, String, bool or null).
typedef ScriptFn = FutureOr<Object?> Function(List<Object?> args);

class ScriptLimits {
  const ScriptLimits({this.steps = 200000, this.total = const Duration(minutes: 10), this.maxWait = 600});
  final int steps;
  final Duration total;

  /// Longest single wait() in seconds.
  final int maxWait;
}

// ------------------------------------------------------------------------------- lexer

enum _T { num, str, id, kw, op, eof }

class _Tok {
  _Tok(this.t, this.v, this.line);
  final _T t;
  final String v;
  final int line;
  @override
  String toString() => v;
}

const _keywords = {
  'local', 'if', 'then', 'elseif', 'else', 'end', 'while', 'do', 'for', //
  'and', 'or', 'not', 'true', 'false', 'nil', 'break', 'return', 'repeat', 'until',
};

List<_Tok> _lex(String src) {
  final out = <_Tok>[];
  var i = 0, line = 1;
  bool at(String s) => src.startsWith(s, i);
  while (i < src.length) {
    final c = src[i];
    if (c == '\n') {
      line++;
      i++;
    } else if (c == ' ' || c == '\t' || c == '\r' || c == ';') {
      i++;
    } else if (at('--')) {
      while (i < src.length && src[i] != '\n') {
        i++;
      }
    } else if (RegExp(r'[0-9]').hasMatch(c) ||
        (c == '.' && i + 1 < src.length && RegExp(r'[0-9]').hasMatch(src[i + 1]))) {
      final m = RegExp(r'[0-9]*\.?[0-9]+([eE][-+]?[0-9]+)?').matchAsPrefix(src, i)!;
      out.add(_Tok(_T.num, m[0]!, line));
      i = m.end;
    } else if (c == '"' || c == "'") {
      final b = StringBuffer();
      i++;
      while (i < src.length && src[i] != c) {
        if (src[i] == '\n') throw ScriptError('merkkijono jäi kesken', line);
        if (src[i] == '\\' && i + 1 < src.length) {
          final n = src[i + 1];
          b.write(switch (n) {
            'n' => '\n',
            't' => '\t',
            _ => n,
          });
          i += 2;
        } else {
          b.write(src[i++]);
        }
      }
      if (i >= src.length) throw ScriptError('merkkijono jäi kesken', line);
      i++;
      out.add(_Tok(_T.str, b.toString(), line));
    } else if (RegExp(r'[A-Za-z_äöåÄÖÅ]').hasMatch(c)) {
      final m = RegExp(r'[A-Za-z_äöåÄÖÅ0-9]+').matchAsPrefix(src, i)!;
      out.add(_Tok(_keywords.contains(m[0]) ? _T.kw : _T.id, m[0]!, line));
      i = m.end;
    } else {
      const ops = ['==', '~=', '!=', '<=', '>=', '..', '+', '-', '*', '/', '%', '<', '>', '=', '(', ')', ','];
      final op = ops.where(at).firstOrNull;
      if (op == null) throw ScriptError("tuntematon merkki '$c'", line);
      out.add(_Tok(_T.op, op, line));
      i += op.length;
    }
  }
  out.add(_Tok(_T.eof, '<loppu>', line));
  return out;
}

// ------------------------------------------------------------------------------- AST

sealed class _E {
  _E(this.line);
  final int line;
}

class _Lit extends _E {
  _Lit(this.v, super.line);
  final Object? v;
}

class _Var extends _E {
  _Var(this.name, super.line);
  final String name;
}

class _Un extends _E {
  _Un(this.op, this.e, super.line);
  final String op;
  final _E e;
}

class _Bin extends _E {
  _Bin(this.op, this.a, this.b, super.line);
  final String op;
  final _E a, b;
}

class _Call extends _E {
  _Call(this.name, this.args, super.line);
  final String name;
  final List<_E> args;
}

sealed class _S {
  _S(this.line);
  final int line;
}

class _Assign extends _S {
  _Assign(this.name, this.e, this.local, super.line);
  final String name;
  final _E e;
  final bool local;
}

class _CallS extends _S {
  _CallS(this.call, super.line);
  final _Call call;
}

class _If extends _S {
  _If(this.branches, this.otherwise, super.line);
  final List<(_E, List<_S>)> branches;
  final List<_S>? otherwise;
}

class _While extends _S {
  _While(this.cond, this.body, super.line);
  final _E cond;
  final List<_S> body;
}

class _Repeat extends _S {
  _Repeat(this.body, this.cond, super.line);
  final List<_S> body;
  final _E cond;
}

class _For extends _S {
  _For(this.name, this.from, this.to, this.step, this.body, super.line);
  final String name;
  final _E from, to;
  final _E? step;
  final List<_S> body;
}

class _Break extends _S {
  _Break(super.line);
}

class _Return extends _S {
  _Return(this.e, super.line);
  final _E? e;
}

// ------------------------------------------------------------------------------- parser

class _Parser {
  _Parser(this.t);
  final List<_Tok> t;
  var p = 0;
  _Tok get cur => t[p];
  bool isOp(String v) => cur.t == _T.op && cur.v == v;
  bool isKw(String v) => cur.t == _T.kw && cur.v == v;
  _Tok next() => t[p++];
  void expectOp(String v) {
    if (!isOp(v)) throw ScriptError("odotettiin '$v', löytyi '${cur.v}'", cur.line);
    p++;
  }

  void expectKw(String v) {
    if (!isKw(v)) throw ScriptError("odotettiin '$v', löytyi '${cur.v}'", cur.line);
    p++;
  }

  List<_S> block(Set<String> enders) {
    final out = <_S>[];
    while (cur.t != _T.eof && !(cur.t == _T.kw && enders.contains(cur.v))) {
      out.add(statement());
    }
    return out;
  }

  List<_S> program() {
    final b = block(const {});
    if (cur.t != _T.eof) throw ScriptError("ylimääräinen '${cur.v}'", cur.line);
    return b;
  }

  _S statement() {
    final line = cur.line;
    if (isKw('local')) {
      next();
      final n = next();
      if (n.t != _T.id) throw ScriptError('odotettiin muuttujan nimeä', n.line);
      if (isOp('=')) {
        next();
        return _Assign(n.v, expr(), true, line);
      }
      return _Assign(n.v, _Lit(null, line), true, line);
    }
    if (isKw('if')) {
      next();
      final branches = <(_E, List<_S>)>[];
      final c = expr();
      expectKw('then');
      branches.add((c, block(const {'elseif', 'else', 'end'})));
      List<_S>? otherwise;
      while (true) {
        if (isKw('elseif')) {
          next();
          final c2 = expr();
          expectKw('then');
          branches.add((c2, block(const {'elseif', 'else', 'end'})));
        } else if (isKw('else')) {
          next();
          otherwise = block(const {'end'});
        } else {
          break;
        }
      }
      expectKw('end');
      return _If(branches, otherwise, line);
    }
    if (isKw('while')) {
      next();
      final c = expr();
      expectKw('do');
      final b = block(const {'end'});
      expectKw('end');
      return _While(c, b, line);
    }
    if (isKw('repeat')) {
      next();
      final b = block(const {'until'});
      expectKw('until');
      return _Repeat(b, expr(), line);
    }
    if (isKw('for')) {
      next();
      final n = next();
      if (n.t != _T.id) throw ScriptError('odotettiin muuttujan nimeä', n.line);
      expectOp('=');
      final a = expr();
      expectOp(',');
      final b = expr();
      _E? s;
      if (isOp(',')) {
        next();
        s = expr();
      }
      expectKw('do');
      final body = block(const {'end'});
      expectKw('end');
      return _For(n.v, a, b, s, body, line);
    }
    if (isKw('break')) {
      next();
      return _Break(line);
    }
    if (isKw('return')) {
      next();
      final atEnd = cur.t == _T.eof || (cur.t == _T.kw && const {'end', 'else', 'elseif', 'until'}.contains(cur.v));
      return _Return(atEnd ? null : expr(), line);
    }
    if (cur.t == _T.id) {
      final n = next();
      if (isOp('=')) {
        next();
        return _Assign(n.v, expr(), false, line);
      }
      if (isOp('(')) return _CallS(call(n), line);
      throw ScriptError("odotettiin '=' tai '(' nimen '${n.v}' jälkeen", n.line);
    }
    throw ScriptError("odottamaton '${cur.v}'", cur.line);
  }

  _Call call(_Tok name) {
    expectOp('(');
    final args = <_E>[];
    if (!isOp(')')) {
      args.add(expr());
      while (isOp(',')) {
        next();
        args.add(expr());
      }
    }
    expectOp(')');
    return _Call(name.v, args, name.line);
  }

  static const _prec = {
    'or': 1, 'and': 2, //
    '<': 3, '>': 3, '<=': 3, '>=': 3, '==': 3, '~=': 3, '!=': 3,
    '..': 4, '+': 5, '-': 5, '*': 6, '/': 6, '%': 6,
  };

  String? get _binop {
    if (cur.t == _T.op && _prec.containsKey(cur.v)) return cur.v;
    if (cur.t == _T.kw && (cur.v == 'and' || cur.v == 'or')) return cur.v;
    return null;
  }

  _E expr([int min = 1]) {
    var left = unary();
    while (true) {
      final op = _binop;
      if (op == null || _prec[op]! < min) break;
      final line = next().line;
      // '..' is right-associative, the rest left.
      final right = expr(op == '..' ? _prec[op]! : _prec[op]! + 1);
      left = _Bin(op, left, right, line);
    }
    return left;
  }

  _E unary() {
    if (isKw('not')) {
      final l = next().line;
      return _Un('not', expr(7), l);
    }
    if (isOp('-')) {
      final l = next().line;
      return _Un('-', expr(7), l);
    }
    return primary();
  }

  _E primary() {
    final tk = next();
    switch (tk.t) {
      case _T.num:
        return _Lit(num.parse(tk.v), tk.line);
      case _T.str:
        return _Lit(tk.v, tk.line);
      case _T.kw:
        if (tk.v == 'true') return _Lit(true, tk.line);
        if (tk.v == 'false') return _Lit(false, tk.line);
        if (tk.v == 'nil') return _Lit(null, tk.line);
        throw ScriptError("odottamaton '${tk.v}'", tk.line);
      case _T.id:
        if (isOp('(')) return call(tk);
        return _Var(tk.v, tk.line);
      case _T.op:
        if (tk.v == '(') {
          final e = expr();
          expectOp(')');
          return e;
        }
        throw ScriptError("odottamaton '${tk.v}'", tk.line);
      case _T.eof:
        throw ScriptError('skripti loppui kesken', tk.line);
    }
  }
}

/// Parses without running (editor: "Tarkista"). Throws [ScriptError].
void checkScript(String src) => _Parser(_lex(src)).program();

// ------------------------------------------------------------------------------- interpreter

class _BreakSignal {}

class _ReturnSignal {
  _ReturnSignal(this.v);
  final Object? v;
}

class ScriptCancel {
  bool cancelled = false;
  void cancel() => cancelled = true;
}

class ScriptRun {
  ScriptRun(this.functions, {this.limits = const ScriptLimits(), ScriptCancel? cancel, this.log})
    : cancel = cancel ?? ScriptCancel();

  /// Host API by name (get, set, on, off, notify, price, …) plus [builtins].
  final Map<String, ScriptFn> functions;
  final ScriptLimits limits;
  final ScriptCancel cancel;
  final void Function(String line)? log;

  final _globals = <String, Object?>{};
  final _sw = Stopwatch();
  int _steps = 0;

  /// Runs [src]; returns the value of a top-level `return` (or null).
  Future<Object?> run(String src) async {
    final prog = _Parser(_lex(src)).program();
    _sw.start();
    try {
      await _block(prog, [{}]);
      return null;
    } on _ReturnSignal catch (r) {
      return r.v;
    } on _BreakSignal {
      throw ScriptError("'break' silmukan ulkopuolella");
    }
  }

  void _tick(int line) {
    if (cancel.cancelled) throw ScriptError('pysäytetty', line);
    if (++_steps > limits.steps) throw ScriptError('liian monta askelta (${limits.steps}) – ikuinen silmukka?', line);
    if (_sw.elapsed > limits.total) throw ScriptError('aikaraja ${limits.total.inMinutes} min ylittyi', line);
  }

  Object? _lookup(String n, List<Map<String, Object?>> scopes, int line) {
    for (final s in scopes.reversed) {
      if (s.containsKey(n)) return s[n];
    }
    if (_globals.containsKey(n)) return _globals[n];
    return null; // like Lua: unknown variables are nil
  }

  void _assign(String n, Object? v, List<Map<String, Object?>> scopes, bool local) {
    if (local) {
      scopes.last[n] = v;
      return;
    }
    for (final s in scopes.reversed) {
      if (s.containsKey(n)) {
        s[n] = v;
        return;
      }
    }
    _globals[n] = v;
  }

  Future<void> _block(List<_S> b, List<Map<String, Object?>> scopes) async {
    scopes.add({});
    try {
      for (final s in b) {
        await _stmt(s, scopes);
      }
    } finally {
      scopes.removeLast();
    }
  }

  static bool truthy(Object? v) => v != null && v != false;

  Future<void> _stmt(_S s, List<Map<String, Object?>> scopes) async {
    _tick(s.line);
    switch (s) {
      case _Assign():
        _assign(s.name, await _eval(s.e, scopes), scopes, s.local);
      case _CallS():
        await _eval(s.call, scopes);
      case _If():
        for (final (c, body) in s.branches) {
          if (truthy(await _eval(c, scopes))) {
            await _block(body, scopes);
            return;
          }
        }
        if (s.otherwise != null) await _block(s.otherwise!, scopes);
      case _While():
        while (truthy(await _eval(s.cond, scopes))) {
          try {
            await _block(s.body, scopes);
          } on _BreakSignal {
            break;
          }
          _tick(s.line);
        }
      case _Repeat():
        while (true) {
          try {
            await _block(s.body, scopes);
          } on _BreakSignal {
            break;
          }
          if (truthy(await _eval(s.cond, scopes))) break;
          _tick(s.line);
        }
      case _For():
        final a = _num(await _eval(s.from, scopes), s.line);
        final b = _num(await _eval(s.to, scopes), s.line);
        final st = s.step == null ? 1 : _num(await _eval(s.step!, scopes), s.line);
        if (st == 0) throw ScriptError('for-silmukan askel ei voi olla 0', s.line);
        for (var i = a; st > 0 ? i <= b : i >= b; i += st) {
          scopes.add({s.name: i});
          try {
            await _block(s.body, scopes);
          } on _BreakSignal {
            break;
          } finally {
            scopes.removeLast();
          }
          _tick(s.line);
        }
      case _Break():
        throw _BreakSignal();
      case _Return():
        throw _ReturnSignal(s.e == null ? null : await _eval(s.e!, scopes));
    }
  }

  num _num(Object? v, int line) {
    if (v is num) return v;
    if (v is String) {
      final n = num.tryParse(v.trim().replaceAll(',', '.'));
      if (n != null) return n;
    }
    throw ScriptError('odotettiin lukua, saatiin ${_show(v)}', line);
  }

  static String _show(Object? v) => switch (v) {
    null => 'nil',
    String s => '"$s"',
    _ => '$v',
  };

  static String str(Object? v) {
    if (v == null) return 'nil';
    if (v is double && v == v.roundToDouble() && v.abs() < 1e15) return v.toInt().toString();
    return '$v';
  }

  Future<Object?> _eval(_E e, List<Map<String, Object?>> scopes) async {
    _tick(e.line);
    switch (e) {
      case _Lit():
        return e.v;
      case _Var():
        return _lookup(e.name, scopes, e.line);
      case _Un():
        final v = await _eval(e.e, scopes);
        return e.op == 'not' ? !truthy(v) : -_num(v, e.line);
      case _Bin():
        if (e.op == 'and') {
          final a = await _eval(e.a, scopes);
          return truthy(a) ? await _eval(e.b, scopes) : a;
        }
        if (e.op == 'or') {
          final a = await _eval(e.a, scopes);
          return truthy(a) ? a : await _eval(e.b, scopes);
        }
        final a = await _eval(e.a, scopes), b = await _eval(e.b, scopes);
        switch (e.op) {
          case '..':
            return '${str(a)}${str(b)}';
          case '==':
            return _eq(a, b);
          case '~=' || '!=':
            return !_eq(a, b);
          case '<' || '>' || '<=' || '>=':
            if (a is String && b is String) {
              final c = a.compareTo(b);
              return switch (e.op) {
                '<' => c < 0,
                '>' => c > 0,
                '<=' => c <= 0,
                _ => c >= 0,
              };
            }
            final x = _num(a, e.line), y = _num(b, e.line);
            return switch (e.op) {
              '<' => x < y,
              '>' => x > y,
              '<=' => x <= y,
              _ => x >= y,
            };
          default:
            final x = _num(a, e.line), y = _num(b, e.line);
            switch (e.op) {
              case '+':
                return x + y;
              case '-':
                return x - y;
              case '*':
                return x * y;
              case '/':
                if (y == 0) throw ScriptError('jako nollalla', e.line);
                return x / y;
              default:
                if (y == 0) throw ScriptError('jako nollalla', e.line);
                return x % y;
            }
        }
      case _Call():
        final f = functions[e.name] ?? _builtins[e.name];
        if (f == null) throw ScriptError("tuntematon funktio '${e.name}'", e.line);
        final args = [for (final a in e.args) await _eval(a, scopes)];
        try {
          if (e.name == 'wait') {
            final s = args.isEmpty ? 1 : _num(args.first, e.line);
            if (s < 0 || s > limits.maxWait) throw ScriptError('wait() 0–${limits.maxWait} s', e.line);
          }
          if (e.name == 'log') log?.call(args.map(str).join(' '));
          return await f(args);
        } on ScriptError catch (x) {
          throw x.line == null ? ScriptError(x.message, e.line) : x;
        } catch (x) {
          throw ScriptError('${e.name}(): $x', e.line);
        }
    }
  }

  static bool _eq(Object? a, Object? b) {
    if (a is num && b is num) return a == b;
    return a == b;
  }

  late final Map<String, ScriptFn> _builtins = {
    'log': (a) => null,
    'tostring': (a) => str(a.firstOrNull),
    'tonumber': (a) => a.isEmpty ? null : (a.first is num ? a.first : num.tryParse('${a.first}'.replaceAll(',', '.'))),
    'round': (a) {
      final v = _num(a.first, 0);
      final d = a.length > 1 ? _num(a[1], 0).toInt() : 0;
      if (d <= 0) return v.round();
      final f = [1, 10, 100, 1000, 10000][d.clamp(0, 4)];
      return (v * f).round() / f;
    },
    'abs': (a) => _num(a.first, 0).abs(),
    'min': (a) => a.map((v) => _num(v, 0)).reduce((x, y) => x < y ? x : y),
    'max': (a) => a.map((v) => _num(v, 0)).reduce((x, y) => x > y ? x : y),
    'wait': (a) async {
      final s = a.isEmpty ? 1 : _num(a.first, 0);
      final end = DateTime.now().add(Duration(milliseconds: (s * 1000).round()));
      while (DateTime.now().isBefore(end)) {
        if (cancel.cancelled) throw ScriptError('pysäytetty');
        final left = end.difference(DateTime.now());
        await Future<void>.delayed(left < const Duration(milliseconds: 200) ? left : const Duration(milliseconds: 200));
      }
      return null;
    },
  };
}
