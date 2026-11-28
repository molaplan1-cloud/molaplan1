/// t340u: in add / discovery multi-select lists, items already on a dashboard are
/// hidden by default. A toggle reveals them, labelled and unchecked.
library;

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import 'app_scope.dart';

String showAlreadyAddedLabel(
  int n, {
  required String Function(String fi, String en) tr,
}) => tr(
  'Näytä jo lisätyt ({p0})',
  'Show already added ({p0})',
).replaceFirst('{p0}', '$n');

String alreadyAddedBadge({required String Function(String fi, String en) tr}) =>
    tr('Lisätty', 'Added');

String allAlreadyAddedMessage({
  required String Function(String fi, String en) tr,
}) => tr('Kaikki löydetyt on jo lisätty', 'Everything found is already added');

/// True when [tile] already exists on any dashboard (same device address and
/// the same read / commands – see [AppState.tileKey]).
bool tileAlreadyOnDashboards(
  AppState st,
  TileConfig tile, {
  List<ConnectionConfig> extra = const [],
}) {
  for (final d in st.config.dashboards) {
    if (st.duplicatesIn(d, [tile], extra: extra).isNotEmpty) return true;
  }
  return false;
}

/// Toggle used on add / discovery checklists.
class ShowAlreadyAddedToggle extends StatelessWidget {
  const ShowAlreadyAddedToggle({
    super.key,
    required this.count,
    required this.value,
    required this.onChanged,
  });
  final int count;
  final bool value;
  final ValueChanged<bool> onChanged;

  @override
  Widget build(BuildContext context) {
    if (count <= 0) return const SizedBox.shrink();
    return SwitchListTile(
      key: const ValueKey('show-already-added'),
      contentPadding: EdgeInsets.zero,
      dense: true,
      value: value,
      onChanged: onChanged,
      title: Text(
        showAlreadyAddedLabel(count, tr: (fi, en) => tx(context, fi, en)),
      ),
    );
  }
}

/// Friendly empty state when every found item is already on a dashboard.
class AllAlreadyAddedNotice extends StatelessWidget {
  const AllAlreadyAddedNotice({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      key: const ValueKey('all-already-added'),
      padding: const EdgeInsets.fromLTRB(4, 16, 4, 8),
      child: Text(
        allAlreadyAddedMessage(tr: (fi, en) => tx(context, fi, en)),
        style: Theme.of(context).textTheme.bodyLarge,
      ),
    );
  }
}
