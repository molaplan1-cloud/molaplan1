import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../state/update_state.dart';
import '../update/update_core.dart';
import '../version.dart';
import 'app_scope.dart';
import 'windows_update_ui.dart';

/// Release notes as plain readable text (GitHub markdown without the markup).
String plainNotes(String md) {
  final lines = md
      .replaceAll('\r', '')
      .split('\n')
      .map(
        (l) => l
            .replaceFirst(RegExp(r'^\s{0,3}#{1,6}\s*'), '')
            .replaceFirst(RegExp(r'^\s*[-*+]\s+'), '• ')
            .replaceAll(RegExp(r'\*\*|__|`'), '')
            .replaceAllMapped(RegExp(r'\[([^\]]+)\]\([^)]+\)'), (m) => m[1]!),
      )
      .toList();
  return lines.join('\n').replaceAll(RegExp(r'\n{3,}'), '\n\n').trim();
}

/// Startup, app resume and every 20 min: check (at most once an hour; offline = retry next time) and offer the update. In bridge mode only
/// the non-blocking banner appears, so the bridge keeps working undisturbed.
Future<void> startupUpdateCheck(BuildContext context) async {
  final st = AppScope.read(context);
  // R703: Windows waits a little after start-up so the first screen is never slowed down.
  if (!_startupDelayed && st.update.platform.os == 'windows' && st.update.autoCheck) {
    _startupDelayed = true;
    await Future<void>.delayed(windowsStartupDelay);
    if (!context.mounted) return;
  }
  final r = await st.update.checkOnStartup();
  if (r == null || !context.mounted) return;
  // R709: "Asenna automaattisesti" (Windows, off by default) downloads in the background and gives a notice.
  if (st.update.autoInstallEnabled && st.update.platform.os == 'windows') {
    if (await autoInstallWindows(context, r)) return;
  }
  if (st.config.bridgeMode || !context.mounted) return;
  await showUpdateDialog(context, r);
}

bool _startupDelayed = false;

/// Windows waits this long after start-up before the first automatic check (tests set it to zero).
Duration windowsStartupDelay = const Duration(seconds: 8);

/// Settings button: always asks GitHub, tells the result.
Future<void> manualUpdateCheck(BuildContext context) async {
  final st = AppScope.read(context);
  final r = await st.update.checkNow();
  if (!context.mounted) return;
  switch (r.outcome) {
    case CheckOutcome.newer:
      await showUpdateDialog(context, r.release!, manual: true);
    case CheckOutcome.upToDate:
      showSnack(
        context,
        tx(context, 'Sinulla on uusin versio ($appVersion).', 'You have the latest version ($appVersion).'),
      );
    case CheckOutcome.unavailable:
      showSnack(
        context,
        tx(
          context,
          'Päivityksiä ei voitu tarkistaa juuri nyt. Tarkista nettiyhteys ja yritä myöhemmin.',
          'Could not check for updates right now. Check the internet connection and try again later.',
        ),
        error: true,
      );
  }
}

Future<void> showUpdateDialog(BuildContext context, ReleaseInfo r, {bool manual = false}) async {
  final st = AppScope.read(context);
  final root = Navigator.of(context, rootNavigator: true).context; // t229u: outlives a banner
  final notes = plainNotes(r.notes);
  final choice = await showDialog<String>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.system_update, size: 40),
      title: Text(tx(c, 'Uusi versio ${r.version} on saatavilla', 'Version ${r.version} is available')),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 360),
        child: SingleChildScrollView(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(tx(c, 'Sinulla on nyt versio $appVersion.', 'You have version $appVersion.')),
              if (AppScope.read(c).update.platform.canSelfUpdate) ...[
                const SizedBox(height: 8),
                Text(
                  tx(
                    c,
                    'Molaplan lataa päivityksen, sulkeutuu hetkeksi ja käynnistyy itse uudelleen. Asetuksesi säilyvät.',
                    'Molaplan downloads the update, closes for a moment and restarts by itself. Your settings are kept.',
                  ),
                  key: const ValueKey('update-self-note'),
                ),
              ],
              if (notes.isNotEmpty) ...[
                const SizedBox(height: 12),
                Text(tx(c, 'Mitä uutta:', "What's new:"), style: Theme.of(c).textTheme.titleSmall),
                const SizedBox(height: 4),
                SelectableText(notes, key: const ValueKey('update-notes')),
              ],
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('update-skip'),
          onPressed: () => Navigator.pop(c, 'skip'),
          child: Text(tx(c, 'Ohita tämä versio', 'Skip this version')),
        ),
        TextButton(
          key: const ValueKey('update-later'),
          onPressed: () => Navigator.pop(c, 'later'),
          child: Text(tx(c, 'Myöhemmin', 'Later')),
        ),
        FilledButton.icon(
          key: const ValueKey('update-now'),
          onPressed: () => Navigator.pop(c, 'update'),
          icon: const Icon(Icons.download),
          label: Text(
            AppScope.read(c).update.platform.canSelfUpdate ? tx(c, 'Päivitä nyt', 'Update now') : tx(c, 'Päivitä', 'Update'),
          ),
        ),
      ],
    ),
  );
  if (!root.mounted) return;
  switch (choice) {
    case 'update':
      await runUpdate(root, r);
    case 'skip':
      await st.update.skip(r);
    default:
      st.update.later();
  }
}

/// Download + verify + install (Android) / open (Windows) / release page (others).
Future<void> runUpdate(BuildContext from, ReleaseInfo r) async {
  // t229u: the automatic notice (startup dialog / bridge banner) and Asetukset share this one
  // path. Work on the root navigator's context, which lives as long as the app, so a notice
  // or banner that rebuilds or disappears during the download can never drop the install.
  final context = Navigator.of(from, rootNavigator: true).context;
  final up = AppScope.read(context).update;
  final p = up.platform;
  final asset = pickAsset(r, os: p.os, abis: await p.abis());
  if (!context.mounted) return;
  if (asset == null) {
    await p.openUrl(r.pageUrl);
    return;
  }
  // R702: an installed Windows copy replaces itself (download, verify, unpack, updater, restart).
  if (p.os == 'windows' && p.canSelfUpdate) {
    await runWindowsUpdate(context, r);
    return;
  }
  // A device owner (bridge) installs silently and needs no "unknown sources" permission.
  final owner = p.os == 'android' && await p.deviceOwner();
  if (p.os == 'android' && !owner && !await p.canInstall()) {
    if (!context.mounted) return;
    await _allowInstallsGuide(context);
    return;
  }
  if (!context.mounted) return;
  final nav = Navigator.of(context);
  showDialog<void>(context: context, barrierDismissible: false, builder: (_) => const _ProgressDialog());
  File? f;
  Object? err;
  try {
    f = await up.downloadVerified(r);
  } catch (e) {
    err = e;
  }
  nav.pop();
  if (!context.mounted) return;
  if (err != null || f == null) {
    final bad = err is ChecksumMismatch;
    await showDialog<void>(
      context: context,
      builder: (c) => AlertDialog(
        icon: const Icon(Icons.error_outline, size: 40),
        title: Text(
          bad
              ? tx(c, 'Lataus oli viallinen', 'The download was corrupted')
              : tx(c, 'Lataus ei onnistunut', 'Download failed'),
        ),
        content: Text(
          bad
              ? tx(
                  c,
                  'Tiedoston tarkistussumma ei täsmännyt, joten mitään ei asennettu. Yritä hetken päästä uudelleen.',
                  'The file checksum did not match, so nothing was installed. Please try again in a moment.',
                )
              : tx(
                  c,
                  'Tarkista nettiyhteys ja yritä uudelleen. Voit myös ladata päivityksen julkaisusivulta.',
                  'Check the internet connection and try again. You can also download the update from the release page.',
                ),
        ),
        actions: [
          TextButton(
            onPressed: () => p.openUrl(r.pageUrl),
            child: Text(tx(c, 'Avaa julkaisusivu', 'Open release page')),
          ),
          FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
        ],
      ),
    );
    return;
  }
  if (owner) {
    String res;
    try {
      res = await up.installSilentlyIfOwner(r, f) ?? 'error';
    } catch (e) {
      res = 'error: $e';
    }
    if (context.mounted) {
      showSnack(
        context,
        res.startsWith('started')
            ? tx(
                context,
                'Asennetaan versio ${r.version} – sovellus käynnistyy uudelleen hetken kuluttua.',
                'Installing ${r.version} – the app restarts in a moment.',
              )
            : tx(context, 'Asennus epäonnistui: $res', 'Install failed: $res'),
        error: !res.startsWith('started'),
      );
    }
    return;
  }
  if (p.os == 'android') {
    // t228u: not a device owner -> always the system prompt; every outcome is shown.
    String res;
    try {
      res = await p.installApk(f.path);
    } catch (e) {
      res = 'failed: $e';
    }
    if (context.mounted) await showInstallResult(context, r, res);
    return;
  }
  // Windows: keep it simple and safe, the user replaces the folder themselves.
  final file = f;
  final folder = file.parent.path;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.check_circle_outline, size: 40),
      title: Text(tx(c, 'Päivitys ladattu', 'Update downloaded')),
      content: Text(
        tx(
          c,
          'Tiedosto on tarkistettu ja tallennettu:\n${file.path}\n\nNäin otat sen käyttöön:\n1. Sulje Molaplan.\n2. Pura zip-tiedosto vanhan Molaplan-kansion päälle (tai uuteen kansioon).\n3. Käynnistä molaplan.exe. Asetuksesi säilyvät.',
          'The file is verified and saved:\n${file.path}\n\nTo use it:\n1. Close Molaplan.\n2. Extract the zip over the old Molaplan folder (or into a new folder).\n3. Start molaplan.exe. Your settings are kept.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => p.openUrl(r.pageUrl), child: Text(tx(c, 'Julkaisusivu', 'Release page'))),
        TextButton(onPressed: () => p.openFile(file.path), child: Text(tx(c, 'Avaa zip', 'Open zip'))),
        FilledButton.icon(
          onPressed: () {
            p.openFolder(folder);
            Navigator.pop(c);
          },
          icon: const Icon(Icons.folder_open),
          label: Text(tx(c, 'Avaa kansio', 'Open folder')),
        ),
      ],
    ),
  );
}

/// t228u: what the user sees after the APK was handed to Android.
Future<void> showInstallResult(BuildContext context, ReleaseInfo r, String res) async {
  final p = AppScope.read(context).update.platform;
  if (res == 'needs_permission') return _allowInstallsGuide(context);
  if (res == 'installed' || res == 'superseded') return;
  if (res == 'cancelled') {
    // t240u: a prompt that was swallowed also looks like "cancelled" – offer the retry here.
    final again = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('update-install-cancelled'),
        icon: const Icon(Icons.system_update, size: 40),
        title: Text(tx(c, 'Asennus ei jatkunut', 'The install did not continue')),
        content: Text(
          tx(
            c,
            'Jos perut asennuksen itse, kaikki on kunnossa. Jos Androidin Asenna-ikkunaa ei näkynyt, paina Yritä uudelleen.',
            'If you cancelled it yourself, all is well. If Android\'s Install window did not appear, tap Try again.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Sulje', 'Close'))),
          FilledButton(
            key: const ValueKey('update-retry'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Yritä uudelleen', 'Try again')),
          ),
        ],
      ),
    );
    if (again == true && context.mounted) await runUpdate(context, r);
    return;
  }
  if (res.startsWith('session')) {
    showSnack(
      context,
      tx(context, 'Vahvista asennus Androidin ikkunasta tai ilmoituksesta.', 'Confirm the install in the Android window or notification.'),
    );
    // The session reports a failure asynchronously (InstallResultReceiver -> lastUpdate).
    final since = DateTime.now().millisecondsSinceEpoch - 1000;
    var waiting = false;
    for (var i = 0; i < 15; i++) {
      final last = await p.lastUpdate();
      final parts = (last ?? '').split('|');
      final at = int.tryParse(parts.first) ?? 0;
      final st = parts.length > 1 ? parts.sublist(1).join('|') : '';
      if (at >= since && RegExp(r'^(failed|rejected|error)').hasMatch(st)) {
        res = 'failed: $st';
        break;
      }
      if (at >= since && st == 'installed') return;
      waiting = at >= since && st.startsWith('waiting');
      await Future<void>.delayed(const Duration(seconds: 2));
      if (!context.mounted) return;
    }
    // t240u: still waiting for the user and we are in front – the confirmation did not show.
    if (!res.startsWith('failed') && waiting && context.mounted) {
      final open = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          key: const ValueKey('update-confirm-pending'),
          icon: const Icon(Icons.system_update, size: 40),
          title: Text(tx(c, 'Vahvista päivitys', 'Confirm the update')),
          content: Text(
            tx(
              c,
              'Päivitys ${r.version} odottaa vahvistusta. Paina Avaa asennus (tai napauta ilmoitusta "Molaplan-päivitys valmis").',
              'Update ${r.version} is waiting for your confirmation. Tap Open install (or the "Molaplan-päivitys valmis" notification).',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Myöhemmin', 'Later'))),
            FilledButton(
              key: const ValueKey('update-open-confirm'),
              onPressed: () => Navigator.pop(c, true),
              child: Text(tx(c, 'Avaa asennus', 'Open install')),
            ),
          ],
        ),
      );
      if (open == true && !await p.confirmInstall()) await p.openUrl(r.pageUrl);
      return;
    }
    if (!res.startsWith('failed')) return;
  }
  if (!context.mounted) return;
  final detail = res.replaceFirst(RegExp(r'^failed:\s*'), '');
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('update-install-failed'),
      icon: const Icon(Icons.error_outline, size: 40),
      title: Text(tx(c, 'Asennus ei käynnistynyt', 'The install did not start')),
      content: Text(
        tx(
          c,
          'Android ei aloittanut päivityksen ${r.version} asennusta.\n\nTarkista, että "Salli tästä lähteestä" on päällä Molaplanille, ja paina Päivitä uudelleen. Voit myös ladata APK:n julkaisusivulta.\n\nTieto: $detail',
          'Android did not start installing ${r.version}.\n\nCheck that "Allow from this source" is on for Molaplan and tap Update again. You can also download the APK from the release page.\n\nDetail: $detail',
        ),
      ),
      actions: [
        TextButton(onPressed: () => p.openUrl(r.pageUrl), child: Text(tx(c, 'Avaa julkaisusivu', 'Open release page'))),
        TextButton(
          key: const ValueKey('update-failed-settings'),
          onPressed: () {
            p.openInstallSettings();
            Navigator.pop(c);
          },
          child: Text(tx(c, 'Avaa asetukset', 'Open settings')),
        ),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ],
    ),
  );
}

Future<void> _allowInstallsGuide(BuildContext context) async {
  final p = AppScope.read(context).update.platform;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      icon: const Icon(Icons.security_update_warning, size: 40),
      title: Text(tx(c, 'Salli päivitysten asennus', 'Allow installing updates')),
      content: Text(
        tx(
          c,
          'Android kysyy kerran luvan, jotta Molaplan saa asentaa omat päivityksensä.\n\n1. Paina "Avaa asetukset".\n2. Kytke päälle "Salli tästä lähteestä".\n3. Palaa takaisin ja paina "Päivitä" uudelleen.',
          'Android asks once for permission so Molaplan can install its own updates.\n\n1. Tap "Open settings".\n2. Turn on "Allow from this source".\n3. Come back and tap "Update" again.',
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Peruuta', 'Cancel'))),
        FilledButton.icon(
          key: const ValueKey('update-open-settings'),
          onPressed: () {
            p.openInstallSettings();
            Navigator.pop(c);
          },
          icon: const Icon(Icons.settings),
          label: Text(tx(c, 'Avaa asetukset', 'Open settings')),
        ),
      ],
    ),
  );
}

class _ProgressDialog extends StatelessWidget {
  const _ProgressDialog();
  @override
  Widget build(BuildContext context) {
    final up = AppScope.of(context).update;
    final verifying = up.phase == UpdatePhase.verifying;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(
          verifying
              ? tx(context, 'Tarkistetaan…', 'Verifying…')
              : tx(context, 'Ladataan päivitystä…', 'Downloading update…'),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: verifying ? null : up.progress, minHeight: 8),
            const SizedBox(height: 12),
            Text(up.progress == null || verifying ? '' : '${(up.progress! * 100).round()} %'),
          ],
        ),
      ),
    );
  }
}

/// Non-blocking "update available" strip (used in bridge mode instead of a dialog).
class UpdateBanner extends StatelessWidget {
  const UpdateBanner({super.key});
  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = st.update.pending;
    if (r == null || !st.config.bridgeMode) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Material(
      key: const ValueKey('update-banner'),
      color: cs.secondaryContainer,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
        child: Row(
          children: [
            Icon(Icons.system_update, color: cs.onSecondaryContainer),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                tx(
                  context,
                  'Molaplan ${r.version} on saatavilla. Silta toimii normaalisti.',
                  'Molaplan ${r.version} is available. The bridge keeps working.',
                ),
                style: TextStyle(color: cs.onSecondaryContainer),
              ),
            ),
            TextButton(onPressed: () => showUpdateDialog(context, r), child: Text(tx(context, 'Näytä', 'Show'))),
            IconButton(
              tooltip: tx(context, 'Myöhemmin', 'Later'),
              onPressed: st.update.later,
              icon: const Icon(Icons.close),
            ),
          ],
        ),
      ),
    );
  }
}
