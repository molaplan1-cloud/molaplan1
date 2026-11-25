import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/tile_images.dart';
import 'app_scope.dart';
import 'icons.dart';
import 'tile_visuals.dart';

/// Edit mode → "Ulkoasu": name, size, icon, colour and optional background picture.
Future<void> showTileLook(BuildContext context, TileConfig t) => showModalBottomSheet<void>(
  context: context,
  isScrollControlled: true,
  showDragHandle: true,
  builder: (_) => AppScope(
    state: AppScope.read(context),
    child: TileLookSheet(tile: t),
  ),
);

class TileLookSheet extends StatefulWidget {
  const TileLookSheet({super.key, required this.tile});
  final TileConfig tile;

  @override
  State<TileLookSheet> createState() => _TileLookSheetState();
}

class _TileLookSheetState extends State<TileLookSheet> {
  late final _name = TextEditingController(text: widget.tile.title);
  bool _busy = false;

  TileConfig get t => widget.tile;

  Future<void> _change(void Function(TileConfig t) f) async {
    await AppScope.read(context).updateTileLook(t, f);
    if (mounted) setState(() {});
  }

  Future<void> _pickImage() async {
    final st = AppScope.read(context);
    try {
      final f = await FilePicker.pickFile(
        type: FileType.image,
        dialogTitle: tx(context, 'Valitse taustakuva', 'Choose a background picture'),
      );
      if (f == null || !mounted) return;
      setState(() => _busy = true);
      final ok = await st.setTileImage(t, await f.readAsBytes());
      if (!mounted) return;
      if (!ok) {
        showSnack(
          context,
          tx(
            context,
            'Enintään $tileImageMaxCount taustakuvaa. Poista jokin ensin.',
            'At most $tileImageMaxCount background pictures. Remove one first.',
          ),
          error: true,
        );
      }
    } on FormatException {
      if (mounted) showSnack(context, tx(context, 'Tiedosto ei ole kuva', 'The file is not a picture'), error: true);
    } catch (e) {
      if (mounted) showSnack(context, '$e', error: true);
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final st = AppScope.of(context);
    final size = sizeOf(t);
    return Padding(
      padding: EdgeInsets.fromLTRB(20, 0, 20, 20 + MediaQuery.viewInsetsOf(context).bottom),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(tx(context, 'Ulkoasu', 'Look'), style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: 16),
            TextField(
              key: const ValueKey('look-name'),
              controller: _name,
              decoration: InputDecoration(labelText: tx(context, 'Nimi', 'Name'), border: const OutlineInputBorder()),
              onSubmitted: (v) => v.trim().isEmpty ? null : st.renameTile(t, v),
              onTapOutside: (_) {
                if (_name.text.trim().isNotEmpty && _name.text.trim() != t.title) st.renameTile(t, _name.text);
              },
            ),
            const SizedBox(height: 16),
            Text(tx(context, 'Koko', 'Size'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            SegmentedButton<TileSize>(
              key: const ValueKey('look-size'),
              segments: [
                ButtonSegment(
                  value: TileSize.small,
                  label: Text(tx(context, 'Pieni', 'Small')),
                  icon: const Icon(Icons.crop_square),
                ),
                ButtonSegment(
                  value: TileSize.wide,
                  label: Text(tx(context, 'Leveä', 'Wide')),
                  icon: const Icon(Icons.crop_16_9),
                ),
                ButtonSegment(
                  value: TileSize.large,
                  label: Text(tx(context, 'Iso', 'Large')),
                  icon: const Icon(Icons.crop_din),
                ),
              ],
              selected: {size},
              showSelectedIcon: false,
              onSelectionChanged: (s) => _change((t) => applySize(t, s.first)),
            ),
            const SizedBox(height: 16),
            Text(tx(context, 'Väri', 'Colour'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 8, children: [_swatch(null, cs), for (final c in tileColors) _swatch(c, cs)]),
            const SizedBox(height: 16),
            Text(tx(context, 'Kuvake', 'Icon'), style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(
              spacing: 4,
              runSpacing: 4,
              children: [
                for (final e in {'auto': Icons.auto_awesome_outlined, ...tileIcons}.entries)
                  IconButton(
                    key: ValueKey('look-icon-${e.key}'),
                    isSelected: t.icon == e.key,
                    style: IconButton.styleFrom(backgroundColor: t.icon == e.key ? cs.primaryContainer : null),
                    onPressed: () => _change((t) => t.icon = e.key),
                    icon: Icon(e.value),
                  ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              tx(context, 'Taustakuva (valinnainen)', 'Background picture (optional)'),
              style: Theme.of(context).textTheme.titleSmall,
            ),
            const SizedBox(height: 8),
            if (t.bgImage != null)
              ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: SizedBox(
                  height: 110,
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      TileBackground(name: t.bgImage!, scrim: t.bgScrim),
                      Padding(
                        padding: const EdgeInsets.all(12),
                        child: Align(
                          alignment: Alignment.bottomLeft,
                          child: Text(
                            t.title,
                            style: const TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 8),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                FilledButton.tonalIcon(
                  key: const ValueKey('look-pick-image'),
                  onPressed: _busy ? null : _pickImage,
                  icon: _busy
                      ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.image_outlined),
                  label: Text(
                    t.bgImage == null
                        ? tx(context, 'Valitse kuva', 'Choose picture')
                        : tx(context, 'Vaihda kuva', 'Change picture'),
                  ),
                ),
                if (t.bgImage != null)
                  TextButton.icon(
                    key: const ValueKey('look-remove-image'),
                    onPressed: () async {
                      await st.clearTileImage(t);
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.hide_image_outlined),
                    label: Text(tx(context, 'Poista kuva', 'Remove picture')),
                  ),
              ],
            ),
            if (t.bgImage != null && t.type == TileType.toggle)
              SwitchListTile(
                key: const ValueKey('look-dim'),
                contentPadding: EdgeInsets.zero,
                value: t.bgDimOff,
                title: Text(tx(context, 'Himmennä kun laite on pois päältä', 'Dim when the device is off')),
                onChanged: (v) => _change((t) => t.bgDimOff = v),
              ),
            if (t.bgImage != null)
              Text(
                st.account.signedIn
                    ? tx(
                        context,
                        'Kuva pienennetään (≤ 200 kt) ja synkronoidaan tiliisi.',
                        'The picture is shrunk (≤ 200 KB) and synced to your account.',
                      )
                    : tx(
                        context,
                        'Kuva pienennetään (≤ 200 kt) ja tallennetaan vain tälle laitteelle.',
                        'The picture is shrunk (≤ 200 KB) and kept on this device only.',
                      ),
                style: Theme.of(context).textTheme.bodySmall?.copyWith(color: cs.onSurfaceVariant),
              ),
          ],
        ),
      ),
    );
  }

  Widget _swatch(int? c, ColorScheme cs) {
    final sel = t.color == c;
    return InkWell(
      key: ValueKey('look-color-${c ?? 'none'}'),
      customBorder: const CircleBorder(),
      onTap: () => _change((t) => t.color = c),
      child: Container(
        width: 36,
        height: 36,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: c != null ? Color(c) : cs.surfaceContainerHighest,
          border: Border.all(color: sel ? cs.onSurface : Colors.transparent, width: 3),
        ),
        child: c == null ? Icon(Icons.format_color_reset_outlined, size: 18, color: cs.onSurfaceVariant) : null,
      ),
    );
  }
}
