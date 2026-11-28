import 'dart:async';
import 'dart:typed_data';

import '../core/plat.dart';
import '../devices/rtsp_play.dart';
import '../devices/rtsp_still.dart';

import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// RTSP needs the native player (libmpv): Android, Windows, Linux, macOS, iOS. Off in widget tests.
bool rtspSupported =
    !Plat.isFlutterTest && (Plat.isAndroid || Plat.isWindows || Plat.isLinux || Plat.isMacOS || Plat.isIOS);

bool _inited = false;

void initVideo() {
  if (!rtspSupported || _inited) return;
  try {
    MediaKit.ensureInitialized();
    _inited = true;
    RtspStill.grabbers.add(_mediaKitGrab);
  } catch (_) {
    rtspSupported = false;
  }
}

/// One JPEG from an RTSP address with the app's own player (also on the home bridge).
Future<Uint8List?> _mediaKitGrab(String url, Duration timeout) async {
  if (!rtspSupported) return null;
  final player = Player(configuration: const PlayerConfiguration(muted: true, bufferSize: 2 * 1024 * 1024));
  try {
    VideoController(player); // a video output is needed for a frame to be decoded
    final dynamic p = player.platform;
    if (p is NativePlayer) {
      for (final (k, v) in const [('rtsp-transport', 'tcp'), ('cache', 'no'), ('network-timeout', '8')]) {
        try {
          await (p as dynamic).setProperty(k, v);
        } catch (_) {}
      }
    }
    final got = Completer<void>();
    final sub = player.stream.width.listen((w) {
      if ((w ?? 0) > 0 && !got.isCompleted) got.complete();
    });
    await player.open(Media(url));
    try {
      await got.future.timeout(timeout);
    } finally {
      await sub.cancel();
    }
    await Future<void>.delayed(const Duration(milliseconds: 400));
    return await player.screenshot(format: 'image/jpeg');
  } finally {
    await player.dispose();
  }
}

/// Why live video did not start.
enum RtspFailKind { unreachable, login, notFound, noVideo }

class RtspFailure {
  const RtspFailure(this.kind, this.status, this.error, this.tech);
  final RtspFailKind kind;

  /// RTSP status of the check (-1 = no answer).
  final int status;

  /// The player's own message (no login in it), may be empty.
  final String error;

  /// Secret-free technical lines.
  final List<String> tech;
}

/// Live RTSP video (muted, low latency, TCP so it passes Wi-Fi reliably).
class RtspView extends StatefulWidget {
  const RtspView({super.key, required this.url, this.fit = BoxFit.cover, this.onError});
  final String url;
  final BoxFit fit;
  final void Function(RtspFailure failure)? onError;

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
  RtspPlayTarget? _target;
  bool _closed = false;

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _open() async {
    // Check the address and login first: a failure then has a real reason, and a camera that
    // sends no login challenge (Sonoff) gets the login up front through a local relay.
    final t = await rtspPlayTarget(widget.url);
    if (_closed) {
      await t.close();
      return;
    }
    _target = t;
    final pre = t.preflight;
    if (pre.unreachable || pre.status == 401 || pre.status == 404) {
      _fail(
        '',
        kind: pre.unreachable
            ? RtspFailKind.unreachable
            : pre.status == 401
            ? RtspFailKind.login
            : RtspFailKind.notFound,
      );
      return;
    }
    final dynamic p = _player.platform;
    if (p is NativePlayer) {
      for (final (k, v) in const [
        ('rtsp-transport', 'tcp'),
        ('profile', 'low-latency'),
        ('cache', 'no'),
        ('network-timeout', '8'),
      ]) {
        try {
          await (p as dynamic).setProperty(k, v);
        } catch (_) {}
      }
    }
    _err = _player.stream.error.listen((e) => _fail(e));
    _log = _player.stream.log.listen((l) {
      if (_playerLog.length < 12 && l.level != 'v' && l.level != 'debug') {
        _playerLog.add(_mask('${l.prefix}: ${l.text}'.trim()));
      }
    });
    _w = _player.stream.width.listen((w) {
      if ((w ?? 0) > 0 && !_showing && mounted) setState(() => _showing = true);
    });
    // No picture in 15 s: report it (wrong address, RTSP off, or away from home).
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!_showing) _fail('no video within 15 s');
    });
    await _player.open(Media(t.playUrl));
  }

  StreamSubscription<PlayerLog>? _log;
  final _playerLog = <String>[];
  static String _mask(String e) => e.replaceAll(RegExp(r'rtsp://[^@\s/]*@'), 'rtsp://');

  void _fail(String e, {RtspFailKind kind = RtspFailKind.noVideo}) {
    if (!mounted || _failed) return;
    _failed = true;
    _watchdog?.cancel();
    final pre = _target?.preflight;
    widget.onError?.call(
      RtspFailure(kind, pre?.status ?? 0, _mask(e), [
        ...?_target?.tech,
        'player: media_kit/libmpv, TCP transport',
        if (e.isNotEmpty) 'player error: ${_mask(e)}',
        ..._playerLog.map((l) => 'player log: $l'),
      ]),
    );
  }

  bool _failed = false;

  @override
  void dispose() {
    _closed = true;
    _log?.cancel();
    _target?.close();
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
