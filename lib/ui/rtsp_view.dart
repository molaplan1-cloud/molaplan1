import 'dart:async';
import 'dart:io';

import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// RTSP needs the native player (libmpv): Android, Windows, Linux, macOS, iOS. Off in widget tests.
bool rtspSupported =
    !Platform.environment.containsKey('FLUTTER_TEST') &&
    (Platform.isAndroid || Platform.isWindows || Platform.isLinux || Platform.isMacOS || Platform.isIOS);

bool _inited = false;

void initVideo() {
  if (!rtspSupported || _inited) return;
  try {
    MediaKit.ensureInitialized();
    _inited = true;
  } catch (_) {
    rtspSupported = false;
  }
}

/// Live RTSP video (muted, low latency, TCP so it passes Wi-Fi reliably).
class RtspView extends StatefulWidget {
  const RtspView({super.key, required this.url, this.fit = BoxFit.cover, this.onError});
  final String url;
  final BoxFit fit;
  final void Function(String error)? onError;

  @override
  State<RtspView> createState() => _RtspViewState();
}

class _RtspViewState extends State<RtspView> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(muted: true, bufferSize: 4 * 1024 * 1024),
  );
  late final VideoController _video = VideoController(_player);
  StreamSubscription<String>? _err;
  StreamSubscription<int?>? _w;
  Timer? _watchdog;
  bool _showing = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    final p = _player.platform;
    if (p is NativePlayer) {
      for (final (k, v) in const [
        ('rtsp-transport', 'tcp'),
        ('profile', 'low-latency'),
        ('cache', 'no'),
        ('network-timeout', '8'),
      ]) {
        try {
          await p.setProperty(k, v);
        } catch (_) {}
      }
    }
    _err = _player.stream.error.listen((e) => _fail(e));
    _w = _player.stream.width.listen((w) {
      if ((w ?? 0) > 0 && !_showing && mounted) setState(() => _showing = true);
    });
    // No picture in 15 s: report it (wrong address, RTSP off, or away from home).
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!_showing) _fail('RTSP: no video (timeout)');
    });
    await _player.open(Media(widget.url));
  }

  void _fail(String e) {
    if (!mounted) return;
    _watchdog?.cancel();
    widget.onError?.call(e.replaceAll(RegExp(r'rtsp://[^@\s]*@'), 'rtsp://'));
  }

  @override
  void dispose() {
    _watchdog?.cancel();
    _err?.cancel();
    _w?.cancel();
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Stack(
    fit: StackFit.expand,
    children: [
      Video(controller: _video, fit: widget.fit, controls: NoVideoControls),
      if (!_showing) const Center(child: CircularProgressIndicator(strokeWidth: 2)),
    ],
  );
}
