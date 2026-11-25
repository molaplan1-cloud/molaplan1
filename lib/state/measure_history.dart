/// Local history of measurement tiles (power, temperature…): feeds the trend and the
/// gauge's auto range, and keeps the last value for offline display.
/// Downsampled: 1 min buckets for the last hour, 5 min up to 6 h, 15 min up to 24 h
/// (about 190 points per measurement), so it is light to persist.
library;

import 'dart:convert';
import 'dart:math' as math;

import '../models/models.dart';

class MeasureBucket {
  MeasureBucket(this.minute, this.avg, this.min, this.max, this.n);
  final int minute; // minutes since epoch (bucket start)
  double avg;
  double min;
  double max;
  int n;

  DateTime get at => DateTime.fromMillisecondsSinceEpoch(minute * 60000);

  void add(double v) {
    avg = (avg * n + v) / (n + 1);
    n++;
    min = math.min(min, v);
    max = math.max(max, v);
  }

  void merge(MeasureBucket o) {
    avg = (avg * n + o.avg * o.n) / (n + o.n);
    n += o.n;
    min = math.min(min, o.min);
    max = math.max(max, o.max);
  }

  List<num> toJson() => [minute, _r(avg), _r(min), _r(max), n];

  static MeasureBucket fromJson(List l) => MeasureBucket(
    (l[0] as num).toInt(),
    (l[1] as num).toDouble(),
    (l[2] as num).toDouble(),
    (l[3] as num).toDouble(),
    (l[4] as num).toInt(),
  );

  static num _r(double v) => v.abs() >= 100 ? (v * 10).roundToDouble() / 10 : (v * 1000).roundToDouble() / 1000;
}

class MeasureStats {
  const MeasureStats(this.min, this.max, this.last, this.lastAt);
  final double min;
  final double max;
  final double last;
  final DateTime lastAt;
}

/// Numeric measurement tiles (power, energy, temperature, humidity, sensors…): get "Näyttötapa".
bool isMeasureTile(TileConfig t) =>
    t.type == TileType.value &&
    t.unit.trim().isNotEmpty &&
    t.valueMap.trim().isEmpty &&
    t.read['mode'] != 'log' &&
    t.read['field'] != 'chart';

/// Same measurement = same connection + read spec, so tiles share it and edits keep it.
String measureKey(TileConfig t) => '${t.connectionId}|${jsonEncode(t.read)}';

class MeasureHistory {
  final _data = <String, List<MeasureBucket>>{};
  final _last = <String, (DateTime, double)>{};

  /// Bumped on every new sample (widgets compare it to repaint).
  int version = 0;

  bool get isEmpty => _data.isEmpty;

  void add(String key, double v, DateTime at) {
    if (!v.isFinite) return;
    final m = at.millisecondsSinceEpoch ~/ 60000;
    final l = _data.putIfAbsent(key, () => []);
    if (l.isNotEmpty && l.last.minute == m) {
      l.last.add(v);
    } else if (l.isEmpty || l.last.minute < m) {
      l.add(MeasureBucket(m, v, v, v, 1));
    }
    _last[key] = (at, v);
    version++;
    if (l.length > 120 && l.length % 30 == 0) compact(key, at);
  }

  (DateTime, double)? last(String key) => _last[key];

  /// Buckets inside the last [hours] (oldest first).
  List<MeasureBucket> series(String key, int hours, {DateTime? now}) {
    final from = (now ?? DateTime.now()).subtract(Duration(hours: hours)).millisecondsSinceEpoch ~/ 60000;
    return [
      for (final b in _data[key] ?? const <MeasureBucket>[])
        if (b.minute >= from) b,
    ];
  }

  MeasureStats? stats(String key, int hours, {DateTime? now}) {
    final s = series(key, hours, now: now);
    final l = _last[key];
    if (s.isEmpty || l == null) return null;
    return MeasureStats(s.map((b) => b.min).reduce(math.min), s.map((b) => b.max).reduce(math.max), l.$2, l.$1);
  }

  /// Older data in coarser buckets; drops data older than 24 h.
  void compact([String? only, DateTime? now]) {
    final n = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 60000;
    for (final key in only == null ? _data.keys.toList() : [only]) {
      final l = _data[key];
      if (l == null) continue;
      final out = <MeasureBucket>[];
      for (final b in l) {
        final age = n - b.minute;
        if (age > 24 * 60) continue;
        final size = age > 6 * 60 ? 15 : (age > 60 ? 5 : 1);
        final start = b.minute - b.minute % size;
        if (out.isNotEmpty && out.last.minute == start && size > 1) {
          out.last.merge(b);
        } else {
          out.add(size > 1 ? (MeasureBucket(start, b.avg, b.min, b.max, b.n)) : b);
        }
      }
      if (out.isEmpty) {
        _data.remove(key);
      } else {
        _data[key] = out;
      }
    }
  }

  Map<String, dynamic> toJson() {
    compact();
    return {
      'v': 1,
      's': {
        for (final e in _data.entries) e.key: [for (final b in e.value) b.toJson()],
      },
      'last': {
        for (final e in _last.entries) e.key: [e.value.$1.millisecondsSinceEpoch, e.value.$2],
      },
    };
  }

  void loadJson(Map<String, dynamic> j) {
    final s = j['s'];
    if (s is Map) {
      for (final e in s.entries) {
        final l = e.value;
        if (l is! List) continue;
        _data['${e.key}'] = [
          for (final b in l)
            if (b is List && b.length >= 5) MeasureBucket.fromJson(b),
        ];
      }
    }
    final last = j['last'];
    if (last is Map) {
      for (final e in last.entries) {
        final l = e.value;
        if (l is List && l.length == 2) {
          _last['${e.key}'] = (DateTime.fromMillisecondsSinceEpoch((l[0] as num).toInt()), (l[1] as num).toDouble());
        }
      }
    }
    version++;
  }
}
