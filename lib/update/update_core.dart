import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:cryptography/cryptography.dart';
import 'package:http/http.dart' as http;

/// Semantic version (major.minor.patch[-pre]); build metadata (+n) is ignored.
class SemVer implements Comparable<SemVer> {
  SemVer(this.major, this.minor, this.patch, [this.pre = const []]);
  final int major, minor, patch;
  final List<String> pre;

  static SemVer? tryParse(String s) {
    final m = RegExp(r'^[vV]?(\d+)(?:\.(\d+))?(?:\.(\d+))?(?:-([0-9A-Za-z.-]+))?(?:\+.*)?$').firstMatch(s.trim());
    if (m == null) return null;
    return SemVer(
      int.parse(m[1]!),
      int.parse(m[2] ?? '0'),
      int.parse(m[3] ?? '0'),
      m[4] == null ? const [] : m[4]!.split('.'),
    );
  }

  bool get isPrerelease => pre.isNotEmpty;

  @override
  int compareTo(SemVer o) {
    for (final d in [major - o.major, minor - o.minor, patch - o.patch]) {
      if (d != 0) return d.sign;
    }
    // A release is newer than its pre-releases (1.0.0 > 1.0.0-rc.1).
    if (pre.isEmpty && o.pre.isEmpty) return 0;
    if (pre.isEmpty) return 1;
    if (o.pre.isEmpty) return -1;
    for (var i = 0; i < pre.length && i < o.pre.length; i++) {
      final a = int.tryParse(pre[i]), b = int.tryParse(o.pre[i]);
      final c = a != null && b != null
          ? a.compareTo(b)
          : a != null
          ? -1
          : b != null
          ? 1
          : pre[i].compareTo(o.pre[i]);
      if (c != 0) return c.sign;
    }
    return (pre.length - o.pre.length).sign;
  }

  bool operator >(SemVer o) => compareTo(o) > 0;
  @override
  String toString() => '$major.$minor.$patch${pre.isEmpty ? '' : '-${pre.join('.')}'}';
}

/// True if [latest] is newer than [current] (unparseable versions never count as newer).
bool isNewer(String latest, String current) {
  final l = SemVer.tryParse(latest), c = SemVer.tryParse(current);
  return l != null && c != null && l > c;
}

class ReleaseAsset {
  ReleaseAsset(this.name, this.url, this.size);
  final String name;
  final String url;
  final int size;
}

class ReleaseInfo {
  ReleaseInfo({
    required this.tag,
    required this.name,
    required this.notes,
    required this.pageUrl,
    required this.assets,
  });
  final String tag;
  final String name;
  final String notes;
  final String pageUrl;
  final List<ReleaseAsset> assets;

  String get version => SemVer.tryParse(tag)?.toString() ?? tag;

  ReleaseAsset? asset(String name) => assets.where((a) => a.name == name).firstOrNull;

  factory ReleaseInfo.fromGitHub(Map<String, dynamic> j) => ReleaseInfo(
    tag: '${j['tag_name'] ?? ''}',
    name: '${j['name'] ?? j['tag_name'] ?? ''}',
    notes: '${j['body'] ?? ''}'.trim(),
    pageUrl: '${j['html_url'] ?? ''}',
    assets: [
      for (final a in (j['assets'] as List? ?? []))
        ReleaseAsset('${a['name']}', '${a['browser_download_url']}', (a['size'] as num?)?.toInt() ?? 0),
    ],
  );
}

const androidArm64Asset = 'molaplan-android-arm64.apk';
const androidUniversalAsset = 'molaplan-android-universal.apk';
const windowsAsset = 'molaplan-windows-x64.zip';
const checksumAsset = 'SHA256SUMS';

/// The download for this device: arm64 APK on 64-bit ARM Android, otherwise the
/// universal APK; the zip on Windows. Null = no installable asset (open the page instead).
ReleaseAsset? pickAsset(ReleaseInfo r, {required String os, List<String> abis = const []}) {
  switch (os) {
    case 'android':
      if (abis.contains('arm64-v8a')) return r.asset(androidArm64Asset) ?? r.asset(androidUniversalAsset);
      return r.asset(androidUniversalAsset);
    case 'windows':
      return r.asset(windowsAsset);
  }
  return null;
}

/// Parses `sha256sum` output: `HEX  NAME` or `HEX *NAME` per line.
Map<String, String> parseSha256Sums(String text) {
  final out = <String, String>{};
  for (final line in const LineSplitter().convert(text)) {
    final m = RegExp(r'^([0-9a-fA-F]{64})\s+\*?(.+?)\s*$').firstMatch(line.trim());
    if (m != null) out[m[2]!.split('/').last] = m[1]!.toLowerCase();
  }
  return out;
}

Future<String> sha256OfFile(File f) async {
  final sink = Sha256().newHashSink();
  await for (final chunk in f.openRead()) {
    sink.add(chunk);
  }
  sink.close();
  final h = await sink.hash();
  return h.bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
}

class ChecksumMismatch implements Exception {
  ChecksumMismatch(this.file, this.expected, this.actual);
  final String file, expected, actual;
  @override
  String toString() => 'Checksum mismatch for $file';
}

/// Throws [ChecksumMismatch] unless [f] matches the [sums] entry for [assetName].
Future<void> verifyChecksum(File f, String assetName, Map<String, String> sums) async {
  final expected = sums[assetName];
  if (expected == null) throw ChecksumMismatch(assetName, '(missing from SHA256SUMS)', '');
  final actual = await sha256OfFile(f);
  if (actual != expected) throw ChecksumMismatch(assetName, expected, actual);
}

enum CheckOutcome { newer, upToDate, unavailable }

class CheckResult {
  CheckResult(this.outcome, [this.release]);
  final CheckOutcome outcome;
  final ReleaseInfo? release;
}

/// Asks GitHub for the latest release. Never throws: offline, rate limited
/// (403/429) or odd answers all give [CheckOutcome.unavailable].
Future<CheckResult> checkLatest({
  required String current,
  String repo = 'molaplan1-cloud/molaplan1',
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final c = client ?? http.Client();
  try {
    final r = await c
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/latest'),
          headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'molaplan-app/$current'},
        )
        .timeout(timeout);
    if (r.statusCode != 200) return CheckResult(CheckOutcome.unavailable);
    final rel = ReleaseInfo.fromGitHub(jsonDecode(r.body) as Map<String, dynamic>);
    return isNewer(rel.tag, current) ? CheckResult(CheckOutcome.newer, rel) : CheckResult(CheckOutcome.upToDate, rel);
  } catch (_) {
    return CheckResult(CheckOutcome.unavailable);
  } finally {
    if (client == null) c.close();
  }
}

/// R701: where the version of the live web app (= the latest release) is published. It is a plain
/// static file on molaplan.com, so it has no API rate limit; GitHub is the fallback.
const manifestUrl = 'https://molaplan.com/version.json';

/// The version in molaplan.com/version.json (`{"version":"0.20.25",...}`), or null for anything else.
String? parseManifestVersion(String body) {
  try {
    final j = jsonDecode(body);
    if (j is! Map) return null;
    final v = '${j['version'] ?? ''}';
    return SemVer.tryParse(v)?.toString();
  } catch (_) {
    return null;
  }
}

/// A [ReleaseInfo] built from a version number alone: the download links of a GitHub release follow
/// a fixed pattern, and these links are not rate limited.
ReleaseInfo releaseFromVersion(String version, {String repo = 'molaplan1-cloud/molaplan1'}) {
  final base = 'https://github.com/$repo/releases/download/v$version';
  return ReleaseInfo(
    tag: 'v$version',
    name: 'Molaplan v$version',
    notes: '',
    pageUrl: 'https://github.com/$repo/releases/tag/v$version',
    assets: [
      for (final n in [androidArm64Asset, androidUniversalAsset, windowsAsset, checksumAsset])
        ReleaseAsset(n, '$base/$n', 0),
    ],
  );
}

/// R701: the update check. Asks molaplan.com first (no rate limit); when that says a newer version
/// exists, the release (notes + files) comes from GitHub's tag endpoint, or, if the API is rate
/// limited, from the fixed download links. When molaplan.com cannot be reached the GitHub "latest"
/// endpoint decides. Never throws: [CheckOutcome.unavailable] means "could not tell".
Future<CheckResult> checkUpdate({
  required String current,
  String repo = 'molaplan1-cloud/molaplan1',
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  final c = client ?? http.Client();
  try {
    String? latest;
    try {
      final r = await c
          .get(Uri.parse('$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'), headers: {'Cache-Control': 'no-cache'})
          .timeout(timeout);
      if (r.statusCode == 200) latest = parseManifestVersion(r.body);
    } catch (_) {}
    if (latest == null) return await checkLatest(current: current, repo: repo, client: c, timeout: timeout);
    if (!isNewer(latest, current)) return CheckResult(CheckOutcome.upToDate);
    try {
      final r = await c
          .get(
            Uri.parse('https://api.github.com/repos/$repo/releases/tags/v$latest'),
            headers: {'Accept': 'application/vnd.github+json', 'User-Agent': 'molaplan-app/$current'},
          )
          .timeout(timeout);
      if (r.statusCode == 200) {
        final rel = ReleaseInfo.fromGitHub(jsonDecode(r.body) as Map<String, dynamic>);
        if (rel.tag.isNotEmpty && rel.assets.isNotEmpty) return CheckResult(CheckOutcome.newer, rel);
      }
    } catch (_) {}
    return CheckResult(CheckOutcome.newer, releaseFromVersion(latest, repo: repo));
  } finally {
    if (client == null) c.close();
  }
}

/// Downloads [url] to [to], reporting progress 0..1 (null when the size is unknown).
Future<File> download(String url, File to, {void Function(double?)? progress, http.Client? client}) async {
  final c = client ?? http.Client();
  try {
    final res = await c.send(http.Request('GET', Uri.parse(url))).timeout(const Duration(seconds: 30));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(url));
    await to.parent.create(recursive: true);
    final tmp = File('${to.path}.part');
    final sink = tmp.openWrite();
    var got = 0;
    final total = res.contentLength;
    await for (final chunk in res.stream.timeout(const Duration(seconds: 60))) {
      sink.add(chunk);
      got += chunk.length;
      progress?.call(total == null || total == 0 ? null : got / total);
    }
    await sink.close();
    if (await to.exists()) await to.delete();
    return await tmp.rename(to.path);
  } finally {
    if (client == null) c.close();
  }
}

Future<Map<String, String>> fetchSums(ReleaseInfo r, {http.Client? client}) async {
  final a = r.asset(checksumAsset);
  if (a == null) throw ChecksumMismatch(checksumAsset, '(missing)', '');
  final c = client ?? http.Client();
  try {
    final res = await c.get(Uri.parse(a.url)).timeout(const Duration(seconds: 20));
    if (res.statusCode != 200) throw HttpException('HTTP ${res.statusCode}', uri: Uri.parse(a.url));
    return parseSha256Sums(res.body);
  } finally {
    if (client == null) c.close();
  }
}
