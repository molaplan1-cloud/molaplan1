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
    this.draft = false,
  });
  final bool draft;
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
    draft: j['draft'] == true,
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
  CheckResult(this.outcome, [this.release, this.pendingNewer = false]);
  final CheckOutcome outcome;
  final ReleaseInfo? release;

  /// A newer version is already tagged or listed on molaplan.com, but its installers are not
  /// published yet (CI is still running). The user is up to date with what can be installed.
  final bool pendingNewer;
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

/// The installers this device needs: the platform file and SHA256SUMS, listed on the release
/// (the URLs themselves are checked with [assetsArePublished] when the list is only constructed).
bool releaseIsInstallable(ReleaseInfo r, {required String os, List<String> abis = const []}) {
  if (r.draft) return false;
  if (os == 'windows' || os == 'android') {
    if (r.asset(checksumAsset) == null) return false;
    return pickAsset(r, os: os, abis: abis) != null;
  }
  // Linux/macOS and tests on them have no installer of their own: a published release is still
  // offered (the UI opens the release page).
  return r.assets.isNotEmpty;
}

ReleaseInfo? newestInstallable(Iterable<ReleaseInfo> releases, {required String os, List<String> abis = const []}) {
  ReleaseInfo? best;
  SemVer? bestV;
  for (final r in releases) {
    if (!releaseIsInstallable(r, os: os, abis: abis)) continue;
    final v = SemVer.tryParse(r.tag);
    if (v == null) continue;
    if (bestV == null || v > bestV) {
      best = r;
      bestV = v;
    }
  }
  return best;
}

Map<String, String> _ghHeaders(String current) => {
  'Accept': 'application/vnd.github+json',
  'User-Agent': 'molaplan-app/$current',
};

/// True when [url] answers 200 (or a partial-content range). Used so a constructed download link
/// is not offered before CI has uploaded the file.
Future<bool> remoteAssetExists(String url, {http.Client? client, Duration timeout = const Duration(seconds: 12)}) async {
  final c = client ?? http.Client();
  try {
    final head = http.Request('HEAD', Uri.parse(url));
    final hr = await c.send(head).timeout(timeout);
    if (hr.statusCode == 200 || hr.statusCode == 204 || hr.statusCode == 206) return true;
    if (hr.statusCode == 404 || hr.statusCode == 410) return false;
    // Some hosts refuse HEAD: a 1-byte GET is enough and does not download the zip.
    final get = http.Request('GET', Uri.parse(url));
    get.headers['Range'] = 'bytes=0-0';
    final gr = await c.send(get).timeout(timeout);
    return gr.statusCode == 200 || gr.statusCode == 206;
  } catch (_) {
    return false;
  } finally {
    if (client == null) c.close();
  }
}

Future<bool> assetsArePublished(
  ReleaseInfo r, {
  required String os,
  List<String> abis = const [],
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  if (!releaseIsInstallable(r, os: os, abis: abis)) return false;
  final asset = pickAsset(r, os: os, abis: abis)!;
  final sums = r.asset(checksumAsset)!;
  return await remoteAssetExists(asset.url, client: client, timeout: timeout) &&
      await remoteAssetExists(sums.url, client: client, timeout: timeout);
}

Future<List<ReleaseInfo>> fetchReleases({
  required String repo,
  required String current,
  required http.Client client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final r = await client
        .get(Uri.parse('https://api.github.com/repos/$repo/releases?per_page=30'), headers: _ghHeaders(current))
        .timeout(timeout);
    if (r.statusCode != 200) return const [];
    final list = jsonDecode(r.body);
    if (list is! List) return const [];
    return [
      for (final e in list)
        if (e is Map) ReleaseInfo.fromGitHub(Map<String, dynamic>.from(e)),
    ];
  } catch (_) {
    return const [];
  }
}

Future<ReleaseInfo?> fetchReleaseByTag({
  required String repo,
  required String current,
  required String version,
  required http.Client client,
  Duration timeout = const Duration(seconds: 12),
}) async {
  try {
    final r = await client
        .get(
          Uri.parse('https://api.github.com/repos/$repo/releases/tags/v$version'),
          headers: _ghHeaders(current),
        )
        .timeout(timeout);
    if (r.statusCode != 200) return null;
    return ReleaseInfo.fromGitHub(jsonDecode(r.body) as Map<String, dynamic>);
  } catch (_) {
    return null;
  }
}

/// Resolves [version] to a release whose installers are actually downloadable. Never offers a tag
/// that only exists or a release whose zip is still being built.
Future<ReleaseInfo?> resolvePublishedRelease({
  required String version,
  required String repo,
  required String current,
  required String os,
  List<String> abis = const [],
  required http.Client client,
  Duration timeout = const Duration(seconds: 12),
  ReleaseInfo? known,
}) async {
  final tagged = known ??
      await fetchReleaseByTag(repo: repo, current: current, version: version, client: client, timeout: timeout);
  if (tagged != null && releaseIsInstallable(tagged, os: os, abis: abis)) return tagged;
  final constructed = releaseFromVersion(version, repo: repo);
  if (await assetsArePublished(constructed, os: os, abis: abis, client: client, timeout: timeout)) {
    return constructed;
  }
  return null;
}

/// R701 / R735–R737: the update check. Prefers molaplan.com/version.json (no API rate limit) but
/// only when that version's Windows/Android file and SHA256SUMS are already published. Otherwise
/// the newest GitHub release that actually has those files is used; tags still building are
/// skipped, never offered, and never shown as an error. If nothing newer is downloadable the
/// outcome is up to date ([CheckResult.pendingNewer] when a newer version is on the way).
/// Never throws: [CheckOutcome.unavailable] means "could not tell".
Future<CheckResult> checkUpdate({
  required String current,
  String repo = 'molaplan1-cloud/molaplan1',
  http.Client? client,
  Duration timeout = const Duration(seconds: 12),
  String os = 'windows',
  List<String> abis = const [],
}) async {
  final c = client ?? http.Client();
  try {
    String? manifest;
    try {
      final r = await c
          .get(
            Uri.parse('$manifestUrl?t=${DateTime.now().millisecondsSinceEpoch ~/ 60000}'),
            headers: {'Cache-Control': 'no-cache'},
          )
          .timeout(timeout);
      if (r.statusCode == 200) manifest = parseManifestVersion(r.body);
    } catch (_) {}

    final releases = await fetchReleases(repo: repo, current: current, client: c, timeout: timeout);
    final best = newestInstallable(releases, os: os, abis: abis);

    if (manifest != null) {
      if (isNewer(manifest, current)) {
        final known = releases.where((r) => SemVer.tryParse(r.tag)?.toString() == manifest).firstOrNull;
        final published = await resolvePublishedRelease(
          version: manifest,
          repo: repo,
          current: current,
          os: os,
          abis: abis,
          client: c,
          timeout: timeout,
          known: known,
        );
        if (published != null) return CheckResult(CheckOutcome.newer, published);
        // Manifest is ahead of the installers (CI still running). Offer the newest complete
        // release if it is still newer than the one installed; otherwise the user is up to date.
        if (best != null && isNewer(best.tag, current)) return CheckResult(CheckOutcome.newer, best);
        return CheckResult(CheckOutcome.upToDate, best, true);
      }
      // Manifest is not newer. A complete GitHub release could still be newer if version.json
      // has not been deployed yet – offer that. Do not offer a tag that is only building.
      if (best != null && isNewer(best.tag, current)) return CheckResult(CheckOutcome.newer, best);
      return CheckResult(CheckOutcome.upToDate, best);
    }

    // molaplan.com could not be reached: GitHub only, and only releases with real assets.
    if (releases.isNotEmpty || best != null) {
      if (best != null && isNewer(best.tag, current)) return CheckResult(CheckOutcome.newer, best);
      final pending = releases.any((r) => !r.draft && isNewer(r.tag, current));
      return CheckResult(CheckOutcome.upToDate, best, pending);
    }
    // The list endpoint failed (rate limit, offline): try /releases/latest, but only if it has files.
    final fallback = await checkLatest(current: current, repo: repo, client: c, timeout: timeout);
    if (fallback.outcome == CheckOutcome.newer &&
        fallback.release != null &&
        !releaseIsInstallable(fallback.release!, os: os, abis: abis)) {
      return CheckResult(CheckOutcome.upToDate, fallback.release, true);
    }
    return fallback;
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
