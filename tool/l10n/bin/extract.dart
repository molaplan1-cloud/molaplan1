// Molaplan l10n extractor.
//
//   dart run bin/extract.dart <repo>/lib rewrite   # turn `lang == 'fi' ? A : B` into tr(lang, A, B)
//   dart run bin/extract.dart <repo>/lib extract   # write strings.json (all fi/en pairs)
//
// The app keeps Finnish + English inline (tx/dtx/tr, FieldSpec, templates…). This tool
// collects every pair so translate.py can build ARB files for the other languages.
import 'dart:convert';
import 'dart:io';

import 'package:analyzer/dart/analysis/utilities.dart';
import 'package:analyzer/dart/ast/ast.dart';
import 'package:analyzer/dart/ast/visitor.dart';

class Tpl {
  Tpl(this.text, this.args);
  final String text;
  final List<String> args;
}

/// String expression -> template with {p0}… placeholders (null if not a string literal).
Tpl? tpl(Expression? e) {
  if (e == null) return null;
  if (e is ParenthesizedExpression) return tpl(e.expression);
  if (e is SimpleStringLiteral) return Tpl(e.value, []);
  if (e is AdjacentStrings) {
    final b = StringBuffer();
    final args = <String>[];
    for (final s in e.strings) {
      final t = tpl(s);
      if (t == null) return null;
      var text = t.text;
      for (var i = 0; i < t.args.length; i++) {
        text = text.replaceAll('{#$i}', '{#${args.length + i}}');
      }
      args.addAll(t.args);
      b.write(text);
    }
    return Tpl(b.toString(), args);
  }
  if (e is StringInterpolation) {
    final b = StringBuffer();
    final args = <String>[];
    for (final el in e.elements) {
      if (el is InterpolationString) {
        b.write(el.value);
      } else if (el is InterpolationExpression) {
        b.write('{#${args.length}}');
        args.add(el.expression.toSource());
      }
    }
    return Tpl(b.toString(), args);
  }
  return null;
}

class Pair {
  Pair(this.fi, this.en, this.file, this.line);
  final Tpl fi, en;
  final String file;
  final int line;
}

class Edit {
  Edit(this.offset, this.end, this.text);
  final int offset, end;
  final String text;
}

bool _isFiTest(Expression c) =>
    c is BinaryExpression &&
    (c.operator.lexeme == '==' || c.operator.lexeme == '!=') &&
    c.rightOperand is SimpleStringLiteral &&
    (c.rightOperand as SimpleStringLiteral).value == 'fi';

class V extends RecursiveAstVisitor<void> {
  V(this.file, this.unit, this.src);
  final String file;
  final CompilationUnit unit;
  final String src;
  final pairs = <Pair>[];
  final edits = <Edit>[];
  final unhandled = <String>[];
  final fiVars = <String, String>{}; // `final fi = X == 'fi'` -> X (per function, approximated by name+scope)

  int line(AstNode n) => unit.lineInfo.getLocation(n.offset).lineNumber;

  void pair(Expression? a, Expression? b, AstNode at) {
    final x = tpl(a), y = tpl(b);
    if (x == null || y == null) return;
    if (x.text.trim().isEmpty && y.text.trim().isEmpty) return;
    pairs.add(Pair(x, y, file, line(at)));
  }

  @override
  void visitVariableDeclaration(VariableDeclaration n) {
    final i = n.initializer;
    if (i != null && _isFiTest(i) && (i as BinaryExpression).operator.lexeme == '==') {
      fiVars[n.name.lexeme] = i.leftOperand.toSource();
    }
    super.visitVariableDeclaration(n);
  }

  @override
  void visitMethodInvocation(MethodInvocation n) {
    final name = n.methodName.name;
    final pos = n.argumentList.arguments.whereType<Expression>().toList();
    if ({'tx', 'dtx', 'tr', '_t', 't', '_ip'}.contains(name) && pos.length >= 2) {
      pair(pos[pos.length - 2], pos[pos.length - 1], n);
    }
    if (name == 'FieldSpec' && pos.length >= 3) pair(pos[1], pos[2], n);
    super.visitMethodInvocation(n);
  }

  @override
  void visitInstanceCreationExpression(InstanceCreationExpression n) {
    final name = n.constructorName.type.name.lexeme;
    final pos = n.argumentList.arguments.whereType<Expression>().toList();
    if (name == 'FieldSpec' && pos.length >= 3) pair(pos[1], pos[2], n);
    super.visitInstanceCreationExpression(n);
  }

  @override
  void visitArgumentList(ArgumentList n) {
    final named = {
      for (final a in n.arguments.whereType<NamedArgument>()) a.name.lexeme: a.argumentExpression,
    };
    for (final k in named.keys) {
      if (k == 'fi' && named.containsKey('en')) pair(named[k], named['en'], n);
      if (k.endsWith('Fi')) {
        final en = '${k.substring(0, k.length - 2)}En';
        if (named.containsKey(en)) pair(named[k], named[en], n);
      }
    }
    super.visitArgumentList(n);
  }

  @override
  void visitRecordLiteral(RecordLiteral n) {
    final f = n.fields.whereType<Expression>().toList();
    // Txt = (fi, en). Skip plain identifier tuples like ('heat', 'fire').
    final id = RegExp(r'^[a-z_0-9]+$');
    if (f.length == 2 && !(f.every((e) => e is SimpleStringLiteral && id.hasMatch(e.value)))) pair(f[0], f[1], n);
    if (f.length == 5) pair(f[2], f[3], n); // heat pump service ports: (brand, port, fi, en, url)
    if (f.length == 4) pair(f[2], f[3], n);
    super.visitRecordLiteral(n);
  }

  /// Top-level `const _ipHelpFi = '…'` / `_ipHelpEn`.
  @override
  void visitCompilationUnit(CompilationUnit n) {
    final vals = <String, Expression>{};
    for (final d in n.declarations.whereType<TopLevelVariableDeclaration>()) {
      for (final v in d.variables.variables) {
        if (v.initializer != null) vals[v.name.lexeme] = v.initializer!;
      }
    }
    for (final k in vals.keys.where((k) => k.endsWith('Fi'))) {
      final en = vals['${k.substring(0, k.length - 2)}En'];
      if (en != null) pair(vals[k], en, vals[k]!);
    }
    super.visitCompilationUnit(n);
  }

  /// Class members `String get descFi => '…'` / `descEn`, `fi` / `en` (device providers etc.).
  @override
  void visitClassDeclaration(ClassDeclaration n) {
    if (n.body.members.isNotEmpty) _members(n.body.members);
    super.visitClassDeclaration(n);
  }

  void _members(Iterable<ClassMember> members) {
    final vals = <String, Expression>{};
    for (final m in members) {
      if (m is MethodDeclaration && m.isGetter) {
        final b = m.body;
        Expression? e;
        if (b is ExpressionFunctionBody) e = b.expression;
        if (b is BlockFunctionBody && b.block.statements.length == 1 && b.block.statements.first is ReturnStatement) {
          e = (b.block.statements.first as ReturnStatement).expression;
        }
        if (e != null) vals[m.name.lexeme] = e;
      } else if (m is FieldDeclaration) {
        for (final v in m.fields.variables) {
          if (v.initializer != null) vals[v.name.lexeme] = v.initializer!;
        }
      }
    }
    for (final k in vals.keys) {
      if (k == 'fi' && vals.containsKey('en')) pair(vals[k], vals['en'], members.first);
      if (k.endsWith('Fi') && vals.containsKey('${k.substring(0, k.length - 2)}En')) {
        pair(vals[k], vals['${k.substring(0, k.length - 2)}En'], members.first);
      }
    }
  }

  @override
  void visitConditionalExpression(ConditionalExpression n) {
    final c = n.condition;
    String? lang;
    var swap = false;
    if (_isFiTest(c)) {
      lang = (c as BinaryExpression).leftOperand.toSource();
      swap = c.operator.lexeme == '!=';
    } else if (c is SimpleIdentifier && fiVars.containsKey(c.name)) {
      lang = fiVars[c.name];
    } else if (c is PrefixExpression && c.operator.lexeme == '!' && c.operand is SimpleIdentifier &&
        fiVars.containsKey((c.operand as SimpleIdentifier).name)) {
      lang = fiVars[(c.operand as SimpleIdentifier).name];
      swap = true;
    }
    if (lang != null) {
      final a = swap ? n.elseExpression : n.thenExpression;
      final b = swap ? n.thenExpression : n.elseExpression;
      bool stringy(Expression e) {
        if (tpl(e) != null) return true;
        final s = e.toSource();
        return RegExp(r'(\bfi|\ben|Fi|En|\$[1-4])\b').hasMatch(s) || RegExp(r'Fi\(|En\(').hasMatch(s);
      }

      if (stringy(a) && stringy(b)) {
        pair(a, b, n);
        edits.add(Edit(n.offset, n.end, 'tr($lang, ${a.toSource()}, ${b.toSource()})'));
      } else {
        unhandled.add('$file:${line(n)}: ${n.toSource()}');
      }
    }
    super.visitConditionalExpression(n);
  }
}

/// Map literals in `fooFi(...)` / `fooEn(...)` functions, paired by key (e.g. irModeFi/irModeEn).
List<Pair> mapPairs(String file, CompilationUnit unit) {
  final maps = <String, Map<String, Expression>>{};
  for (final d in unit.declarations.whereType<FunctionDeclaration>()) {
    final name = d.name.lexeme;
    if (!name.endsWith('Fi') && !name.endsWith('En')) continue;
    final lit = <SetOrMapLiteral>[];
    d.accept(_Collect(lit));
    for (final l in lit) {
      for (final e in l.elements.whereType<MapLiteralEntry>()) {
        if (e.key is SimpleStringLiteral) (maps[name] ??= {})[(e.key as SimpleStringLiteral).value] = e.value;
      }
    }
  }
  final out = <Pair>[];
  for (final k in maps.keys.where((k) => k.endsWith('Fi'))) {
    final en = maps['${k.substring(0, k.length - 2)}En'];
    if (en == null) continue;
    for (final e in maps[k]!.entries) {
      final x = tpl(e.value), y = tpl(en[e.key]);
      if (x != null && y != null) out.add(Pair(x, y, file, 0));
    }
  }
  return out;
}

class _Collect extends RecursiveAstVisitor<void> {
  _Collect(this.out);
  final List<SetOrMapLiteral> out;
  @override
  void visitSetOrMapLiteral(SetOrMapLiteral node) {
    out.add(node);
    super.visitSetOrMapLiteral(node);
  }
}

void main(List<String> argv) {
  final root = Directory(argv[0]);
  final mode = argv.length > 1 ? argv[1] : 'extract';
  final files = root.listSync(recursive: true).whereType<File>().where(
    (f) => f.path.endsWith('.dart') && !f.path.endsWith('.g.dart') && !f.path.contains('/l10n/'),
  );
  final all = <Pair>[];
  final unhandled = <String>[];
  var changed = 0;
  for (final f in files) {
    final rel = f.path.substring(root.path.length + 1);
    var src = f.readAsStringSync();
    for (var pass = 0; pass < 6; pass++) {
      final unit = parseString(content: src, path: f.path, throwIfDiagnostics: false).unit;
      final v = V(rel, unit, src);
      unit.accept(v);
      if (mode != 'rewrite' || v.edits.isEmpty) {
        if (pass == 0 || mode == 'rewrite') {
          all.addAll(v.pairs);
          all.addAll(mapPairs(rel, unit));
          unhandled.addAll(v.unhandled);
        }
        break;
      }
      // Outermost, non-overlapping edits only; inner ones are found again next pass.
      final es = [...v.edits]..sort((a, b) => a.offset.compareTo(b.offset));
      final keep = <Edit>[];
      for (final e in es) {
        if (keep.any((k) => e.offset < k.end && k.offset < e.end)) continue;
        keep.add(e);
      }
      for (final e in keep.reversed) {
        src = src.replaceRange(e.offset, e.end, e.text);
      }
      changed++;
    }
    if (mode == 'rewrite' && src != f.readAsStringSync()) {
      if (!src.contains('l10n/l10n.dart')) {
        final depth = rel.split('/').length - 1;
        final imp = "import '${depth == 0 ? '' : '../' * depth}l10n/l10n.dart';\n";
        final m = RegExp(r"^import .*;\n", multiLine: true).allMatches(src).lastOrNull;
        src = m == null ? imp + src : src.replaceRange(m.end, m.end, imp);
      }
      f.writeAsStringSync(src);
    }
  }
  stderr.writeln('pairs: ${all.length}, rewrite passes: $changed');
  for (final u in unhandled) {
    stderr.writeln('UNHANDLED $u');
  }
  if (mode == 'extract') {
    // Unique by (Finnish, English) – the same Finnish word can mean different things.
    final seen = <String, Map<String, Object?>>{};
    final conflicts = <String>[];
    for (final p in all) {
      // Map English placeholders to the Finnish order (same expression source).
      final enText = p.en.text.replaceAllMapped(RegExp(r'\{#(\d+)\}'), (m) {
        final src = p.en.args[int.parse(m[1]!)];
        final i = p.fi.args.indexOf(src);
        return i < 0 ? '{?$src}' : '{#$i}';
      });
      if (enText.contains('{?')) conflicts.add('${p.file}:${p.line}: English uses a value the Finnish text lacks: $enText');
      if (seen.containsKey('${p.fi.text}\u0000$enText')) continue;
      seen['${p.fi.text}\u0000$enText'] = {
        'fi': p.fi.text,
        'en': enText,
        'n': p.fi.args.length,
        'where': '${p.file}:${p.line}',
      };
    }
    for (final c in conflicts) {
      stderr.writeln('CONFLICT $c');
    }
    File(argv.length > 2 ? argv[2] : 'strings.json').writeAsStringSync(
      const JsonEncoder.withIndent(' ').convert(seen.values.toList()),
    );
    stderr.writeln('unique: ${seen.length}, conflicts: ${conflicts.length}');
  }
}
