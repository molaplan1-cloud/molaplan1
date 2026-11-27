/// NIBE register list import (t269u): the pump exports its own Modbus register list to USB
/// (S-series menu 7.5.9, F-series ModbusManager CSV). Importing it makes every model work, not
/// only the built-in maps.
library;

import 'dart:convert';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../heatpumps/gshp_modbus.dart';
import '../models/models.dart';
import 'app_scope.dart';

/// File picker (replaced in tests). Returns the file text or null.
Future<String?> Function(BuildContext context) pickNibeCsv = (context) async {
  final f = await FilePicker.pickFile(type: FileType.any, dialogTitle: tx(context, 'Valitse rekisterilista (CSV)', 'Choose the register list (CSV)'));
  if (f == null) return null;
  final b = await f.readAsBytes();
  try {
    return utf8.decode(b);
  } catch (_) {
    return latin1.decode(b); // older NIBE exports are Windows-1252
  }
};

/// Picks, parses and stores the list on [c] (profile 'custom'). Returns the number of registers.
Future<int?> importNibeCsv(BuildContext context, ConnectionConfig c) async {
  final st = AppScope.read(context);
  final text = await pickNibeCsv(context);
  if (text == null || !context.mounted) return null;
  List<GshpReg> regs;
  try {
    regs = parseNibeCsv(text);
  } catch (e) {
    showSnack(
      context,
      tx(context, 'Tiedostoa ei tunnistettu NIBEn rekisterilistaksi.', 'Not recognised as a NIBE register list.'),
      error: true,
    );
    return null;
  }
  if (regs.isEmpty) {
    showSnack(context, tx(context, 'Listassa ei ollut rekistereitä.', 'The list had no registers.'), error: true);
    return null;
  }
  final known = regs.where((r) => !r.key.startsWith('r')).length;
  c.settings['profile'] = 'custom';
  c.settings['registers'] = [for (final r in regs) r.toJson()];
  await st.upsertConnection(c);
  if (context.mounted) {
    showSnack(
      context,
      tx(
        context,
        '${regs.length} rekisteriä tuotu, $known tunnistettu (ulkolämpö, menovesi, käyttövesi, käyrän siirto…).',
        '${regs.length} registers imported, $known recognised (outdoor, supply, hot water, curve offset…).',
      ),
    );
  }
  return regs.length;
}
