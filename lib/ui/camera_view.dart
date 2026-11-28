import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../drivers/camera_driver.dart';
import '../models/models.dart';
import 'app_scope.dart';
import 'error_box.dart';
import 'ptz_pad.dart';
import 'rtsp_view.dart';

/// Shows an MJPEG stream, a periodically refreshed snapshot, or live RTSP video.
/// RTSP plays only on the home network; away from home the picture comes as
/// throttled snapshots through the relay (or a clear note when the camera has none).
class CameraView extends StatefulWidget {
  const CameraView({super.key, required this.tile, this.fit = BoxFit.cover, this.live = false});
  final TileConfig tile;
  final BoxFit fit;

  /// Full screen: prefer the full-quality live RTSP stream when there is one.
  final bool live;

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
  String? _rtsp;

  /// A plain note for the user (shown as is, not as an error to translate).
  bool _plainNote = false;

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
    _plainNote = false;
    final d = _driver;
    if (d == null && AppScope.read(context).connection(widget.tile.connectionId)?.settings['demo'] == true) {
      _plainNote = true;
      setState(
        () => _error = tx(
          context,
          'Esimerkkikamera – lisää oma kamerasi Lisää laite -painikkeella',
          'Example camera – add your own with Add device',
        ),
      );
      return;
    }
    if (d == null) {
      _plainNote = true;
      setState(() => _error = tx(context, 'Valitse kamerayhteys', 'Choose a camera connection'));
      return;
    }
    final spec = widget.tile.read;
    final mode = spec.str('mode', 'mjpeg');
    final away = AppScope.read(context).remote.router.preferRemote;
    final url = d.rtspUrl(sub: !widget.live, stream: spec.integer('stream', 0));
    if (url != null && (mode == 'rtsp' || widget.live) && rtspSupported && !away) {
      setState(() => _rtsp = url);
      return;
    }
    if (mode == 'rtsp') {
      _plainNote = true;
      setState(
        () => _error = !rtspSupported
            ? tx(context, 'Live-video ei toimi tällä laitteella', 'Live video does not work on this device')
            : tx(
                context,
                'Live-video näkyy vain kotiverkossa. Tällä kameralla ei ole still-kuvaa etäkäyttöön.',
                'Live video shows only on the home network. This camera has no still picture for remote use.',
              ),
      );
      return;
    }
    _startStill(d);
  }

  void _startStill(CameraDriver d) {
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
        if (_rtsp != null)
          RtspView(
            key: ValueKey(_rtsp),
            url: _rtsp!,
            fit: widget.fit,
            onError: (e) {
              if (!mounted) return;
              final hasSnap = widget.tile.read.str('mode', 'mjpeg') != 'rtsp';
              setState(() {
                _rtsp = null;
                if (!hasSnap) {
                  _plainNote = true;
                  _error = tx(
                    context,
                    'Live-videota ei saatu. Tarkista, että olet kotiverkossa ja kameran RTSP on päällä.',
                    'No live video. Check that you are on the home network and RTSP is on in the camera.',
                  );
                }
              });
              // Fall back to the still picture / MJPEG (e.g. RTSP switched off on the camera).
              if (hasSnap) {
                final d = _driver;
                if (d != null) _startStill(d);
              }
            },
          ),
        if (_frame != null)
          Image.memory(_frame!, fit: widget.fit, gaplessPlayback: true, errorBuilder: (_, _, _) => const SizedBox()),
        if (_frame == null && _error == null && _rtsp == null)
          const Center(child: CircularProgressIndicator(strokeWidth: 2)),
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
              child: Text(
                _plainNote ? _error! : friendlyText(context, _error!),
                maxLines: _plainNote ? 4 : 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontSize: 11),
              ),
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
    body: Stack(
      fit: StackFit.expand,
      children: [
        InteractiveViewer(
          maxScale: 5,
          child: CameraView(tile: tile, fit: BoxFit.contain, live: true),
        ),
        // R554: PTZ buttons when the camera's ONVIF profile has pan / tilt / zoom.
        if (PtzPad.available(context, tile)) PtzPad(tile: tile),
      ],
    ),
  );
}

/// A short, plain text for a failed PTZ command.
String friendlyPtzError(BuildContext context, Object e) => tx(
  context,
  'PTZ-ohjaus ei onnistunut (${e.toString().replaceFirst('DriverException: ', '')}). Tarkista, että olet kotiverkossa.',
  'PTZ command failed (${e.toString().replaceFirst('DriverException: ', '')}). Check that you are on the home network.',
);
