/// R511 (t315u): one tile alone, full screen – `molaplan.com/?view=<id>` and the self-contained
/// electricity price view molaplan.com/?price=FI&…. Added to an iPhone / Android home screen it
/// is a small app of its own that keeps itself up to date (the tile's own polling / live feed).
library;

import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/web_url.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'home_page.dart';
import 'push_listener.dart';
import 'tile_widget.dart';

class TileViewPage extends StatefulWidget {
  const TileViewPage({super.key, required this.tileId, this.standalone = false});
  final String tileId;

  /// The price view (no account): no "open Molaplan" into the full app of this browser.
  final bool standalone;

  @override
  State<TileViewPage> createState() => _TileViewPageState();
}

class _TileViewPageState extends State<TileViewPage> {
  Timer? _tick;

  @override
  void initState() {
    super.initState();
    // Repaint every minute so "now" markers and ages move even when the value did not change.
    _tick = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  void _openApp() {
    replaceBrowserUrl('/');
    Navigator.of(context).pushReplacement(MaterialPageRoute(builder: (_) => const HomePage()));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final TileConfig? tile = findTile(st, widget.tileId);
    return Scaffold(
      key: const ValueKey('tile-view-page'),
      body: SafeArea(
        child: tile == null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        tx(
                          context,
                          'Laattaa ei löytynyt tästä selaimesta. Kirjaudu sisään samalla tilillä, jolla laatta tehtiin.',
                          'Tile not found in this browser. Sign in with the account the tile was made with.',
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(onPressed: _openApp, child: Text(tx(context, 'Avaa Molaplan', 'Open Molaplan'))),
                    ],
                  ),
                ),
              )
            : LayoutBuilder(
                builder: (context, box) {
                  final w = (box.maxWidth - 24).clamp(160.0, 720.0);
                  final h = (box.maxHeight - (widget.standalone ? 40 : 72)).clamp(140.0, w * 0.9);
                  return Column(
                    children: [
                      Expanded(
                        child: Center(
                          child: SizedBox(
                            key: const ValueKey('tile-view-box'),
                            width: w,
                            height: h,
                            child: TileWidget(tile: tile, control: true),
                          ),
                        ),
                      ),
                      if (!widget.standalone)
                        TextButton.icon(
                          key: const ValueKey('tile-view-open-app'),
                          onPressed: _openApp,
                          icon: const Icon(Icons.dashboard_outlined, size: 18),
                          label: Text(tx(context, 'Avaa koko Molaplan', 'Open full Molaplan')),
                        ),
                      if (widget.standalone)
                        Padding(
                          padding: const EdgeInsets.only(bottom: 8),
                          child: Text(
                            'molaplan.com',
                            style: Theme.of(context).textTheme.labelSmall?.copyWith(color: Theme.of(context).hintColor),
                          ),
                        ),
                    ],
                  );
                },
              ),
      ),
    );
  }
}
