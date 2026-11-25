import 'dart:io' show Platform;

import 'package:material_ui/material_ui.dart';

import 'account_page.dart';
import 'app_scope.dart';

/// Account is optional but encouraged (t115u/t116u): a welcome screen on first launch, a small
/// persistent banner while there is no account, and a friendly prompt after every device add.
/// All of it disappears once an account exists. Off in widget tests unless a test turns it on.
bool accountNudges = !Platform.environment.containsKey('FLUTTER_TEST');

bool needsAccountNudge(BuildContext context) => accountNudges && !AppScope.of(context).account.signedIn;

Future<void> openAccountSignUp(BuildContext context) =>
    Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage(startWithCode: true)));

/// "Ei tiliä – asetukset vain tällä laitteella. Luo tili ›" – not dismissable.
class NoAccountBanner extends StatelessWidget {
  const NoAccountBanner({super.key, this.compact = false, this.margin = const EdgeInsets.fromLTRB(14, 6, 14, 2)});
  final bool compact;
  final EdgeInsets margin;

  @override
  Widget build(BuildContext context) {
    if (!needsAccountNudge(context)) return const SizedBox.shrink();
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: margin,
      child: Material(
        key: const ValueKey('no-account-banner'),
        color: cs.tertiaryContainer,
        borderRadius: BorderRadius.circular(compact ? 12 : 14),
        child: InkWell(
          borderRadius: BorderRadius.circular(compact ? 12 : 14),
          onTap: () => openAccountSignUp(context),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: 14, vertical: compact ? 8 : 10),
            child: Row(
              children: [
                Icon(Icons.cloud_off_outlined, size: 18, color: cs.onTertiaryContainer),
                const SizedBox(width: 10),
                Expanded(
                  child: Text.rich(
                    TextSpan(
                      children: [
                        TextSpan(
                          text: tx(
                            context,
                            'Ei tiliä – asetukset vain tällä laitteella. ',
                            'No account – settings only on this device. ',
                          ),
                        ),
                        TextSpan(
                          text: tx(context, 'Luo tili ›', 'Create account ›'),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                      ],
                    ),
                    style: TextStyle(color: cs.onTertiaryContainer, fontSize: 13.5),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// After every device add while there is no account. "Ei nyt" just closes it.
Future<void> maybePromptAccount(BuildContext context) async {
  if (!context.mounted || !needsAccountNudge(context)) return;
  final go = await showDialog<bool>(
    context: context,
    builder: (c) => AlertDialog(
      key: const ValueKey('account-prompt'),
      icon: const Icon(Icons.cloud_done_outlined),
      title: Text(tx(c, 'Laite lisätty! 🎉', 'Device added! 🎉')),
      content: Text(
        tx(
          c,
          'Luo tili, niin asetukset säilyvät ja siirtyvät muille laitteille. Se käy sähköpostikoodilla, salasanaa ei tarvita.',
          'Create an account so your settings are kept and move to your other devices. It only takes an email code, no password needed.',
        ),
      ),
      actions: [
        TextButton(
          key: const ValueKey('account-prompt-later'),
          onPressed: () => Navigator.pop(c, false),
          child: Text(tx(c, 'Ei nyt', 'Not now')),
        ),
        FilledButton(
          key: const ValueKey('account-prompt-create'),
          onPressed: () => Navigator.pop(c, true),
          child: Text(tx(c, 'Luo tili', 'Create account')),
        ),
      ],
    ),
  );
  if (go == true && context.mounted) await openAccountSignUp(context);
}

/// First launch: create an account / sign in, or continue without one.
class WelcomePage extends StatelessWidget {
  const WelcomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    Widget point(IconData i, String s) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(i, color: cs.primary),
          const SizedBox(width: 12),
          Expanded(child: Text(s, style: text.bodyLarge)),
        ],
      ),
    );
    return Scaffold(
      key: const ValueKey('welcome-page'),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 480),
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(24),
              children: [
                Icon(Icons.home_outlined, size: 64, color: cs.primary),
                const SizedBox(height: 12),
                Text(
                  tx(context, 'Tervetuloa Molaplaniin', 'Welcome to Molaplan'),
                  style: text.headlineMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 20),
                point(
                  Icons.devices_outlined,
                  tx(context, 'Asetukset kaikilla laitteillasi', 'Your setup on all your devices'),
                ),
                point(
                  Icons.backup_outlined,
                  tx(context, 'Mitään ei katoa, vaikka puhelin vaihtuu', 'Nothing is lost when you change phones'),
                ),
                point(
                  Icons.lock_outline,
                  tx(context, 'Laitteiden salasanat salataan', 'Device passwords are encrypted'),
                ),
                const SizedBox(height: 24),
                FilledButton(
                  key: const ValueKey('welcome-account'),
                  style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(56)),
                  onPressed: () async {
                    await openAccountSignUp(context);
                    if (context.mounted) Navigator.pop(context);
                  },
                  child: Text(
                    tx(context, 'Luo tili / Kirjaudu', 'Create account / Sign in'),
                    style: const TextStyle(fontSize: 17),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  tx(context, 'Sähköpostikoodilla – ei salasanaa.', 'With an email code – no password.'),
                  style: text.bodySmall?.copyWith(color: cs.onSurfaceVariant),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),
                TextButton(
                  key: const ValueKey('welcome-skip'),
                  onPressed: () => Navigator.pop(context),
                  child: Text(tx(context, 'Jatka ilman tiliä', 'Continue without an account')),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
