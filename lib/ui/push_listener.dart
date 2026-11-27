/// t128u: in-app banners for push messages and molaplan://tile/ID links (notification taps,
/// the ntfy app's Click action) that open the tile.
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/app_state.dart';
import '../state/automation_state.dart';
import 'app_scope.dart';
import 'home_launcher_ui.dart';
import 'notify.dart';
import 'tile_grid.dart';
import 'tile_widget.dart';

TileConfig? findTile(AppState st, String id) {
  for (final d in st.config.dashboards) {
    for (final t in d.tiles) {
      if (t.id == id) return t;
    }
  }
  return null;
}

/// One tile, big, on its own page (what a notification tap opens).
class TileFocusPage extends StatelessWidget {
  const TileFocusPage({super.key, required this.tile});
  final TileConfig tile;

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: Text(tile.title)),
    body: LayoutBuilder(
      builder: (context, box) {
        final g = tileGridFor(box.maxWidth < 520 ? box.maxWidth : 520, 'normal');
        return Center(
          child: SizedBox(
            key: const ValueKey('tile-focus'),
            width: g.width(g.cols < 2 ? g.cols : 2),
            height: g.height(2),
            child: TileWidget(tile: tile, control: true),
          ),
        );
      },
    ),
  );
}

Future<void> openTileById(BuildContext context, String id) async {
  final st = AppScope.read(context);
  final t = findTile(st, id);
  if (t == null) return;
  await Navigator.of(context).push(MaterialPageRoute(builder: (_) => TileFocusPage(tile: t)));
}

class PushListener extends StatefulWidget {
  const PushListener({super.key, required this.child, required this.navigator});
  final Widget child;
  final GlobalKey<NavigatorState> navigator;

  @override
  State<PushListener> createState() => _PushListenerState();
}

class _PushListenerState extends State<PushListener> {
  StreamSubscription<PushMessage>? _msgs;
  StreamSubscription<Uri>? _links;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _msgs ??= AppScope.read(context).automations.messages.listen(_banner);
    _links ??= DeepLinks.links.listen(_open);
    final p = DeepLinks.pending;
    if (p != null) {
      DeepLinks.pending = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _open(p));
    }
  }

  void _open(Uri u) {
    final c = widget.navigator.currentContext;
    if (c == null || !c.mounted) return;
    final runId = DeepLinks.runOf(u);
    if (runId != null) {
      runTileFromShortcut(c, runId, confirm: DeepLinks.confirmOf(u));
      return;
    }
    final id = DeepLinks.tileOf(u);
    if (id == null) return;
    openTileById(c, id);
  }

  void _banner(PushMessage m) {
    final c = widget.navigator.currentContext;
    if (c == null || !c.mounted) return;
    final text = m.body.isEmpty ? m.title : '${m.title}: ${m.body}';
    final tile = m.tileId;
    if (tile == null) {
      showSnack(c, text, error: m.priority >= 5);
    } else {
      showUndo(c, text, () => openTileById(c, tile), label: tx(c, 'Avaa', 'Open'));
    }
  }

  @override
  void dispose() {
    _msgs?.cancel();
    _links?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => widget.child;
}
