import 'dart:async';
import 'dart:typed_data';

import 'package:material_ui/material_ui.dart';

import '../core/fields.dart';
import '../devices/rtsp_probe.dart';
import '../devices/rtsp_still.dart';
import '../drivers/camera_driver.dart';
import '../models/models.dart';
import '../core/plat.dart';
import '../state/browser_tile_hide.dart';
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

  @override
  void setState(VoidCallback fn) {
    super.setState(fn);
    _reportHide();
  }

  void _reportHide() {
    if (!Plat.isWeb || !mounted) return;
    final ok = (_frame != null || _rtsp != null) && (_error == null || _error!.isEmpty);
    browserHide.reportCamera(widget.tile.id, error: _error, ok: ok);
  }

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
    final router = AppScope.read(context).remote.router;
    final away = router.preferRemote;
    // t333u: a camera on the home bridge's network must not be opened from this device.
    final viaBridge = d.s['viaBridge'] == true;
    final url = d.rtspUrl(sub: !widget.live, stream: spec.integer('stream', 0));
    // t331ua0: whether this device is "at home" is not decided from the home bridge's state: when
    // this device can reach the camera's RTSP port, the video plays here. The RtspView checks the
    // address first; only when the camera does not answer from here, the still pictures come
    // through the home bridge.
    if (url != null &&
        (mode == 'rtsp' || widget.live) &&
        rtspSupported &&
        !viaBridge &&
        !(away && _skipLocalRtsp(url))) {
      setState(() => _rtsp = url);
      return;
    }
    if (mode == 'rtsp') {
      if (url == null) {
        _plainNote = true;
        setState(
          () => _error = tx(
            context,
            'Kameralle ei ole tallennettu videon osoitetta. Poista kamera ja lisää se uudelleen, tai kirjoita RTSP-osoite käsin.',
            'No video address is stored for this camera. Remove it and add it again, or type the RTSP address by hand.',
          ),
        );
        return;
      }
      if (!rtspSupported) {
        _tech.add('live video: not available on this platform (browser) – stills through the home bridge');
      }
      _startRtspStills(d);
      return;
    }
    _startStill(d);
  }

  /// Cameras that did not answer from this device lately (while the app thinks it is away): their
  /// RTSP port is not tried again for a minute.
  static final _unreachable = <String, DateTime>{};
  bool _skipLocalRtsp(String url) {
    final t = _unreachable[Uri.tryParse(url)?.host ?? ''];
    return t != null && DateTime.now().difference(t) < const Duration(minutes: 1);
  }

  final _tech = <String>[];

  /// Still pictures made from the RTSP stream (this device, or the home bridge when remote).
  void _startRtspStills(CameraDriver d) {
    _sub?.cancel();
    _sub = d
        .rtspStills(stream: widget.tile.read.integer('stream', 0))
        .listen(
          (f) {
            if (mounted) {
              setState(() {
                _frame = f;
                _error = null;
                _plainNote = false;
              });
            }
          },
          onError: (Object e) {
            if (!mounted) return;
            final host = Uri.tryParse(d.rtspUrl(sub: true) ?? '')?.host ?? '';
            final text = e.toString();
            setState(() {
              if (e is RtspStillException && e.status != 0) {
                _plainNote = true;
                _error = _rtspReason(
                  RtspFailure(
                    e.status == -1
                        ? RtspFailKind.unreachable
                        : e.status == 401
                        ? RtspFailKind.login
                        : RtspFailKind.notFound,
                    e.status,
                    '',
                    const [],
                  ),
                  host,
                );
              } else if (text.contains('RTSP still:')) {
                _plainNote = true;
                _error = tx(
                  context,
                  'Still-kuvaa ei saatu tehtyä videovirrasta. Kotisillan tietokoneella tarvitaan ffmpeg tai Molaplan-sovellus kotisiltana.',
                  'A still picture could not be made from the video stream. The home bridge computer needs ffmpeg, or use the Molaplan app as the home bridge.',
                );
              } else {
                _error = text;
              }
            });
            if (_tech.length < 30) {
              if (e is RtspStillException) {
                _tech.addAll(e.tech.where((l) => !_tech.contains(l)));
              }
              _tech.add('still from RTSP: ${_clean(text)}');
            }
          },
        );
  }

  static String _clean(String e) => e.replaceAll(RegExp(r'rtsp://[^@\s/]*@'), 'rtsp://');

  /// The real reason live video did not start, in plain words.
  String _rtspReason(RtspFailure f, String host) {
    switch (f.kind) {
      case RtspFailKind.unreachable:
        return tx(
          context,
          'Kamera ($host) ei vastaa tältä laitteelta. Tarkista, että laite on samassa verkossa kuin kamera ja että kameran RTSP on päällä.',
          'The camera ($host) does not answer from this device. Check that this device is on the same network as the camera and that RTSP is on in the camera.',
        );
      case RtspFailKind.login:
        return tx(
          context,
          'Kamera hylkäsi tunnuksen tai salasanan (RTSP 401). Tarkista ne kameran ONVIF/RTSP-asetuksista.',
          'The camera refused the username or password (RTSP 401). Check them in the camera\'s ONVIF/RTSP settings.',
        );
      case RtspFailKind.notFound:
        return tx(
          context,
          'Kamera ei tunne videon osoitetta (RTSP 404). Lisää kamera uudelleen tai kirjoita RTSP-osoite käsin.',
          'The camera does not know this video address (RTSP 404). Add the camera again or type the RTSP address by hand.',
        );
      case RtspFailKind.codec:
        final copy = rtspUnsupportedCodecCopy(f.codec);
        return tx(context, copy.$1, copy.$2);
      case RtspFailKind.noVideo:
        return f.status == 200
            ? tx(
                context,
                'Kamera vastasi, mutta kuvaa ei saatu toistettua${f.error.isEmpty ? '' : ' (${f.error})'}. Yritä uudelleen; jos vika jatkuu, katso tekniset tiedot.',
                'The camera answered, but the video could not be played${f.error.isEmpty ? '' : ' (${f.error})'}. Try again; if it keeps failing, see the technical details.',
              )
            : tx(
                context,
                'Kamera vastasi RTSP ${f.status}, eikä kuvaa saatu. Tarkista tunnus ja salasana ja että RTSP on päällä.',
                'The camera answered RTSP ${f.status} and no picture came. Check the username and password and that RTSP is on.',
              );
    }
  }

  void _retryNow() {
    _sub?.cancel();
    _sub = null;
    _timer?.cancel();
    _timer = null;
    _retry?.cancel();
    _frame = null;
    _error = null;
    _rtsp = null;
    _tech.clear();
    _start();
  }

  void _showTech() {
    final text = _tech.isEmpty ? '–' : _tech.join('\n');
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx(ctx, 'Tekniset tiedot', 'Technical details')),
        content: SingleChildScrollView(child: SelectableText(text, style: const TextStyle(fontSize: 12))),
        actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx(ctx, 'Sulje', 'Close')))],
      ),
    );
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
            fallbackUrl: _driver?.rtspUrl(sub: true, stream: widget.tile.read.integer('stream', 0)),
            fit: widget.fit,
            onError: (f) {
              if (!mounted) return;
              final spec = widget.tile.read;
              final hasSnap = spec.str('mode', 'mjpeg') != 'rtsp';
              final d = _driver;
              final host = Uri.tryParse(_rtsp ?? '')?.host ?? '';
              _tech
                ..clear()
                ..addAll(f.tech);
              final router = AppScope.read(context).remote.router;
              _tech.add(
                rtspNetworkNote(
                  bridgeConfigured: router.enabled,
                  awayFromBridge: router.preferRemote || router.awayFromBridge,
                  cameraAnsweredHere: f.status == 200,
                ),
              );
              setState(() {
                _rtsp = null;
                if (!hasSnap && f.kind != RtspFailKind.unreachable) {
                  _plainNote = true;
                  _error = _rtspReason(f, host);
                }
              });
              if (f.kind == RtspFailKind.unreachable) {
                _unreachable[host] = DateTime.now();
              }
              if (hasSnap) {
                // Fall back to the still picture / MJPEG (e.g. RTSP switched off on the camera).
                if (d != null) _startStill(d);
              } else if (f.kind == RtspFailKind.unreachable && d != null && router.enabled) {
                // Not reachable from here: stills through the home bridge.
                _startRtspStills(d);
                if (_error == null) setState(() => _plainNote = false);
              } else if (f.kind == RtspFailKind.unreachable) {
                setState(() {
                  _plainNote = true;
                  _error = _rtspReason(f, host);
                });
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
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    _plainNote ? _error! : friendlyText(context, _error!),
                    maxLines: _plainNote ? 4 : 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontSize: 11),
                  ),
                  if (_tech.isNotEmpty || widget.tile.read.str('mode', 'mjpeg') == 'rtsp')
                    Wrap(
                      spacing: 4,
                      children: [
                        if (_driver != null)
                          TextButton(
                            key: const ValueKey('cam-retry'),
                            style: _smallButton,
                            onPressed: _retryNow,
                            child: Text(tx(context, 'Yritä uudelleen', 'Try again')),
                          ),
                        if (_tech.isNotEmpty)
                          TextButton(
                            key: const ValueKey('cam-tech'),
                            style: _smallButton,
                            onPressed: _showTech,
                            child: Text(tx(context, 'Tekniset tiedot', 'Technical details')),
                          ),
                      ],
                    ),
                ],
              ),
            ),
          ),
      ],
    );
  }
}

const _smallButton = ButtonStyle(
  visualDensity: VisualDensity.compact,
  padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: 6)),
  minimumSize: WidgetStatePropertyAll(Size(0, 24)),
  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
  textStyle: WidgetStatePropertyAll(TextStyle(fontSize: 11)),
);

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
