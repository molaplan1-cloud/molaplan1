import 'control_view.dart';
import 'energy_pages.dart';
import 'dart:async';

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'app_scope.dart';
import 'remote_pages.dart';
import 'connections_page.dart';
import 'onboarding_page.dart';
import 'settings_page.dart';
import 'tile_editor.dart';
import 'tile_widget.dart';
import 'update_ui.dart';

class HomePage extends StatefulWidget {
  const HomePage({super.key});
  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  String? _dashId;
  bool _editing = false;
  bool _pickedGallery = false;
  Timer? _hourly;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;
      final st = AppScope.read(context);
      if (st.loaded && !st.config.onboardingDone && st.config.connections.isEmpty) {
        await Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
      }
      if (mounted && st.loaded) {
        unawaited(startupUpdateCheck(context));
        unawaited(st.account.syncNow(quiet: true));
      }
    });
    // A tablet/PC that stays open for days still notices new versions (the check itself
    // runs at most once per UpdateState.interval and retries soon when offline).
    _hourly = Timer.periodic(const Duration(minutes: 20), (_) {
      if (mounted) unawaited(startupUpdateCheck(context));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed || !mounted) return;
    final st = AppScope.read(context);
    unawaited(startupUpdateCheck(context));
    unawaited(st.account.syncNow(quiet: true));
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _hourly?.cancel();
    super.dispose();
  }

  Dashboard _current() {
    final ds = AppScope.of(context).config.dashboards;
    return ds.firstWhere((d) => d.id == _dashId, orElse: () => ds.first);
  }

  Future<void> _addDashboard() async {
    final st = AppScope.read(context);
    final name = await promptText(
      context,
      tx(context, 'Uusi näkymä', 'New dashboard'),
      hint: tx(context, 'esim. Mökki', 'e.g. Cottage'),
    );
    if (name == null || name.isEmpty) return;
    final d = await st.addDashboard(name);
    setState(() {
      _dashId = d.id;
      _editing = true;
    });
  }

  Future<void> _renameDashboard(Dashboard d) async {
    final st = AppScope.read(context);
    final name = await promptText(context, tx(context, 'Nimeä näkymä', 'Rename dashboard'), initial: d.name);
    if (name != null && name.isNotEmpty) await st.renameDashboard(d, name);
  }

  Future<void> _deleteDashboard(Dashboard d) async {
    final st = AppScope.read(context);
    final ok = await confirmDialog(
      context,
      tx(context, 'Poistetaanko näkymä?', 'Delete dashboard?'),
      tx(
        context,
        '"${d.name}" ja sen ${d.tiles.length} ruutua poistetaan.',
        '"${d.name}" and its ${d.tiles.length} tiles will be deleted.',
      ),
      ok: tx(context, 'Poista', 'Delete'),
    );
    if (!ok || !mounted) return;
    final index = st.config.dashboards.indexOf(d);
    await st.deleteDashboard(d);
    setState(() => _dashId = null);
    if (!mounted) return;
    showUndo(context, tx(context, 'Näkymä "${d.name}" poistettu', 'Dashboard "${d.name}" deleted'), () async {
      await st.restoreDashboard(d, index);
      if (mounted) setState(() => _dashId = d.id);
    });
  }

  Future<void> _addTile(Dashboard d) async {
    if (!AppScope.read(context).config.advanced) {
      await ConnectionsPage.addNew(context, dashboard: d);
      return;
    }
    final type = await showModalBottomSheet<TileType>(
      context: context,
      showDragHandle: true,
      builder: (c) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 8),
              child: Text(
                tx(context, 'Valitse ruudun tyyppi', 'Choose tile type'),
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            ListTile(
              leading: const Icon(Icons.auto_awesome_outlined),
              title: Text(tx(context, 'Uusi laite valmiilla ruuduilla', 'New device with ready tiles')),
              subtitle: Text(
                tx(
                  context,
                  'Helpoin tapa: Shelly, ESP32-CAM, Home Assistant, IV-kone…',
                  'Easiest: Shelly, ESP32-CAM, Home Assistant…',
                ),
              ),
              onTap: () {
                _pickedGallery = true;
                Navigator.pop(c, null);
              },
              trailing: const Icon(Icons.chevron_right),
            ),
            const Divider(),
            for (final t in TileType.values.where((x) => x != TileType.thermostat))
              ListTile(
                leading: Icon(tileTypeIcon(t)),
                title: Text(tileTypeLabel(context, t)),
                subtitle: Text(tileTypeHelp(context, t)),
                onTap: () => Navigator.pop(c, t),
              ),
          ],
        ),
      ),
    );
    if (!mounted) return;
    if (type == null) {
      // dismissed or "new device" chosen: distinguish by a flag
      if (_pickedGallery) {
        _pickedGallery = false;
        await ConnectionsPage.addNew(context, dashboard: d);
      }
      return;
    }
    final tile = TileConfig(
      type: type,
      colSpan: type == TileType.camera ? 2 : (type == TileType.slider ? 2 : 1),
      rowSpan: type == TileType.camera ? 2 : 1,
    );
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => TileEditor(dashboard: d, initial: tile, isNew: true),
      ),
    );
  }

  Future<void> _openSettings() async {
    final r = await Navigator.push<String>(context, MaterialPageRoute(builder: (_) => const SettingsPage()));
    if (r == 'example' && mounted) {
      setState(() => _dashId = AppScope.read(context).config.dashboards.last.id);
    }
  }

  Widget _nav(BuildContext context, {required bool drawer}) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    final cur = _current();
    void close() {
      if (drawer) Navigator.pop(context);
    }

    return SafeArea(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 18, 12, 12),
            child: Row(
              children: [
                Container(
                  width: 34,
                  height: 34,
                  decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(10)),
                  child: Icon(Icons.dashboard_customize_outlined, color: cs.onPrimary, size: 20),
                ),
                const SizedBox(width: 10),
                Text('Molaplan', style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w700)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 4),
            child: Text(tx(context, 'NÄKYMÄT', 'DASHBOARDS'), style: Theme.of(context).textTheme.labelSmall),
          ),
          Expanded(
            child: ListView(
              padding: const EdgeInsets.symmetric(horizontal: 8),
              children: [
                for (final d in st.config.dashboards)
                  ListTile(
                    selected: d.id == cur.id,
                    selectedTileColor: cs.secondaryContainer.withValues(alpha: 0.5),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.space_dashboard_outlined),
                    title: Text(d.name, overflow: TextOverflow.ellipsis),
                    onTap: () {
                      setState(() => _dashId = d.id);
                      close();
                    },
                  ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.add),
                  title: Text(tx(context, 'Uusi näkymä', 'New dashboard')),
                  onTap: () {
                    close();
                    _addDashboard();
                  },
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Padding(
            padding: const EdgeInsets.all(8),
            child: Column(
              children: [
                if (st.config.advanced)
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.device_hub),
                    title: Text(tx(context, 'Yhteydet', 'Connections')),
                    trailing: Text('${st.config.connections.length}'),
                    onTap: () {
                      close();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsPage()));
                    },
                  ),
                if (st.config.energy.meters.isNotEmpty)
                  ListTile(
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    leading: const Icon(Icons.bolt_outlined),
                    title: Text(tx(context, 'Energia', 'Energy')),
                    onTap: () {
                      close();
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const EnergyPage()));
                    },
                  ),
                ListTile(
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(tx(context, 'Asetukset', 'Settings')),
                  onTap: () {
                    close();
                    _openSettings();
                  },
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    if (!st.loaded) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    // After setup: the clean control view (tiles only). Editing is one tap away in its gear menu.
    if (!_editing && st.hasTiles) {
      return ControlView(
        onAddDevice: () => ConnectionsPage.addNew(context, dashboard: _current()),
        onEdit: (d) => setState(() {
          _dashId ??= d.id;
          _editing = true;
        }),
        onSettings: _openSettings,
        onEnergy: st.config.energy.meters.isEmpty
            ? null
            : () => Navigator.push(context, MaterialPageRoute(builder: (_) => const EnergyPage())),
      );
    }
    final d = _current();
    final wide = MediaQuery.sizeOf(context).width >= 900;
    final cs = Theme.of(context).colorScheme;

    final body = Column(
      children: [
        const UpdateBanner(),
        Expanded(
          child: _DashboardGrid(
            dashboard: d,
            editing: _editing,
            onAddTile: () => _addTile(d),
            onStartEditing: () => setState(() => _editing = true),
          ),
        ),
      ],
    );

    final scaffold = Scaffold(
      drawer: wide ? null : Drawer(child: _nav(context, drawer: true)),
      appBar: AppBar(
        title: Text(d.name),
        actions: [
          if (!_editing) const RemoteStatusChip(),
          if (_editing) ...[
            IconButton(
              tooltip: tx(context, 'Nimeä', 'Rename'),
              icon: const Icon(Icons.drive_file_rename_outline),
              onPressed: () => _renameDashboard(d),
            ),
            IconButton(
              tooltip: tx(context, 'Poista näkymä', 'Delete dashboard'),
              icon: const Icon(Icons.delete_outline),
              onPressed: () => _deleteDashboard(d),
            ),
            const SizedBox(width: 4),
            FilledButton.icon(
              onPressed: () => setState(() => _editing = false),
              icon: const Icon(Icons.check),
              label: Text(tx(context, 'Valmis', 'Done')),
            ),
          ] else
            IconButton(
              tooltip: tx(context, 'Muokkaa', 'Edit'),
              icon: const Icon(Icons.edit_outlined),
              onPressed: () => setState(() => _editing = true),
            ),
          const SizedBox(width: 12),
        ],
      ),
      floatingActionButton: _editing
          ? (st.config.advanced
                ? FloatingActionButton.extended(
                    onPressed: () => _addTile(d),
                    icon: const Icon(Icons.add),
                    label: Text(tx(context, 'Lisää ruutu', 'Add tile')),
                  )
                : null)
          : (d.tiles.isEmpty
                ? null // the empty view has its own big button
                : FloatingActionButton.extended(
                    key: const ValueKey('home-add-device'),
                    onPressed: () => ConnectionsPage.addNew(context, dashboard: d),
                    icon: const Icon(Icons.add, size: 28),
                    label: Text(tx(context, 'Lisää laite', 'Add device'), style: const TextStyle(fontSize: 18)),
                  )),
      body: body,
    );

    if (!wide) return scaffold;
    return Row(
      children: [
        SizedBox(
          width: 260,
          child: Material(color: cs.surfaceContainerLowest, child: _nav(context, drawer: false)),
        ),
        const VerticalDivider(width: 1),
        Expanded(child: scaffold),
      ],
    );
  }
}

class _DashboardGrid extends StatelessWidget {
  const _DashboardGrid({
    required this.dashboard,
    required this.editing,
    required this.onAddTile,
    required this.onStartEditing,
  });
  final Dashboard dashboard;
  final bool editing;
  final VoidCallback onAddTile;
  final VoidCallback onStartEditing;

  static bool get _desktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    if (dashboard.tiles.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.dashboard_customize_outlined, size: 56, color: cs.primary),
              const SizedBox(height: 16),
              Text(tx(context, 'Tyhjä näkymä', 'Empty dashboard'), style: Theme.of(context).textTheme.titleLarge),
              const SizedBox(height: 8),
              Text(
                tx(
                  context,
                  'Täällä näkyvät laitteidesi ruudut: lämpötilat, kytkimet, kamerat ja pikakomennot. Aloita lisäämällä laite.',
                  'Your device tiles appear here: temperatures, switches, cameras and shortcuts. Start by adding a device.',
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: 320,
                height: 64,
                child: st.config.connections.isEmpty || !st.config.advanced
                    ? FilledButton.icon(
                        key: const ValueKey('empty-add-device'),
                        onPressed: () => ConnectionsPage.addNew(context, dashboard: dashboard),
                        icon: const Icon(Icons.add, size: 28),
                        label: Text(
                          st.config.connections.isEmpty
                              ? tx(context, 'Lisää ensimmäinen laite', 'Add your first device')
                              : tx(context, 'Lisää laite', 'Add device'),
                          style: const TextStyle(fontSize: 18),
                        ),
                      )
                    : FilledButton.icon(
                        key: const ValueKey('empty-add-tile'),
                        onPressed: () {
                          onStartEditing();
                          onAddTile();
                        },
                        icon: const Icon(Icons.add, size: 28),
                        label: Text(tx(context, 'Lisää ruutu', 'Add a tile'), style: const TextStyle(fontSize: 18)),
                      ),
              ),
            ],
          ),
        ),
      );
    }

    return LayoutBuilder(
      builder: (context, box) {
        const gap = 12.0;
        final cols = (box.maxWidth / 170).floor().clamp(2, 8);
        final cell = (box.maxWidth - gap * (cols + 1)) / cols;
        final cellH = (cell * 0.8).clamp(110.0, 170.0);
        return SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(gap, 4, gap, 96),
          child: Wrap(
            spacing: gap,
            runSpacing: gap,
            children: [for (var i = 0; i < dashboard.tiles.length; i++) _sized(context, i, cols, cell, cellH, gap)],
          ),
        );
      },
    );
  }

  Widget _sized(BuildContext context, int index, int cols, double cell, double cellH, double gap) {
    final t = dashboard.tiles[index];
    final span = t.colSpan.clamp(1, cols);
    final w = span * cell + (span - 1) * gap;
    final h = t.rowSpan * cellH + (t.rowSpan - 1) * gap;
    final tile = SizedBox(
      width: w,
      height: h,
      child: TileWidget(key: ValueKey(t.id), tile: t, editing: editing),
    );
    if (!editing) return tile;
    return _EditableTile(dashboard: dashboard, index: index, width: w, height: h, desktop: _desktop, child: tile);
  }
}

class _EditableTile extends StatelessWidget {
  const _EditableTile({
    required this.dashboard,
    required this.index,
    required this.width,
    required this.height,
    required this.desktop,
    required this.child,
  });
  final Dashboard dashboard;
  final int index;
  final double width;
  final double height;
  final bool desktop;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.read(context);
    final cs = Theme.of(context).colorScheme;
    final t = dashboard.tiles[index];
    final overlay = Stack(
      children: [
        child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TileEditor(dashboard: dashboard, initial: t.copy()),
                ),
              ),
              child: Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: cs.primary.withValues(alpha: 0.7), width: 1.5),
                ),
              ),
            ),
          ),
        ),
        Positioned(
          right: 4,
          top: 4,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mini(context, Icons.chevron_left, () => st.moveTile(dashboard, index, index - 1), enabled: index > 0),
              _mini(
                context,
                Icons.chevron_right,
                () => st.moveTile(dashboard, index, index + 1),
                enabled: index < dashboard.tiles.length - 1,
              ),
              _mini(context, Icons.delete_outline, () async {
                final ok = await confirmDialog(
                  context,
                  tx(context, 'Poistetaanko ruutu?', 'Delete tile?'),
                  t.title,
                  ok: tx(context, 'Poista', 'Delete'),
                );
                if (!ok) return;
                await st.deleteTile(dashboard, t.id);
                if (context.mounted) {
                  showUndo(
                    context,
                    tx(context, 'Ruutu "${t.title}" poistettu', 'Tile "${t.title}" deleted'),
                    () => st.restoreTile(dashboard, t, index),
                  );
                }
              }),
            ],
          ),
        ),
        Positioned(right: 8, bottom: 8, child: Icon(Icons.drag_indicator, size: 22, color: cs.primary)),
      ],
    );

    final feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: SizedBox(width: width, height: height, child: child),
      ),
    );
    final draggable = desktop
        ? Draggable<int>(
            data: index,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.3, child: overlay),
            child: overlay,
          )
        : LongPressDraggable<int>(
            data: index,
            feedback: feedback,
            childWhenDragging: Opacity(opacity: 0.3, child: overlay),
            child: overlay,
          );

    return DragTarget<int>(
      onWillAcceptWithDetails: (d) => d.data != index,
      onAcceptWithDetails: (d) => st.moveTile(dashboard, d.data, index),
      builder: (context, cand, _) => AnimatedScale(
        duration: const Duration(milliseconds: 120),
        scale: cand.isNotEmpty ? 0.95 : 1,
        child: draggable,
      ),
    );
  }

  Widget _mini(BuildContext context, IconData icon, VoidCallback onTap, {bool enabled = true}) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest,
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: enabled ? onTap : null,
        child: Padding(
          padding: const EdgeInsets.all(9),
          child: Icon(icon, size: 20, color: enabled ? null : Colors.grey),
        ),
      ),
    ),
  );
}
