// R256–R262 (t261u/t264u): approved installers.
//  * InstallerHubPage ('Asetukset → Asentaja'): customers give an installer access with the
//    installer's ID and see / revoke who has access; an approved installer sees their own ID (copy,
//    share, QR) and their customers; others can apply; Molaplan admins manage installers.
//  * InstallerGrantPage: ID (typed or scanned) → verified name from the server → scope → confirm.
//  * InstallerAdminPage: search a user by e-mail, grant / revoke the status, applications.
// Everything stays out of the main view.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../sharing/share_api.dart';
import '../sharing/share_core.dart';
import 'account_page.dart';
import 'app_scope.dart';
import 'remote_pages.dart' show canScanQr, scanMolaplanQr;
import 'share_pages.dart';

String _d(DateTime? t) => t == null ? '' : '${t.toLocal().day}.${t.toLocal().month}.${t.toLocal().year}';

/// "Kaikki laitteet · ohjaus + asetukset" for one installer access.
String installerScopeText(BuildContext context, ShareRecord r) {
  final what = r.summary['all'] == true
      ? tx(context, 'Kaikki laitteet', 'All devices')
      : '${r.tiles.length} ${tx(context, 'laitetta', 'devices')}';
  final how = r.preset == SharePreset.full
      ? tx(context, 'ohjaus + asetukset', 'control + settings')
      : tx(context, 'ohjaus', 'control');
  return '$what · $how';
}

// ---------------------------------------------------------------- hub

class InstallerHubPage extends StatefulWidget {
  const InstallerHubPage({super.key, this.scan});

  /// Injectable QR scanner (tests).
  final Future<String?> Function(BuildContext)? scan;

  @override
  State<InstallerHubPage> createState() => _InstallerHubPageState();
}

class _InstallerHubPageState extends State<InstallerHubPage> {
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _refresh());
  }

  Future<void> _refresh() async {
    final st = AppScope.read(context);
    if (!st.account.signedIn) return;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      await st.sharing.refresh();
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _run(Future<void> Function() f, {String? ok}) async {
    try {
      await f();
      if (mounted && ok != null) showSnack(context, ok, kind: SnackKind.success);
    } catch (e) {
      if (mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    }
  }

  Future<void> _revoke(ShareRecord r) async {
    final sh = AppScope.read(context).sharing;
    final ok = await showDialog<bool>(
      context: context,
      builder: (c) => AlertDialog(
        title: Text(tx(c, 'Perutaanko asentajan pääsy?', 'Revoke the installer\'s access?')),
        content: Text(
          tx(
            c,
            '${r.recipientName} ei enää pääse laitteisiisi. Pääsy loppuu heti, kun kotisilta saa tiedon (yleensä saman tien).',
            '${r.recipientName} can no longer reach your devices. Access ends as soon as the home bridge hears of it (usually at once).',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('installer-revoke-ok'),
            onPressed: () => Navigator.pop(c, true),
            child: Text(tx(c, 'Peru pääsy', 'Revoke access')),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _run(() => sh.revoke(r), ok: tx(context, 'Pääsy peruttu', 'Access revoked'));
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sh = st.sharing;
    final text = Theme.of(context).textTheme;
    final info = sh.installerInfo;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Asentaja', 'Installer')),
        actions: [
          IconButton(
            tooltip: tx(context, 'Päivitä', 'Refresh'),
            onPressed: loading ? null : _refresh,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (!st.account.signedIn) ...[
                Text(
                  tx(
                    context,
                    'Asentajan pääsy tarvitsee Molaplan-tilin, jotta asentaja tunnistetaan ja salaus toimii.',
                    'Installer access needs a Molaplan account so the installer can be verified and encryption works.',
                  ),
                ),
                const SizedBox(height: 12),
                FilledButton(
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage())),
                  child: Text(tx(context, 'Kirjaudu tai luo tili', 'Sign in or create an account')),
                ),
              ] else ...[
                Text(
                  tx(
                    context,
                    'Anna asentajalle pääsy laitteisiisi hänen asentajatunnuksellaan (esim. MPL-K7Q-M2X). Molaplan on tarkistanut jokaisen asentajan nimen ja yrityksen. Salasanat ja osoitteet eivät lähde kotoa, ja voit perua pääsyn milloin vain.',
                    'Give an installer access to your devices with their installer ID (e.g. MPL-K7Q-M2X). Molaplan has verified every installer\'s name and company. Passwords and addresses never leave home, and you can revoke access at any time.',
                  ),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerLeft,
                  child: FilledButton.icon(
                    key: const ValueKey('installer-grant'),
                    onPressed: () async {
                      await Navigator.push(context, MaterialPageRoute(builder: (_) => InstallerGrantPage(scan: widget.scan)));
                      if (mounted) setState(() {});
                    },
                    icon: const Icon(Icons.key_outlined),
                    label: Text(tx(context, 'Anna pääsy', 'Give access')),
                  ),
                ),
                if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, key: const ValueKey('installer-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                const SizedBox(height: 20),
                Text(tx(context, 'Asentajat, joilla on pääsy', 'Installers with access'), style: text.titleMedium),
                if (sh.installerAccess.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tx(context, 'Kenelläkään asentajalla ei ole pääsyä.', 'No installer has access.'),
                      key: const ValueKey('installer-access-empty'),
                      style: text.bodySmall,
                    ),
                  ),
                for (final r in sh.installerAccess)
                  Card(
                    child: ListTile(
                      key: ValueKey('installer-access-${r.id}'),
                      leading: const Icon(Icons.verified_user_outlined),
                      title: Text(r.recipientName),
                      subtitle: Text(
                        [
                          if ('${r.summary['installer_id'] ?? ''}'.isNotEmpty) '${r.summary['installer_id']}',
                          installerScopeText(context, r),
                          if (r.status != ShareStatus.active) statusText(context, r),
                        ].join(' · '),
                      ),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('installer-access-menu-${r.id}'),
                        onSelected: (v) async {
                          if (v == 'revoke') {
                            await _revoke(r);
                          } else if (v == 'edit') {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => InstallerGrantPage(edit: r)));
                          }
                        },
                        itemBuilder: (c) => [
                          PopupMenuItem(value: 'edit', child: Text(tx(c, 'Muuta laitteita tai oikeuksia', 'Change devices or rights'))),
                          PopupMenuItem(
                            key: const ValueKey('installer-access-revoke'),
                            value: 'revoke',
                            child: Text(tx(c, 'Peru pääsy', 'Revoke access')),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 24),
                if (info != null && info.active) ...[
                  InstallerIdCard(info: info),
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('installer-customers'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallerPage())),
                      icon: const Icon(Icons.engineering_outlined),
                      label: Text(
                        sh.customers.isEmpty
                            ? tx(context, 'Asiakkaani', 'My customers')
                            : '${tx(context, 'Asiakkaani', 'My customers')} (${sh.customers.length})',
                      ),
                    ),
                  ),
                ] else
                  _ApplySection(info: info),
                if (sh.isAdmin) ...[
                  const SizedBox(height: 20),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('installer-admin'),
                      onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallerAdminPage())),
                      icon: const Icon(Icons.admin_panel_settings_outlined),
                      label: Text(tx(context, 'Asentajien hallinta', 'Manage installers')),
                    ),
                  ),
                ],
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// The approved installer's own card: the ID with copy, share and QR.
class InstallerIdCard extends StatelessWidget {
  const InstallerIdCard({super.key, required this.info});
  final InstallerInfo info;

  String _shareText(BuildContext context) => tx(
    context,
    'Asentajatunnukseni Molaplanissa: ${info.publicId} (${info.label}). Anna minulle pääsy: Molaplan → Asetukset → Asentaja → Anna pääsy.',
    'My Molaplan installer ID: ${info.publicId} (${info.label}). To give me access: Molaplan → Settings → Installer → Give access.',
  );

  Future<void> _share(BuildContext context) async {
    final msg = _shareText(context);
    final enc = Uri.encodeComponent(msg);
    final choice = await showModalBottomSheet<String>(
      context: context,
      builder: (c) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              key: const ValueKey('installer-share-copy'),
              leading: const Icon(Icons.copy),
              title: Text(tx(c, 'Kopioi viesti', 'Copy the message')),
              onTap: () => Navigator.pop(c, 'copy'),
            ),
            ListTile(
              leading: const Icon(Icons.mail_outline),
              title: Text(tx(c, 'Sähköposti', 'E-mail')),
              onTap: () => Navigator.pop(c, 'mailto:?subject=${Uri.encodeComponent('Molaplan')}&body=$enc'),
            ),
            ListTile(
              leading: const Icon(Icons.sms_outlined),
              title: Text(tx(c, 'Tekstiviesti', 'Text message')),
              onTap: () => Navigator.pop(c, 'sms:?body=$enc'),
            ),
            ListTile(
              leading: const Icon(Icons.chat_outlined),
              title: const Text('WhatsApp'),
              onTap: () => Navigator.pop(c, 'https://wa.me/?text=$enc'),
            ),
          ],
        ),
      ),
    );
    if (choice == null || !context.mounted) return;
    if (choice == 'copy') {
      await Clipboard.setData(ClipboardData(text: msg));
      if (context.mounted) showSnack(context, tx(context, 'Viesti kopioitu', 'Message copied'), kind: SnackKind.success);
      return;
    }
    try {
      final ok = await launchUrl(Uri.parse(choice), mode: LaunchMode.externalApplication);
      if (!ok) throw StateError('no app');
    } catch (_) {
      await Clipboard.setData(ClipboardData(text: msg));
      if (context.mounted) {
        showSnack(context, tx(context, 'Sovellusta ei voitu avata – viesti kopioitiin.', 'Could not open the app – the message was copied.'));
      }
    }
  }

  void _qr(BuildContext context) => showDialog<void>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(info.publicId),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            key: const ValueKey('installer-qr'),
            color: Colors.white,
            padding: const EdgeInsets.all(8),
            // Fixed size: the dialog measures intrinsic widths, which QrImageView cannot give.
            child: SizedBox(
              width: 220,
              height: 220,
              child: QrImageView(data: installerLink(info.publicId), size: 220, backgroundColor: Colors.white),
            ),
          ),
          const SizedBox(height: 8),
          Text(
            tx(d, 'Asiakas skannaa: Asetukset → Asentaja → Anna pääsy.', 'The customer scans it: Settings → Installer → Give access.'),
            textAlign: TextAlign.center,
          ),
        ],
      ),
      actions: [TextButton(onPressed: () => Navigator.pop(d), child: Text(tx(d, 'Sulje', 'Close')))],
    ),
  );

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    return Card(
      key: const ValueKey('installer-id-card'),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.verified, color: Theme.of(context).colorScheme.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(tx(context, 'Olet Molaplan-asentaja', 'You are a Molaplan installer'), style: text.titleMedium)),
              ],
            ),
            const SizedBox(height: 4),
            Text(info.label, style: text.bodyMedium),
            const SizedBox(height: 12),
            Text(tx(context, 'Asentajatunnuksesi', 'Your installer ID'), style: text.labelMedium),
            SelectableText(
              info.publicId,
              key: const ValueKey('installer-public-id'),
              style: text.headlineSmall?.copyWith(fontFeatures: const [FontFeature.tabularFigures()], letterSpacing: 1.5),
            ),
            const SizedBox(height: 4),
            Text(
              tx(
                context,
                'Anna tunnus asiakkaalle. Hän avaa sillä pääsyn laitteisiinsa ja näkee nimesi ja yrityksesi Molaplanin vahvistamina.',
                'Give the ID to your customer. They open access to their devices with it and see your name and company as verified by Molaplan.',
              ),
              style: text.bodySmall,
            ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                OutlinedButton.icon(
                  key: const ValueKey('installer-copy'),
                  onPressed: () async {
                    await Clipboard.setData(ClipboardData(text: info.publicId));
                    if (context.mounted) showSnack(context, tx(context, 'Tunnus kopioitu', 'ID copied'), kind: SnackKind.success);
                  },
                  icon: const Icon(Icons.copy, size: 18),
                  label: Text(tx(context, 'Kopioi', 'Copy')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('installer-share'),
                  onPressed: () => _share(context),
                  icon: const Icon(Icons.share_outlined, size: 18),
                  label: Text(tx(context, 'Jaa', 'Share')),
                ),
                OutlinedButton.icon(
                  key: const ValueKey('installer-show-qr'),
                  onPressed: () => _qr(context),
                  icon: const Icon(Icons.qr_code_2, size: 18),
                  label: Text(tx(context, 'QR-koodi', 'QR code')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Not (or no longer) an installer: apply, or see the application's state.
class _ApplySection extends StatelessWidget {
  const _ApplySection({required this.info});
  final InstallerInfo? info;

  Future<void> _apply(BuildContext context) async {
    final sh = AppScope.read(context).sharing;
    final name = TextEditingController(text: sh.displayName);
    final company = TextEditingController();
    final msg = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tx(d, 'Hae asentajaksi', 'Apply to be an installer')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                tx(
                  d,
                  'Molaplan tarkistaa nimesi ja yrityksesi ja myöntää asentajatunnuksen. Saat tiedon sovellukseen.',
                  'Molaplan checks your name and company and gives you an installer ID. You will see the result in the app.',
                ),
              ),
              TextField(
                key: const ValueKey('apply-name'),
                controller: name,
                decoration: InputDecoration(labelText: tx(d, 'Nimesi', 'Your name')),
              ),
              TextField(
                key: const ValueKey('apply-company'),
                controller: company,
                decoration: InputDecoration(
                  labelText: tx(d, 'Yritys', 'Company'),
                  helperText: tx(d, 'esim. Y-tunnus tai Kevytyrittäjä', 'e.g. business ID or sole trader'),
                ),
              ),
              TextField(
                key: const ValueKey('apply-message'),
                controller: msg,
                maxLines: 3,
                decoration: InputDecoration(labelText: tx(d, 'Viesti (valinnainen)', 'Message (optional)')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tx(d, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('apply-send'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tx(d, 'Lähetä hakemus', 'Send application')),
          ),
        ],
      ),
    );
    if (ok != true || !context.mounted) return;
    if (name.text.trim().isEmpty) {
      showSnack(context, tx(context, 'Kirjoita nimesi.', 'Type your name.'), kind: SnackKind.error);
      return;
    }
    try {
      await sh.applyInstaller(name: name.text, company: company.text, message: msg.text);
      if (context.mounted) showSnack(context, tx(context, 'Hakemus lähetetty', 'Application sent'), kind: SnackKind.success);
    } catch (e) {
      if (context.mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final sh = AppScope.of(context).sharing;
    final text = Theme.of(context).textTheme;
    final a = sh.application;
    return ExpansionTile(
      key: const ValueKey('installer-apply-section'),
      tilePadding: EdgeInsets.zero,
      initiallyExpanded: info != null || a != null,
      title: Text(tx(context, 'Oletko asentaja?', 'Are you an installer?')),
      children: [
        if (info != null && !info!.active)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Text(
              tx(
                context,
                'Asentajan tilasi (${info!.publicId}) on poistettu, eikä asiakkaiden pääsyjä voi käyttää. Kysy lisää Molaplanilta: molaplan1@gmail.com.',
                'Your installer status (${info!.publicId}) was removed and customer access cannot be used. Ask Molaplan: molaplan1@gmail.com.',
              ),
              key: const ValueKey('installer-revoked'),
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        Text(
          tx(
            context,
            'Asentajana näet asiakkaidesi laitteet, tilan ja hälytykset sillä laajuudella kuin asiakas sallii. Asentajan tilan myöntää Molaplan.',
            'As an installer you see your customers\' devices, status and alarms as far as each customer allows. Molaplan grants the installer status.',
          ),
          style: text.bodySmall,
        ),
        const SizedBox(height: 8),
        if (a != null && a.status == 'new')
          Row(
            children: [
              Expanded(
                child: Text(
                  tx(context, 'Hakemus lähetetty ${_d(a.created)} – odottaa käsittelyä.', 'Application sent ${_d(a.created)} – waiting for review.'),
                  key: const ValueKey('apply-pending'),
                ),
              ),
              TextButton(
                onPressed: () => sh.withdrawApplication().catchError((Object e) {
                  if (context.mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
                }),
                child: Text(tx(context, 'Peru hakemus', 'Withdraw')),
              ),
            ],
          )
        else ...[
          if (a != null && a.status == 'declined')
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text(tx(context, 'Edellistä hakemusta ei hyväksytty.', 'The previous application was not approved.'), style: text.bodySmall),
            ),
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              key: const ValueKey('installer-apply'),
              onPressed: () => _apply(context),
              icon: const Icon(Icons.badge_outlined),
              label: Text(tx(context, 'Hae asentajaksi', 'Apply to be an installer')),
            ),
          ),
        ],
        const SizedBox(height: 8),
      ],
    );
  }
}

// ---------------------------------------------------------------- grant / change

class InstallerGrantPage extends StatefulWidget {
  const InstallerGrantPage({super.key, this.edit, this.scan, this.initialId});
  final ShareRecord? edit;
  final Future<String?> Function(BuildContext)? scan;
  final String? initialId;
  @override
  State<InstallerGrantPage> createState() => _InstallerGrantPageState();
}

class _InstallerGrantPageState extends State<InstallerGrantPage> {
  final id = TextEditingController();
  InstallerInfo? found;
  bool all = true;
  bool settings = false;
  final selected = <String>{};
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      all = e.summary['all'] == true;
      settings = e.preset == SharePreset.full;
      selected.addAll(e.tiles.map((t) => t.id));
    }
    if (widget.initialId != null) {
      id.text = widget.initialId!;
      WidgetsBinding.instance.addPostFrameCallback((_) => _find());
    }
  }

  @override
  void dispose() {
    id.dispose();
    super.dispose();
  }

  Future<void> _find() async {
    final sh = AppScope.read(context).sharing;
    final n = normalizeInstallerId(id.text);
    setState(() {
      error = null;
      found = null;
    });
    if (n == null) {
      setState(() => error = tx(context, 'Tunnus on muotoa MPL-XXX-XXX.', 'The ID looks like MPL-XXX-XXX.'));
      return;
    }
    id.text = n;
    setState(() => busy = true);
    try {
      final who = await sh.findInstaller(n);
      if (!mounted) return;
      setState(() {
        found = who;
        if (who == null) {
          error = tx(
            context,
            'Tunnuksella ei löytynyt hyväksyttyä asentajaa. Tarkista tunnus asentajalta.',
            'No approved installer has this ID. Check the ID with the installer.',
          );
        }
      });
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  Future<void> _scan() async {
    final raw = await (widget.scan ?? scanMolaplanQr)(context);
    if (raw == null || !mounted) return;
    id.text = raw;
    await _find();
  }

  Future<void> _go() async {
    final st = AppScope.read(context);
    final edit = widget.edit;
    final name = edit?.recipientName ?? found!.label;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(edit == null ? tx(d, 'Annetaanko pääsy?', 'Give access?') : tx(d, 'Tallennetaanko muutokset?', 'Save the changes?')),
        content: Text(
          [
            name,
            if (found != null) found!.publicId,
            all ? tx(d, 'Kaikki laitteet (myös myöhemmin lisättävät)', 'All devices (also ones added later)') : '${selected.length} ${tx(d, 'laitetta', 'devices')}',
            settings ? tx(d, 'Saa ohjata ja muuttaa asetuksia', 'May control and change settings') : tx(d, 'Saa ohjata, ei muuttaa asetuksia', 'May control, not change settings'),
            tx(d, 'Voit perua pääsyn milloin vain.', 'You can revoke access at any time.'),
          ].join('\n'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tx(d, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('installer-confirm-ok'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(edit == null ? tx(d, 'Anna pääsy', 'Give access') : tx(d, 'Tallenna', 'Save')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    setState(() {
      busy = true;
      error = null;
    });
    try {
      if (edit != null) {
        await st.sharing.changeInstaller(edit, allDevices: all, tileIds: selected, settings: settings);
      } else {
        await st.sharing.grantInstaller(found!, allDevices: all, tileIds: selected, settings: settings);
      }
      if (!mounted) return;
      showSnack(
        context,
        edit == null ? tx(context, 'Pääsy annettu: $name', 'Access given: $name') : tx(context, 'Tallennettu', 'Saved'),
        kind: SnackKind.success,
      );
      Navigator.pop(context);
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    final edit = widget.edit;
    final tiles = shareableTiles(st.config);
    final ready = edit != null || found != null;
    return Scaffold(
      appBar: AppBar(title: Text(edit == null ? tx(context, 'Anna pääsy asentajalle', 'Give an installer access') : edit.recipientName)),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (edit == null) ...[
                Text(tx(context, 'Asentajan tunnus', 'Installer ID'), style: text.titleMedium),
                const SizedBox(height: 6),
                Row(
                  children: [
                    Expanded(
                      child: TextField(
                        key: const ValueKey('installer-id'),
                        controller: id,
                        textCapitalization: TextCapitalization.characters,
                        decoration: const InputDecoration(hintText: 'MPL-XXX-XXX'),
                        onSubmitted: (_) => _find(),
                      ),
                    ),
                    const SizedBox(width: 8),
                    FilledButton(
                      key: const ValueKey('installer-find'),
                      onPressed: busy ? null : _find,
                      child: Text(tx(context, 'Hae', 'Find')),
                    ),
                  ],
                ),
                if (canScanQr || widget.scan != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton.icon(
                      key: const ValueKey('installer-scan'),
                      onPressed: busy ? null : _scan,
                      icon: const Icon(Icons.qr_code_scanner),
                      label: Text(tx(context, 'Skannaa asentajan QR-koodi', 'Scan the installer\'s QR code')),
                    ),
                  ),
                ],
                if (found != null) ...[
                  const SizedBox(height: 12),
                  Card(
                    key: const ValueKey('installer-found'),
                    child: ListTile(
                      leading: Icon(Icons.verified, color: Theme.of(context).colorScheme.primary),
                      title: Text(found!.name),
                      subtitle: Text(
                        [
                          if (found!.company.isNotEmpty) found!.company,
                          found!.publicId,
                          tx(context, 'Molaplanin vahvistama asentaja', 'Installer verified by Molaplan'),
                        ].join('\n'),
                      ),
                      isThreeLine: true,
                    ),
                  ),
                ],
              ],
              if (busy) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (ready) ...[
                const SizedBox(height: 16),
                Text(tx(context, 'Mihin asentaja pääsee?', 'What can the installer reach?'), style: text.titleMedium),
                const SizedBox(height: 8),
                SegmentedButton<bool>(
                  key: const ValueKey('installer-scope'),
                  segments: [
                    ButtonSegment(value: true, label: Text(tx(context, 'Kaikki laitteet', 'All devices'))),
                    ButtonSegment(value: false, label: Text(tx(context, 'Valitut laitteet', 'Selected devices'))),
                  ],
                  selected: {all},
                  onSelectionChanged: (v) => setState(() => all = v.first),
                ),
                if (all)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(
                      tx(context, '${tiles.length} laitetta nyt, myöhemmin lisättävät tulevat mukaan.', '${tiles.length} devices now; ones added later are included.'),
                      style: text.bodySmall,
                    ),
                  )
                else
                  for (final t in tiles)
                    CheckboxListTile(
                      key: ValueKey('installer-tile-${t.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: selected.contains(t.id),
                      title: Text(t.title),
                      onChanged: (v) => setState(() => v == true ? selected.add(t.id) : selected.remove(t.id)),
                    ),
                const SizedBox(height: 8),
                SwitchListTile(
                  key: const ValueKey('installer-settings'),
                  contentPadding: EdgeInsets.zero,
                  value: settings,
                  title: Text(tx(context, 'Saa muuttaa asetuksia', 'May change settings')),
                  subtitle: Text(
                    tx(
                      context,
                      'Lämpötilat, toimintatilat ja muut asetukset. Pois päältä: asentaja voi ohjata ja katsoa tilaa.',
                      'Temperatures, modes and other settings. Off: the installer can control and see the status.',
                    ),
                  ),
                  onChanged: (v) => setState(() => settings = v),
                ),
              ],
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, key: const ValueKey('installer-grant-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (ready) ...[
                const SizedBox(height: 16),
                SizedBox(
                  height: 52,
                  child: FilledButton.icon(
                    key: const ValueKey('installer-confirm'),
                    onPressed: busy || (!all && selected.isEmpty) || tiles.isEmpty ? null : _go,
                    icon: const Icon(Icons.check),
                    label: Text(edit == null ? tx(context, 'Anna pääsy', 'Give access') : tx(context, 'Tallenna', 'Save')),
                  ),
                ),
                if (tiles.isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(tx(context, 'Sinulla ei ole vielä jaettavia laitteita.', 'You have no shareable devices yet.'), style: text.bodySmall),
                  ),
                const SizedBox(height: 12),
                Text(
                  tx(
                    context,
                    'Kotisilta tarkistaa jokaisen pyynnön oikeudet. Laitteiden salasanat ja osoitteet eivät lähde kotoa.',
                    'The home bridge checks the rights of every request. Device passwords and addresses never leave home.',
                  ),
                  style: text.bodySmall,
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------- admin

class InstallerAdminPage extends StatefulWidget {
  const InstallerAdminPage({super.key});
  @override
  State<InstallerAdminPage> createState() => _InstallerAdminPageState();
}

class _InstallerAdminPageState extends State<InstallerAdminPage> {
  List<InstallerInfo> installers = const [];
  List<InstallerApplication> applications = const [];
  List<AdminUser> found = const [];
  final search = TextEditingController();
  bool loading = false;
  String? error;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
  }

  @override
  void dispose() {
    search.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final sh = AppScope.read(context).sharing;
    setState(() {
      loading = true;
      error = null;
    });
    try {
      final r = await Future.wait([sh.adminInstallers(), sh.adminApplications()]);
      if (!mounted) return;
      setState(() {
        installers = r[0] as List<InstallerInfo>;
        applications = r[1] as List<InstallerApplication>;
      });
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    } finally {
      if (mounted) setState(() => loading = false);
    }
  }

  Future<void> _search() async {
    final sh = AppScope.read(context).sharing;
    if (search.text.trim().length < 3) {
      setState(() => error = tx(context, 'Kirjoita vähintään 3 merkkiä sähköpostista.', 'Type at least 3 characters of the e-mail.'));
      return;
    }
    try {
      final r = await sh.adminFindUsers(search.text);
      if (mounted) {
        setState(() {
          found = r;
          error = r.isEmpty ? tx(context, 'Käyttäjää ei löytynyt.', 'No user found.') : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    }
  }

  Future<void> _grant({required String email, String name = '', String company = '', String note = ''}) async {
    final sh = AppScope.read(context).sharing;
    final n = TextEditingController(text: name), c = TextEditingController(text: company), no = TextEditingController(text: note);
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tx(d, 'Asentajan tila', 'Installer status')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(email),
              TextField(
                key: const ValueKey('admin-grant-name'),
                controller: n,
                decoration: InputDecoration(labelText: tx(d, 'Vahvistettu nimi', 'Verified name')),
              ),
              TextField(
                key: const ValueKey('admin-grant-company'),
                controller: c,
                decoration: InputDecoration(
                  labelText: tx(d, 'Yritys', 'Company'),
                  helperText: tx(d, 'esim. Kevytyrittäjä', 'e.g. sole trader'),
                ),
              ),
              TextField(
                key: const ValueKey('admin-grant-note'),
                controller: no,
                maxLines: 2,
                decoration: InputDecoration(labelText: tx(d, 'Muistiinpano (vain ylläpito)', 'Note (admins only)')),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tx(d, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('admin-grant-ok'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tx(d, 'Myönnä', 'Grant')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    if (n.text.trim().isEmpty) {
      showSnack(context, tx(context, 'Nimi puuttuu.', 'The name is missing.'), kind: SnackKind.error);
      return;
    }
    try {
      final r = await sh.adminGrant(email: email, name: n.text, company: c.text, note: no.text);
      if (mounted) showSnack(context, tx(context, 'Asentaja ${r.label}: ${r.publicId}', 'Installer ${r.label}: ${r.publicId}'), kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    }
  }

  Future<void> _revoke(InstallerInfo i) async {
    final sh = AppScope.read(context).sharing;
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(tx(d, 'Poistetaanko asentajan tila?', 'Remove the installer status?')),
        content: Text(
          tx(
            d,
            '${i.label} (${i.publicId}) menettää asentajan tilan, ja kaikki asiakkaiden antamat pääsyt (${i.customers}) katkeavat heti. Tunnus säilyy, jos tila myönnetään myöhemmin uudelleen.',
            '${i.label} (${i.publicId}) loses the installer status and all customer access (${i.customers}) ends at once. The ID stays if the status is granted again later.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(tx(d, 'Peruuta', 'Cancel'))),
          FilledButton(
            key: const ValueKey('admin-revoke-ok'),
            onPressed: () => Navigator.pop(d, true),
            child: Text(tx(d, 'Poista tila', 'Remove status')),
          ),
        ],
      ),
    );
    if (ok != true || !mounted) return;
    try {
      await sh.adminRevoke(i.userId);
      if (mounted) showSnack(context, tx(context, 'Asentajan tila poistettu', 'Installer status removed'), kind: SnackKind.success);
      await _load();
    } catch (e) {
      if (mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    }
  }

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final open = applications.where((a) => a.status == 'new').toList();
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Asentajien hallinta', 'Manage installers')),
        actions: [IconButton(tooltip: tx(context, 'Päivitä', 'Refresh'), onPressed: loading ? null : _load, icon: const Icon(Icons.refresh))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 720),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(
                  context,
                  'Myönnä asentajan tila vain henkilölle, jonka nimen ja yrityksen olet tarkistanut. Sama hallinta on myös osoitteessa molaplan.com/tilaa/hallinta (Asentajat).',
                  'Grant the installer status only to someone whose name and company you have checked. The same tools are at molaplan.com/tilaa/hallinta (Installers).',
                ),
                style: text.bodySmall,
              ),
              if (loading) const Padding(padding: EdgeInsets.only(top: 8), child: LinearProgressIndicator()),
              if (error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(error!, key: const ValueKey('admin-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ),
              const SizedBox(height: 16),
              Text(tx(context, 'Hae käyttäjä sähköpostilla', 'Find a user by e-mail'), style: text.titleMedium),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      key: const ValueKey('admin-search'),
                      controller: search,
                      keyboardType: TextInputType.emailAddress,
                      onSubmitted: (_) => _search(),
                      decoration: InputDecoration(hintText: tx(context, 'nimi@esimerkki.fi', 'name@example.com')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  FilledButton(key: const ValueKey('admin-search-go'), onPressed: _search, child: Text(tx(context, 'Hae', 'Find'))),
                ],
              ),
              for (final u in found)
                ListTile(
                  key: ValueKey('admin-user-${u.email}'),
                  contentPadding: EdgeInsets.zero,
                  title: Text(u.email),
                  subtitle: Text(
                    [
                      if (u.name.isNotEmpty) u.name,
                      if (!u.hasApp) tx(context, 'ei ole vielä avannut sovellusta', 'has not opened the app yet'),
                      if (u.installerStatus == 'active') '${tx(context, 'asentaja', 'installer')} ${u.publicId}',
                      if (u.installerStatus == 'revoked') '${tx(context, 'tila poistettu', 'status removed')} ${u.publicId}',
                    ].join(' · '),
                  ),
                  trailing: FilledButton.tonal(
                    key: ValueKey('admin-user-grant-${u.email}'),
                    onPressed: () {
                      final ex = installers.where((i) => i.userId == u.userId).firstOrNull;
                      _grant(email: u.email, name: ex?.name ?? u.name, company: ex?.company ?? '', note: ex?.note ?? '');
                    },
                    child: Text(u.installerStatus == 'active' ? tx(context, 'Muokkaa', 'Edit') : tx(context, 'Myönnä', 'Grant')),
                  ),
                ),
              const SizedBox(height: 20),
              Text('${tx(context, 'Hakemukset', 'Applications')} (${open.length})', style: text.titleMedium),
              if (open.isEmpty) Text(tx(context, 'Ei avoimia hakemuksia.', 'No open applications.'), style: text.bodySmall),
              for (final a in open)
                Card(
                  child: Padding(
                    key: ValueKey('admin-application-${a.id}'),
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('${a.name}${a.company.isEmpty ? '' : ' · ${a.company}'}', style: text.titleSmall),
                        Text('${a.email} · ${_d(a.created)}', style: text.bodySmall),
                        if (a.message.isNotEmpty) Text(a.message),
                        const SizedBox(height: 6),
                        Wrap(
                          spacing: 8,
                          children: [
                            FilledButton(
                              key: ValueKey('admin-application-approve-${a.id}'),
                              onPressed: () => _grant(email: a.email, name: a.name, company: a.company),
                              child: Text(tx(context, 'Hyväksy', 'Approve')),
                            ),
                            TextButton(
                              onPressed: () async {
                                try {
                                  await AppScope.read(context).sharing.adminDecline(a.id);
                                  await _load();
                                } catch (e) {
                                  if (context.mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
                                }
                              },
                              child: Text(tx(context, 'Hylkää', 'Decline')),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 20),
              Text('${tx(context, 'Asentajat', 'Installers')} (${installers.length})', style: text.titleMedium),
              for (final i in installers)
                Card(
                  child: ListTile(
                    key: ValueKey('admin-installer-${i.publicId}'),
                    leading: Icon(i.active ? Icons.verified_user_outlined : Icons.block, color: i.active ? null : Theme.of(context).colorScheme.error),
                    title: Text('${i.label} · ${i.publicId}'),
                    subtitle: Text(
                      [
                        i.email,
                        i.active ? '${i.customers} ${tx(context, 'asiakasta', 'customers')}' : tx(context, 'tila poistettu', 'status removed'),
                        if (i.note.isNotEmpty) i.note,
                      ].join(' · '),
                    ),
                    trailing: PopupMenuButton<String>(
                      key: ValueKey('admin-installer-menu-${i.publicId}'),
                      onSelected: (v) => v == 'revoke' ? _revoke(i) : _grant(email: i.email, name: i.name, company: i.company, note: i.note),
                      itemBuilder: (c) => [
                        PopupMenuItem(value: 'edit', child: Text(i.active ? tx(c, 'Muokkaa', 'Edit') : tx(c, 'Myönnä uudelleen', 'Grant again'))),
                        if (i.active)
                          PopupMenuItem(
                            key: const ValueKey('admin-installer-revoke'),
                            value: 'revoke',
                            child: Text(tx(c, 'Poista asentajan tila', 'Remove installer status')),
                          ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
