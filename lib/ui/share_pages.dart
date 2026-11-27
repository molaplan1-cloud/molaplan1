// R215–R217 (t215u): 'Jakaminen' – share devices or a whole view, invites, codes, and the
// installer's customer list. The main path is short; per-tile rights and the ntfy notice are under
// 'Edistyneet'. R256–R262: installer access (by installer ID) lives in installer_pages.dart.
import 'dart:async';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import '../remote/protocol.dart';
import '../sharing/share_api.dart';
import '../sharing/share_core.dart';
import 'account_nudge.dart';
import 'app_scope.dart';

String shareErrorText(BuildContext context, Object e) {
  if (e is ShareError) {
    return switch (e.problem) {
      ShareProblem.notFound when e.detail.startsWith('email:') => tx(
        context,
        'Sähköpostilla ei ole Molaplan-tiliä.',
        'There is no Molaplan account with that e-mail.',
      ),
      ShareProblem.notFound when e.detail.contains('@') => tx(
        context,
        'Osoitteella ei löytynyt Molaplan-käyttäjää. Hänen pitää kirjautua Molaplan 0.9:ään kerran – tai lähetä hänelle kutsukoodi.',
        'No Molaplan user with that address. They need to sign in to Molaplan 0.9 once – or send them an invite code.',
      ),
      ShareProblem.notFound when e.detail.contains('tiles') => tx(
        context,
        'Valituissa ei ole jaettavia laitteita (termostaatteja ei voi vielä jakaa).',
        'Nothing shareable selected (thermostats cannot be shared yet).',
      ),
      ShareProblem.notFound => tx(context, 'Kutsua ei enää ole.', 'The invite no longer exists.'),
      ShareProblem.noKey => tx(
        context,
        'Avaa ensin tilin salaukset tällä laitteella (Tili → Avaa salasanalla). Jakaminen käyttää tilin avainta.',
        'Unlock the account secrets on this device first (Account → Unlock with password). Sharing uses the account key.',
      ),
      ShareProblem.notInstaller => tx(
        context,
        'Tämä on asentajan kutsu, ja sen voi käyttää vain Molaplanin hyväksymä asentaja (Asetukset → Asentaja → Hae asentajaksi).',
        'This invite is for an installer and only an installer approved by Molaplan can use it (Settings → Installer → Apply).',
      ),
      ShareProblem.notAdmin => tx(context, 'Vain Molaplanin ylläpito voi tehdä tämän.', 'Only Molaplan admins can do this.'),
      ShareProblem.badInstallerId => tx(context, 'Tunnus on muotoa MPL-XXX-XXX.', 'The ID looks like MPL-XXX-XXX.'),
      ShareProblem.badCode => tx(context, 'Koodi on väärä, vanhentunut tai jo käytetty.', 'The code is wrong, expired or already used.'),
      ShareProblem.noBridge => tx(
        context,
        'Kotisilta ei vastaa. Jakaminen tarvitsee kotisillan (Etäkäyttö), koska oikeudet valvotaan siellä.',
        'The home bridge does not answer. Sharing needs the home bridge (Remote access) – permissions are enforced there.',
      ),
      ShareProblem.bridgeOld => tx(
        context,
        'Kotisilta on vanha eikä osaa jakamista. Päivitä silta (Etäkäyttö → Päivitä silta).',
        'The home bridge is too old for sharing. Update it (Remote access → Update bridge).',
      ),
      ShareProblem.offline => tx(context, 'Ei yhteyttä Molaplan-tiliin.', 'No connection to the Molaplan account.'),
      ShareProblem.server => tx(context, 'Tilipalvelu ei hyväksynyt pyyntöä: ${e.detail}', 'The account service refused: ${e.detail}'),
    };
  }
  if (e is RemoteUnavailable) {
    return switch (e.reason) {
      'bridge_offline' => tx(context, 'Kodin silta ei ole yhteydessä.', 'The home bridge is offline.'),
      'not_paired' => tx(context, 'Jako on peruttu.', 'The share was revoked.'),
      'timeout' => tx(context, 'Kotisilta ei vastaa.', 'The home bridge does not answer.'),
      _ => tx(context, 'Ei yhteyttä.', 'No connection.'),
    };
  }
  if (e is RemoteDeviceError && e.message.contains('Ei oikeutta')) {
    return tx(context, 'Ei oikeutta tähän toimintoon.', 'Not allowed.');
  }
  return '$e';
}

String presetText(BuildContext context, SharePreset p) => switch (p) {
  SharePreset.view => tx(context, 'Vain katselu', 'View only'),
  SharePreset.control => tx(context, 'Ohjaus', 'Control'),
  SharePreset.full => tx(context, 'Täysi (ohjaus + asetukset)', 'Full (control + settings)'),
};

String statusText(BuildContext context, ShareRecord r) => switch (r.status) {
  ShareStatus.pending when r.recipientId == null => tx(context, 'Koodi odottaa käyttöä', 'Code not used yet'),
  ShareStatus.pending => tx(context, 'Odottaa hyväksyntää', 'Waiting for acceptance'),
  ShareStatus.claimed => tx(context, 'Vahvistetaan…', 'Being confirmed…'),
  ShareStatus.active => tx(context, 'Käytössä', 'Active'),
  ShareStatus.declined => tx(context, 'Hylätty', 'Declined'),
  ShareStatus.revoked => tx(context, 'Peruttu', 'Revoked'),
};

class SharingPage extends StatefulWidget {
  const SharingPage({super.key});
  @override
  State<SharingPage> createState() => _SharingPageState();
}

class _SharingPageState extends State<SharingPage> {
  String? error;
  bool loading = false;

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

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sh = st.sharing;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(
        title: Text(tx(context, 'Jakaminen', 'Sharing')),
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
                const NeedsAccountNote(
                  reasonFi: 'Jakaminen tarvitsee Molaplan-tilin, jotta kutsut löytävät perille ja salaus toimii.',
                  reasonEn: 'Sharing needs a Molaplan account so invites can reach people and encryption works.',
                ),
              ] else ...[
                Text(
                  tx(
                    context,
                    'Anna perheenjäsenelle, naapurille tai asentajalle pääsy valitsemiisi laitteisiin. Salasanat ja osoitteet eivät lähde kotoa, ja voit perua jaon milloin vain.',
                    'Give a family member, neighbour or installer access to the devices you choose. Passwords and addresses never leave home, and you can revoke at any time.',
                  ),
                  style: text.bodyMedium,
                ),
                const SizedBox(height: 12),
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  children: [
                    FilledButton.icon(
                      key: const ValueKey('share-new'),
                      onPressed: () async {
                        await Navigator.push(context, MaterialPageRoute(builder: (_) => const ShareCreatePage()));
                        if (mounted) setState(() {});
                      },
                      icon: const Icon(Icons.share_outlined),
                      label: Text(tx(context, 'Jaa laitteita', 'Share devices')),
                    ),
                    OutlinedButton.icon(
                      key: const ValueKey('share-claim'),
                      onPressed: () => claimDialog(context),
                      icon: const Icon(Icons.vpn_key_outlined),
                      label: Text(tx(context, 'Käytä kutsukoodia', 'Use an invite code')),
                    ),
                  ],
                ),
                if (loading) const Padding(padding: EdgeInsets.only(top: 12), child: LinearProgressIndicator()),
                if (error != null) ...[
                  const SizedBox(height: 12),
                  Text(error!, key: const ValueKey('share-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
                ],
                if (sh.invites.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tx(context, 'Kutsut sinulle', 'Invites for you'), style: text.titleMedium),
                  for (final r in sh.invites)
                    Card(
                      key: ValueKey('invite-${r.id}'),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '${r.ownerName}: ${r.label.isEmpty ? tx(context, 'laitteita', 'devices') : r.label}',
                              style: text.titleSmall,
                            ),
                            Text(
                              '${presetText(context, r.preset)} · ${r.tiles.map((t) => t.title).join(', ')}',
                              style: text.bodySmall,
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                FilledButton(
                                  key: ValueKey('invite-accept-${r.id}'),
                                  onPressed: () => _run(() => sh.accept(r), ok: tx(context, 'Hyväksytty', 'Accepted')),
                                  child: Text(tx(context, 'Hyväksy', 'Accept')),
                                ),
                                const SizedBox(width: 8),
                                TextButton(
                                  key: ValueKey('invite-decline-${r.id}'),
                                  onPressed: () => _run(() => sh.leave(r)),
                                  child: Text(tx(context, 'Hylkää', 'Decline')),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
                if (sh.activeToMe.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  Text(tx(context, 'Jaettu minulle', 'Shared with me'), style: text.titleMedium),
                  for (final r in sh.activeToMe)
                    Card(
                      child: ListTile(
                        key: ValueKey('shared-${r.id}'),
                        leading: const Icon(Icons.home_outlined),
                        title: Text(r.label.isEmpty ? r.ownerName : '${r.label} (${r.ownerName})'),
                        subtitle: Text(presetText(context, r.preset)),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(builder: (_) => SharedHomePage(shareId: r.id)),
                        ),
                      ),
                    ),
                ],
                const SizedBox(height: 20),
                Text(tx(context, 'Jakamasi', 'Your shares'), style: text.titleMedium),
                if (sh.mineShares.where((r) => r.status != ShareStatus.revoked && r.status != ShareStatus.declined).isEmpty)
                  Padding(
                    padding: const EdgeInsets.only(top: 6),
                    child: Text(tx(context, 'Et ole jakanut mitään.', 'You have not shared anything.'), style: text.bodySmall),
                  ),
                for (final r in sh.mineShares.where((r) => r.status != ShareStatus.revoked && r.status != ShareStatus.declined))
                  Card(
                    child: ListTile(
                      key: ValueKey('mine-${r.id}'),
                      leading: Icon(r.installer ? Icons.engineering_outlined : Icons.person_outline),
                      title: Text(
                        r.recipientId == null
                            ? (r.label.isEmpty ? tx(context, 'Kutsukoodi', 'Invite code') : r.label)
                            : '${r.recipientName}${r.label.isEmpty ? '' : ' · ${r.label}'}',
                      ),
                      subtitle: Text(
                        '${presetText(context, r.preset)} · ${r.tiles.length} ${tx(context, 'laitetta', 'devices')} · ${statusText(context, r)}',
                      ),
                      trailing: PopupMenuButton<String>(
                        key: ValueKey('mine-menu-${r.id}'),
                        onSelected: (v) async {
                          if (v == 'revoke') {
                            final ok = await showDialog<bool>(
                              context: context,
                              builder: (c) => AlertDialog(
                                title: Text(tx(c, 'Perutaanko jako?', 'Revoke the share?')),
                                content: Text(
                                  tx(
                                    c,
                                    'Pääsy loppuu heti, kun kotisilta saa tiedon (yleensä saman tien).',
                                    'Access ends as soon as the home bridge hears of it (usually at once).',
                                  ),
                                ),
                                actions: [
                                  TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Peruuta', 'Cancel'))),
                                  FilledButton(
                                    key: const ValueKey('revoke-confirm'),
                                    onPressed: () => Navigator.pop(c, true),
                                    child: Text(tx(c, 'Peru jako', 'Revoke')),
                                  ),
                                ],
                              ),
                            );
                            if (ok == true && context.mounted) {
                              await _run(() => sh.revoke(r), ok: tx(context, 'Jako peruttu', 'Share revoked'));
                            }
                          } else if (v == 'edit' && context.mounted) {
                            await Navigator.push(context, MaterialPageRoute(builder: (_) => ShareCreatePage(edit: r)));
                          }
                        },
                        itemBuilder: (c) => [
                          PopupMenuItem(value: 'edit', child: Text(tx(c, 'Muuta laitteita tai oikeuksia', 'Change devices or rights'))),
                          PopupMenuItem(
                            key: const ValueKey('mine-revoke'),
                            value: 'revoke',
                            child: Text(tx(c, 'Peru jako', 'Revoke')),
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 16),
                ExpansionTile(
                  key: const ValueKey('share-advanced'),
                  tilePadding: EdgeInsets.zero,
                  title: Text(tx(context, 'Edistyneet', 'Advanced')),
                  children: [
                    ListTile(
                      contentPadding: EdgeInsets.zero,
                      title: Text(tx(context, 'Nimesi jaoissa', 'Your name in shares')),
                      subtitle: Text(sh.displayName.isEmpty ? '–' : sh.displayName),
                      trailing: const Icon(Icons.edit_outlined),
                      onTap: () async {
                        final v = await _ask(context, tx(context, 'Nimesi jaoissa', 'Your name in shares'), sh.displayName);
                        if (v != null) await _run(() => sh.setDisplayName(v));
                      },
                    ),
                    Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: Text(
                        tx(
                          context,
                          'Turvallisuus: kotisilta tarkistaa jokaisen pyynnön oikeudet. Yhteystunnus kulkee salattuna vain vastaanottajan avaimelle; laitteiden salasanat ja osoitteet eivät lähde kotoa.',
                          'Security: the home bridge checks the rights of every request. The connection credential travels encrypted to the recipient\'s key only; device passwords and addresses never leave home.',
                        ),
                        style: text.bodySmall,
                      ),
                    ),
                  ],
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

Future<String?> _ask(BuildContext context, String title, String initial) {
  final c = TextEditingController(text: initial);
  return showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(title),
      content: TextField(controller: c, autofocus: true),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(tx(d, 'Peruuta', 'Cancel'))),
        FilledButton(onPressed: () => Navigator.pop(d, c.text.trim()), child: Text(tx(d, 'Tallenna', 'Save'))),
      ],
    ),
  );
}

Future<void> claimDialog(BuildContext context, {bool installer = false}) async {
  final st = AppScope.read(context);
  final c = TextEditingController();
  final code = await showDialog<String>(
    context: context,
    builder: (d) => AlertDialog(
      title: Text(installer ? tx(d, 'Lisää asiakas koodilla', 'Add a customer with a code') : tx(d, 'Käytä kutsukoodia', 'Use an invite code')),
      content: TextField(
        key: const ValueKey('claim-code'),
        controller: c,
        autofocus: true,
        textCapitalization: TextCapitalization.characters,
        decoration: const InputDecoration(hintText: 'XXXX-XXXX-XXXX'),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(d), child: Text(tx(d, 'Peruuta', 'Cancel'))),
        FilledButton(
          key: const ValueKey('claim-ok'),
          onPressed: () => Navigator.pop(d, c.text),
          child: Text(tx(d, 'Käytä', 'Use')),
        ),
      ],
    ),
  );
  if (code == null || code.trim().isEmpty || !context.mounted) return;
  try {
    await st.sharing.claim(code);
    if (context.mounted) {
      showSnack(
        context,
        tx(
          context,
          'Koodi hyväksytty. Pääsy aukeaa, kun omistajan Molaplan vahvistaa sen (yleensä parissa minuutissa).',
          'Code accepted. Access opens when the owner\'s Molaplan confirms it (usually within a couple of minutes).',
        ),
        kind: SnackKind.success,
      );
    }
  } catch (e) {
    if (context.mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
  }
}

// ---------------------------------------------------------------- create / change

class ShareCreatePage extends StatefulWidget {
  const ShareCreatePage({super.key, this.edit});
  final ShareRecord? edit;
  @override
  State<ShareCreatePage> createState() => _ShareCreatePageState();
}

enum _To { user, code }

class _ShareCreatePageState extends State<ShareCreatePage> {
  final selected = <String>{};
  SharePreset preset = SharePreset.control;
  _To to = _To.user;
  bool installerAccess = false;
  final email = TextEditingController();
  final label = TextEditingController();
  final ntfy = TextEditingController();
  Map<String, Set<ShareCap>>? custom;
  bool busy = false;
  String? error;

  @override
  void initState() {
    super.initState();
    final e = widget.edit;
    if (e != null) {
      selected.addAll(e.tiles.map((t) => t.id));
      preset = e.preset;
      label.text = e.label;
      installerAccess = e.installer;
    }
  }

  @override
  void dispose() {
    email.dispose();
    label.dispose();
    ntfy.dispose();
    super.dispose();
  }

  Future<void> _go() async {
    final st = AppScope.read(context);
    setState(() {
      busy = true;
      error = null;
    });
    try {
      final c = custom == null ? null : {for (final id in selected) id: custom![id] ?? {ShareCap.view}};
      if (widget.edit != null) {
        await st.sharing.change(widget.edit!, tileIds: selected, preset: preset, custom: c);
        if (mounted) Navigator.pop(context);
        return;
      }
      final code = await st.sharing.create(
        tileIds: selected,
        preset: preset,
        email: to == _To.user ? email.text : null,
        label: label.text.trim(),
        installerAccess: installerAccess,
        custom: c,
        ntfyTopic: ntfy.text,
      );
      if (!mounted) return;
      if (code != null) {
        await showDialog<void>(
          context: context,
          builder: (d) => AlertDialog(
            title: Text(tx(d, 'Kutsukoodi', 'Invite code')),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                SelectableText(code, key: const ValueKey('share-code'), style: Theme.of(d).textTheme.headlineSmall),
                const SizedBox(height: 8),
                Text(
                  tx(
                    d,
                    'Anna koodi (tai linkki) vastaanottajalle: Molaplan → Jakaminen → Käytä kutsukoodia. Voimassa 7 päivää, kerran.',
                    'Give the code (or link) to the recipient: Molaplan → Sharing → Use an invite code. Valid for 7 days, once.',
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Clipboard.setData(ClipboardData(text: inviteLink(code))),
                child: Text(tx(d, 'Kopioi linkki', 'Copy link')),
              ),
              FilledButton(onPressed: () => Navigator.pop(d), child: Text(tx(d, 'Valmis', 'Done'))),
            ],
          ),
        );
      } else {
        showSnack(context, tx(context, 'Kutsu lähetetty – vastaanottaja hyväksyy sen Molaplanissa.', 'Invite sent – the recipient accepts it in Molaplan.'), kind: SnackKind.success);
      }
      if (mounted) Navigator.pop(context);
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
    final views = st.config.dashboards;
    final editing = widget.edit != null;
    return Scaffold(
      appBar: AppBar(title: Text(editing ? tx(context, 'Muuta jakoa', 'Change share') : tx(context, 'Jaa laitteita', 'Share devices'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(tx(context, '1. Mitä jaetaan', '1. What to share'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(tx(context, 'Napauta näkymää jakaaksesi sen kaikki laitteet, tai valitse yksittäin.', 'Tap a view to share all its devices, or pick them one by one.'), style: text.bodySmall),
              for (final d in views) ...[
                Builder(
                  builder: (context) {
                    final ids = [for (final t in d.tiles) if (shareableTile(t)) t.id];
                    final all = ids.isNotEmpty && ids.every(selected.contains);
                    return CheckboxListTile(
                      key: ValueKey('share-view-${d.id}'),
                      contentPadding: EdgeInsets.zero,
                      value: all,
                      tristate: false,
                      title: Text('${tx(context, 'Koko näkymä', 'Whole view')}: ${d.name}', style: text.titleSmall),
                      onChanged: ids.isEmpty
                          ? null
                          : (v) => setState(() => v == true ? selected.addAll(ids) : selected.removeAll(ids)),
                    );
                  },
                ),
                for (final t in d.tiles.where(shareableTile))
                  CheckboxListTile(
                    key: ValueKey('share-tile-${t.id}'),
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 24),
                    value: selected.contains(t.id),
                    title: Text(t.title.isEmpty ? t.id : t.title),
                    onChanged: (v) => setState(() => v == true ? selected.add(t.id) : selected.remove(t.id)),
                  ),
              ],
              const SizedBox(height: 16),
              Text(tx(context, '2. Oikeudet', '2. Rights'), style: text.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<SharePreset>(
                key: const ValueKey('share-preset'),
                segments: [
                  for (final p in SharePreset.values)
                    ButtonSegment(value: p, label: Text(switch (p) {
                      SharePreset.view => tx(context, 'Katselu', 'View'),
                      SharePreset.control => tx(context, 'Ohjaus', 'Control'),
                      SharePreset.full => tx(context, 'Täysi', 'Full'),
                    })),
                ],
                selected: {preset},
                onSelectionChanged: (s) => setState(() {
                  preset = s.first;
                  custom = null;
                }),
              ),
              const SizedBox(height: 6),
              Text(
                switch (preset) {
                  SharePreset.view => tx(context, 'Näkee tilat ja mittaukset, ei voi ohjata.', 'Sees states and readings, cannot control.'),
                  SharePreset.control => tx(context, 'Voi kytkeä ja säätää, ei muuttaa asetuksia (esim. lämpötilan asetusarvoja).', 'Can switch and adjust, cannot change settings (e.g. temperature setpoints).'),
                  SharePreset.full => tx(context, 'Ohjaus ja laitteiden asetukset. Omia näkymiäsi tai salasanoja hän ei näe.', 'Control and device settings. Never your own views or passwords.'),
                },
                style: text.bodySmall,
              ),
              if (!editing) ...[
                const SizedBox(height: 16),
                Text(tx(context, '3. Kenelle', '3. To whom'), style: text.titleMedium),
                RadioGroup<_To>(
                  groupValue: to,
                  onChanged: (v) => setState(() => to = v ?? _To.user),
                  child: Column(
                    children: [
                      RadioListTile(
                        key: const ValueKey('share-to-user'),
                        contentPadding: EdgeInsets.zero,
                        value: _To.user,
                        title: Text(tx(context, 'Molaplan-käyttäjälle (sähköposti)', 'A Molaplan user (e-mail)')),
                      ),
                      RadioListTile(
                        key: const ValueKey('share-to-code'),
                        contentPadding: EdgeInsets.zero,
                        value: _To.code,
                        title: Text(tx(context, 'Kutsukoodi tai -linkki', 'Invite code or link')),
                      ),
                    ],
                  ),
                ),
                if (to == _To.user)
                  TextField(
                    key: const ValueKey('share-email'),
                    controller: email,
                    keyboardType: TextInputType.emailAddress,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(labelText: tx(context, 'Sähköposti', 'E-mail')),
                  ),
                TextField(
                  key: const ValueKey('share-label'),
                  controller: label,
                  decoration: InputDecoration(
                    labelText: tx(context, 'Nimi jaolle (valinnainen)', 'Name for the share (optional)'),
                    hintText: tx(context, 'esim. Mökki', 'e.g. Cottage'),
                  ),
                ),
              ],
              ExpansionTile(
                tilePadding: EdgeInsets.zero,
                title: Text(tx(context, 'Edistyneet', 'Advanced')),
                children: [
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(tx(context, 'Oikeudet laitekohtaisesti', 'Rights per device'), style: text.titleSmall),
                  ),
                  for (final d in views)
                    for (final t in d.tiles.where((t) => selected.contains(t.id)))
                      Row(
                        key: ValueKey('share-caps-${t.id}'),
                        children: [
                          Expanded(child: Text(t.title.isEmpty ? t.id : t.title)),
                          for (final c in ShareCap.values)
                            Padding(
                              padding: const EdgeInsets.only(left: 4),
                              child: FilterChip(
                                label: Text(switch (c) {
                                  ShareCap.view => tx(context, 'Näe', 'View'),
                                  ShareCap.control => tx(context, 'Ohjaa', 'Control'),
                                  ShareCap.settings => tx(context, 'Asetukset', 'Settings'),
                                }),
                                selected: (custom?[t.id] ?? ShareScope.preset(preset, [t.id]).tiles[t.id]!).contains(c),
                                onSelected: (on) => setState(() {
                                  custom ??= {for (final id in selected) id: ShareScope.preset(preset, [id]).tiles[id]!};
                                  final s = custom![t.id] ??= {ShareCap.view};
                                  on ? s.add(c) : s.remove(c);
                                  if (s.isEmpty) s.add(ShareCap.view);
                                }),
                              ),
                            ),
                        ],
                      ),
                  if (!editing)
                    TextField(
                      controller: ntfy,
                      decoration: InputDecoration(
                        labelText: tx(context, 'Ilmoita ntfy-aiheeseen (valinnainen)', 'Notify an ntfy topic (optional)'),
                        helperText: tx(context, 'Viestissä ei ole koodia eikä laitetietoja.', 'The message contains no code or device details.'),
                      ),
                    ),
                  const SizedBox(height: 8),
                ],
              ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, key: const ValueKey('share-create-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              const SizedBox(height: 16),
              SizedBox(
                height: 52,
                child: FilledButton.icon(
                  key: const ValueKey('share-go'),
                  onPressed: busy || selected.isEmpty || (!editing && to == _To.user && !email.text.contains('@')) ? null : _go,
                  icon: busy
                      ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.check),
                  label: Text(
                    editing
                        ? tx(context, 'Tallenna', 'Save')
                        : to == _To.code
                        ? tx(context, 'Luo kutsukoodi', 'Create invite code')
                        : tx(context, 'Lähetä kutsu', 'Send invite'),
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

// ---------------------------------------------------------------- recipient view

/// A share given to me: the tiles I may see, live values, and the controls I may use.
class SharedHomePage extends StatefulWidget {
  const SharedHomePage({super.key, required this.shareId, this.installerView = false});
  final String shareId;
  final bool installerView;
  @override
  State<SharedHomePage> createState() => _SharedHomePageState();
}

class _SharedHomePageState extends State<SharedHomePage> {
  Map<String, dynamic>? cfg;
  Map<String, dynamic> values = {};
  List<Map<String, dynamic>> alarms = [];
  String? error;
  DateTime? updated;
  Timer? _t;
  final _busy = <String>{};
  final _images = <String, Uint8List>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _load());
    _t = Timer.periodic(const Duration(seconds: 30), (_) => _status());
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final c = await AppScope.read(context).sharing.sharedConfig(widget.shareId);
      if (!mounted) return;
      setState(() {
        cfg = c;
        error = null;
      });
      await _status();
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    }
  }

  Future<void> _status() async {
    if (cfg == null) return;
    try {
      final s = await AppScope.read(context).sharing.sharedStatus(widget.shareId);
      if (!mounted) return;
      setState(() {
        values = Map<String, dynamic>.from((s['tiles'] as Map?) ?? const {});
        alarms = [for (final a in (s['alarms'] as List? ?? const [])) Map<String, dynamic>.from(a as Map)];
        updated = DateTime.now();
        error = null;
      });
    } catch (e) {
      if (mounted) setState(() => error = shareErrorText(context, e));
    }
  }

  Future<void> _send(String tile, String action, {Object? value}) async {
    setState(() => _busy.add(tile));
    try {
      await AppScope.read(context).sharing.sharedSend(widget.shareId, tile, action, value: value);
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await _status();
    } catch (e) {
      if (mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(tile));
    }
  }

  Future<void> _snapshot(String tile) async {
    setState(() => _busy.add(tile));
    try {
      final v = await AppScope.read(context).sharing.sharedRead(widget.shareId, tile);
      if (v is Uint8List && mounted) setState(() => _images[tile] = v);
    } catch (e) {
      if (mounted) showSnack(context, shareErrorText(context, e), kind: SnackKind.error);
    } finally {
      if (mounted) setState(() => _busy.remove(tile));
    }
  }

  String _show(Map<String, dynamic> t, Object? v) {
    if (v == null) return '–';
    final map = '${t['valueMap'] ?? ''}';
    if (map.trim().isNotEmpty) {
      final key = v is double && v == v.roundToDouble() ? v.toInt().toString() : '$v';
      for (final part in map.split(';')) {
        final i = part.indexOf('=');
        if (i > 0 && part.substring(0, i).trim() == key) return part.substring(i + 1).trim();
      }
    }
    if (v is num) {
      final d = (t['decimals'] as num?)?.toInt() ?? 1;
      return '${v.toStringAsFixed(v == v.roundToDouble() && d > 0 ? 0 : d)} ${t['unit'] ?? ''}'.trim();
    }
    return '$v ${t['unit'] ?? ''}'.trim();
  }

  bool _isOn(Map<String, dynamic> t, Object? v) {
    final on = '${t['onValue'] ?? ''}';
    if (on.isNotEmpty) return '$v' == on;
    return v == true || v == 1 || v == '1' || '$v'.toLowerCase() == 'on' || '$v'.toLowerCase() == 'true';
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final r = st.sharing.toMe.where((x) => x.id == widget.shareId).firstOrNull;
    final text = Theme.of(context).textTheme;
    final tiles = [for (final t in (cfg?['tiles'] as List? ?? const [])) Map<String, dynamic>.from(t as Map)];
    return Scaffold(
      appBar: AppBar(
        title: Text(cfg == null ? (r?.label ?? '') : '${cfg!['label'] == '' ? cfg!['home'] : cfg!['label']}'),
        actions: [IconButton(onPressed: _load, icon: const Icon(Icons.refresh), tooltip: tx(context, 'Päivitä', 'Refresh'))],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              if (r != null)
                Text(
                  '${tx(context, 'Omistaja', 'Owner')}: ${r.ownerName} · ${presetText(context, r.preset)}',
                  style: text.bodySmall,
                ),
              if (updated != null)
                Text(
                  '${tx(context, 'Päivitetty', 'Updated')} ${TimeOfDay.fromDateTime(updated!).format(context)}',
                  style: text.bodySmall,
                ),
              if (error != null) ...[
                const SizedBox(height: 8),
                Text(error!, key: const ValueKey('shared-error'), style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ],
              if (alarms.isNotEmpty) ...[
                const SizedBox(height: 8),
                Card(
                  key: const ValueKey('shared-alarms'),
                  color: Theme.of(context).colorScheme.errorContainer,
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(tx(context, 'Huomioitavaa', 'Attention'), style: text.titleSmall),
                        for (final a in alarms)
                          Text(
                            a['error'] != null
                                ? '${a['title']}: ${tx(context, 'ei vastaa', 'not answering')} (${a['error']})'
                                : '${a['title']}: ${tx(context, 'hälytys', 'alarm')}',
                          ),
                      ],
                    ),
                  ),
                ),
              ],
              if (cfg == null && error == null) const Padding(padding: EdgeInsets.all(24), child: Center(child: CircularProgressIndicator())),
              for (final t in tiles) _tile(context, t),
            ],
          ),
        ),
      ),
    );
  }

  Widget _tile(BuildContext context, Map<String, dynamic> t) {
    final id = '${t['id']}';
    final caps = {for (final c in (t['caps'] as List? ?? const [])) '$c'};
    final setting = t['setting'] == true;
    final canAct = setting ? caps.contains('settings') : caps.contains('control');
    final v = values[id] is Map ? (values[id] as Map)['v'] : null;
    final err = values[id] is Map ? (values[id] as Map)['e'] : null;
    final busy = _busy.contains(id);
    final type = '${t['type']}';
    final subtitle = err != null ? Text('$err', style: TextStyle(color: Theme.of(context).colorScheme.error)) : null;
    Widget? trailing;
    switch (type) {
      case 'toggle':
        trailing = Switch(
          key: ValueKey('shared-switch-$id'),
          value: _isOn(t, v),
          onChanged: !canAct || busy ? null : (on) => _send(id, on ? 'on' : 'off'),
        );
      case 'button':
        trailing = FilledButton.tonal(
          key: ValueKey('shared-press-$id'),
          onPressed: !canAct || busy ? null : () => _send(id, 'press'),
          child: Text(tx(context, 'Suorita', 'Run')),
        );
      case 'camera':
        trailing = IconButton(
          onPressed: busy ? null : () => _snapshot(id),
          icon: const Icon(Icons.photo_camera_outlined),
          tooltip: tx(context, 'Näytä kuva', 'Show picture'),
        );
      default:
        trailing = Text(_show(t, v), key: ValueKey('shared-value-$id'), style: Theme.of(context).textTheme.titleMedium);
    }
    return Card(
      child: Column(
        children: [
          ListTile(
            title: Text('${t['title']}'),
            subtitle: subtitle ?? (type == 'toggle' || type == 'button' ? Text(_show(t, v)) : null),
            trailing: busy ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2)) : trailing,
          ),
          if (type == 'slider')
            Padding(
              padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
              child: Slider(
                key: ValueKey('shared-slider-$id'),
                min: (t['min'] as num?)?.toDouble() ?? 0,
                max: (t['max'] as num?)?.toDouble() ?? 100,
                value: ((v is num ? v.toDouble() : null) ?? (t['min'] as num?)?.toDouble() ?? 0)
                    .clamp((t['min'] as num?)?.toDouble() ?? 0, (t['max'] as num?)?.toDouble() ?? 100),
                onChanged: canAct && !busy ? (_) {} : null,
                onChangeEnd: canAct && !busy ? (x) => _send(id, 'set', value: x) : null,
              ),
            ),
          if (_images[id] != null) Padding(padding: const EdgeInsets.all(8), child: Image.memory(_images[id]!)),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------- installer

/// 'Asentaja': the customers who gave me access, their devices, status and alarms.
class InstallerPage extends StatefulWidget {
  const InstallerPage({super.key});
  @override
  State<InstallerPage> createState() => _InstallerPageState();
}

class _InstallerPageState extends State<InstallerPage> {
  final _status = <String, ({int alarms, String? error})>{};

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      final sh = AppScope.read(context).sharing;
      try {
        await sh.refresh();
      } catch (_) {}
      for (final r in sh.customers.where((r) => r.status == ShareStatus.active)) {
        unawaited(
          sh.sharedStatus(r.id).then(
            (s) {
              if (mounted) setState(() => _status[r.id] = (alarms: (s['alarms'] as List? ?? const []).length, error: null));
            },
            onError: (Object e) {
              if (mounted) setState(() => _status[r.id] = (alarms: 0, error: shareErrorText(context, e)));
            },
          ),
        );
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final sh = st.sharing;
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Asentaja', 'Installer'))),

      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Text(
                tx(
                  context,
                  'Asiakkaasi, jotka ovat antaneet sinulle pääsyn. Näet vain jaetut laitteet ja toimit asiakkaan antamin oikeuksin – salasanoja et näe.',
                  'Customers who gave you access. You see only the shared devices and act within the rights the customer gave – never their passwords.',
                ),
                style: text.bodySmall,
              ),
              if (!sh.installer && sh.available)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    tx(context, 'Asentajan tilasi ei ole voimassa.', 'Your installer status is not valid.'),
                    key: const ValueKey('installer-not-valid'),
                    style: TextStyle(color: Theme.of(context).colorScheme.error),
                  ),
                ),
              const SizedBox(height: 12),
              if (sh.customers.isEmpty)
                Text(
                  tx(
                    context,
                    'Ei asiakkaita vielä. Anna asiakkaalle asentajatunnuksesi ${sh.installerInfo?.publicId ?? ''}: asiakas avaa Asetukset → Asentaja → Anna pääsy.',
                    'No customers yet. Give your customer your installer ID ${sh.installerInfo?.publicId ?? ''}: they open Settings → Installer → Give access.',
                  ),
                  key: const ValueKey('installer-empty'),
                ),
              for (final r in sh.customers)
                Card(
                  child: ListTile(
                    key: ValueKey('customer-${r.id}'),
                    leading: Icon(
                      (_status[r.id]?.alarms ?? 0) > 0 || _status[r.id]?.error != null ? Icons.warning_amber_rounded : Icons.home_work_outlined,
                      color: (_status[r.id]?.alarms ?? 0) > 0 || _status[r.id]?.error != null ? Theme.of(context).colorScheme.error : null,
                    ),
                    title: Text('${r.ownerName}${r.label.isEmpty ? '' : ' · ${r.label}'}'),
                    subtitle: Text(
                      r.status == ShareStatus.claimed
                          ? tx(context, 'Odottaa asiakkaan Molaplanin vahvistusta', 'Waiting for the customer\'s Molaplan to confirm')
                          : [
                              presetText(context, r.preset),
                              '${r.tiles.length} ${tx(context, 'laitetta', 'devices')}',
                              if (_status[r.id]?.error != null) _status[r.id]!.error!,
                              if ((_status[r.id]?.alarms ?? 0) > 0) '${_status[r.id]!.alarms} ${tx(context, 'huomiota', 'alerts')}',
                            ].join(' · '),
                    ),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: r.status != ShareStatus.active
                        ? null
                        : () => Navigator.push(
                            context,
                            MaterialPageRoute(builder: (_) => SharedHomePage(shareId: r.id, installerView: true)),
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

/// Small helper for other pages: the tiles of [cfg] that can be shared.
List<TileConfig> shareableTiles(AppConfig cfg) => [for (final d in cfg.dashboards) ...d.tiles.where(shareableTile)];
