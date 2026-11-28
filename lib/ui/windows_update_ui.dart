import 'dart:async';

import 'package:material_ui/material_ui.dart';

import '../core/plat.dart';
import '../state/update_state.dart';
import '../update/update_core.dart';
import '../update/windows_update.dart';
import '../version.dart';
import 'app_scope.dart';
import 'update_ui.dart';

/// R702-R712: the Windows self-update screens. The download and checks run in [UpdateState]; this
/// file only talks to the user.

/// "Päivitä nyt": download + verify + unpack with progress, then (after the UAC note if the install
/// folder needs it) hand over to the updater, which restarts Molaplan.
Future<void> runWindowsUpdate(BuildContext context, ReleaseInfo r) async {
  final root = Navigator.of(context, rootNavigator: true).context;
  final st = AppScope.read(root);
  final up = st.update;
  if (!root.mounted) return;
  final nav = Navigator.of(root);
  showDialog<void>(context: root, barrierDismissible: false, builder: (_) => const UpdateProgressDialog());
  StagedUpdate? staged;
  UpdateFailure? fail;
  try {
    staged = await up.prepareWindows(r);
  } catch (e) {
    fail = classifyFailure(e);
  }
  nav.pop();
  if (!root.mounted) return;
  if (fail != null || staged == null) {
    await showUpdateFailure(root, r, fail ?? UpdateFailure('launch', 'no result'));
    return;
  }
  await installStaged(root, staged, askFirst: true);
}

/// Last step: explains the UAC question when the install folder needs it, then starts the updater.
Future<void> installStaged(BuildContext context, StagedUpdate staged, {bool askFirst = false}) async {
  final st = AppScope.read(context);
  final up = st.update;
  if (staged.needsAdmin && askFirst) {
    final go = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        key: const ValueKey('update-uac'),
        icon: const Icon(Icons.admin_panel_settings_outlined, size: 40),
        title: Text(tx(c, 'Windows kysyy luvan', 'Windows will ask for permission')),
        content: Text(
          tx(
            c,
            'Molaplan on asennettu kansioon ${staged.installDir.path}, johon tavallisella käyttäjällä ei ole kirjoitusoikeutta. Kun painat Jatka, Windows kysyy luvan päivityksen asentamiseen. Valitse Kyllä. Jos et anna lupaa, mitään ei muuteta.',
            'Molaplan is installed in ${staged.installDir.path}, which a normal user cannot write to. When you tap Continue, Windows asks for permission to install the update. Choose Yes. If you do not allow it, nothing is changed.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('update-uac-go'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Jatka', 'Continue')),
          ),
        ],
      ),
    );
    if (go != true || !context.mounted) return;
  }
  if (!context.mounted) return;
  // A last, short notice: the window closes in a moment and Molaplan comes back by itself.
  unawaited(
    showDialog<void>(
      context: context,
      barrierDismissible: false,
      builder: (c) => PopScope(
        canPop: false,
        child: AlertDialog(
          key: const ValueKey('update-restarting'),
          title: Text(tx(c, 'Päivitetään…', 'Updating…')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const LinearProgressIndicator(minHeight: 8),
              const SizedBox(height: 12),
              Text(
                tx(
                  c,
                  'Molaplan sulkeutuu hetkeksi ja käynnistyy itse uudelleen uudessa versiossa ${staged.version}. Asetuksesi säilyvät.',
                  'Molaplan closes for a moment and restarts by itself in the new version ${staged.version}. Your settings are kept.',
                ),
              ),
            ],
          ),
        ),
      ),
    ),
  );
  await Future<void>.delayed(const Duration(milliseconds: 700));
  try {
    await up.launchStaged(
      staged,
      beforeExit: () async {
        try {
          await st.saveHistory();
          await st.save();
        } catch (_) {}
      },
    );
  } catch (e) {
    final f = classifyFailure(e);
    if (context.mounted) {
      Navigator.of(context, rootNavigator: true).pop();
      final r = up.available;
      await showUpdateFailure(context, r, f);
    }
  }
}

/// R709: "Asenna automaattisesti": the update is fetched in the background; the user gets a clear
/// 30 second notice (Myöhemmin / Päivitä nyt) before Molaplan restarts. Needing administrator rights
/// never installs unasked – that case falls back to the normal dialog.
Future<bool> autoInstallWindows(BuildContext context, ReleaseInfo r, {Duration countdown = const Duration(seconds: 30)}) async {
  final root = Navigator.of(context, rootNavigator: true).context;
  final up = AppScope.read(root).update;
  StagedUpdate staged;
  try {
    staged = await up.prepareWindows(r);
  } catch (e) {
    final f = classifyFailure(e);
    // Offline is no news: the next check tries again. Anything else is worth telling.
    if (f.kind != 'offline' && f.kind != 'notReady' && root.mounted) {
      showSnack(root, '${_failTitle(root, f)}. ${tx(root, 'Voit yrittää Asetukset-sivun Tarkista päivitykset -napilla.', 'You can try again with Check for updates in Settings.')}', error: true);
    }
    return false;
  }
  if (!root.mounted) return false;
  if (staged.needsAdmin) return false;
  final go = await showDialog<bool>(
    context: root,
    barrierDismissible: false,
    builder: (c) => _CountdownDialog(version: staged.version, seconds: countdown.inSeconds),
  );
  if (go != true || !root.mounted) {
    up.later();
    return true;
  }
  await installStaged(root, staged);
  return true;
}

class _CountdownDialog extends StatefulWidget {
  const _CountdownDialog({required this.version, required this.seconds});
  final String version;
  final int seconds;
  @override
  State<_CountdownDialog> createState() => _CountdownDialogState();
}

class _CountdownDialogState extends State<_CountdownDialog> {
  late int left = widget.seconds;
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      setState(() => left--);
      if (left <= 0) {
        t.cancel();
        Navigator.pop(context, true);
      }
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => AlertDialog(
    key: const ValueKey('update-countdown'),
    icon: const Icon(Icons.system_update, size: 40),
    title: Text(tx(context, 'Päivitys ${widget.version} on valmis', 'Update ${widget.version} is ready')),
    content: Text(
      tx(
        context,
        'Molaplan päivittyy ja käynnistyy uudelleen $left s kuluttua. Asetuksesi säilyvät.',
        'Molaplan updates and restarts in $left s. Your settings are kept.',
      ),
    ),
    actions: [
      TextButton(
        key: const ValueKey('update-countdown-later'),
        onPressed: () => Navigator.pop(context, false),
        child: Text(tx(context, 'Myöhemmin', 'Later')),
      ),
      FilledButton(
        key: const ValueKey('update-countdown-now'),
        onPressed: () => Navigator.pop(context, true),
        child: Text(tx(context, 'Päivitä nyt', 'Update now')),
      ),
    ],
  );
}

class UpdateProgressDialog extends StatelessWidget {
  const UpdateProgressDialog({super.key});
  @override
  Widget build(BuildContext context) {
    final up = AppScope.of(context).update;
    final ph = up.phase;
    final title = switch (ph) {
      UpdatePhase.verifying => tx(context, 'Tarkistetaan…', 'Verifying…'),
      UpdatePhase.extracting => tx(context, 'Puretaan…', 'Unpacking…'),
      _ => tx(context, 'Ladataan päivitystä…', 'Downloading update…'),
    };
    final determinate = ph == UpdatePhase.downloading && up.progress != null;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        key: const ValueKey('update-progress'),
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            LinearProgressIndicator(value: determinate ? up.progress : null, minHeight: 8),
            const SizedBox(height: 12),
            Text(determinate ? '${(up.progress! * 100).round()} %' : ''),
          ],
        ),
      ),
    );
  }
}

String _failTitle(BuildContext c, UpdateFailure f) => switch (f.kind) {
  'offline' => tx(c, 'Päivitystä ei voitu ladata', 'The update could not be downloaded'),
  'notReady' => tx(c, 'Päivitys ei ole vielä ladattavissa', 'The update is not available for download yet'),
  'checksum' => tx(c, 'Lataus oli viallinen', 'The download was corrupted'),
  'disk' => tx(c, 'Päivitystä ei voitu tallentaa levylle', 'The update could not be saved to disk'),
  'extract' => tx(c, 'Päivityksen purku ei onnistunut', 'The update could not be unpacked'),
  'package' => tx(c, 'Ladattu tiedosto ei ole Molaplan-paketti', 'The downloaded file is not a Molaplan package'),
  'launch' => tx(c, 'Päivitysohjelmaa ei saatu käynnistettyä', 'The updater could not be started'),
  'downgrade' => tx(c, 'Vanhempaa versiota ei asenneta', 'An older version is not installed'),
  _ => tx(c, 'Päivitys ei onnistunut', 'The update did not work'),
};

String _failText(BuildContext c, UpdateFailure f) => switch (f.kind) {
  'offline' => tx(
    c,
    'Nettiyhteys ei toiminut. Mitään ei muutettu, ja nykyinen versio toimii entiseen tapaan. Tarkista nettiyhteys ja yritä uudelleen.',
    'The internet connection did not work. Nothing was changed and the current version keeps working. Check the connection and try again.',
  ),
  'notReady' => tx(
    c,
    'Uusi versio on juuri julkaistu, eikä sen tiedostoja ole vielä saatavilla. Yritä uudelleen muutaman minuutin päästä.',
    'The new version has just been published and its files are not available yet. Try again in a few minutes.',
  ),
  'checksum' => tx(
    c,
    'Tiedoston tarkistussumma ei täsmännyt, joten mitään ei asennettu. Yritä hetken päästä uudelleen.',
    'The file checksum did not match, so nothing was installed. Please try again in a moment.',
  ),
  'disk' => tx(
    c,
    'Päivityksen tallennus levylle epäonnistui. Tarkista, että levyllä on vähintään 500 Mt vapaata tilaa ja ettei virustorjunta estä tiedostoja, ja yritä uudelleen. Mitään ei muutettu.',
    'Saving the update to disk failed. Check that the disk has at least 500 MB free and that antivirus is not blocking the files, then try again. Nothing was changed.',
  ),
  'extract' => tx(
    c,
    'Ladattua tiedostoa ei saatu purettua. Mitään ei muutettu. Yritä uudelleen; jos vika toistuu, lataa päivitys julkaisusivulta.',
    'The downloaded file could not be unpacked. Nothing was changed. Try again; if it keeps failing, download the update from the release page.',
  ),
  'package' => tx(
    c,
    'Ladatusta tiedostosta puuttuu Molaplanin ohjelmatiedosto, joten sitä ei asennettu. Mitään ei muutettu.',
    'The downloaded file does not contain the Molaplan program, so it was not installed. Nothing was changed.',
  ),
  'launch' => tx(
    c,
    'Windows tai virustorjunta esti päivitysohjelman käynnistyksen. Mitään ei muutettu. Voit ladata zip-tiedoston julkaisusivulta ja purkaa sen vanhan Molaplan-kansion päälle.',
    'Windows or antivirus stopped the updater from starting. Nothing was changed. You can download the zip from the release page and extract it over the old Molaplan folder.',
  ),
  'downgrade' => tx(
    c,
    'Tarjottu versio ei ole uudempi kuin käytössäsi oleva, joten sitä ei asennettu.',
    'The offered version is not newer than the one you have, so it was not installed.',
  ),
  _ => tx(c, 'Mitään ei muutettu. Yritä uudelleen myöhemmin.', 'Nothing was changed. Try again later.'),
};

bool _retryable(UpdateFailure f) => const {'offline', 'notReady', 'checksum', 'disk', 'extract'}.contains(f.kind);

/// Plain-language failure dialog with "Tekniset tiedot", a retry (when it can help) and the release page.
Future<void> showUpdateFailure(BuildContext context, ReleaseInfo? r, UpdateFailure f) async {
  final st = AppScope.read(context);
  final p = st.update.platform;
  final retry = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('update-failure'),
      icon: const Icon(Icons.error_outline, size: 40),
      title: Text(_failTitle(c, f)),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(_failText(c, f)),
              _TechDetails(f.detail.isEmpty ? f.kind : '${f.kind}: ${f.detail}'),
            ],
          ),
        ),
      ),
      actions: [
        if (r != null)
          TextButton(onPressed: () => p.openUrl(r.pageUrl), child: Text(tx(c, 'Avaa julkaisusivu', 'Open release page'))),
        if (r != null && _retryable(f))
          FilledButton(
            key: const ValueKey('update-failure-retry'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Yritä uudelleen', 'Try again')),
          ),
        TextButton(onPressed: () => Navigator.pop(c, false), child: const Text('OK')),
      ],
    ),
  );
  if (retry == true && r != null && context.mounted) await runWindowsUpdate(context, r);
}

class _TechDetails extends StatelessWidget {
  const _TechDetails(this.text);
  final String text;
  @override
  Widget build(BuildContext context) => Theme(
    data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
    child: ExpansionTile(
      key: const ValueKey('update-tech'),
      tilePadding: EdgeInsets.zero,
      dense: true,
      title: Text(tx(context, 'Tekniset tiedot', 'Technical details'), style: const TextStyle(fontSize: 13)),
      children: [Align(alignment: Alignment.centerLeft, child: SelectableText(text, style: const TextStyle(fontSize: 12)))],
    ),
  );
}

/// R710-R712: on start-up, tells what happened to an update that ran just before (once). On Windows
/// only; [outcome] lets a test inject one.
Future<void> showUpdateOutcome(BuildContext context, {UpdateOutcome? outcome}) async {
  outcome ??= Plat.isWindows ? readUpdateOutcome(running: appVersion) : null;
  if (outcome == null || !context.mounted) return;
  final o = outcome;
  cleanUpdateWork(); // the unpacked files and the downloaded zip are not needed any more (the backup stays)
  if (o.ok) {
    showSnack(
      context,
      tx(
        context,
        'Molaplan on päivitetty versioon ${o.to}. Asetuksesi säilyivät.',
        'Molaplan was updated to version ${o.to}. Your settings were kept.',
      ),
    );
    return;
  }
  final p = AppScope.read(context).update.platform;
  final (title, text) = switch (o.status) {
    'rolled_back' => (
      tx(context, 'Päivitys ei onnistunut – vanha versio palautettiin', 'The update did not work – the old version was restored'),
      tx(
        context,
        'Uusi versio ${o.to} ei käynnistynyt tai sen tiedostoja ei saatu korvattua (esimerkiksi virustorjunta saattoi lukita ne), joten Molaplan palautti edellisen version ${o.from}. Asetuksesi ovat tallessa. Voit yrittää myöhemmin uudelleen.',
        'The new version ${o.to} did not start or its files could not be replaced (antivirus may have locked them), so Molaplan restored the previous version ${o.from}. Your settings are safe. You can try again later.',
      ),
    ),
    'rollback_failed' => (
      tx(context, 'Päivitys ja palautus epäonnistuivat', 'The update and the restore both failed'),
      tx(
        context,
        'Molaplanin tiedostot voivat olla vaiheittain päivittyneet. Lataa uusin Molaplan julkaisusivulta ja pura se vanhan kansion päälle. Asetuksesi eivät häviä.',
        'Molaplan\'s files may be partly updated. Download the latest Molaplan from the release page and extract it over the old folder. Your settings are not lost.',
      ),
    ),
    'elevation_declined' || 'not_writable' => (
      tx(context, 'Päivitystä ei asennettu – lupa puuttui', 'The update was not installed – permission was missing'),
      tx(
        context,
        'Molaplanin kansioon kirjoittaminen vaatii järjestelmänvalvojan luvan, jota ei annettu. Mitään ei muutettu. Yritä uudelleen ja valitse Windowsin kysymykseen Kyllä, tai siirrä Molaplan kansioon, johon sinulla on kirjoitusoikeus, esimerkiksi omiin tiedostoihisi.',
        'Writing to the Molaplan folder needs administrator permission, which was not given. Nothing was changed. Try again and choose Yes when Windows asks, or move Molaplan to a folder you can write to, for example your own files.',
      ),
    ),
    _ => (
      tx(context, 'Päivitys ei valmistunut', 'The update did not finish'),
      tx(
        context,
        'Mitään ei muutettu tai edellinen versio palautettiin. Sulje mahdolliset muut Molaplan-ikkunat ja yritä uudelleen. Jos vika toistuu, lataa päivitys julkaisusivulta.',
        'Nothing was changed, or the previous version was restored. Close any other Molaplan windows and try again. If it keeps failing, download the update from the release page.',
      ),
    ),
  };
  final r = AppScope.read(context).update.available;
  await showDialog<void>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('update-outcome'),
      icon: const Icon(Icons.error_outline, size: 40),
      title: Text(title),
      content: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 480),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(text),
              _TechDetails('${o.status}: ${o.detail}\n${o.log}'),
            ],
          ),
        ),
      ),
      actions: [
        if (r != null)
          TextButton(onPressed: () => p.openUrl(r.pageUrl), child: Text(tx(c, 'Avaa julkaisusivu', 'Open release page'))),
        FilledButton(onPressed: () => Navigator.pop(c), child: const Text('OK')),
      ],
    ),
  );
}

/// R703: Asetukset → the update settings (not in the browser, which updates itself on reload).
class UpdateSettingsSection extends StatelessWidget {
  const UpdateSettingsSection({super.key});

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final up = st.update;
    final checking = up.phase == UpdatePhase.checking;
    final at = st.config.updateCheckedAt;
    String last = '';
    if (at != null) {
      final d = DateTime.fromMillisecondsSinceEpoch(at);
      String two(int n) => n.toString().padLeft(2, '0');
      last = '${d.day}.${d.month}. ${two(d.hour)}:${two(d.minute)}';
    }
    final win = up.platform.os == 'windows';
    final self = up.platform.canSelfUpdate;
    final text = Theme.of(context).textTheme;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 12,
          runSpacing: 4,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('settings-check-updates'),
              onPressed: checking ? null : () => manualUpdateCheck(context),
              icon: checking
                  ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.system_update_alt),
              label: Text(tx(context, 'Tarkista päivitykset', 'Check for updates')),
            ),
            if (last.isNotEmpty)
              Text(
                tx(context, 'Viimeksi tarkistettu $last', 'Last checked $last'),
                key: const ValueKey('update-last-checked'),
                style: text.bodySmall,
              ),
          ],
        ),
        SwitchListTile(
          key: const ValueKey('update-auto-check'),
          contentPadding: EdgeInsets.zero,
          title: Text(tx(context, 'Tarkista päivitykset automaattisesti', 'Check for updates automatically')),
          subtitle: Text(
            win
                ? tx(
                    context,
                    'Käynnistyksen jälkeen ja noin 6 tunnin välein. Näet ilmoituksen, kun uusi versio on saatavilla.',
                    'After start-up and about every 6 hours. You see a notice when a new version is available.',
                  )
                : tx(
                    context,
                    'Käynnistyksen yhteydessä ja säännöllisesti. Näet ilmoituksen, kun uusi versio on saatavilla.',
                    'At start-up and regularly. You see a notice when a new version is available.',
                  ),
          ),
          value: st.config.updateAuto,
          onChanged: st.setUpdateAuto,
        ),
        if (self)
          SwitchListTile(
            key: const ValueKey('update-auto-install'),
            contentPadding: EdgeInsets.zero,
            title: Text(tx(context, 'Asenna päivitykset automaattisesti', 'Install updates automatically')),
            subtitle: Text(
              tx(
                context,
                'Lataa ja asentaa uuden version itse. Ennen uudelleenkäynnistystä näkyy 30 sekunnin ilmoitus, jonka voit siirtää myöhemmäksi. Jos et valitse tätä, painat itse Päivitä nyt.',
                'Downloads and installs the new version by itself. A 30-second notice appears before the restart, and you can postpone it. If this is off, you tap Update now yourself.',
              ),
            ),
            value: st.config.updateAutoInstall,
            onChanged: st.setUpdateAutoInstall,
          ),
      ],
    );
  }
}
