import '../state/net_health.dart';

import 'tile_grid.dart';
import 'tile_status.dart';
import 'control_view.dart';
import 'energy_pages.dart';

import 'dart:async';

import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'account_nudge.dart';
import 'add_sheet.dart';
import 'app_scope.dart';
import 'automation_pages.dart';
import 'remote_pages.dart';
import 'connections_page.dart';
import 'onboarding_page.dart';
import 'settings_page.dart';
import 'tile_editor.dart';
import 'tile_look.dart';
import 'tile_visuals.dart' show RoomBackdrop;
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
        if (accountNudges && !st.account.signedIn) {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const WelcomePage()));
          if (!mounted) return;
        }
        // Signed in to an account that already has a setup: no device guide needed.
        if (!st.hasTiles) await Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage()));
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
    if (!mounted) return;
    if (state == AppLifecycleState.paused) {
      // Keep the measurement history (trends, last values for offline).
      unawaited(AppScope.read(context).saveHistory());
      return;
    }
    if (state != AppLifecycleState.resumed) return;
    // Home Wi-Fi or away? (LAN tiles grey out / come back – t131u.)
    unawaited(NetHealth.instance.check(force: true));
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
                ListTile(
                  key: const ValueKey('nav-automations'),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  leading: const Icon(Icons.auto_mode),
                  title: Text(tx(context, 'Automaatiot', 'Automations')),
                  trailing: st.config.automation.automations.isEmpty
                      ? null
                      : Text('${st.config.automation.automations.where((a) => a.enabled).length}'),
                  onTap: () {
                    close();
                    Navigator.push(context, MaterialPageRoute(builder: (_) => const AutomationsPage()));
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
        const OfflineBanner(),
          const AwayNoBridgeBanner(),
        const NoAccountBanner(),
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
                    onPressed: () => showAddSheet(context, dashboard: d),
                    icon: const Icon(Icons.add, size: 28),
                    label: Text(tx(context, 'Lisää', 'Add'), style: const TextStyle(fontSize: 18)),
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

class _DashboardGrid extends StatefulWidget {
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

  @override
  State<_DashboardGrid> createState() => _DashboardGridState();
}

class _DashboardGridState extends State<_DashboardGrid> {
  static bool get _desktop => Platform.isWindows || Platform.isLinux || Platform.isMacOS;

  /// While dragging: the live order (tile ids) – the other tiles reflow as you move.
  List<String>? _order;
  String? _dragging;

  /// While resizing: (tile id, cols, rows) preview.
  (String, int, int)? _resize;

  Dashboard get dashboard => widget.dashboard;

  void _hover(String target) {
    final id = _dragging;
    if (id == null || id == target) return;
    final o = _order ?? [for (final t in dashboard.tiles) t.id];
    final from = o.indexOf(id), to = o.indexOf(target);
    if (from < 0 || to < 0) return;
    setState(() {
      o.removeAt(from);
      o.insert(to, id);
      _order = o;
    });
  }

  Future<void> _commitDrag() async {
    final id = _dragging, o = _order;
    setState(() {
      _dragging = null;
      _order = null;
    });
    if (id == null || o == null) return;
    final st = AppScope.read(context);
    final from = dashboard.tiles.indexWhere((t) => t.id == id);
    await st.moveTile(dashboard, from, o.indexOf(id));
  }

  Future<void> _commitResize() async {
    final r = _resize;
    setState(() => _resize = null);
    if (r == null) return;
    final t = dashboard.tiles.where((t) => t.id == r.$1).firstOrNull;
    if (t == null || (t.w2 == r.$2 && t.h2 == r.$3)) return;
    final c = t.copy()
      ..w2 = r.$2
      ..h2 = r.$3;
    await AppScope.read(context).upsertTile(dashboard, c);
  }

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
                          widget.onStartEditing();
                          widget.onAddTile();
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

    return ListenableBuilder(
      listenable: NetHealth.instance,
      builder: (context, _) => LayoutBuilder(
        builder: (context, box) {
          final g = tileGridFor(box.maxWidth, AppScope.of(context).config.tileDensity);
          final byId = {for (final t in dashboard.tiles) t.id: t};
          final ids = _order ?? [for (final t in dashboard.tiles) t.id];
          // t172u: "Koko näkymän tausta" also while editing.
          return RoomBackdrop(
            dashboard: dashboard,
            child: SingleChildScrollView(
              padding: EdgeInsets.fromLTRB(g.gap, 4, g.gap, 96),
              child: Wrap(
                spacing: g.gap,
                runSpacing: g.gap,
                children: [
                  for (final id in ids)
                    if (byId[id] != null &&
                        (widget.editing || !st.config.hideAwayTiles || awayLanConnection(st, byId[id]!) == null))
                      _sized(context, byId[id]!, g),
                  if (!widget.editing)
                    SizedBox(
                      width: g.width(1),
                      height: g.height(1),
                      child: AddPlaceholderTile(
                        key: const ValueKey('add-placeholder'),
                        onTap: () => showAddSheet(context, dashboard: dashboard),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _sized(BuildContext context, TileConfig t, TileGridMetrics g) {
    final r = _resize != null && _resize!.$1 == t.id ? _resize : null;
    final w = g.widthOf(r?.$2 ?? t.w2);
    final h = g.height((r?.$3 ?? t.h2) / 2);
    final tile = AnimatedContainer(
      duration: const Duration(milliseconds: 120),
      width: w,
      height: h,
      child: TileWidget(key: ValueKey(t.id), tile: t, editing: widget.editing),
    );
    if (!widget.editing) return tile;
    return _EditableTile(
      key: ValueKey('edit-${t.id}'),
      dashboard: dashboard,
      tile: t,
      width: w,
      height: h,
      desktop: _desktop,
      dragging: _dragging == t.id,
      onDragStart: () => setState(() {
        _dragging = t.id;
        _order = [for (final x in dashboard.tiles) x.id];
      }),
      onHover: () => _hover(t.id),
      onDragEnd: _commitDrag,
      onResize: (dx, dy) {
        // t144u: snap to HALF grid units: 0,5–4 wide (as the grid allows) and tall.
        final (nc, nr) = snapResize(g, t, dx, dy);
        if (_resize?.$2 != nc || _resize?.$3 != nr) setState(() => _resize = (t.id, nc, nr));
      },
      onResizeEnd: _commitResize,
      child: tile,
    );
  }
}

class _EditableTile extends StatefulWidget {
  const _EditableTile({
    super.key,
    required this.dashboard,
    required this.tile,
    required this.width,
    required this.height,
    required this.desktop,
    required this.dragging,
    required this.onDragStart,
    required this.onHover,
    required this.onDragEnd,
    required this.onResize,
    required this.onResizeEnd,
    required this.child,
  });
  final Dashboard dashboard;
  final TileConfig tile;
  final double width;
  final double height;
  final bool desktop;
  final bool dragging;
  final VoidCallback onDragStart;
  final VoidCallback onHover;
  final VoidCallback onDragEnd;
  final void Function(double dx, double dy) onResize;
  final VoidCallback onResizeEnd;
  final Widget child;

  @override
  State<_EditableTile> createState() => _EditableTileState();
}

class _EditableTileState extends State<_EditableTile> {
  Offset _drag = Offset.zero;

  @override
  Widget build(BuildContext context) {
    final st = AppScope.read(context);
    final cs = Theme.of(context).colorScheme;
    final t = widget.tile;
    final d = widget.dashboard;
    final overlay = Stack(
      children: [
        widget.child,
        Positioned.fill(
          child: Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => TileEditor(dashboard: d, initial: t.copy()),
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
          right: 3,
          top: 3,
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _mini(context, Icons.palette_outlined, () => showTileLook(context, t), key: 'tile-look-${t.id}'),
              _mini(context, Icons.delete_outline, () async {
                final index = d.tiles.indexWhere((x) => x.id == t.id);
                final ok = await confirmDialog(
                  context,
                  tx(context, 'Poistetaanko ruutu?', 'Delete tile?'),
                  t.title,
                  ok: tx(context, 'Poista', 'Delete'),
                );
                if (!ok) return;
                await st.deleteTile(d, t.id);
                if (context.mounted) {
                  showUndo(
                    context,
                    tx(context, 'Ruutu "${t.title}" poistettu', 'Tile "${t.title}" deleted'),
                    () => st.restoreTile(d, t, index),
                  );
                }
              }, key: 'tile-delete-${t.id}'),
            ],
          ),
        ),
      ],
    );

    final feedback = Material(
      color: Colors.transparent,
      child: Opacity(
        opacity: 0.85,
        child: SizedBox(width: widget.width, height: widget.height, child: widget.child),
      ),
    );
    Widget drag(Widget child) => widget.desktop
        ? Draggable<String>(
            data: t.id,
            feedback: feedback,
            onDragStarted: widget.onDragStart,
            onDragEnd: (_) => widget.onDragEnd(),
            childWhenDragging: Opacity(opacity: 0.25, child: overlay),
            child: child,
          )
        : LongPressDraggable<String>(
            data: t.id,
            feedback: feedback,
            onDragStarted: widget.onDragStart,
            onDragEnd: (_) => widget.onDragEnd(),
            childWhenDragging: Opacity(opacity: 0.25, child: overlay),
            child: child,
          );

    // Corner handle: drag to resize (snaps to grid units).
    final handle = Positioned(
      right: 0,
      bottom: 0,
      child: MouseRegion(
        cursor: SystemMouseCursors.resizeDownRight,
        child: GestureDetector(
          key: ValueKey('tile-resize-${t.id}'),
          behavior: HitTestBehavior.opaque,
          onPanStart: (_) => _drag = Offset.zero,
          onPanUpdate: (e) {
            _drag += e.delta;
            widget.onResize(_drag.dx, _drag.dy);
          },
          onPanEnd: (_) => widget.onResizeEnd(),
          onPanCancel: widget.onResizeEnd,
          child: SizedBox(
            width: 34,
            height: 34,
            child: Align(
              alignment: Alignment.bottomRight,
              child: Padding(
                padding: const EdgeInsets.all(5),
                child: CustomPaint(size: const Size(14, 14), painter: _CornerPainter(cs.primary)),
              ),
            ),
          ),
        ),
      ),
    );

    return DragTarget<String>(
      onWillAcceptWithDetails: (e) {
        if (e.data != t.id) widget.onHover();
        return e.data != t.id;
      },
      onAcceptWithDetails: (_) {},
      builder: (context, cand, _) => Stack(clipBehavior: Clip.none, children: [drag(overlay), handle]),
    );
  }

  Widget _mini(BuildContext context, IconData icon, VoidCallback onTap, {String? key}) => Padding(
    padding: const EdgeInsets.only(left: 2),
    child: Material(
      color: Theme.of(context).colorScheme.surfaceContainerHighest.withValues(alpha: 0.92),
      shape: const CircleBorder(),
      elevation: 1,
      child: InkWell(
        key: key == null ? null : ValueKey(key),
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(padding: const EdgeInsets.all(5), child: Icon(icon, size: 15)),
      ),
    ),
  );
}

class _CornerPainter extends CustomPainter {
  _CornerPainter(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()
      ..color = color
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;
    for (final f in const [0.35, 0.7, 1.0]) {
      canvas.drawLine(Offset(size.width * (1 - f), size.height), Offset(size.width, size.height * (1 - f)), p);
    }
  }

  @override
  bool shouldRepaint(_CornerPainter o) => o.color != color;
}

/// t144u / t169u: corner-drag result in half-units (w2, h2): 0,5–4 wide, snapping to "Koko leveys"
/// ([fullWidthW2]) when dragged past 4 units or to the row's edge; 0,5–6 tall.
(int, int) snapResize(TileGridMetrics g, TileConfig t, double dx, double dy) {
  final unitW = g.cell + g.gap, unitH = g.cellH + g.gap;
  final raw = ((g.widthOf(t.w2) + dx + g.gap) / unitW * 2).round();
  final nc = raw > 8 || raw >= g.cols * 2 ? fullWidthW2 : raw.clamp(1, 8);
  final nr = ((g.height(t.hUnits) + dy + g.gap) / unitH * 2).round().clamp(1, maxH2).toInt();
  return (nc, nr);
}
