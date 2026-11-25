import '../state/net_health.dart';
import 'add_sheet.dart';
import 'tile_grid.dart';
import 'tile_status.dart';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'account_nudge.dart';
import 'app_scope.dart';
import 'automation_pages.dart';
import 'home_header.dart';
import 'tile_widget.dart';
import 'remote_pages.dart';
import 'update_ui.dart';

/// "Ohjausnäkymä": the everyday screen once something is set up. Only the tiles with their live
/// state and controls, grouped by room/dashboard, big enough for a wall tablet. Editing, settings
/// and adding devices sit behind one small gear menu, which can be locked (installer → customer).
class ControlView extends StatelessWidget {
  const ControlView({
    super.key,
    required this.onAddDevice,
    required this.onEdit,
    required this.onSettings,
    this.onEnergy,
  });
  final VoidCallback onAddDevice;
  final void Function(Dashboard d) onEdit;
  final VoidCallback onSettings;
  final VoidCallback? onEnergy;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final groups = st.config.dashboards.where((d) => d.tiles.isNotEmpty).toList();
    final single = groups.length == 1;
    final title = single ? groups.first.name : tx(context, 'Koti', 'Home');
    // t147u: never "Koti" in the app bar and again as the first section header.
    bool sameAsTitle(Dashboard d) => d.name.trim().toLowerCase() == title.trim().toLowerCase();
    return Scaffold(
      key: const ValueKey('control-view'),
      appBar: AppBar(
        title: Text(title, key: const ValueKey('cv-title')),
        actions: [
          const RemoteStatusChip(),
          if (!st.viewLocked && showAppBarAdd(context))
            IconButton(
              key: const ValueKey('appbar-add'),
              tooltip: tx(context, 'Lisää', 'Add'),
              icon: const Icon(Icons.add),
              onPressed: () => showAddSheet(context, dashboard: groups.isEmpty ? null : groups.last),
            ),
          if (st.viewLocked)
            Padding(
              padding: const EdgeInsets.only(right: 4),
              child: Tooltip(
                message: tx(context, 'Näkymä on lukittu', 'The view is locked'),
                child: const Icon(Icons.lock_outline, size: 20),
              ),
            ),
          _menu(context, groups),
          const SizedBox(width: 8),
        ],
      ),
      floatingActionButton: st.viewLocked
          ? null
          : FloatingActionButton.extended(
              key: const ValueKey('add-fab'),
              onPressed: () => showAddSheet(context, dashboard: groups.isEmpty ? null : groups.last),
              icon: const Icon(Icons.add),
              label: Text(tx(context, 'Lisää', 'Add')),
            ),
      body: Column(
        children: [
          const UpdateBanner(),
          const OfflineBanner(),
          const NoAccountBanner(),
          Expanded(
            child: ListenableBuilder(
              listenable: NetHealth.instance,
              builder: (context, _) => LayoutBuilder(
                builder: (context, box) {
                  final g = tileGridFor(box.maxWidth, AppScope.of(context).config.tileDensity);
                  final gap = g.gap;
                  return ListView(
                    padding: EdgeInsets.fromLTRB(gap, 6, gap, st.viewLocked ? 32 : 96),
                    children: [
                      const HomeHeader(),
                      for (final d in groups) ...[
                        if (!single && !sameAsTitle(d))
                          Padding(
                            padding: const EdgeInsets.fromLTRB(4, 14, 4, 10),
                            child: Text(
                              d.name,
                              key: ValueKey('group-${d.id}'),
                              style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w600),
                            ),
                          ),
                        Wrap(
                          spacing: gap,
                          runSpacing: gap,
                          children: [
                            for (final t in d.tiles)
                              if (!st.config.hideAwayTiles || awayLanConnection(st, t) == null)
                                SizedBox(
                                  width: g.width(t.wUnits),
                                  height: g.height(t.hUnits),
                                  child: TileWidget(key: ValueKey('cv-${t.id}'), tile: t, control: true),
                                ),
                            if (!st.viewLocked && d == groups.last)
                              SizedBox(
                                width: g.width(1),
                                height: g.height(1),
                                child: AddPlaceholderTile(
                                  key: const ValueKey('add-placeholder'),
                                  onTap: () => showAddSheet(context, dashboard: d),
                                ),
                              ),
                          ],
                        ),
                      ],
                    ],
                  );
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _menu(BuildContext context, List<Dashboard> groups) {
    final st = AppScope.of(context);
    if (st.viewLocked) {
      return IconButton(
        key: const ValueKey('control-menu'),
        tooltip: tx(context, 'Avaa lukitus', 'Unlock'),
        icon: const Icon(Icons.settings_outlined),
        onPressed: () => unlockFlow(context),
      );
    }
    return PopupMenuButton<String>(
      key: const ValueKey('control-menu'),
      tooltip: tx(context, 'Valikko', 'Menu'),
      icon: const Icon(Icons.settings_outlined),
      onSelected: (v) async {
        switch (v) {
          case 'add':
            onAddDevice();
          case 'edit':
            onEdit(groups.first);
          case 'energy':
            onEnergy?.call();
          case 'automations':
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationsPage()));
          case 'settings':
            onSettings();
          case 'lock':
            await lockFlow(context);
        }
      },
      itemBuilder: (c) => [
        PopupMenuItem(
          key: const ValueKey('home-add-device'),
          value: 'add',
          child: _item(const Icon(Icons.add), Text(tx(c, 'Lisää laite', 'Add device'))),
        ),
        PopupMenuItem(
          key: const ValueKey('control-edit'),
          value: 'edit',
          child: _item(const Icon(Icons.edit_outlined), Text(tx(c, 'Muokkaa näkymää', 'Edit the view'))),
        ),
        PopupMenuItem(
          key: const ValueKey('control-automations'),
          value: 'automations',
          child: _item(const Icon(Icons.auto_mode), Text(tx(c, 'Automaatiot', 'Automations'))),
        ),
        if (onEnergy != null)
          PopupMenuItem(
            value: 'energy',
            child: _item(const Icon(Icons.bolt_outlined), Text(tx(c, 'Energia', 'Energy'))),
          ),
        PopupMenuItem(
          key: const ValueKey('control-settings'),
          value: 'settings',
          child: _item(const Icon(Icons.tune), Text(tx(c, 'Asetukset', 'Settings'))),
        ),
        const PopupMenuDivider(),
        PopupMenuItem(
          key: const ValueKey('control-lock'),
          value: 'lock',
          child: _item(const Icon(Icons.lock_outline), Text(tx(c, 'Lukitse näkymä', 'Lock the view'))),
        ),
      ],
    );
  }

  static Widget _item(Widget icon, Widget label) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      icon,
      const SizedBox(width: 14),
      Flexible(child: label),
    ],
  );

  /// Lock with an optional PIN (e.g. an installer handing the tablet over to a customer).
  static Future<void> lockFlow(BuildContext context) async {
    final st = AppScope.read(context);
    final pin = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tx(c, 'Lukitse näkymä', 'Lock the view')),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              tx(
                c,
                'Laitteita voi edelleen ohjata, mutta muokkaus, asetukset ja laitteiden lisäys piilotetaan. Avaa lukitus rataskuvakkeesta.',
                'Devices can still be controlled, but editing, settings and adding devices are hidden. Unlock from the gear icon.',
              ),
            ),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('lock-pin'),
              controller: pin,
              obscureText: true,
              keyboardType: TextInputType.number,
              inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(8)],
              decoration: InputDecoration(
                labelText: tx(c, 'PIN-koodi (valinnainen)', 'PIN code (optional)'),
                helperText: tx(
                  c,
                  'Ilman PIN-koodia lukitus avataan yhdellä napautuksella.',
                  'Without a PIN one tap unlocks.',
                ),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton.icon(
            key: const ValueKey('lock-confirm'),
            onPressed: () => Navigator.pop(c, true),
            icon: const Icon(Icons.lock_outline),
            label: Text(tx(c, 'Lukitse', 'Lock')),
          ),
        ],
      ),
    );
    if (ok == true) await st.lockView(pin: pin.text.trim());
  }

  static Future<void> unlockFlow(BuildContext context) async {
    final st = AppScope.read(context);
    if (!await st.lockHasPin) {
      if (!context.mounted) return;
      final ok = await confirmDialog(
        context,
        tx(context, 'Avaa lukitus?', 'Unlock?'),
        tx(context, 'Muokkaus ja asetukset tulevat taas näkyviin.', 'Editing and settings become visible again.'),
        ok: tx(context, 'Avaa', 'Unlock'),
      );
      if (ok) await st.unlockView();
      return;
    }
    if (!context.mounted) return;
    final pin = TextEditingController();
    String? error;
    await showDialog<void>(
      context: context,
      builder: (c) => StatefulBuilder(
        builder: (c, set) => AlertDialog(
          title: Text(tx(c, 'Avaa lukitus', 'Unlock')),
          content: TextField(
            key: const ValueKey('unlock-pin'),
            controller: pin,
            autofocus: true,
            obscureText: true,
            keyboardType: TextInputType.number,
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            decoration: InputDecoration(
              labelText: tx(c, 'PIN-koodi', 'PIN code'),
              errorText: error,
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
            FilledButton(
              key: const ValueKey('unlock-confirm'),
              onPressed: () async {
                if (await st.unlockView(pin.text.trim())) {
                  if (c.mounted) Navigator.pop(c);
                } else {
                  set(() => error = tx(c, 'Väärä PIN-koodi', 'Wrong PIN code'));
                }
              },
              child: Text(tx(c, 'Avaa', 'Unlock')),
            ),
          ],
        ),
      ),
    );
  }
}
