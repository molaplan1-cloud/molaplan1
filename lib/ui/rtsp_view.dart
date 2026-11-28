import 'dart:async';
import 'dart:typed_data';

import '../core/plat.dart';
import '../devices/rtsp_play.dart';
import '../devices/rtsp_probe.dart';
import '../devices/rtsp_still.dart';

import 'package:material_ui/material_ui.dart';
import 'package:media_kit/media_kit.dart';
import 'package:media_kit_video/media_kit_video.dart';

/// RTSP needs the native player (libmpv): Android, Windows, Linux, macOS, iOS. Off in widget tests.
bool rtspSupported =
    !Plat.isFlutterTest && (Plat.isAndroid || Plat.isWindows || Plat.isLinux || Plat.isMacOS || Plat.isIOS);

bool _inited = false;

/// Android: MediaCodec copy-back, then software. Direct `auto-safe` / `mediacodec` needs a Surface
/// that media_kit's vo path does not have at open, and "Could not open codec" would stop playback
/// before the software fallback. Other platforms: any safe copy-back method, then software.
String rtspHwdec() => Plat.isAndroid ? 'mediacodec-copy,no' : 'auto-copy,no';

VideoControllerConfiguration _videoCfg() => VideoControllerConfiguration(hwdec: rtspHwdec());

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
    VideoController(player, configuration: _videoCfg()); // a video output is needed for a frame to be decoded
    final dynamic p = player.platform;
    if (p is NativePlayer) {
      for (final (k, v) in [
        ('rtsp-transport', 'tcp'),
        ('cache', 'no'),
        ('network-timeout', '8'),
        ('hwdec', rtspHwdec()),
      ]) {
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
enum RtspFailKind { unreachable, login, notFound, noVideo, codec }

class RtspFailure {
  const RtspFailure(this.kind, this.status, this.error, this.tech, {this.codec = ''});
  final RtspFailKind kind;

  /// RTSP status of the check (-1 = no answer).
  final int status;

  /// The player's own message (no login in it), may be empty.
  final String error;

  /// Secret-free technical lines.
  final List<String> tech;

  /// Video codec from the DESCRIBE SDP or the player log (e.g. H.265). Empty when unknown.
  final String codec;
}

/// Live RTSP video (muted, low latency, TCP so it passes Wi-Fi reliably).
class RtspView extends StatefulWidget {
  const RtspView({super.key, required this.url, this.fallbackUrl, this.fit = BoxFit.cover, this.onError});
  final String url;

  /// Stored sub-stream (ONVIF profile 2 / settings) tried after a codec failure on [url].
  final String? fallbackUrl;
  final BoxFit fit;
  final void Function(RtspFailure failure)? onError;

  @override
  State<RtspView> createState() => _RtspViewState();
}

class _RtspViewState extends State<RtspView> {
  late final Player _player = Player(
    configuration: const PlayerConfiguration(muted: true, bufferSize: 4 * 1024 * 1024),
  );
  late final VideoController _video = VideoController(_player, configuration: _videoCfg());
  StreamSubscription<String>? _err;
  StreamSubscription<int?>? _w;
  Timer? _watchdog;
  Timer? _codecGrace;
  bool _showing = false;
  RtspPlayTarget? _target;
  bool _closed = false;
  int _try = 0;
  late final List<String> _queue = rtspPlayQueue(widget.url, storedSub: widget.fallbackUrl);
  final _tried = <String>[];
  String _codec = '';

  @override
  void initState() {
    super.initState();
    _open();
  }

  Future<void> _applyPlayerProps() async {
    final dynamic p = _player.platform;
    if (p is! NativePlayer) return;
    for (final (k, v) in [
      ('rtsp-transport', 'tcp'),
      ('profile', 'low-latency'),
      ('cache', 'no'),
      ('network-timeout', '8'),
      ('hwdec', rtspHwdec()),
    ]) {
      try {
        await (p as dynamic).setProperty(k, v);
      } catch (_) {}
    }
  }

  Future<void> _open() async {
    // Check the address and login first: a failure then has a real reason, and a camera that
    // sends no login challenge (Sonoff) gets the login up front through a local relay.
    final url = _queue[_try];
    _tried.add(Uri.tryParse(url)?.path ?? url);
    final t = await rtspPlayTarget(url);
    if (_closed) {
      await t.close();
      return;
    }
    await _target?.close();
    _target = t;
    final pre = t.preflight;
    if (pre.codec.isNotEmpty) _codec = pre.codec;
    if (pre.unreachable || pre.status == 401 || pre.status == 404) {
      // A fallback address that does not answer: try the next one when this was not the first.
      if (_try > 0 && _try + 1 < _queue.length) {
        _try++;
        await _open();
        return;
      }
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
    await _applyPlayerProps();
    _err ??= _player.stream.error.listen(_onPlayerError);
    _log ??= _player.stream.log.listen((l) {
      if (_playerLog.length < 16 && l.level != 'v' && l.level != 'debug') {
        _playerLog.add(_mask('${l.prefix}: ${l.text}'.trim()));
      }
      if (_codec.isEmpty) {
        final c = codecFromPlayerLogs([l.text, l.prefix]);
        if (c.isNotEmpty) _codec = c;
      }
    });
    _w ??= _player.stream.width.listen((w) {
      if ((w ?? 0) > 0 && !_showing && mounted) {
        _codecGrace?.cancel();
        setState(() => _showing = true);
      }
    });
    // No picture in 15 s: report it (wrong address, RTSP off, or away from home).
    _watchdog?.cancel();
    _watchdog = Timer(const Duration(seconds: 15), () {
      if (!_showing) _onTimeout();
    });
    await _player.open(Media(t.playUrl));
  }

  void _onPlayerError(String e) {
    if (_showing || _failed || _closed) return;
    if (isRtspCodecError(e)) {
      // mpv logs this when a hwdec fails, then often opens a software decoder. Wait briefly.
      _codecGrace?.cancel();
      _codecGrace = Timer(const Duration(seconds: 2), () {
        if (!_showing && !_failed && !_closed) unawaited(_tryNext(e, codec: true));
      });
      return;
    }
    unawaited(_tryNext(e));
  }

  void _onTimeout() {
    if (_showing || _failed || _closed) return;
    final codecFail = _codecGrace != null || _playerLog.any((l) => isRtspCodecError(l));
    unawaited(_tryNext('no video within 15 s', codec: codecFail));
  }

  Future<void> _tryNext(String e, {bool codec = false}) async {
    if (_failed || _closed || _showing) return;
    if (codec && _try + 1 < _queue.length) {
      _try++;
      _codecGrace?.cancel();
      _watchdog?.cancel();
      try {
        await _player.stop();
      } catch (_) {}
      await _open();
      return;
    }
    _fail(e, kind: codec ? RtspFailKind.codec : RtspFailKind.noVideo);
  }

  StreamSubscription<PlayerLog>? _log;
  final _playerLog = <String>[];
  static String _mask(String e) => e.replaceAll(RegExp(r'rtsp://[^@\s/]*@'), 'rtsp://');

  void _fail(String e, {RtspFailKind kind = RtspFailKind.noVideo}) {
    if (!mounted || _failed) return;
    _failed = true;
    _watchdog?.cancel();
    _codecGrace?.cancel();
    final pre = _target?.preflight;
    final codec = [
      _codec,
      pre?.codec ?? '',
      codecFromPlayerLogs(_playerLog),
    ].firstWhere((c) => c.isNotEmpty, orElse: () => '');
    widget.onError?.call(
      RtspFailure(kind, pre?.status ?? 0, _mask(e), [
        ...?_target?.tech,
        if (codec.isNotEmpty) 'codec: $codec',
        'player: media_kit/libmpv, TCP transport, hwdec ${rtspHwdec()}',
        if (_tried.length > 1) 'tried paths: ${_tried.join(' then ')}',
        if (e.isNotEmpty) 'player error: ${_mask(e)}',
        ..._playerLog.map((l) => 'player log: $l'),
      ], codec: codec),
    );
  }

  bool _failed = false;

  @override
  void dispose() {
    _closed = true;
    _codecGrace?.cancel();
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
