import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../drivers/camera_driver.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'camera_view.dart' show friendlyPtzError;

/// R554: pan / tilt / zoom buttons for a camera whose ONVIF profile has PTZ. Hold = move, release
/// = stop (ONVIF ContinuousMove / Stop). Only shown where the camera answered with a PTZ service
/// when it was added. Not tested on a device.
class PtzPad extends StatelessWidget {
  const PtzPad({super.key, required this.tile});
  final TileConfig tile;

  /// True when the tile's camera has PTZ and is reachable directly from this device.
  static bool available(BuildContext context, TileConfig tile) {
    if (tile.read['ptz'] != true) return false;
    final d = AppScope.read(context).driverFor(tile.connectionId);
    return d is CameraDriver && d.ptzToken(stream: tile.read.integer('stream', 0)) != null;
  }

  @override
  Widget build(BuildContext context) {
    final d = AppScope.read(context).driverFor(tile.connectionId);
    if (d is! CameraDriver) return const SizedBox.shrink();
    final stream = tile.read.integer('stream', 0);

    Future<void> run(Future<void> Function() f) async {
      try {
        await f();
      } catch (e) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(friendlyPtzError(context, e))));
        }
      }
    }

    Widget btn(String key, IconData icon, String tip, {double pan = 0, double tilt = 0, double zoom = 0}) => Listener(
      onPointerDown: (_) => run(() => d.ptzMove(pan: pan, tilt: tilt, zoom: zoom, stream: stream)),
      onPointerUp: (_) => run(() => d.ptzStop(stream: stream)),
      onPointerCancel: (_) => run(() => d.ptzStop(stream: stream)),
      child: Tooltip(
        message: tip,
        child: Container(
          key: ValueKey(key),
          width: 52,
          height: 52,
          margin: const EdgeInsets.all(3),
          decoration: BoxDecoration(color: Colors.black54, borderRadius: BorderRadius.circular(26)),
          child: Icon(icon, color: Colors.white, size: 28),
        ),
      ),
    );

    const s = 0.5;
    return Positioned(
      right: 12,
      bottom: 12,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn('ptz-zoom-in', Icons.zoom_in, tx(context, 'Lähennä', 'Zoom in'), zoom: s),
              btn('ptz-zoom-out', Icons.zoom_out, tx(context, 'Loitonna', 'Zoom out'), zoom: -s),
            ],
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              btn('ptz-up', Icons.keyboard_arrow_up, tx(context, 'Ylös', 'Up'), tilt: s),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  btn('ptz-left', Icons.keyboard_arrow_left, tx(context, 'Vasemmalle', 'Left'), pan: -s),
                  const SizedBox(width: 52, height: 52),
                  btn('ptz-right', Icons.keyboard_arrow_right, tx(context, 'Oikealle', 'Right'), pan: s),
                ],
              ),
              btn('ptz-down', Icons.keyboard_arrow_down, tx(context, 'Alas', 'Down'), tilt: -s),
            ],
          ),
        ],
      ),
    );
  }
}
