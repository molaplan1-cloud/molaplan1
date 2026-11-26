/// One "+ Lisää" for everything (t129u): the FAB, the dashed '+' tile at the end of the grid and the
/// app-bar '+' (desktop) all open this sheet with two clear choices – a device (the wizard with the
/// network scan) or a service tile (price, weather, camera, gauge, ntfy/command).
library;

import '../core/plat.dart';

import 'package:material_ui/material_ui.dart';

import '../devices/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart';
import 'add_device_wizard.dart';
import 'app_scope.dart';
import 'automation_pages.dart';
import 'connections_page.dart';
import 'template_gallery.dart';
import 'tile_editor.dart';
import 'weather_tile.dart';

/// Desktop gets a '+' in the app bar as well.
bool showAppBarAdd(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 900 || Plat.isWindows || Plat.isLinux || Plat.isMacOS;

Future<void> showAddSheet(BuildContext context, {Dashboard? dashboard}) async {
  final d = dashboard ?? AppScope.read(context).config.dashboards.first;
  final pick = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tx(c, 'Mitä lisätään?', 'What do you want to add?'), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            _Choice(
              key: const ValueKey('add-choice-device'),
              icon: Icons.devices_other,
              title: tx(c, 'Laite', 'Device'),
              desc: tx(
                c,
                'Shelly, Sonoff, Hue, kamera, lämpöpumppu… Etsii kotiverkosta automaattisesti.',
                'Shelly, Sonoff, Hue, camera, heat pump… Searches your home network automatically.',
              ),
              onTap: () => Navigator.pop(c, 'device'),
            ),
            const SizedBox(height: 10),
            _Choice(
              key: const ValueKey('add-choice-tile'),
              icon: Icons.dashboard_customize_outlined,
              title: tx(c, 'Ruutu', 'Tile'),
              desc: tx(
                c,
                'Sähkön hinta, sää, kamera, mittari, ilmoitus tai komento – ei vaadi uutta laitetta.',
                'Electricity price, weather, camera, gauge, notification or command – no new device needed.',
              ),
              onTap: () => Navigator.pop(c, 'tile'),
            ),
            const SizedBox(height: 10),
            _Choice(
              key: const ValueKey('add-choice-automation'),
              icon: Icons.auto_mode,
              title: tx(c, 'Luo automaatio', 'Create automation'),
              desc: tx(
                c,
                'Kun… jos… tee: valot auringonlaskussa, ilmoitus vuodosta, halvimmat tunnit, skriptit ja tilannekuvat.',
                'When… if… do: lights at sunset, a leak alert, the cheapest hours, scripts and scenes.',
              ),
              onTap: () => Navigator.pop(c, 'automation'),
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || pick == null) return;
  if (pick == 'device') {
    await ConnectionsPage.addNew(context, dashboard: d);
  } else if (pick == 'automation') {
    await showAutomationStart(context, dashboard: d);
  } else {
    await showServiceTileSheet(context, d);
  }
}

class _ServiceTile {
  const _ServiceTile(this.id, this.icon, this.color, this.fi, this.en, this.descFi, this.descEn);
  final String id;
  final IconData icon;
  final Color color;
  final String fi, en, descFi, descEn;
}

const _serviceTiles = [
  _ServiceTile(
    'price',
    Icons.bolt,
    Color(0xFFC2A15A),
    'Sähkön hinta',
    'Electricity price',
    'Pörssihinta nyt ja tunneittain, halvimmat tunnit.',
    'Spot price now and hourly, the cheapest hours.',
  ),
  _ServiceTile(
    'weather',
    Icons.wb_sunny_outlined,
    Color(0xFF7FA8D8),
    'Sää',
    'Weather',
    'Lämpötila, sade ja tuuli kotisi sijainnista.',
    'Temperature, rain and wind at your home.',
  ),
  _ServiceTile(
    'camera',
    Icons.videocam_outlined,
    Color(0xFF8E9AAF),
    'Kamera',
    'Camera',
    'Valvontakamera (ONVIF/RTSP) tai ESP32-CAM.',
    'Security camera (ONVIF/RTSP) or ESP32-CAM.',
  ),
  _ServiceTile(
    'gauge',
    Icons.speed,
    Color(0xFF5E9E7C),
    'Mittari',
    'Gauge',
    'Teho, lämpötila tai muu lukema mittarina ja trendinä.',
    'Power, temperature or another reading as a gauge and trend.',
  ),
  _ServiceTile(
    'ntfy',
    Icons.notifications_active_outlined,
    Color(0xFFBF6F68),
    'Ilmoitus tai komento',
    'Notification or command',
    'ntfy-ilmoitus puhelimeen tai oma HTTP-komento.',
    'ntfy push to a phone or your own HTTP command.',
  ),
  _ServiceTile(
    'ntfy_device',
    Icons.settings_remote_outlined,
    Color(0xFF26A69A),
    'ntfy-komentolaite',
    'ntfy command device',
    'Laite, jota ohjataan ntfy-viesteillä (esim. valvontapaneeli): kytkimet, tila ja PIN.',
    'A device controlled with ntfy messages (e.g. a security panel): switches, state and PIN.',
  ),
];

Future<void> showServiceTileSheet(BuildContext context, Dashboard d) async {
  final id = await showModalBottomSheet<String>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (c) => SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(tx(c, 'Lisää ruutu', 'Add a tile'), style: Theme.of(c).textTheme.titleLarge),
            const SizedBox(height: 12),
            LayoutBuilder(
              builder: (c, box) {
                final cols = box.maxWidth >= 560 ? 3 : 2;
                final w = (box.maxWidth - 10 * (cols - 1)) / cols;
                return Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    for (final s in _serviceTiles)
                      SizedBox(
                        width: w,
                        child: _Preview(key: ValueKey('add-tile-${s.id}'), s: s, onTap: () => Navigator.pop(c, s.id)),
                      ),
                  ],
                );
              },
            ),
          ],
        ),
      ),
    ),
  );
  if (!context.mounted || id == null) return;
  Future<void> template(String tid) async {
    final t = deviceTemplates.where((t) => t.id == tid).firstOrNull;
    if (t == null) return;
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => TemplateSetupPage(template: t, dashboard: d),
      ),
    );
  }

  switch (id) {
    case 'price':
      await template('electricity_price');
    case 'weather':
      await addWeatherTile(context, d);
    case 'camera':
      final p = providerById('camera_onvif');
      if (p != null) {
        await Navigator.push<bool>(
          context,
          MaterialPageRoute(
            builder: (_) => AddDeviceWizard(provider: p, dashboard: d),
          ),
        );
      }
    case 'gauge':
      final st = AppScope.read(context);
      final conn = st.config.connections.where((c) => c.type != 'price').firstOrNull;
      if (conn == null) {
        // Nothing to measure yet: a device first.
        await ConnectionsPage.addNew(context, dashboard: d);
        return;
      }
      await Navigator.push<bool>(
        context,
        MaterialPageRoute(
          builder: (_) => TileEditor(
            dashboard: d,
            isNew: true,
            initial: TileConfig(
              type: TileType.value,
              title: tx(context, 'Mittari', 'Gauge'),
              icon: 'speed',
              connectionId: conn.id,
              unit: 'W',
              display: 'gauge_trend',
            ),
          ),
        ),
      );
    case 'ntfy':
      await template('ntfy');
    case 'ntfy_device':
      await template('ntfy_device');
  }
}

class _Choice extends StatelessWidget {
  const _Choice({super.key, required this.icon, required this.title, required this.desc, required this.onTap});
  final IconData icon;
  final String title, desc;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: cs.primaryContainer,
                child: Icon(icon, size: 28, color: cs.onPrimaryContainer),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: Theme.of(context).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(desc, style: Theme.of(context).textTheme.bodySmall),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

/// A small mock of the tile with its icon and a hint of what it shows.
class _Preview extends StatelessWidget {
  const _Preview({super.key, required this.s, required this.onTap});
  final _ServiceTile s;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    final fi = AppScope.of(context).lang == 'fi';
    return Material(
      color: cs.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                height: 44,
                child: CustomPaint(painter: _PreviewPainter(s.id, s.color, cs), child: const SizedBox.expand()),
              ),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(s.icon, size: 18, color: s.color),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text(
                      tx(context, s.fi, s.en),
                      style: Theme.of(context).textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Text(
                fi ? s.descFi : tx(context, s.descFi, s.descEn),
                maxLines: 3,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PreviewPainter extends CustomPainter {
  _PreviewPainter(this.id, this.color, this.cs);
  final String id;
  final Color color;
  final ColorScheme cs;

  @override
  void paint(Canvas canvas, Size size) {
    final p = Paint()..color = color.withValues(alpha: 0.85);
    switch (id) {
      case 'price':
        const v = [0.3, 0.25, 0.4, 0.7, 0.9, 0.6, 0.45, 0.35, 0.5, 0.8, 0.65, 0.4];
        final w = size.width / v.length;
        for (var i = 0; i < v.length; i++) {
          canvas.drawRRect(
            RRect.fromRectAndCorners(
              Rect.fromLTWH(i * w + 1, size.height * (1 - v[i]), w - 2, size.height * v[i]),
              topLeft: const Radius.circular(2),
              topRight: const Radius.circular(2),
            ),
            p,
          );
        }
      case 'gauge':
        final r = Rect.fromCircle(center: Offset(size.width / 2, size.height), radius: size.height * 0.9);
        final bg = Paint()
          ..color = cs.onSurfaceVariant.withValues(alpha: 0.2)
          ..style = PaintingStyle.stroke
          ..strokeWidth = 6
          ..strokeCap = StrokeCap.round;
        canvas.drawArc(r, 3.3, 2.8, false, bg);
        canvas.drawArc(r, 3.3, 1.8, false, bg..color = color);
      case 'weather':
        final path = Path()..moveTo(0, size.height * 0.7);
        for (var x = 0.0; x <= size.width; x += 4) {
          path.lineTo(x, size.height * (0.55 - 0.25 * (x / size.width - 0.5) * (x / size.width - 0.5) * 4 + 0.1));
        }
        canvas.drawPath(
          path,
          Paint()
            ..color = color
            ..style = PaintingStyle.stroke
            ..strokeWidth = 2,
        );
        canvas.drawCircle(Offset(size.width * 0.82, size.height * 0.3), 8, p);
      default:
        canvas.drawRRect(
          RRect.fromRectAndRadius(Offset.zero & size, const Radius.circular(8)),
          Paint()..color = color.withValues(alpha: 0.18),
        );
    }
  }

  @override
  bool shouldRepaint(_PreviewPainter o) => o.id != id;
}

/// Dashed '+' placeholder at the end of the grid.
class AddPlaceholderTile extends StatelessWidget {
  const AddPlaceholderTile({super.key, required this.onTap});
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Semantics(
      button: true,
      label: tx(context, 'Lisää', 'Add'),
      child: InkWell(
        borderRadius: BorderRadius.circular(20),
        onTap: onTap,
        child: CustomPaint(
          painter: _Dashed(cs.onSurfaceVariant.withValues(alpha: 0.45)),
          child: Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.add, size: 30, color: cs.onSurfaceVariant),
                const SizedBox(height: 2),
                Text(tx(context, 'Lisää', 'Add'), style: TextStyle(color: cs.onSurfaceVariant)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _Dashed extends CustomPainter {
  _Dashed(this.color);
  final Color color;
  @override
  void paint(Canvas canvas, Size size) {
    final path = Path()..addRRect(RRect.fromRectAndRadius((Offset.zero & size).deflate(1), const Radius.circular(20)));
    final p = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.6;
    for (final m in path.computeMetrics()) {
      for (var d = 0.0; d < m.length; d += 12) {
        canvas.drawPath(m.extractPath(d, d + 6), p);
      }
    }
  }

  @override
  bool shouldRepaint(_Dashed o) => o.color != color;
}
