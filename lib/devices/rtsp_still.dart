/// A still picture (JPEG) from an RTSP stream (t331ua0): for cameras with no snapshot address, so
/// a preview works remotely and on the home bridge. Done where the stream can be reached – this
/// device or the home bridge: the app registers a media_kit grabber, anything else (the headless
/// bridge, a PC) uses `ffmpeg` when it is installed.
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import '../core/plat.dart';
import '../drivers/driver.dart';
import 'rtsp_play.dart';

/// Grabs one JPEG from [playUrl]; returns null when this grabber cannot (try the next one).
typedef RtspStillGrabber = Future<Uint8List?> Function(String playUrl, Duration timeout);

/// A still could not be made; [status] is the RTSP status of the check (-1 = no answer, 0 = other).
class RtspStillException extends DriverException {
  RtspStillException(super.message, {this.status = 0, this.tech = const []});
  final int status;

  /// Secret-free technical lines of the check.
  final List<String> tech;
}

class RtspStill {
  /// Grabbers added by the app (the video player). Tried first, then [ffmpegGrabber].
  static final grabbers = <RtspStillGrabber>[];

  /// Test hook: replaces ffmpeg.
  static RtspStillGrabber? ffmpegOverride;

  static Future<Uint8List> grab(String url, {Duration timeout = const Duration(seconds: 20)}) async {
    if (Plat.isWeb) throw DriverException('RTSP still: a browser cannot reach the camera');
    final t = await rtspPlayTarget(url);
    try {
      final p = t.preflight;
      if (p.unreachable) {
        throw RtspStillException('RTSP still: the camera does not answer (${p.error})', status: -1, tech: t.tech);
      }
      if (p.status == 401) {
        throw RtspStillException('RTSP still: the camera refused the login (RTSP 401)', status: 401, tech: t.tech);
      }
      if (p.status == 404) {
        throw RtspStillException(
          'RTSP still: the camera does not know this video address (RTSP 404)',
          status: 404,
          tech: t.tech,
        );
      }
      final why = <String>[];
      for (final g in [...grabbers, ffmpegOverride ?? ffmpegGrabber]) {
        try {
          final b = await g(t.playUrl, timeout);
          if (b != null && b.isNotEmpty) return b;
        } catch (e) {
          why.add(_clean('$e'));
        }
      }
      throw DriverException(
        'RTSP still: no picture could be made from the stream'
        '${why.isEmpty ? ' (no video decoder available: install ffmpeg on the home bridge computer or use the Molaplan app as the home bridge)' : ' (${why.join('; ')})'}',
      );
    } finally {
      await t.close();
    }
  }

  /// `ffmpeg` on the PATH: one frame as JPEG on stdout.
  static Future<Uint8List?> ffmpegGrabber(String playUrl, Duration timeout) async {
    Process p;
    try {
      p = await Process.start('ffmpeg', [
        '-v', 'error', '-nostdin', '-rtsp_transport', 'tcp', '-i', playUrl,
        '-frames:v', '1', '-q:v', '5', '-f', 'image2pipe', '-vcodec', 'mjpeg', 'pipe:1', //
      ]);
    } on ProcessException {
      return null; // not installed
    }
    final out = BytesBuilder(copy: false);
    final err = StringBuffer();
    p.stdout.listen(out.add);
    p.stderr.transform(utf8.decoder).listen(err.write);
    final code = await p.exitCode.timeout(
      timeout,
      onTimeout: () {
        p.kill();
        return -1;
      },
    );
    if (code != 0 || out.length == 0) throw 'ffmpeg exit $code ${_clean(err.toString()).trim()}';
    return out.takeBytes();
  }

  static String _clean(String s) => s.replaceAll(RegExp(r'rtsp://[^@\s/]*@'), 'rtsp://');
}
