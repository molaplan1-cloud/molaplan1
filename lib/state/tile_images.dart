import 'dart:convert';
import 'dart:io';
import 'dart:isolate';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:image/image.dart' as img;

/// Tile background images: resized + compressed JPEG (≤ [maxBytes]), stored locally by content
/// hash, synced to Supabase Storage (bucket `tile-images`, folder = user id) when signed in.
const tileImageMaxBytes = 200 * 1024;

/// Free-tier guard: at most this many distinct background images per account.
const tileImageMaxCount = 40;

class ProcessedTileImage {
  ProcessedTileImage(this.bytes, this.name, this.luminance, this.scrim);
  final Uint8List bytes;
  final String name;

  /// Mean relative luminance (0..1) of the picture.
  final double luminance;

  /// Opacity of the dark scrim that keeps white text at ≥ 4.5:1 contrast.
  final double scrim;
}

/// WCAG relative luminance of an sRGB channel triple (0..255).
double relLuminance(num r, num g, num b) {
  double lin(num c) {
    final s = c / 255;
    return s <= 0.03928 ? s / 12.92 : math.pow((s + 0.055) / 1.055, 2.4).toDouble();
  }

  return 0.2126 * lin(r) + 0.7152 * lin(g) + 0.0722 * lin(b);
}

double contrastRatio(double l1, double l2) => (math.max(l1, l2) + 0.05) / (math.min(l1, l2) + 0.05);

/// Black overlay opacity needed so that white text on the darkened picture reaches 4.5:1
/// (L·(1−a) ≤ 1.05/4.5 − 0.05). Uses the brighter end of the picture (mean + spread) and
/// never goes below 0.35 so state colours stay readable on busy photos.
double scrimFor(double luminance) {
  const target = 0.18; // 1.05/4.5 − 0.05 ≈ 0.183, with a margin
  if (luminance <= 0) return 0.35;
  return (1 - target / luminance).clamp(0.35, 0.85).toDouble();
}

/// Decodes any common format, scales to ≤ 800 px (then 640/480 if needed) and encodes JPEG
/// until it fits [maxBytes]. Throws [FormatException] for unreadable files.
ProcessedTileImage processTileImage(Uint8List input, {int maxBytes = tileImageMaxBytes}) {
  final src = img.decodeImage(input);
  if (src == null) throw const FormatException('not an image');
  final oriented = img.bakeOrientation(src);
  Uint8List? out;
  img.Image? used;
  for (final side in const [800, 640, 480, 360]) {
    final scaled = oriented.width >= oriented.height
        ? (oriented.width > side
              ? img.copyResize(oriented, width: side, interpolation: img.Interpolation.average)
              : oriented)
        : (oriented.height > side
              ? img.copyResize(oriented, height: side, interpolation: img.Interpolation.average)
              : oriented);
    for (final q in const [82, 72, 62, 50]) {
      final b = img.encodeJpg(scaled, quality: q);
      used = scaled;
      out = b;
      if (b.length <= maxBytes) break;
    }
    if (out!.length <= maxBytes) break;
  }
  // Luminance: sample a grid; use mean + 1 SD so bright patches behind text are covered.
  final im = used!;
  var n = 0;
  var sum = 0.0;
  var sq = 0.0;
  final stepX = math.max(1, im.width ~/ 40), stepY = math.max(1, im.height ~/ 40);
  for (var y = 0; y < im.height; y += stepY) {
    for (var x = 0; x < im.width; x += stepX) {
      final p = im.getPixel(x, y);
      final l = relLuminance(p.r, p.g, p.b);
      sum += l;
      sq += l * l;
      n++;
    }
  }
  final mean = sum / n;
  final sd = math.sqrt(math.max(0, sq / n - mean * mean));
  final name = '${sha1.convert(out!).toString().substring(0, 20)}.jpg';
  return ProcessedTileImage(out, name, mean, scrimFor(math.min(1, mean + sd)));
}

Future<ProcessedTileImage> processTileImageAsync(Uint8List input) => Isolate.run(() => processTileImage(input));

/// Local image files (app support dir/tile_images). Bytes are cached in memory for painting.
class TileImageStore {
  TileImageStore([this.dir]);

  /// Null = memory only (tests, or no app-support dir).
  Directory? dir;
  final _mem = <String, Uint8List>{};

  static bool validName(String n) => RegExp(r'^[0-9a-f]{20}\.jpg$').hasMatch(n);

  File? _file(String name) => dir == null || !validName(name) ? null : File('${dir!.path}/$name');

  Uint8List? cached(String name) => _mem[name];

  Future<Uint8List?> read(String name) async {
    final m = _mem[name];
    if (m != null) return m;
    final f = _file(name);
    if (f == null || !await f.exists()) return null;
    return _mem[name] = await f.readAsBytes();
  }

  Future<bool> has(String name) async => _mem.containsKey(name) || (await _file(name)?.exists() ?? false);

  Future<void> write(String name, Uint8List bytes) async {
    _mem[name] = bytes;
    final f = _file(name);
    if (f == null) return;
    await f.parent.create(recursive: true);
    await f.writeAsBytes(bytes, flush: true);
  }

  Future<void> delete(String name) async {
    _mem.remove(name);
    final f = _file(name);
    if (f != null && await f.exists()) await f.delete();
  }

  /// Names already uploaded to the account (per user id), so a sync only sends new files.
  final _uploaded = <String, Set<String>>{};

  Future<Set<String>> uploaded(String user) async {
    final m = _uploaded[user];
    if (m != null) return {...m};
    final f = dir == null ? null : File('${dir!.path}/uploaded-$user.json');
    if (f == null || !await f.exists()) return {};
    try {
      return {
        ...(_uploaded[user] = {for (final x in jsonDecode(await f.readAsString()) as List) '$x'}),
      };
    } catch (_) {
      return {};
    }
  }

  Future<void> setUploaded(String user, Set<String> names) async {
    _uploaded[user] = {...names};
    if (dir == null) return;
    final f = File('${dir!.path}/uploaded-$user.json');
    await f.parent.create(recursive: true);
    await f.writeAsString(jsonEncode(names.toList()..sort()));
  }
}
