/// R623 (t334u): compact row at the end of the browser dashboard for auto-hidden tiles.
library;

import 'package:material_ui/material_ui.dart';

import '../core/plat.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/browser_tile_hide.dart';
import 'app_scope.dart';

class BrowserHiddenTilesRow extends StatefulWidget {
  const BrowserHiddenTilesRow({
    super.key,
    required this.tiles,
    required this.hasBridge,
  });
  final List<TileConfig> tiles;
  final bool hasBridge;

  @override
  State<BrowserHiddenTilesRow> createState() => _BrowserHiddenTilesRowState();
}

class _BrowserHiddenTilesRowState extends State<BrowserHiddenTilesRow> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    if (widget.tiles.isEmpty) return const SizedBox.shrink();
    final n = widget.tiles.length;
    final cs = Theme.of(context).colorScheme;
    final text = Theme.of(context).textTheme;
    final st = AppScope.of(context);
    return Padding(
      key: const ValueKey('browser-hidden-row'),
      padding: const EdgeInsets.only(top: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            key: const ValueKey('browser-hidden-toggle'),
            onTap: () => setState(() => _open = !_open),
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
              child: Row(
                children: [
                  Icon(
                    Icons.visibility_off_outlined,
                    size: 18,
                    color: cs.onSurfaceVariant,
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      tx(
                        context,
                        '{p0} laitetta piilotettu – ei käytettävissä selaimessa',
                        '{p0} devices hidden – not available in the browser',
                      ).replaceFirst('{p0}', '$n'),
                      key: const ValueKey('browser-hidden-count'),
                      style: text.bodyMedium?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ),
                  Icon(
                    _open ? Icons.expand_less : Icons.expand_more,
                    color: cs.onSurfaceVariant,
                  ),
                ],
              ),
            ),
          ),
          if (_open)
            for (final t in widget.tiles) _hiddenCard(context, st, t, cs, text),
        ],
      ),
    );
  }

  Widget _hiddenCard(
    BuildContext context,
    AppState st,
    TileConfig t,
    ColorScheme cs,
    TextTheme text,
  ) {
    final err = browserTileError(t);
    final avail = classifyBrowserTile(
      tile: t,
      connection: st.connection,
      hasBridge: widget.hasBridge,
      error: err,
      hasValue: browserTileHasValue(t),
      isWeb: true,
    );
    final reason = browserHideReason(avail, error: err);
    final hint = browserHideHint(
      avail,
      error: err,
      hasBridge: widget.hasBridge,
    );
    return Opacity(
      key: ValueKey('browser-hidden-tile-${t.id}'),
      opacity: 0.72,
      child: Card(
        color: cs.surfaceContainerHighest,
        margin: const EdgeInsets.only(top: 6),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Icon(Icons.devices_other, color: cs.onSurfaceVariant),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      t.title.isEmpty ? t.type.name : t.title,
                      style: text.titleSmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx(context, reason.$1, reason.$2),
                      style: text.bodySmall,
                    ),
                    const SizedBox(height: 2),
                    Text(
                      tx(context, hint.$1, hint.$2),
                      style: text.bodySmall?.copyWith(
                        color: cs.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              TextButton(
                key: ValueKey('browser-hidden-always-${t.id}'),
                onPressed: () =>
                    st.setTileBrowserVisibility(t.id, tileBrowserShowAlways),
                child: Text(tx(context, 'Näytä aina', 'Always show')),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Visibility control used in the tile editor (browser only).
class BrowserTileShowSetting extends StatelessWidget {
  const BrowserTileShowSetting({
    super.key,
    required this.tileId,
    required this.mode,
    required this.onChanged,
  });
  final String tileId;
  final String mode;
  final ValueChanged<String> onChanged;

  static bool get visible => Plat.isWeb;

  @override
  Widget build(BuildContext context) {
    if (!visible) return const SizedBox.shrink();
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Text(
          tx(context, 'Selainnäkymä', 'Browser view'),
          style: text.titleMedium,
        ),
        const SizedBox(height: 4),
        Text(
          tx(
            context,
            'Koskee vain tätä selainta. Muissa laitteissa ruutu pysyy paikallaan.',
            'Applies only in this browser. On other devices the tile stays in place.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        SegmentedButton<String>(
          key: const ValueKey('tile-browser-show'),
          segments: [
            ButtonSegment(
              value: tileBrowserShowAuto,
              label: Text(
                tx(context, 'Piilota automaattisesti', 'Hide automatically'),
              ),
            ),
            ButtonSegment(
              value: tileBrowserShowAlways,
              label: Text(tx(context, 'Näytä aina', 'Always show')),
            ),
          ],
          selected: {
            mode == tileBrowserShowAlways
                ? tileBrowserShowAlways
                : tileBrowserShowAuto,
          },
          showSelectedIcon: false,
          onSelectionChanged: (v) => onChanged(v.first),
        ),
      ],
    );
  }
}
