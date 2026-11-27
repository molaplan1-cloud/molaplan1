/// R481–R482 (t312u): numeric samples of a user-built trend, stored on the device.
///
/// Buckets (avg / min / max / n) get coarser with age, so a year of data stays small:
/// 1 min for the last 6 h, 5 min up to 24 h, 15 min up to 7 days, 1 h up to 30 days and
/// 3 h after that – a 30-day trend is about 1 700 buckets (≈ 50 KB). Each trend is also capped
/// at [TrendSeries.maxBuckets]. Long ranges are drawn from [downsample] (≤ ~240 points).
library;

import 'dart:convert';
import 'dart:math' as math;

import 'package:shared_preferences/shared_preferences.dart';

class TrendPoint {
  TrendPoint(this.minute, this.avg, this.min, this.max, this.n);

  /// Bucket start, minutes since epoch.
  final int minute;
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

  void merge(TrendPoint o) {
    avg = (avg * n + o.avg * o.n) / (n + o.n);
    n += o.n;
    min = math.min(min, o.min);
    max = math.max(max, o.max);
  }

  List<num> toJson() => [minute, _r(avg), _r(min), _r(max), n];

  static TrendPoint? fromJson(Object? l) {
    if (l is! List || l.length < 5 || l.any((e) => e is! num)) return null;
    return TrendPoint(
      (l[0] as num).toInt(),
      (l[1] as num).toDouble(),
      (l[2] as num).toDouble(),
      (l[3] as num).toDouble(),
      (l[4] as num).toInt(),
    );
  }

  static num _r(double v) => v.abs() >= 100 ? (v * 10).roundToDouble() / 10 : (v * 10000).roundToDouble() / 10000;
}

class TrendStats {
  const TrendStats(this.min, this.max, this.avg, this.last, this.count);
  final double min;
  final double max;
  final double avg;
  final double last;
  final int count;
}

/// Bucket size (minutes) for data of [ageMin] minutes.
int trendBucketMinutes(int ageMin) {
  if (ageMin <= 6 * 60) return 1;
  if (ageMin <= 24 * 60) return 5;
  if (ageMin <= 7 * 24 * 60) return 15;
  if (ageMin <= 30 * 24 * 60) return 60;
  return 180;
}

class TrendSeries {
  TrendSeries([List<TrendPoint>? points]) : points = points ?? [];

  static const maxBuckets = 5000;

  /// Oldest first.
  final List<TrendPoint> points;

  /// The last recorded raw value and its time (for dedupe / interval sampling).
  double? lastValue;
  DateTime? lastAt;

  bool get isEmpty => points.isEmpty;

  /// Adds one sample. Older samples (backfill) go in their place.
  void add(double v, DateTime at) {
    if (!v.isFinite) return;
    final m = at.millisecondsSinceEpoch ~/ 60000;
    if (points.isEmpty || points.last.minute < m) {
      points.add(TrendPoint(m, v, v, v, 1));
    } else if (points.last.minute == m) {
      points.last.add(v);
    } else {
      var i = points.length;
      while (i > 0 && points[i - 1].minute > m) {
        i--;
      }
      if (i > 0 && points[i - 1].minute == m) {
        points[i - 1].add(v);
      } else {
        points.insert(i, TrendPoint(m, v, v, v, 1));
      }
    }
    if (lastAt == null || !at.isBefore(lastAt!)) {
      lastAt = at;
      lastValue = v;
    }
  }

  /// Coarser buckets for older data; drops data older than [retention]; caps the count.
  void compact({required Duration retention, DateTime? now}) {
    final n = (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 60000;
    final oldest = n - retention.inMinutes;
    final out = <TrendPoint>[];
    for (final b in points) {
      if (b.minute < oldest) continue;
      final size = trendBucketMinutes(n - b.minute);
      final start = b.minute - b.minute % size;
      if (out.isNotEmpty && size > 1 && out.last.minute == start) {
        out.last.merge(b);
      } else {
        out.add(size > 1 && b.minute != start ? TrendPoint(start, b.avg, b.min, b.max, b.n) : b);
      }
    }
    if (out.length > maxBuckets) out.removeRange(0, out.length - maxBuckets);
    points
      ..clear()
      ..addAll(out);
  }

  /// Buckets in [from, to) (oldest first).
  List<TrendPoint> range(DateTime from, [DateTime? to]) {
    final f = from.millisecondsSinceEpoch ~/ 60000;
    final t = to == null ? null : to.millisecondsSinceEpoch ~/ 60000;
    return [
      for (final b in points)
        if (b.minute >= f && (t == null || b.minute < t)) b,
    ];
  }

  TrendStats? stats(DateTime from, [DateTime? to]) => trendStats(range(from, to));

  Map<String, dynamic> toJson() => {
    'v': 1,
    'p': [for (final b in points) b.toJson()],
    if (lastAt != null) 'la': lastAt!.millisecondsSinceEpoch,
    'lv': ?lastValue,
  };

  static TrendSeries fromJson(Object? j) {
    final s = TrendSeries();
    if (j is! Map) return s;
    final p = j['p'];
    if (p is List) {
      for (final e in p) {
        final b = TrendPoint.fromJson(e);
        if (b != null) s.points.add(b);
      }
      s.points.sort((a, b) => a.minute.compareTo(b.minute));
    }
    final la = (j['la'] as num?)?.toInt();
    if (la != null) s.lastAt = DateTime.fromMillisecondsSinceEpoch(la);
    s.lastValue = (j['lv'] as num?)?.toDouble();
    return s;
  }
}

TrendStats? trendStats(List<TrendPoint> s) {
  if (s.isEmpty) return null;
  var n = 0;
  var sum = 0.0;
  var lo = double.infinity;
  var hi = double.negativeInfinity;
  for (final b in s) {
    lo = math.min(lo, b.min);
    hi = math.max(hi, b.max);
    sum += b.avg * b.n;
    n += b.n;
  }
  return TrendStats(lo, hi, n == 0 ? s.last.avg : sum / n, s.last.avg, n);
}

/// At most [maxPoints] buckets for drawing a long range: neighbours are merged into equal
/// time slots (avg weighted by sample count, min / max kept).
List<TrendPoint> downsample(List<TrendPoint> s, {int maxPoints = 240}) {
  if (s.length <= maxPoints || s.length < 2) return s;
  final span = s.last.minute - s.first.minute + 1;
  final slot = math.max(1, (span / maxPoints).ceil());
  final out = <TrendPoint>[];
  for (final b in s) {
    final start = s.first.minute + ((b.minute - s.first.minute) ~/ slot) * slot;
    if (out.isNotEmpty && out.last.minute == start) {
      out.last.merge(b);
    } else {
      out.add(TrendPoint(start, b.avg, b.min, b.max, b.n));
    }
  }
  return out;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// ISO-like local time for CSV (spreadsheets read it as a date).
String csvTime(DateTime t) =>
    '${t.year}-${_two(t.month)}-${_two(t.day)} ${_two(t.hour)}:${_two(t.minute)}:${_two(t.second)}';

String csvCell(Object? v) {
  final s = v == null ? '' : '$v';
  return s.contains(RegExp(r'[",\n;]')) ? '"${s.replaceAll('"', '""')}"' : s;
}

/// CSV of a trend: time, avg, min, max, samples.
String trendCsv(List<TrendPoint> s, {String unit = ''}) {
  final u = unit.isEmpty ? '' : ' ($unit)';
  final b = StringBuffer('time,avg$u,min$u,max$u,samples\n');
  for (final p in s) {
    b.writeln([csvTime(p.at), p.avg, p.min, p.max, p.n].map(csvCell).join(','));
  }
  return b.toString();
}

/// Trends on the device (SharedPreferences: Android, Windows and the browser).
class TrendStore {
  static String key(String logId) => 'trend.$logId';

  static Future<TrendSeries> load(String logId) async {
    final p = await SharedPreferences.getInstance();
    final raw = p.getString(key(logId));
    if (raw == null) return TrendSeries();
    try {
      return TrendSeries.fromJson(jsonDecode(raw));
    } catch (_) {
      return TrendSeries();
    }
  }

  static Future<void> save(String logId, TrendSeries s) async {
    final p = await SharedPreferences.getInstance();
    await p.setString(key(logId), jsonEncode(s.toJson()));
  }

  static Future<void> delete(String logId) async {
    final p = await SharedPreferences.getInstance();
    await p.remove(key(logId));
  }
}
