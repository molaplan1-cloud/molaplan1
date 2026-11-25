import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../drivers/camera_driver.dart';
import '../models/models.dart';
import 'app_scope.dart';

/// Shows an MJPEG stream or periodically refreshed snapshot.
class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.tile, this.fit = BoxFit.cover});
  final TileConfig tile;
  final BoxFit fit;

  @override
  State<CameraView> createState() => _CameraViewState();
}

class _CameraViewState extends State<CameraView> {
  Uint8List? _frame;
  String? _error;
  StreamSubscription? _sub;
  Timer? _timer;
  Timer? _retry;
  bool _started = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_started) {
      _started = true;
      _start();
    }
  }

  CameraDriver? get _driver {
    final d = AppScope.read(context).driverFor(widget.tile.connectionId);
    return d is CameraDriver ? d : null;
  }

  void _start() {
    final d = _driver;
    if (d == null) {
      setState(() => _error = tx(context, 'Valitse kamerayhteys', 'Choose a camera connection'));
      return;
    }
    final spec = widget.tile.read;
    if (spec.str('mode', 'mjpeg') == 'snapshot') {
      _snap(d);
      _timer = Timer.periodic(Duration(seconds: spec.integer('refreshSeconds', 2).clamp(1, 3600)), (_) => _snap(d));
    } else {
      _sub = d
          .mjpeg(spec.str('path'))
          .listen(
            (f) {
              if (mounted) {
                setState(() {
                  _frame = f;
                  _error = null;
                });
              }
            },
            onError: (Object e) => _fail(e),
            onDone: () => _fail(mounted ? tx(context, 'Virta päättyi', 'Stream ended') : 'ended'),
          );
    }
  }

  void _fail(Object e) {
    if (!mounted) return;
    setState(() => _error = e.toString());
    _sub?.cancel();
    _sub = null;
    _retry?.cancel();
    _retry = Timer(const Duration(seconds: 5), () {
      if (mounted && _timer == null) _start();
    });
  }

  Future<void> _snap(CameraDriver d) async {
    try {
      final f = await d.snapshot(widget.tile.read.str('path'));
      if (mounted) {
        setState(() {
          _frame = f;
          _error = null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = e.toString());
    }
  }

  @override
  void dispose() {
    _sub?.cancel();
    _timer?.cancel();
    _retry?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return Stack(
      fit: StackFit.expand,
      children: [
        Container(color: Colors.black),
        if (_frame != null)
          Image.memory(_frame!, fit: widget.fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
        if (_frame == null && _error == null) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
        if (_error != null)
          Positioned(
            left: 8,
            right: 8,
            bottom: 8,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: cs.errorContainer.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(_error!, maxLines: 2, overflow: TextOverflow.ellipsis, style: const TextStyle(fontSize: 11)),
            ),
          ),
      ],
    );
  }
}

class CameraFullscreen extends StatelessWidget {
  const CameraFullscreen({super.key, required this.tile});
  final TileConfig tile;
  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(backgroundColor: Colors.black, title: Text(tile.title)),
    body: InteractiveViewer(
      maxScale: 5,
      child: CameraView(tile: tile, fit: BoxFit.contain),
    ),
  );
}
