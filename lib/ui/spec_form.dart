import 'package:material_ui/material_ui.dart';

import '../devices/provider.dart' show checkAddress, addressHint, AddressIssue;

import '../core/field_help.dart';
import '../core/fields.dart';
import 'app_scope.dart';

/// Generic form for a list of [FieldSpec]s editing [values] in place.
class SpecForm extends StatelessWidget {
  const SpecForm({super.key, required this.fields, required this.values, this.onChanged, this.scope});
  final List<FieldSpec> fields;
  final Map<String, dynamic> values;
  final VoidCallback? onChanged;

  /// e.g. "modbus.read" – selects help texts and advanced fields.
  final String? scope;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final basic = fields.where((f) => !isAdvanced(f, scope: scope)).toList();
    final adv = fields.where((f) => isAdvanced(f, scope: scope)).toList();
    Widget input(FieldSpec f) => Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: _FieldInput(
        key: ValueKey(f.key),
        field: f,
        lang: lang,
        help: helpText(f, lang, scope: scope),
        values: values,
        onChanged: onChanged,
      ),
    );
    // Open the advanced section if something there differs from its default.
    final advUsed = adv.any((f) {
      final v = values[f.key];
      return v != null && v != false && v.toString().isNotEmpty && v.toString() != (f.defaultValue?.toString() ?? '');
    });
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in basic) input(f),
        if (adv.isNotEmpty)
          Theme(
            data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
            child: ExpansionTile(
              key: const ValueKey('advanced'),
              initiallyExpanded: advUsed,
              tilePadding: EdgeInsets.zero,
              leading: const Icon(Icons.tune),
              title: Text(lang == 'fi' ? 'Lisäasetukset' : 'Advanced settings'),
              subtitle: Text(
                lang == 'fi' ? 'Yleensä näihin ei tarvitse koskea' : "Usually you don't need these",
                style: Theme.of(context).textTheme.bodySmall,
              ),
              childrenPadding: const EdgeInsets.only(top: 4),
              children: [for (final f in adv) input(f)],
            ),
          ),
      ],
    );
  }
}

class _FieldInput extends StatefulWidget {
  const _FieldInput({
    super.key,
    required this.field,
    required this.lang,
    required this.values,
    this.onChanged,
    this.help,
  });
  final FieldSpec field;
  final String lang;
  final String? help;
  final Map<String, dynamic> values;
  final VoidCallback? onChanged;

  @override
  State<_FieldInput> createState() => _FieldInputState();
}

class _FieldInputState extends State<_FieldInput> {
  bool _obscure = true;
  late final TextEditingController _ctl;

  FieldSpec get f => widget.field;

  @override
  void initState() {
    super.initState();
    final v = widget.values[f.key] ?? f.defaultValue;
    _ctl = TextEditingController(text: v?.toString() ?? '');
    if (!widget.values.containsKey(f.key) && f.defaultValue != null) {
      widget.values[f.key] = f.defaultValue;
    }
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  void _setText(String t) {
    if (t.isEmpty) {
      widget.values.remove(f.key);
    } else if (f.kind == FieldKind.number) {
      widget.values[f.key] = num.tryParse(t.replaceAll(',', '.')) ?? t;
    } else {
      widget.values[f.key] = t;
    }
    widget.onChanged?.call();
  }

  bool get _isAddress => const {'host', 'baseUrl', 'url', 'broker'}.contains(f.key);

  /// Warns about typos like 191.168.50.172 (not a home network address).
  String? get _addrHint {
    if (!_isAddress) return null;
    final t = _ctl.text.trim();
    if (!RegExp(r'^(\w+://)?[\d.]+(:\d+)?(/.*)?$').hasMatch(t)) return null;
    final r = checkAddress(t, const []);
    return r.issue == AddressIssue.ok ? null : addressHint(t, const [], widget.lang);
  }

  @override
  Widget build(BuildContext context) {
    final label = '${f.label(widget.lang)}${f.required ? ' *' : ''}';
    switch (f.kind) {
      case FieldKind.boolean:
        final v = widget.values[f.key];
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          subtitle: widget.help == null ? null : Text(widget.help!, style: Theme.of(context).textTheme.bodySmall),
          value: v == true || v == 'true',
          onChanged: (b) {
            setState(() => widget.values[f.key] = b);
            widget.onChanged?.call();
          },
        );
      case FieldKind.choice:
        final cur = widget.values[f.key]?.toString() ?? f.defaultValue?.toString() ?? f.options.first;
        return DropdownButtonFormField<String>(
          isExpanded: true,
          initialValue: f.options.contains(cur) ? cur : f.options.first,
          decoration: InputDecoration(labelText: label, helperText: widget.help),
          items: [for (final o in f.options) DropdownMenuItem(value: o, child: Text(o))],
          onChanged: (v) {
            widget.values[f.key] = v;
            widget.onChanged?.call();
          },
        );
      case FieldKind.secret:
        return TextField(
          controller: _ctl,
          obscureText: _obscure,
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint,
            helperText: widget.help,
            suffixIcon: IconButton(
              icon: Icon(_obscure ? Icons.visibility_outlined : Icons.visibility_off_outlined),
              onPressed: () => setState(() => _obscure = !_obscure),
            ),
          ),
          onChanged: _setText,
        );
      case FieldKind.multiline:
      case FieldKind.text:
      case FieldKind.number:
        return TextField(
          controller: _ctl,
          minLines: f.kind == FieldKind.multiline ? 2 : 1,
          maxLines: f.kind == FieldKind.multiline ? 6 : 1,
          keyboardType: f.kind == FieldKind.number
              ? const TextInputType.numberWithOptions(decimal: true, signed: true)
              : (f.kind == FieldKind.multiline ? TextInputType.multiline : TextInputType.text),
          decoration: InputDecoration(
            labelText: label,
            hintText: f.hint == null ? null : '${widget.lang == 'fi' ? 'esim.' : 'e.g.'} ${f.hint}',
            helperText: _addrHint ?? widget.help,
            helperMaxLines: 4,
            helperStyle: _addrHint == null ? null : TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
          onChanged: (t) {
            _setText(t);
            if (_isAddress) setState(() {});
          },
        );
    }
  }
}
