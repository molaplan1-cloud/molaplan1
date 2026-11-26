/// t173u: "On jo näkymässä – lisätäänkö silti?" before a script, scene or device tile that the
/// view already has is added again.
library;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'app_scope.dart';

/// True = go ahead (no duplicates, or the user said yes).
Future<bool> confirmNoDuplicates(
  BuildContext context,
  Dashboard d,
  List<TileConfig> tiles, {
  List<ConnectionConfig> extra = const [],
}) async {
  final dup = AppScope.read(context).duplicatesIn(d, tiles, extra: extra);
  if (dup.isEmpty) return true;
  final names = dup.map((t) => t.title).toSet().join(', ');
  final r = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('duplicate-dialog'),
      title: Text(tx(c, 'On jo näkymässä – lisätäänkö silti?', 'Already in the view – add anyway?')),
      content: Text(tx(c, '$names on jo näkymässä ${d.name}.', '$names is already in the view ${d.name}.')),
      actions: [
        TextButton(
          key: const ValueKey('duplicate-cancel'),
          onPressed: () => Navigator.pop(c, false),
          child: Text(tx(c, 'Peruuta', 'Cancel')),
        ),
        FilledButton(
          key: const ValueKey('duplicate-add'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(c, 'Lisää silti', 'Add anyway')),
        ),
      ],
    ),
  );
  return r == true;
}
