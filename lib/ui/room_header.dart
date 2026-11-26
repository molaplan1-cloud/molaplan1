/// Room photo header per view (v0.7.2, R132): a picture of the room above its tiles with the
/// room name on a readable scrim. Chosen from the gear menu › "Huoneen kuva".
library;

import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../state/tile_images.dart';
import 'app_scope.dart';
import 'motion.dart';
import 'room_presets.dart';
import 'tile_look.dart';
import 'tile_visuals.dart';

/// File picker for the room photo (replaced in tests).
Future<Uint8List?> Function(BuildContext context) pickRoomPhoto = (context) async {
  final f = await FilePicker.pickFile(
    type: FileType.image,
    dialogTitle: tx(context, 'Valitse huoneen kuva', 'Choose a room photo'),
  );
  return f?.readAsBytes();
};

class RoomHeader extends StatelessWidget {
  const RoomHeader({super.key, required this.dashboard, this.subtitle});
  final Dashboard dashboard;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    final d = dashboard;
    final wide = MediaQuery.sizeOf(context).width >= 700;
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 10, 0, 10),
      child: TweenAnimationBuilder<double>(
        // A gentle fade-in when the photo appears; skipped when motion is off.
        tween: Tween(begin: 0, end: 1),
        duration: motion(context, 400),
        builder: (context, v, child) => Opacity(opacity: v, child: child),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            key: ValueKey('room-header-${d.id}'),
            height: wide ? 150 : 112,
            child: Stack(
              fit: StackFit.expand,
              children: [
                TileBackground(name: d.headerImage!, scrim: d.headerScrim),
                Positioned(
                  left: 16,
                  right: 16,
                  bottom: 12,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        d.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w700,
                          shadows: const [Shadow(blurRadius: 8, color: Colors.black54)],
                        ),
                      ),
                      if (subtitle != null)
                        Text(
                          subtitle!,
                          key: ValueKey('room-sub-${d.id}'),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: const Color(0xE6FFFFFF)),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Gear menu › "Huoneen kuva": pick the view (when there are several), then choose, take or
/// remove its photo.
Future<void> showRoomPhotoSheet(BuildContext context, List<Dashboard> views) async {
  final st = AppScope.read(context);
  if (views.isEmpty) return;
  var d = views.first;
  if (views.length > 1) {
    final pick = await showModalBottomSheet<Dashboard>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tx(c, 'Minkä huoneen kuva?', 'Photo for which room?'),
                style: Theme.of(c).textTheme.titleMedium,
              ),
            ),
            for (final v in views)
              ListTile(
                key: ValueKey('room-pick-${v.id}'),
                leading: Icon(v.headerImage != null ? Icons.image : Icons.image_outlined),
                title: Text(v.name),
                onTap: () => Navigator.pop(c, v),
              ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    d = pick;
  }
  if (!context.mounted) return;
  final view = d;
  final suggested = suggestRoomPreset(view.name);
  final presets = [?suggested, ...roomPresets.where((p) => p != suggested)];
  final action = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => StatefulBuilder(
      builder: (c, setSheet) {
        final lang = langOf(c);
        final dark = Theme.of(c).brightness;
        final current = roomPreset(view.headerImage);
        return SafeArea(
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  title: Text(view.name, style: Theme.of(c).textTheme.titleMedium),
                  subtitle: Text(
                    tx(
                      c,
                      'Valitse valmis huonekuva tai oma kuva. Kuva näkyy otsikkona tai koko näkymän taustana.',
                      'Pick a built-in room picture or your own photo. It is shown as the header or behind the whole view.',
                    ),
                  ),
                ),
                // t172u: built-in pictures with thumbnails; the one matching the view's name first.
                SizedBox(
                  height: 104,
                  child: ListView(
                    key: const ValueKey('room-presets'),
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 12),
                    children: [
                      for (final p in presets)
                        Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          child: InkWell(
                            key: ValueKey('room-preset-${p.id}'),
                            borderRadius: BorderRadius.circular(10),
                            onTap: () async {
                              await st.setHeaderPreset(view, p.id);
                              setSheet(() {});
                            },
                            child: Column(
                              children: [
                                Container(
                                  width: 120,
                                  height: 68,
                                  decoration: BoxDecoration(
                                    borderRadius: BorderRadius.circular(10),
                                    border: Border.all(
                                      width: current == p ? 3 : 1,
                                      color: current == p
                                          ? Theme.of(c).colorScheme.primary
                                          : Theme.of(c).colorScheme.outlineVariant,
                                    ),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: Image.asset(p.asset(dark, thumb: true), fit: BoxFit.cover),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  p == suggested ? '★ ${p.label(lang)}' : p.label(lang),
                                  key: p == suggested ? const ValueKey('room-preset-suggested') : null,
                                  style: Theme.of(c).textTheme.labelSmall,
                                ),
                              ],
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                ListTile(
                  key: const ValueKey('room-photo-choose'),
                  leading: const Icon(Icons.image_outlined),
                  title: Text(
                    view.headerImage == null || current != null
                        ? tx(c, 'Valitse oma kuva', 'Choose your own picture')
                        : tx(c, 'Vaihda kuva', 'Change picture'),
                  ),
                  onTap: () => Navigator.pop(c, 'choose'),
                ),
                if (cameraCaptureAvailable)
                  ListTile(
                    key: const ValueKey('room-photo-take'),
                    leading: const Icon(Icons.photo_camera_outlined),
                    title: Text(tx(c, 'Ota kuva', 'Take photo')),
                    onTap: () => Navigator.pop(c, 'take'),
                  ),
                if (view.headerImage != null) ...[
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
                    child: SegmentedButton<String>(
                      key: const ValueKey('room-photo-mode'),
                      segments: [
                        ButtonSegment(
                          value: 'header',
                          icon: const Icon(Icons.vertical_align_top),
                          label: Text(tx(c, 'Otsikkokuva', 'Header picture'), key: const ValueKey('room-mode-header')),
                        ),
                        ButtonSegment(
                          value: 'background',
                          icon: const Icon(Icons.wallpaper),
                          label: Text(
                            tx(c, 'Koko näkymän tausta', 'Whole view background'),
                            key: const ValueKey('room-mode-background'),
                          ),
                        ),
                      ],
                      selected: {view.photoMode},
                      onSelectionChanged: (v) async {
                        await st.setRoomPhotoMode(view, mode: v.first);
                        setSheet(() {});
                      },
                    ),
                  ),
                  if (view.photoMode == 'background') ...[
                    ListTile(
                      dense: true,
                      title: Text(tx(c, 'Himmennys', 'Dimming')),
                      subtitle: Slider(
                        key: const ValueKey('room-bg-dim'),
                        value: view.bgDim,
                        max: 0.9,
                        divisions: 9,
                        label: '${(view.bgDim * 100).round()} %',
                        onChanged: (v) {
                          view.bgDim = v;
                          setSheet(() {});
                        },
                        onChangeEnd: (v) => st.setRoomPhotoMode(view, dim: v),
                      ),
                    ),
                    ListTile(
                      dense: true,
                      title: Text(tx(c, 'Sumennus', 'Blur')),
                      subtitle: Slider(
                        key: const ValueKey('room-bg-blur'),
                        value: view.bgBlur,
                        max: 20,
                        divisions: 10,
                        label: view.bgBlur.round().toString(),
                        onChanged: (v) {
                          view.bgBlur = v;
                          setSheet(() {});
                        },
                        onChangeEnd: (v) => st.setRoomPhotoMode(view, blur: v),
                      ),
                    ),
                  ],
                  ListTile(
                    key: const ValueKey('room-photo-remove'),
                    leading: const Icon(Icons.hide_image_outlined),
                    title: Text(tx(c, 'Poista kuva', 'Remove picture')),
                    onTap: () => Navigator.pop(c, 'remove'),
                  ),
                ],
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    ),
  );
  if (action == null || !context.mounted) return;
  if (action == 'remove') {
    await st.clearHeaderImage(d);
    return;
  }
  try {
    final bytes = action == 'take' ? await takeTilePhoto() : await pickRoomPhoto(context);
    if (bytes == null) return;
    final ok = await st.setHeaderImage(d, bytes);
    if (!ok && context.mounted) {
      showSnack(
        context,
        tx(
          context,
          'Enintään $tileImageMaxCount kuvaa. Poista jokin ensin.',
          'At most $tileImageMaxCount pictures. Remove one first.',
        ),
        error: true,
      );
    }
  } on FormatException {
    if (context.mounted) {
      showSnack(context, tx(context, 'Tiedosto ei ole kuva', 'The file is not a picture'), error: true);
    }
  }
}
