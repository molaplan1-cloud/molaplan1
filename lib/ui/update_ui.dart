import 'dart:io';

import 'package:material_ui/material_ui.dart';

import '../state/update_state.dart';
import '../update/update_core.dart';
import '../version.dart';
import 'app_scope.dart';

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
  final r = await st.update.checkOnStartup();
  if (r == null || !context.mounted || st.config.bridgeMode) return;
  await showUpdateDialog(context, r);
}

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
          label: Text(tx(c, 'Päivitä', 'Update')),
        ),
      ],
    ),
  );
  if (!context.mounted) return;
  switch (choice) {
    case 'update':
      await runUpdate(context, r);
    case 'skip':
      await st.update.skip(r);
    default:
      st.update.later();
  }
}

/// Download + verify + install (Android) / open (Windows) / release page (others).
Future<void> runUpdate(BuildContext context, ReleaseInfo r) async {
  final up = AppScope.read(context).update;
  final p = up.platform;
  final asset = pickAsset(r, os: p.os, abis: await p.abis());
  if (!context.mounted) return;
  if (asset == null) {
    await p.openUrl(r.pageUrl);
    return;
  }
  if (p.os == 'android' && !await p.canInstall()) {
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
  if (p.os == 'android') {
    try {
      await p.installApk(f.path);
    } catch (_) {
      if (context.mounted) await _allowInstallsGuide(context);
    }
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
