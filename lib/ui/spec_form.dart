import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import 'app_scope.dart';

/// Generic form for a list of [FieldSpec]s editing [values] in place.
class SpecForm extends StatelessWidget {
  const SpecForm({super.key, required this.fields, required this.values, this.onChanged});
  final List<FieldSpec> fields;
  final Map<String, dynamic> values;
  final VoidCallback? onChanged;

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final f in fields)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _FieldInput(
              key: ValueKey(f.key),
              field: f,
              lang: lang,
              values: values,
              onChanged: onChanged,
            ),
          ),
      ],
    );
  }
}

class _FieldInput extends StatefulWidget {
  const _FieldInput({super.key, required this.field, required this.lang, required this.values, this.onChanged});
  final FieldSpec field;
  final String lang;
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

  @override
  Widget build(BuildContext context) {
    final label = '${f.label(widget.lang)}${f.required ? ' *' : ''}';
    switch (f.kind) {
      case FieldKind.boolean:
        final v = widget.values[f.key];
        return SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(label),
          value: v == true || v == 'true',
          onChanged: (b) {
            setState(() => widget.values[f.key] = b);
            widget.onChanged?.call();
          },
        );
      case FieldKind.choice:
        final cur = widget.values[f.key]?.toString() ?? f.defaultValue?.toString() ?? f.options.first;
        return DropdownButtonFormField<String>(
          initialValue: f.options.contains(cur) ? cur : f.options.first,
          decoration: InputDecoration(labelText: label),
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
          decoration: InputDecoration(labelText: label, hintText: f.hint),
          onChanged: _setText,
        );
    }
  }
}
