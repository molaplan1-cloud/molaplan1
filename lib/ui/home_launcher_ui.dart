/// t290u: "Lisää aloitusnäytölle" sheet and running a command from a pinned shortcut.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../core/plat.dart';
import '../core/template.dart';
import '../models/models.dart';
import '../state/app_state.dart';
import '../state/home_launcher.dart';
import '../state/tile_runtime.dart';
import 'app_scope.dart';
import 'push_listener.dart';

/// Long-press action: pin a command shortcut and/or a status widget for [tile].
Future<void> showAddToHomeScreen(BuildContext context, TileConfig tile) async {
  if (!launcherSupported) return;
  final st = AppScope.read(context);
  final canRun = tileCanRun(tile);
  var mode = canRun ? 'command' : 'status';
  var confirm = launcherNeedsConfirm(tile);
  final live = _valueOf(tile);
  final ok = await showDialog<bool>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        key: const ValueKey('add-home-dialog'),
        title: Text(tx(c, 'Lisää aloitusnäytölle', 'Add to home screen')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (canRun)
                RadioGroup<String>(
                  groupValue: mode,
                  onChanged: (v) => set(() => mode = v ?? mode),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      RadioListTile<String>(
                        key: const ValueKey('add-home-command'),
                        value: 'command',
                        title: Text(tx(c, 'Komento', 'Command')),
                        subtitle: Text(
                          tx(
                            c,
                            'Pikakuvake suorittaa komennon suoraan aloitusnäytöltä.',
                            'A shortcut runs the command directly from the home screen.',
                          ),
                        ),
                      ),
                      RadioListTile<String>(
                        key: const ValueKey('add-home-status'),
                        value: 'status',
                        title: Text(tx(c, 'Tila (widget)', 'Status (widget)')),
                        subtitle: Text(
                          tx(
                            c,
                            'Widget näyttää laatan tilan aloitusnäytöllä.',
                            'A widget shows the tile status on the home screen.',
                          ),
                        ),
                      ),
                    ],
                  ),
                )
              else
                Text(
                  tx(
                    c,
                    'Tälle laatalle lisätään tilawidget, joka näyttää arvon aloitusnäytöllä.',
                    'This tile gets a status widget that shows the value on the home screen.',
                  ),
                ),
              if (mode == 'command') ...[
                CheckboxListTile(
                  key: const ValueKey('add-home-confirm'),
                  contentPadding: EdgeInsets.zero,
                  value: confirm,
                  onChanged: (v) => set(() => confirm = v ?? false),
                  title: Text(tx(c, 'Vahvista ennen suoritusta', 'Confirm before running')),
                  subtitle: Text(
                    tx(
                      c,
                      'Suositellaan vaarallisille komennoille, kuten hälytyksen pois päältä.',
                      'Recommended for dangerous commands, such as turning an alarm off.',
                    ),
                  ),
                ),
                Text(
                  tx(
                    c,
                    'PIN-koodia ei tallenneta pikakuvakkeeseen. Jos laite vaatii PIN-koodin, se kysytään sovelluksessa.',
                    'The PIN is not stored in the shortcut. If the device requires a PIN, the app will ask for it.',
                  ),
                ),
              ],
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('add-home-ok'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Lisää', 'Add')),
          ),
        ],
      ),
    ),
  );
  if (ok != true || !context.mounted) return;
  final added = mode == 'command'
      ? await pinCommandShortcut(tile, confirm: confirm)
      : await pinStatusWidget(tile, live, lang: st.lang);
  if (!context.mounted) return;
  if (added) {
    if (mode == 'status') await scheduleLauncherRefresh();
    if (!context.mounted) return;
    showSnack(
      context,
      mode == 'command'
          ? tx(
              context,
              'Pikakuvake lisätty. Vahvista se aloitusnäytöllä.',
              'Shortcut added. Confirm it on the home screen.',
            )
          : tx(context, 'Widget lisätty. Vahvista se aloitusnäytöllä.', 'Widget added. Confirm it on the home screen.'),
    );
  } else {
    showSnack(
      context,
      tx(
        context,
        'Aloitusnäyttö ei tue tätä, tai lisäys peruutettiin.',
        'The home screen does not support this, or the add was cancelled.',
      ),
      error: true,
    );
  }
}

Object? _valueOf(TileConfig t) {
  for (final rt in TileRuntime.live[t.id] ?? const <TileRuntime>{}) {
    return rt.value;
  }
  return null;
}

/// Handles `molaplan://run/<tileId>` from a pinned shortcut.
Future<void> runTileFromShortcut(BuildContext context, String tileId, {required bool confirm}) async {
  final st = AppScope.read(context);
  final tile = findTile(st, tileId);
  if (tile == null) {
    showSnack(context, tx(context, 'Laattaa ei löytynyt', 'Tile not found'), error: true);
    return;
  }
  if (!tileCanRun(tile)) {
    await openTileById(context, tileId);
    return;
  }
  if (confirm || launcherNeedsConfirm(tile)) {
    final ok = await confirmDialog(context, tile.title, tx(context, 'Suoritetaanko komento?', 'Run this command?'));
    if (!ok || !context.mounted) return;
  }
  if (_connectionNeedsPin(st, tile)) {
    if (!await _askConnectionPin(context, st, tile) || !context.mounted) return;
  }
  String? pin;
  if (_asksCommandPin(tile)) {
    pin = await _askCommandPin(context, st, tile);
    if (pin == null || !context.mounted) return;
  }
  try {
    if (tile.type == TileType.toggle) {
      final value = _valueOf(tile);
      final on = isTruthy(value, onValue: tile.onValue.isEmpty ? null : tile.onValue);
      final step = on ? tile.offCommand : tile.onCommand;
      if (step == null) {
        showSnack(context, tx(context, 'Komentoa ei ole määritetty', 'No command configured'), error: true);
        return;
      }
      await st.runStep(step, value: on ? 0 : 1);
    } else if (tile.commands.isNotEmpty) {
      await st.runSequence(tile.commands, value: pin);
    } else if (tile.onCommand != null) {
      await st.runStep(tile.onCommand!, value: pin);
    } else {
      await openTileById(context, tileId);
      return;
    }
    if (context.mounted) showSnack(context, '${tile.title} ✓');
  } catch (e) {
    if (context.mounted) showSnack(context, '${tile.title}: $e', error: true);
  }
}

bool _asksCommandPin(TileConfig t) => t.commands.any((c) => c.spec['askPin'] == true || c.spec['askPin'] == 'true');

bool _connectionNeedsPin(AppState st, TileConfig t) {
  for (final id in [t.connectionId, t.onCommand?.connectionId, ...t.commands.map((c) => c.connectionId)]) {
    final c = st.connection(id);
    if (c != null && st.connectionUsesPin(c) && st.needsPin(c.id)) return true;
  }
  return false;
}

Future<bool> _askConnectionPin(BuildContext context, AppState st, TileConfig tile) async {
  String? connId;
  for (final id in [tile.connectionId, tile.onCommand?.connectionId, ...tile.commands.map((c) => c.connectionId)]) {
    final c = st.connection(id);
    if (c != null && st.connectionUsesPin(c) && st.needsPin(c.id)) {
      connId = c.id;
      break;
    }
  }
  final conn = st.connection(connId);
  if (conn == null) return false;
  final ctl = TextEditingController();
  var remember = !Plat.isWeb;
  final pin = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        key: const ValueKey('conn-pin-dialog'),
        title: Text('${conn.name}: ${tx(c, 'syötä PIN-koodi', 'enter PIN')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('conn-pin-field'),
              controller: ctl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: tx(c, 'PIN', 'PIN')),
              onSubmitted: (v) => Navigator.pop(c, v),
            ),
            if (!Plat.isWeb)
              CheckboxListTile(
                key: const ValueKey('conn-pin-remember'),
                contentPadding: EdgeInsets.zero,
                value: remember,
                onChanged: (v) => set(() => remember = v ?? false),
                title: Text(tx(c, 'Muista tällä laitteella', 'Remember on this device')),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('conn-pin-ok'),
            onPressed: () => Navigator.pop(c, ctl.text),
            child: Text(tx(c, 'Tallenna', 'Save')),
          ),
        ],
      ),
    ),
  );
  if (pin == null || pin.trim().isEmpty) return false;
  await st.setConnectionPin(conn.id, pin.trim(), remember: remember);
  return true;
}

Future<String?> _askCommandPin(BuildContext context, AppState st, TileConfig tile) async {
  final saved = await st.secretStore.read(AppState.pinKey(tile.id));
  if (saved != null && saved.isNotEmpty) return saved;
  if (!context.mounted) return null;
  final ctl = TextEditingController();
  var remember = false;
  final pin = await showDialog<String>(
    context: context,
    builder: (c) => StatefulBuilder(
      builder: (c, set) => AlertDialog(
        title: Text('${tile.title}: ${tx(c, 'PIN-koodi', 'PIN code')}'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const ValueKey('pin-field'),
              controller: ctl,
              autofocus: true,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly],
              decoration: InputDecoration(labelText: tx(c, 'PIN', 'PIN')),
              onSubmitted: (v) => Navigator.pop(c, v),
            ),
            if (!Plat.isWeb)
              CheckboxListTile(
                key: const ValueKey('pin-remember'),
                contentPadding: EdgeInsets.zero,
                value: remember,
                onChanged: (v) => set(() => remember = v ?? false),
                title: Text(tx(c, 'Muista tällä laitteella', 'Remember on this device')),
              ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('pin-ok'),
            onPressed: () => Navigator.pop(c, ctl.text),
            child: Text(tx(c, 'Lähetä', 'Send')),
          ),
        ],
      ),
    ),
  );
  if (pin == null || pin.isEmpty) return null;
  if (remember && !Plat.isWeb) {
    await st.secretStore.write(AppState.pinKey(tile.id), pin);
  }
  return pin;
}
