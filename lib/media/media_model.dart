/// R290: common model for TVs and Cast devices (Chromecast / Google TV, Samsung Tizen, LG webOS,
/// Philips JointSPACE). Every backend maps to the same state so tiles and automations are
/// brand-independent.
library;

import 'dart:io';

import 'package:http/http.dart' as http;

import '../core/io_http.dart';
import '../drivers/driver.dart';
import '../drivers/http_driver.dart';

class MediaState {
  MediaState({this.power, this.volume, this.muted, this.app = '', this.title = '', this.playing});

  /// null = unknown (Cast devices have no power state).
  bool? power;

  /// 0–100.
  num? volume;
  bool? muted;
  String app, title;

  /// null = nothing playing / unknown.
  bool? playing;

  String get status {
    if (power == false) return dtx('Pois päältä', 'Off');
    final parts = [if (app.isNotEmpty) app, if (title.isNotEmpty) title];
    if (parts.isEmpty) return power == true ? dtx('Päällä', 'On') : dtx('Valmiina', 'Idle');
    return parts.join(' – ');
  }

  Object? value(String key) => switch (key) {
    'status' => status,
    'power' => power == true ? 1 : 0,
    'volume' => volume,
    'muted' => muted == true ? 1 : 0,
    'app' => app,
    'title' => title,
    'playing' => playing == true ? 1 : 0,
    _ => throw DriverException('Media: unknown reading "$key"'),
  };

  Map<String, dynamic> toJson() => {
    'power': power,
    'volume': volume,
    'muted': muted,
    'app': app,
    'title': title,
    'playing': playing,
  };
  factory MediaState.fromJson(Map j) => MediaState(
    power: j['power'] as bool?,
    volume: j['volume'] as num?,
    muted: j['muted'] as bool?,
    app: '${j['app'] ?? ''}',
    title: '${j['title'] ?? ''}',
    playing: j['playing'] as bool?,
  );
}

/// What the device is (wizard): name, model and what it can do.
class MediaInfo {
  MediaInfo({required this.name, this.model = '', this.mac = '', this.caps = const {}, this.extra = const {}});
  final String name, model, mac;

  /// 'power', 'volume', 'mute', 'playpause', 'stop', 'keys'.
  final Set<String> caps;

  /// Values learnt during pairing that must be saved (token / client key / auth key).
  final Map<String, String> extra;

  Map<String, dynamic> toJson() => {'name': name, 'model': model, 'mac': mac, 'caps': caps.toList(), 'extra': extra};
  factory MediaInfo.fromJson(Map j) => MediaInfo(
    name: '${j['name'] ?? ''}',
    model: '${j['model'] ?? ''}',
    mac: '${j['mac'] ?? ''}',
    caps: {for (final c in (j['caps'] as List? ?? const [])) '$c'},
    extra: {for (final e in ((j['extra'] as Map?) ?? const {}).entries) '${e.key}': '${e.value}'},
  );
}

class MediaAuthError extends DriverException {
  MediaAuthError(super.message);
}

/// The TV is showing a pairing prompt / PIN; the user has to accept it.
class MediaPairingNeeded extends DriverException {
  MediaPairingNeeded(super.message);
}

abstract class MediaBackend {
  MediaBackend(this.s);
  final Map<String, dynamic> s;
  String get host => '${s['address'] ?? ''}'.trim().replaceFirst(RegExp(r'^\w+://'), '').split(':').first;

  Future<MediaInfo> info();
  Future<MediaState> state();
  Future<void> setPower(bool on);
  Future<void> setVolume(num level);
  Future<void> setMuted(bool muted);

  /// 'play', 'pause', 'playpause', 'stop', 'volup', 'voldown', 'home', 'back'.
  Future<void> key(String key);
  Future<void> close() async {}
}

/// HTTP client for TV REST calls (self-signed TV certificates accepted). Test hook.
http.Client Function() mediaHttp = () => makeHttpClient(true, timeout: const Duration(seconds: 6));

/// WebSocket to a TV (self-signed certificates accepted).
Future<WebSocket> mediaWebSocket(String url) async {
  final hc = requireIoHttpClient(timeout: const Duration(seconds: 5), allowSelfSigned: true);
  try {
    return await WebSocket.connect(url, customClient: hc).timeout(const Duration(seconds: 8));
  } catch (e) {
    throw DriverException('${Uri.parse(url).host}: ${dtx('televisioon ei saatu yhteyttä', 'TV not reachable')} ($e)');
  }
}
