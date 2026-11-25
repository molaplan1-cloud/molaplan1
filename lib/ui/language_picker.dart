import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';
import 'app_scope.dart';

/// Language selector: "device language" + fi, en, sv, et, es (each in its own language).
class LanguagePicker extends StatelessWidget {
  const LanguagePicker({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final chosen = appLanguages.containsKey(st.config.language) ? st.config.language : 'auto';
    return DropdownMenu<String>(
      key: const ValueKey('language-picker'),
      initialSelection: chosen,
      label: Text(tx(context, 'Kieli', 'Language')),
      onSelected: (v) {
        if (v != null) st.setLanguage(v);
      },
      dropdownMenuEntries: [
        DropdownMenuEntry(
          value: 'auto',
          label: '${tx(context, 'Laitteen kieli', 'Device language')} (${appLanguages[languageForLocale(st.systemLocale())]})',
        ),
        for (final e in appLanguages.entries) DropdownMenuEntry(value: e.key, label: e.value),
      ],
    );
  }
}
