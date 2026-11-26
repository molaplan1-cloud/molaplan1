/// Common RTSP addresses per camera brand (t153u): tried one by one when ONVIF does not tell
/// the stream address, and offered as presets for typing an address by hand.
library;

import 'dart:async';

/// One brand's address scheme. [main]/[sub] are paths (with an optional ":port" in front);
/// [second]/[secondSub] are the second lens / channel when the camera has one.
class RtspPattern {
  const RtspPattern(this.brand, this.name, this.main, {this.sub, this.second, this.secondSub});
  final String brand;
  final String name;
  final String main;
  final String? sub;
  final String? second;
  final String? secondSub;

  int get port {
    final m = RegExp(r'^:(\d+)').firstMatch(main);
    return m == null ? 554 : int.parse(m.group(1)!);
  }

  static String _url(String p) => p.startsWith(':') ? 'rtsp://{{host}}$p' : 'rtsp://{{host}}:554$p';

  /// rtsp://{{host}}:554/… (the camera settings' template form).
  String get mainUrl => _url(main);
  String? get subUrl => sub == null ? null : _url(sub!);
  String? get secondUrl => second == null ? null : _url(second!);
  String? get secondSubUrl => secondSub == null ? null : _url(secondSub!);
}

const rtspPatterns = <RtspPattern>[
  RtspPattern(
    'sonoff',
    'Sonoff (CAM Slim, Dual, GK-200MP2)',
    '/av_stream/ch0',
    sub: '/av_stream/ch1',
    second: '/av_stream/ch1',
  ),
  RtspPattern(
    'hikvision',
    'Hikvision / Annke',
    '/Streaming/Channels/101',
    sub: '/Streaming/Channels/102',
    second: '/Streaming/Channels/201',
    secondSub: '/Streaming/Channels/202',
  ),
  RtspPattern(
    'dahua',
    'Dahua / Imou / Amcrest / Lorex',
    '/cam/realmonitor?channel=1&subtype=0',
    sub: '/cam/realmonitor?channel=1&subtype=1',
    second: '/cam/realmonitor?channel=2&subtype=0',
    secondSub: '/cam/realmonitor?channel=2&subtype=1',
  ),
  RtspPattern(
    'reolink',
    'Reolink',
    '/h264Preview_01_main',
    sub: '/h264Preview_01_sub',
    second: '/h264Preview_02_main',
    secondSub: '/h264Preview_02_sub',
  ),
  RtspPattern('reolink', 'Reolink (H.265)', '/Preview_01_main', sub: '/Preview_01_sub'),
  RtspPattern('tapo', 'TP-Link Tapo / VIGI', '/stream1', sub: '/stream2', second: '/stream6', secondSub: '/stream7'),
  RtspPattern('ezviz', 'Ezviz', '/h264/ch1/main/av_stream', sub: '/h264/ch1/sub/av_stream'),
  RtspPattern(
    'axis',
    'Axis',
    '/axis-media/media.amp',
    sub: '/axis-media/media.amp?resolution=640x360',
    second: '/axis-media/media.amp?camera=2',
  ),
  RtspPattern(
    'uniview',
    'Uniview',
    '/unicast/c1/s0/live',
    sub: '/unicast/c1/s1/live',
    second: '/unicast/c2/s0/live',
    secondSub: '/unicast/c2/s1/live',
  ),
  RtspPattern('foscam', 'Foscam', ':88/videoMain', sub: ':88/videoSub'),
  RtspPattern('foscam', 'Foscam (554)', '/videoMain', sub: '/videoSub'),
  RtspPattern('generic', 'Yleinen /live/ch00_0', '/live/ch00_0', sub: '/live/ch00_1', second: '/live/ch01_0'),
  RtspPattern('generic', 'Yleinen /11', '/11', sub: '/12'),
  RtspPattern('generic', 'Yleinen /onvif1 (Yoosee)', '/onvif1', sub: '/onvif2'),
  RtspPattern('generic', 'Yleinen /h264_stream', '/h264_stream'),
  RtspPattern('generic', 'Yleinen /live', '/live'),
  RtspPattern('generic', 'Yleinen /stream', '/stream'),
  RtspPattern('generic', 'Yleinen /video1', '/video1', sub: '/video2'),
  RtspPattern('generic', 'Yleinen /ch0_0.h264', '/ch0_0.h264', sub: '/ch0_1.h264'),
];

/// Brand guess from a model / manufacturer / name text (ONVIF answer, discovery scopes).
String rtspBrandHint(String text) {
  final t = text.toLowerCase();
  for (final (k, b) in const [
    ('sonoff', 'sonoff'),
    ('ewelink', 'sonoff'),
    ('gk-200', 'sonoff'),
    ('hikvision', 'hikvision'),
    ('ds-2', 'hikvision'),
    ('annke', 'hikvision'),
    ('ezviz', 'ezviz'),
    ('dahua', 'dahua'),
    ('imou', 'dahua'),
    ('amcrest', 'dahua'),
    ('lorex', 'dahua'),
    ('reolink', 'reolink'),
    ('tapo', 'tapo'),
    ('tp-link', 'tapo'),
    ('vigi', 'tapo'),
    ('axis', 'axis'),
    ('uniview', 'uniview'),
    ('unv', 'uniview'),
    ('foscam', 'foscam'),
  ]) {
    if (t.contains(k)) return b;
  }
  return '';
}

/// One stream found by [probeRtsp] (templates with {{host}}, no login inside).
class ProbedStream {
  ProbedStream(this.rtsp, [this.rtspSub]);
  final String rtsp;
  final String? rtspSub;
}

class RtspProbeResult {
  RtspProbeResult(this.pattern, this.streams, this.tried, {this.authFailed = false});
  final RtspPattern? pattern;
  final List<ProbedStream> streams;
  final List<String> tried;

  /// Some address answered 401 even with the login: the password is probably wrong.
  final bool authFailed;
}

/// Tries [rtspPatterns] (the [brand] first) with [check] (an RTSP DESCRIBE that returns the
/// status code, login included). The first one that answers 200 wins; then its light stream
/// and second lens are checked. A port that does not answer is skipped for the rest.
Future<RtspProbeResult> probeRtsp(
  String host, {
  required String user,
  required String password,
  required Future<int> Function(String url) check,
  String brand = '',
  Duration budget = const Duration(seconds: 40),
}) async {
  final order = [
    ...rtspPatterns.where((p) => brand.isNotEmpty && p.brand == brand),
    ...rtspPatterns.where((p) => brand.isEmpty || p.brand != brand),
  ];
  final deadPorts = <int>{};
  final tried = <String>[];
  var auth401 = 0, other = 0;
  final end = DateTime.now().add(budget);
  final info = user.isEmpty && password.isEmpty ? '' : '${Uri.encodeComponent(user)}:${Uri.encodeComponent(password)}@';
  String withLogin(String tpl) => tpl.replaceFirst('rtsp://', 'rtsp://$info').replaceAll('{{host}}', host);

  Future<int?> code(String tpl) async {
    try {
      return await check(withLogin(tpl));
    } catch (_) {
      return null;
    }
  }

  for (final p in order) {
    if (DateTime.now().isAfter(end)) break;
    if (deadPorts.contains(p.port)) continue;
    final int c;
    try {
      c = await check(withLogin(p.mainUrl));
    } catch (e) {
      deadPorts.add(p.port);
      tried.add('${p.main}: $e');
      continue;
    }
    tried.add('${p.main}: RTSP $c');
    if (c == 200) {
      final sub = p.subUrl != null && p.subUrl != p.secondUrl && await code(p.subUrl!) == 200 ? p.subUrl : null;
      final streams = [ProbedStream(p.mainUrl, sub)];
      if (p.secondUrl != null && await code(p.secondUrl!) == 200) {
        final ss = p.secondSubUrl != null && await code(p.secondSubUrl!) == 200 ? p.secondSubUrl : null;
        streams.add(ProbedStream(p.secondUrl!, ss));
      }
      return RtspProbeResult(p, streams, tried);
    }
    if (c == 401) {
      auth401++;
    } else {
      other++;
    }
  }
  return RtspProbeResult(null, const [], tried, authFailed: auth401 > 0 && other == 0);
}
