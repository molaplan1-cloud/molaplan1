import 'package:material_ui/material_ui.dart';

import '../account/supabase_api.dart';
import '../account/vault.dart';
import '../state/account_state.dart';
import 'app_scope.dart';

/// Plain-language explanation of an account error.
String accountErrorText(BuildContext context, Object e) {
  String t(String fi, String en) => tx(context, fi, en);
  if (e is WrongVaultPassword) {
    return t(
      'Salasana ei täsmää. Kirjoita tilin salasana (sama jolla kirjauduit ensimmäisen kerran).',
      'The password does not match. Type your account password.',
    );
  }
  if (e is! AccountError) return t('Jokin meni pieleen: $e', 'Something went wrong: $e');
  return switch (e.problem) {
    AccountProblem.offline => t(
      'Ei nettiyhteyttä. Tarkista wifi tai mobiilidata ja yritä uudelleen.',
      'No internet connection. Check Wi-Fi or mobile data and try again.',
    ),
    AccountProblem.wrongPassword => t(
      'Sähköposti tai salasana on väärin. Tarkista kirjoitusasu, tai paina "Unohdin salasanan".',
      'Wrong email or password. Check them, or tap "Forgot password".',
    ),
    AccountProblem.emailNotConfirmed => t(
      'Sähköpostia ei ole vielä vahvistettu. Katso sähköpostistasi koodi.',
      'The email is not confirmed yet. Look for the code in your email.',
    ),
    AccountProblem.userExists => t(
      'Tällä sähköpostilla on jo tili. Paina "Minulla on jo tili" ja kirjaudu.',
      'This email already has an account. Sign in instead.',
    ),
    AccountProblem.weakPassword => t(
      'Salasanan pitää olla vähintään 8 merkkiä.',
      'The password must be at least 8 characters.',
    ),
    AccountProblem.badEmail => t(
      'Sähköpostiosoite ei näytä oikealta (esim. nimi@esimerkki.fi).',
      'That does not look like an email address.',
    ),
    AccountProblem.badCode => t(
      'Koodi on väärä tai vanhentunut. Tarkista koodi tai pyydä uusi.',
      'The code is wrong or expired. Check it or ask for a new one.',
    ),
    AccountProblem.rateLimited => t(
      'Liian monta yritystä. Odota hetki (noin minuutti) ja yritä uudelleen.',
      'Too many attempts. Wait a minute and try again.',
    ),
    AccountProblem.sessionExpired => t(
      'Kirjautuminen on vanhentunut. Kirjaudu uudelleen.',
      'Your sign-in expired. Please sign in again.',
    ),
    AccountProblem.conflict => t(
      'Toinen laite muutti asetuksia samaan aikaan. Yritä uudelleen.',
      'Another device changed the setup at the same time. Try again.',
    ),
    AccountProblem.server => t(
      'Tilipalvelu ei vastannut oikein. Yritä hetken päästä uudelleen.',
      'The account service did not answer properly. Try again shortly.',
    ),
  };
}

/// First sign-in on a device that already has a setup: ask what to do.
Future<void> askFirstSync(BuildContext context) async {
  final acc = AppScope.read(context).account;
  final p = acc.pendingFirstSync;
  if (p == null) return;
  String t(String fi, String en) => tx(context, fi, en);
  final choice = await showDialog<FirstSyncChoice?>(
    context: context,
    barrierDismissible: false,
    builder: (c) => AlertDialog(
      title: Text(
        p.remoteHas
            ? t('Tililläsi on jo kotinäkymä', 'Your account already has a setup')
            : t('Tallennetaanko tämän laitteen kotinäkymä tiliisi?', 'Save this device\'s setup to your account?'),
      ),
      content: Text(
        p.remoteHas
            ? t(
                'Myös tällä laitteella on omia laitteita ja ruutuja. Mitä tehdään?',
                'This device has its own devices and tiles too. What should we do?',
              )
            : t(
                'Silloin samat kodit, laitteet ja ruudut näkyvät kaikilla laitteillasi, joilla kirjaudut tälle tilille.',
                'Then the same homes, devices and tiles appear on every device signed in to this account.',
              ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('first-cancel'),
          onPressed: () => Navigator.pop(c, null),
          child: Text(t('Peru ja kirjaudu ulos', 'Cancel and sign out')),
        ),
        if (p.remoteHas) ...[
          OutlinedButton(
            key: const ValueKey('first-use-account'),
            onPressed: () => Navigator.pop(c, FirstSyncChoice.useAccount),
            child: Text(t('Käytä tilin asetuksia', 'Use the account\'s setup')),
          ),
          FilledButton(
            key: const ValueKey('first-merge'),
            onPressed: () => Navigator.pop(c, FirstSyncChoice.merge),
            child: Text(t('Yhdistä molemmat (suositus)', 'Combine both (recommended)')),
          ),
        ] else
          FilledButton(
            key: const ValueKey('first-upload'),
            onPressed: () => Navigator.pop(c, FirstSyncChoice.uploadLocal),
            child: Text(t('Tallenna tiliin', 'Save to account')),
          ),
      ],
    ),
  );
  try {
    await acc.resolveFirstSync(choice);
  } catch (e) {
    if (context.mounted) showSnack(context, accountErrorText(context, e), error: true);
  }
}

enum _Mode { signIn, signUp, code, forgot, confirm }

class AccountPage extends StatefulWidget {
  const AccountPage({super.key, this.startWithSignUp = false});
  final bool startWithSignUp;
  @override
  State<AccountPage> createState() => _AccountPageState();
}

class _AccountPageState extends State<AccountPage> {
  late _Mode mode = widget.startWithSignUp ? _Mode.signUp : _Mode.signIn;
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _code = TextEditingController();
  final _unlock = TextEditingController();
  bool busy = false;
  bool codeSent = false;
  bool showPassword = false;
  String? error;
  String? info;

  @override
  void dispose() {
    _email.dispose();
    _password.dispose();
    _code.dispose();
    _unlock.dispose();
    super.dispose();
  }

  String t(String fi, String en) => tx(context, fi, en);

  void _go(_Mode m) => setState(() {
    mode = m;
    error = null;
    info = null;
    codeSent = false;
    _code.clear();
  });

  String? _check({bool password = true}) {
    final e = _email.text.trim();
    if (!RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$').hasMatch(e)) {
      return t('Kirjoita sähköpostiosoitteesi (esim. nimi@esimerkki.fi).', 'Type your email address.');
    }
    if (password && _password.text.length < 8) {
      return t('Salasanan pitää olla vähintään 8 merkkiä.', 'At least 8 characters.');
    }
    return null;
  }

  Future<void> _run(Future<void> Function() f, {bool password = true, bool checkInput = true}) async {
    final bad = checkInput ? _check(password: password) : null;
    if (bad != null) return setState(() => error = bad);
    setState(() {
      busy = true;
      error = null;
      info = null;
    });
    try {
      await f();
    } catch (e) {
      if (mounted) setState(() => error = accountErrorText(context, e));
    } finally {
      if (mounted) setState(() => busy = false);
    }
    if (!mounted) return;
    final acc = AppScope.read(context).account;
    if (acc.pendingFirstSync != null) await askFirstSync(context);
  }

  @override
  Widget build(BuildContext context) {
    final acc = AppScope.of(context).account;
    return Scaffold(
      appBar: AppBar(title: Text(t('Molaplan-tili', 'Molaplan account'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 520),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: acc.signedIn ? _signedIn(context, acc) : _signedOut(context, acc),
          ),
        ),
      ),
    );
  }

  Widget _banner(String text, {bool isError = false}) {
    final cs = Theme.of(context).colorScheme;
    return Container(
      margin: const EdgeInsets.only(top: 12),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isError ? cs.errorContainer : cs.primaryContainer,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: TextStyle(color: isError ? cs.onErrorContainer : cs.onPrimaryContainer)),
    );
  }

  Widget _big(Key key, String label, VoidCallback? onPressed) => Padding(
    padding: const EdgeInsets.only(top: 16),
    child: SizedBox(
      height: 54,
      child: FilledButton(
        key: key,
        onPressed: busy ? null : onPressed,
        child: busy
            ? const SizedBox.square(dimension: 22, child: CircularProgressIndicator(strokeWidth: 2.5))
            : Text(label, style: const TextStyle(fontSize: 17)),
      ),
    ),
  );

  Widget _emailField() => TextField(
    key: const ValueKey('acc-email'),
    controller: _email,
    keyboardType: TextInputType.emailAddress,
    autofillHints: const [AutofillHints.email],
    decoration: InputDecoration(labelText: t('Sähköposti', 'Email'), border: const OutlineInputBorder()),
  );

  Widget _passwordField({String? label, String? helper}) => TextField(
    key: const ValueKey('acc-password'),
    controller: _password,
    obscureText: !showPassword,
    autofillHints: const [AutofillHints.password],
    decoration: InputDecoration(
      labelText: label ?? t('Salasana', 'Password'),
      helperText: helper,
      helperMaxLines: 3,
      border: const OutlineInputBorder(),
      suffixIcon: IconButton(
        tooltip: t('Näytä salasana', 'Show password'),
        icon: Icon(showPassword ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => showPassword = !showPassword),
      ),
    ),
  );

  Widget _codeField() => TextField(
    key: const ValueKey('acc-code'),
    controller: _code,
    keyboardType: TextInputType.number,
    style: const TextStyle(fontSize: 24, letterSpacing: 6),
    decoration: InputDecoration(
      labelText: t('Koodi sähköpostista', 'Code from the email'),
      helperText: t(
        'Koodi tulee muutamassa minuutissa. Katso myös roskapostikansio.',
        'The code arrives in a few minutes. Check the spam folder too.',
      ),
      border: const OutlineInputBorder(),
    ),
  );

  List<Widget> _signedOut(BuildContext context, AccountState acc) {
    final text = Theme.of(context).textTheme;
    final intro = Text(
      t(
        'Tilin avulla kotisi, laitteesi ja ruudut ovat samat kaikilla laitteillasi – PC:llä, tabletilla ja puhelimella. Kotiyhteys siirtyy uudelle laitteelle ilman QR-koodia.\n\nTili on vapaaehtoinen: ilman tiliä Molaplan toimii kuten ennenkin, ja asetukset pysyvät vain tällä laitteella.',
        'With an account your homes, devices and tiles are the same on all your devices – PC, tablet and phone. The home connection moves to a new device without a QR code.\n\nThe account is optional: without one Molaplan works as before and the setup stays on this device.',
      ),
      style: text.bodyLarge,
    );
    final errs = [if (error != null) _banner(error!, isError: true), if (info != null) _banner(info!)];
    switch (mode) {
      case _Mode.signIn:
        return [
          Text(t('Kirjaudu sisään', 'Sign in'), style: text.headlineSmall),
          const SizedBox(height: 8),
          intro,
          const SizedBox(height: 20),
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(),
          ...errs,
          _big(
            const ValueKey('acc-signin'),
            t('Kirjaudu sisään', 'Sign in'),
            () => _run(() => acc.signIn(_email.text, _password.text)),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('acc-mode-signup'),
            onPressed: busy ? null : () => _go(_Mode.signUp),
            child: Text(t('Minulla ei ole tiliä – luo uusi', 'I don\'t have an account – create one')),
          ),
          TextButton(
            key: const ValueKey('acc-mode-code'),
            onPressed: busy ? null : () => _go(_Mode.code),
            child: Text(t('Kirjaudu sähköpostiin tulevalla koodilla', 'Sign in with a code sent by email')),
          ),
          TextButton(
            key: const ValueKey('acc-forgot'),
            onPressed: busy ? null : () => _go(_Mode.forgot),
            child: Text(t('Unohdin salasanan', 'Forgot password')),
          ),
        ];
      case _Mode.signUp:
        return [
          Text(t('Luo Molaplan-tili', 'Create a Molaplan account'), style: text.headlineSmall),
          const SizedBox(height: 8),
          intro,
          const SizedBox(height: 20),
          _emailField(),
          const SizedBox(height: 12),
          _passwordField(
            label: t('Keksi salasana (vähintään 8 merkkiä)', 'Choose a password (8+ characters)'),
            helper: t(
              'Salasana myös suojaa laitteidesi salasanat ja pilviavaimet: ne salataan tällä laitteella ennen tallennusta. Pidä salasana tallessa.',
              'The password also protects your device passwords and cloud keys: they are encrypted on this device before saving. Keep it safe.',
            ),
          ),
          ...errs,
          _big(
            const ValueKey('acc-signup'),
            t('Luo tili', 'Create account'),
            () => _run(() async {
              final ok = await acc.signUp(_email.text, _password.text);
              if (!ok && mounted) {
                setState(() {
                  mode = _Mode.confirm;
                  info = t(
                    'Lähetimme koodin osoitteeseen ${_email.text.trim()}. Kirjoita se alle.',
                    'We sent a code to ${_email.text.trim()}. Type it below.',
                  );
                });
              }
            }),
          ),
          const SizedBox(height: 8),
          OutlinedButton(
            key: const ValueKey('acc-mode-signin'),
            onPressed: busy ? null : () => _go(_Mode.signIn),
            child: Text(t('Minulla on jo tili – kirjaudu', 'I already have an account – sign in')),
          ),
        ];
      case _Mode.confirm:
        return [
          Text(t('Vahvista sähköposti', 'Confirm your email'), style: text.headlineSmall),
          ...errs,
          const SizedBox(height: 16),
          _codeField(),
          _big(
            const ValueKey('acc-verify'),
            t('Vahvista', 'Confirm'),
            () => _run(() => acc.confirmSignUp(_email.text, _code.text), password: false),
          ),
          TextButton(
            onPressed: busy
                ? null
                : () => _run(() async {
                    await acc.api.resendConfirmation(_email.text.trim());
                    if (mounted) setState(() => info = t('Uusi koodi lähetetty.', 'A new code was sent.'));
                  }, password: false),
            child: Text(t('Koodi ei tullut – lähetä uusi', 'No code – send a new one')),
          ),
          TextButton(onPressed: busy ? null : () => _go(_Mode.signUp), child: Text(t('Takaisin', 'Back'))),
        ];
      case _Mode.code:
        return [
          Text(t('Kirjaudu koodilla', 'Sign in with a code'), style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            t(
              'Lähetämme sähköpostiisi koodin. Salasanaa ei tarvita kirjautumiseen.',
              'We email you a code. No password needed to sign in.',
            ),
          ),
          const SizedBox(height: 16),
          _emailField(),
          ...errs,
          if (!codeSent)
            _big(
              const ValueKey('acc-send-code'),
              t('Lähetä koodi', 'Send code'),
              () => _run(() async {
                await acc.sendCode(_email.text);
                if (mounted) {
                  setState(() {
                    codeSent = true;
                    info = t(
                      'Koodi lähetetty osoitteeseen ${_email.text.trim()}.',
                      'Code sent to ${_email.text.trim()}.',
                    );
                  });
                }
              }, password: false),
            )
          else ...[
            const SizedBox(height: 16),
            _codeField(),
            _big(
              const ValueKey('acc-verify'),
              t('Kirjaudu', 'Sign in'),
              () => _run(() => acc.signInWithCode(_email.text, _code.text), password: false),
            ),
            TextButton(
              onPressed: busy ? null : () => setState(() => codeSent = false),
              child: Text(t('Lähetä uusi koodi', 'Send a new code')),
            ),
          ],
          TextButton(onPressed: busy ? null : () => _go(_Mode.signIn), child: Text(t('Takaisin', 'Back'))),
        ];
      case _Mode.forgot:
        return [
          Text(t('Vaihda salasana', 'Reset password'), style: text.headlineSmall),
          const SizedBox(height: 8),
          Text(
            t(
              'Lähetämme sähköpostiisi koodin. Sen jälkeen voit keksiä uuden salasanan.',
              'We email you a code, then you choose a new password.',
            ),
          ),
          const SizedBox(height: 16),
          _emailField(),
          ...errs,
          if (!codeSent)
            _big(
              const ValueKey('acc-send-code'),
              t('Lähetä koodi', 'Send code'),
              () => _run(() async {
                await acc.sendRecovery(_email.text);
                if (mounted) setState(() => codeSent = true);
              }, password: false),
            )
          else ...[
            const SizedBox(height: 16),
            _codeField(),
            const SizedBox(height: 12),
            _passwordField(label: t('Uusi salasana (vähintään 8 merkkiä)', 'New password (8+ characters)')),
            _big(
              const ValueKey('acc-verify'),
              t('Vaihda salasana ja kirjaudu', 'Change password and sign in'),
              () => _run(() => acc.recoverWithCode(_email.text, _code.text, _password.text)),
            ),
          ],
          TextButton(onPressed: busy ? null : () => _go(_Mode.signIn), child: Text(t('Takaisin', 'Back'))),
        ];
    }
  }

  List<Widget> _signedIn(BuildContext context, AccountState acc) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final (icon, label) = switch (acc.status) {
      SyncStatus.syncing => (Icons.sync, t('Synkronoidaan…', 'Syncing…')),
      SyncStatus.ok => (
        Icons.cloud_done_outlined,
        t('Ajan tasalla – samat asetukset kaikilla laitteillasi', 'Up to date on all your devices'),
      ),
      SyncStatus.offline => (
        Icons.cloud_off_outlined,
        t('Ei nettiä – muutokset siirtyvät, kun yhteys palaa', 'Offline – changes sync when back online'),
      ),
      SyncStatus.error => (
        Icons.error_outline,
        t('Synkronointi epäonnistui – yritetään uudelleen', 'Sync failed – will retry'),
      ),
      SyncStatus.off => (Icons.cloud_outlined, t('Ei synkronoitu vielä', 'Not synced yet')),
    };
    return [
      Row(
        children: [
          CircleAvatar(
            radius: 26,
            backgroundColor: cs.primary,
            child: Icon(Icons.person, color: cs.onPrimary),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(t('Kirjautunut', 'Signed in'), style: text.bodySmall),
                Text(acc.email ?? '', key: const ValueKey('acc-email-shown'), style: text.titleLarge),
              ],
            ),
          ),
        ],
      ),
      const SizedBox(height: 16),
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(icon, color: acc.status == SyncStatus.error ? cs.error : cs.primary),
        title: Text(label),
        subtitle: acc.lastError != null && acc.status != SyncStatus.ok
            ? Text(accountErrorText(context, acc.lastError!))
            : null,
        trailing: IconButton(
          key: const ValueKey('acc-sync-now'),
          tooltip: t('Synkronoi nyt', 'Sync now'),
          icon: const Icon(Icons.refresh),
          onPressed: busy ? null : () => _run(() => acc.syncNow(), checkInput: false),
        ),
      ),
      if (acc.needsUnlock) ...[
        _banner(
          t(
            'Laitteiden salasanat ja pilviavaimet ovat tilillä lukittuina. Kirjoita tilin salasana avataksesi ne tällä laitteella.',
            'Device passwords and cloud keys are locked. Type your account password to open them on this device.',
          ),
        ),
        const SizedBox(height: 12),
        TextField(
          key: const ValueKey('acc-unlock-password'),
          controller: _unlock,
          obscureText: true,
          decoration: InputDecoration(
            labelText: t('Tilin salasana', 'Account password'),
            border: const OutlineInputBorder(),
          ),
        ),
        _big(
          const ValueKey('acc-unlock'),
          t('Avaa salasanat', 'Unlock'),
          () => _run(() => acc.unlock(_unlock.text), checkInput: false),
        ),
        TextButton(
          onPressed: busy ? null : () => _resetVault(acc),
          child: Text(t('En muista salasanaa – aloita salasanat alusta', 'I forgot it – start the passwords over')),
        ),
      ],
      if (error != null) _banner(error!, isError: true),
      if (info != null) _banner(info!),
      const SizedBox(height: 12),
      Text(
        t(
          'Mitä tilille tallennetaan: kodit, laitteet, ruudut ja niiden järjestys sekä kotiyhteys. Laitteiden salasanat, pilviavaimet ja kotiyhteyden avaimet salataan tällä laitteella tilisi salasanalla ennen lähettämistä – palvelin ei näe niitä.',
          'Saved to the account: homes, devices, tiles and their order, and the home connection. Device passwords, cloud keys and home connection keys are encrypted on this device with your account password before upload – the server cannot read them.',
        ),
        style: text.bodySmall,
      ),
      const SizedBox(height: 20),
      OutlinedButton.icon(
        key: const ValueKey('acc-change-password'),
        onPressed: busy ? null : () => _changePassword(acc),
        icon: const Icon(Icons.password),
        label: Text(t('Vaihda salasana', 'Change password')),
      ),
      const SizedBox(height: 10),
      FilledButton.tonalIcon(
        key: const ValueKey('acc-signout'),
        onPressed: busy
            ? null
            : () async {
                final ok = await confirmDialog(
                  context,
                  t('Kirjaudu ulos?', 'Sign out?'),
                  t(
                    'Kodit ja ruudut jäävät tälle laitteelle, mutta muutokset eivät enää siirry muille laitteillesi.',
                    'Homes and tiles stay on this device, but changes no longer reach your other devices.',
                  ),
                  ok: t('Kirjaudu ulos', 'Sign out'),
                );
                if (ok) await acc.signOut();
              },
        icon: const Icon(Icons.logout),
        label: Text(t('Kirjaudu ulos', 'Sign out')),
      ),
      const SizedBox(height: 28),
      Text(t('Tilin poistaminen', 'Delete account'), style: text.titleMedium),
      const SizedBox(height: 4),
      Text(
        t(
          'Poistaa tilin ja kaikki palvelimelle tallennetut tiedot pysyvästi. Tämän laitteen kotinäkymä jää laitteelle.',
          'Permanently deletes the account and everything stored on the server. This device keeps its own setup.',
        ),
        style: text.bodySmall,
      ),
      const SizedBox(height: 8),
      OutlinedButton.icon(
        key: const ValueKey('acc-delete'),
        style: OutlinedButton.styleFrom(
          foregroundColor: cs.error,
          side: BorderSide(color: cs.error),
        ),
        onPressed: busy ? null : () => _delete(acc),
        icon: const Icon(Icons.delete_forever_outlined),
        label: Text(t('Poista tili', 'Delete account')),
      ),
    ];
  }

  Future<String?> _askPassword(String title, String body) async {
    final c = TextEditingController();
    final r = await showDialog<String>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(title),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(body),
            const SizedBox(height: 12),
            TextField(
              key: const ValueKey('acc-new-password'),
              controller: c,
              obscureText: true,
              decoration: InputDecoration(
                labelText: t('Uusi salasana (vähintään 8 merkkiä)', 'New password (8+ characters)'),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d), child: Text(t('Peru', 'Cancel'))),
          FilledButton(
            key: const ValueKey('acc-new-password-ok'),
            onPressed: () => Navigator.pop(d, c.text),
            child: Text(t('Tallenna', 'Save')),
          ),
        ],
      ),
    );
    // (controller not disposed here: the dialog's closing animation still uses it)
    if (r == null) return null;
    if (r.length < 8) {
      setState(() => error = t('Salasanan pitää olla vähintään 8 merkkiä.', 'At least 8 characters.'));
      return null;
    }
    return r;
  }

  Future<void> _changePassword(AccountState acc) async {
    final pw = await _askPassword(
      t('Vaihda salasana', 'Change password'),
      t('Keksi uusi salasana tilillesi.', 'Choose a new password.'),
    );
    if (pw == null) return;
    await _run(() async {
      await acc.changePassword(pw);
      if (mounted) setState(() => info = t('Salasana vaihdettu.', 'Password changed.'));
    }, checkInput: false);
  }

  Future<void> _resetVault(AccountState acc) async {
    final pw = await _askPassword(
      t('Aloita salasanat alusta', 'Start passwords over'),
      t(
        'Tilille tallennetut laitteiden salasanat ja pilviavaimet katoavat, ja ne pitää kirjoittaa uudelleen. Kodit ja ruudut säilyvät. Kirjautumissalasana vaihtuu tähän uuteen.',
        'Saved device passwords and cloud keys are lost and must be typed again. Homes and tiles stay. Your sign-in password changes to this new one.',
      ),
    );
    if (pw == null) return;
    await _run(() async {
      await acc.changePassword(pw);
      await acc.resetVault(pw);
    }, checkInput: false);
  }

  Future<void> _delete(AccountState acc) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (d) => AlertDialog(
        title: Text(t('Poistetaanko tili pysyvästi?', 'Delete the account permanently?')),
        content: Text(
          t(
            'Tili ${acc.email} ja kaikki palvelimelle tallennetut kodit, laitteet, ruudut ja salatut salasanat poistetaan. Tätä ei voi perua.\n\nTämä laite jatkaa toimintaa ilman tiliä. Muilla laitteillasi kirjautuminen päättyy.',
            'The account ${acc.email} and everything stored on the server is deleted. This cannot be undone.\n\nThis device keeps working without an account.',
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(d, false), child: Text(t('Peru', 'Cancel'))),
          FilledButton(
            key: const ValueKey('acc-delete-confirm'),
            style: FilledButton.styleFrom(backgroundColor: Theme.of(d).colorScheme.error),
            onPressed: () => Navigator.pop(d, true),
            child: Text(t('Poista tili', 'Delete account')),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _run(() async {
      await acc.deleteAccount();
      if (mounted) setState(() => info = t('Tili poistettu. Molaplan toimii nyt ilman tiliä.', 'Account deleted.'));
    }, checkInput: false);
  }
}
