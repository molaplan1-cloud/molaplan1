/// R512 (t315u): "Tilasyöte" – Molaplan publishes a tile's display state (the same text, colour
/// and bars as the Android widget) to the tile's random feed topic on ntfy.molaplan.com, where
/// an iPhone widget (Scriptable) or an iOS Shortcut reads it. Zero cost: the existing ntfy
/// server (12 h cache), priority 1, never forwarded to ntfy.sh / Apple push.
///
/// Published by every Molaplan where the tile is live (e.g. the wall tablet) – on change, at
/// most once a minute, plus a heartbeat every 15 min. No PIN / secret ever goes out.
library;

import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../core/http_client.dart';
import '../core/plat.dart';
import '../l10n/l10n.dart';
import '../models/models.dart';
import '../sharing/tile_links.dart';
import 'home_launcher.dart';

class TileFeedPublisher {
  TileFeedPublisher({http.Client Function()? client, this.minGap = const Duration(seconds: 60)})
    : _client = client ?? (() => newHttpClient()),
      enabled = client != null || !Plat.isFlutterTest;

  final http.Client Function() _client;
  final Duration minGap;

  /// Off in tests unless a fake client is given.
  bool enabled;

  final _last = <String, (String, DateTime)>{};
  final _inflight = <String>{};

  /// Messages sent (tests / "Tekniset tiedot").
  int sent = 0;

  /// Publishes [value] of [t] when the widget's view of it changed (or the heartbeat is due).
  Future<bool> onValue(TileConfig t, Object? value, {required String lang, DateTime? at, DateTime? now}) async {
    final topic = t.feed;
    if (!enabled || !validFeedTopic(topic)) return false;
    final n = now ?? DateTime.now();
    final payload = feedPayload(launcherWidgetPayload(t, value, lang: lang, at: at), tileId: t.id, now: n);
    if (payloadLeaksSecret(payload)) return false;
    final cmp = feedComparable(payload);
    final last = _last[topic!];
    if (!feedShouldPublish(body: cmp, lastBody: last?.$1, now: n, lastAt: last?.$2, minGap: minGap)) {
      return false;
    }
    if (!_inflight.add(topic)) return false;
    _last[topic] = (cmp, n);
    try {
      return await _post(topic, payload);
    } finally {
      _inflight.remove(topic);
    }
  }

  /// "Poista käytöstä" / "Uusi linkki": the old topic's latest message says so, so a widget
  /// still holding it stops showing a value (the server forgets it within 12 h).
  Future<bool> revoke(String topic, {required String title, required String lang}) async {
    if (!enabled || !validFeedTopic(topic)) return false;
    _last.remove(topic);
    return _post(topic, {
      'v': 1,
      'title': title,
      'value': tr(lang, 'Linkki poistettu käytöstä', 'Link revoked'),
      'color': 0xFF546E7A,
      'revoked': true,
      't': DateTime.now().millisecondsSinceEpoch ~/ 1000,
    });
  }

  Future<bool> _post(String topic, Map<String, dynamic> payload) async {
    final c = _client();
    try {
      final r = await c
          .post(
            Uri.parse(feedUrl(topic)),
            headers: const {'X-Priority': '1', 'X-Firebase': 'no', 'X-Tags': 'molaplan-feed'},
            body: jsonEncode(payload),
          )
          .timeout(const Duration(seconds: 10));
      final ok = r.statusCode >= 200 && r.statusCode < 300;
      if (ok) sent++;
      return ok;
    } catch (_) {
      return false;
    } finally {
      c.close();
    }
  }

  void resetForTests() {
    _last.clear();
    _inflight.clear();
    sent = 0;
  }
}
