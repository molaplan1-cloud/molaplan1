import 'package:material_ui/material_ui.dart';

import '../models/models.dart';
import 'account_page.dart';
import 'app_scope.dart';
import 'connections_page.dart';
import 'error_box.dart';
import 'remote_pages.dart';
import 'add_device_wizard.dart';
import 'template_gallery.dart';
import 'tile_editor.dart';
import 'language_picker.dart';

/// Step-by-step first-run guide. Re-openable from Settings.
class OnboardingPage extends StatefulWidget {
  const OnboardingPage({super.key});
  @override
  State<OnboardingPage> createState() => _OnboardingPageState();
}

class _OnboardingPageState extends State<OnboardingPage> {
  int step = 0;
  static const steps = 5;

  Dashboard get _dash => AppScope.read(context).config.dashboards.first;

  Future<void> _finish() async {
    await AppScope.read(context).setOnboardingDone(true);
    if (mounted) Navigator.of(context).pop();
  }

  void _go(int s) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() => step = s.clamp(0, steps - 1));
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final cs = Theme.of(context).colorScheme;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, _) {
        if (!didPop) step == 0 ? _finish() : _go(step - 1);
      },
      child: Scaffold(
        appBar: AppBar(
          automaticallyImplyLeading: false,
          leading: step == 0 ? null : IconButton(icon: const Icon(Icons.arrow_back), onPressed: () => _go(step - 1)),
          title: Text('${tx(context, 'Vaihe', 'Step')} ${step + 1} / $steps'),
          actions: [
            if (step < steps - 1)
              TextButton(
                key: const ValueKey('onboarding-skip'),
                onPressed: _finish,
                child: Text(tx(context, 'Ohita opas', 'Skip guide')),
              ),
            const SizedBox(width: 8),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(6),
            child: LinearProgressIndicator(value: (step + 1) / steps, backgroundColor: cs.surfaceContainerHigh),
          ),
        ),
        body: SafeArea(
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: KeyedSubtree(key: ValueKey(step), child: _body(context, st.lang)),
          ),
        ),
      ),
    );
  }

  Widget _body(BuildContext context, String lang) {
    switch (step) {
      case 0:
        return _welcome(context);
      case 1:
        return TemplateGrid(
          dashboard: _dash,
          onAdded: (viaWizard) {
            if (mounted) _go(viaWizard ? 3 : 2);
          },
          header: _stepHeader(
            context,
            tx(context, 'Lisää ensimmäinen laite', 'Add your first device'),
            tx(
              context,
              'Valitse laitteesi alta. Täytät vain sen osoitteen – loput tehdään puolestasi.',
              'Pick your device below. You only fill in its address – the rest is done for you.',
            ),
          ),
          onPick: (t) async {
            final ok = await openTemplateSetup(context, t, dashboard: _dash);
            if (ok == true && mounted) _go(2);
          },
          onBrand: (p) async {
            final ok = await Navigator.push<bool>(
              context,
              MaterialPageRoute(
                builder: (_) => AddDeviceWizard(provider: p, dashboard: _dash),
              ),
            );
            // The wizard already created the tiles: skip the "first tile" step.
            if (ok == true && mounted) _go(3);
          },
          onManual: () async {
            final c = await ConnectionsPage.addManual(context);
            if (c != null && mounted) _go(2);
          },
        );
      case 2:
        return _firstTile(context);
      case 3:
        return _remote(context);
      default:
        return _done(context);
    }
  }

  Widget _stepHeader(BuildContext context, String title, String body) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(title, style: Theme.of(context).textTheme.headlineSmall?.copyWith(fontWeight: FontWeight.w700)),
      const SizedBox(height: 6),
      Text(body, style: Theme.of(context).textTheme.bodyLarge),
    ],
  );

  Widget _page(BuildContext context, List<Widget> children, {required Widget action}) => Center(
    child: ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 560),
      child: Column(
        children: [
          Expanded(
            child: ListView(padding: const EdgeInsets.fromLTRB(24, 24, 24, 12), children: children),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 20),
            child: SizedBox(width: double.infinity, height: 60, child: action),
          ),
        ],
      ),
    ),
  );

  Widget _point(BuildContext context, IconData icon, String title, String body) {
    final cs = Theme.of(context).colorScheme;
    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              color: cs.primary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: cs.primary, size: 28),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(context).textTheme.titleMedium),
                const SizedBox(height: 2),
                Text(body, style: Theme.of(context).textTheme.bodyMedium),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _welcome(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _page(
      context,
      [
        Align(alignment: Alignment.centerRight, child: const LanguagePicker()),
        const SizedBox(height: 16),
        Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(color: cs.primary, borderRadius: BorderRadius.circular(22)),
          child: Icon(Icons.dashboard_customize_outlined, color: cs.onPrimary, size: 44),
        ),
        const SizedBox(height: 18),
        Text(
          tx(context, 'Tervetuloa Molaplaniin', 'Welcome to Molaplan'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 8),
        Text(
          tx(
            context,
            'Molaplan on kotisi oma ohjauspaneeli. Kokoat siihen itse ne laitteet ja napit, joita tarvitset.',
            'Molaplan is your home\'s own control panel. You put in exactly the devices and buttons you need.',
          ),
          style: Theme.of(context).textTheme.bodyLarge,
        ),
        const SizedBox(height: 24),
        _point(
          context,
          Icons.visibility_outlined,
          tx(context, 'Näe tilanne yhdellä silmäyksellä', 'See everything at a glance'),
          tx(
            context,
            'Lämpötilat, valot, hälytys ja kamerakuva samassa näkymässä.',
            'Temperatures, lights, alarm and camera in one view.',
          ),
        ),
        _point(
          context,
          Icons.touch_app_outlined,
          tx(context, 'Ohjaa yhdellä napautuksella', 'Control with one tap'),
          tx(
            context,
            'Valot päälle, IV-kone tehostukselle tai "Lähden kotoa" -painike, joka tekee monta asiaa kerralla.',
            'Lights on, boost the ventilation, or a "Leaving home" button that does many things at once.',
          ),
        ),
        _point(
          context,
          Icons.lock_outline,
          tx(context, 'Sama koti kaikilla laitteilla', 'The same home on all devices'),
          tx(
            context,
            'Halutessasi kirjaudu tilillä, niin PC, tabletti ja puhelin näyttävät saman kodin. Salasanat salataan laitteellasi. Tili ei ole pakollinen.',
            'Sign in if you like, and PC, tablet and phone show the same home. Passwords are encrypted on your device. No account needed.',
          ),
        ),
        const SizedBox(height: 8),
        OutlinedButton.icon(
          key: const ValueKey('onboarding-signin'),
          style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(52)),
          onPressed: () async {
            await Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage()));
            if (!mounted) return;
            final st = AppScope.read(this.context);
            if (st.account.signedIn && st.hasLocalSetup) await _finish();
          },
          icon: const Icon(Icons.login),
          label: Text(
            tx(context, 'Minulla on jo Molaplan-tili – kirjaudu', 'I already have a Molaplan account – sign in'),
          ),
        ),
      ],
      action: FilledButton(
        key: const ValueKey('onboarding-start'),
        onPressed: () => _go(1),
        child: Text(tx(context, 'Aloitetaan', 'Let\'s start'), style: const TextStyle(fontSize: 18)),
      ),
    );
  }

  Widget _firstTile(BuildContext context) {
    final d = AppScope.of(context).config.dashboards.first;
    final has = d.tiles.isNotEmpty;
    final cs = Theme.of(context).colorScheme;
    return _page(
      context,
      [
        _stepHeader(
          context,
          has
              ? tx(context, 'Ruudut ovat valmiina', 'Your tiles are ready')
              : tx(context, 'Lisää ensimmäinen ruutu', 'Add your first tile'),
          has
              ? tx(
                  context,
                  'Laitteellesi tehtiin nämä ruudut. Voit muuttaa ja järjestää niitä myöhemmin.',
                  'These tiles were made for your device. You can change and arrange them later.',
                )
              : tx(
                  context,
                  'Ruutu näyttää tiedon tai ohjaa laitetta. Valitse millainen ruutu tehdään:',
                  'A tile shows information or controls a device. Choose what kind of tile:',
                ),
        ),
        const SizedBox(height: 18),
        if (has)
          for (final t in d.tiles)
            Card(
              child: ListTile(
                leading: Icon(tileTypeIcon(t.type), color: cs.primary),
                title: Text(t.title),
                subtitle: Text(tileTypeLabel(context, t.type)),
                trailing: Icon(Icons.check_circle, color: cs.primary),
              ),
            )
        else
          for (final type in TileType.values.where((x) => x != TileType.thermostat))
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Card(
                child: ListTile(
                  leading: Icon(tileTypeIcon(type), color: cs.primary, size: 30),
                  title: Text(tileTypeLabel(context, type)),
                  subtitle: Text(tileTypeHelp(context, type)),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => TileEditor(
                          dashboard: d,
                          initial: TileConfig(
                            type: type,
                            colSpan: type == TileType.camera ? 2 : 1,
                            rowSpan: type == TileType.camera ? 2 : 1,
                          ),
                          isNew: true,
                        ),
                      ),
                    );
                    if (mounted && d.tiles.isNotEmpty) setState(() {});
                  },
                ),
              ),
            ),
      ],
      action: FilledButton(
        key: const ValueKey('onboarding-next'),
        onPressed: () => _go(3),
        child: Text(
          has ? tx(context, 'Seuraava', 'Next') : tx(context, 'Teen tämän myöhemmin', 'I\'ll do this later'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _remote(BuildContext context) {
    final st = AppScope.of(context);
    return _page(
      context,
      [
        _stepHeader(
          context,
          tx(context, 'Haluatko ohjata kotia myös kodin ulkopuolelta?', 'Control your home from outside too?'),
          tx(
            context,
            'Kotona kaikki toimii jo. Kodin ulkopuolelta tarvitaan kotiin yksi aina päällä oleva laite (vanha tabletti tai PC) – ei reititinasetuksia, ei tilejä.',
            'At home everything works already. From outside you need one always-on device at home (an old tablet or a PC) – no router settings, no accounts.',
          ),
        ),
        const SizedBox(height: 16),
        if (st.remote.isPaired || st.remote.bridgeOn) ...[
          SuccessBox(
            text: st.remote.isPaired
                ? tx(context, 'Etäyhteys on käytössä.', 'Remote access is on.')
                : tx(context, 'Tämä laite on kotisilta.', 'This device is the home bridge.'),
          ),
          const SizedBox(height: 12),
        ],
        remoteChoices(context),
      ],
      action: FilledButton(
        key: const ValueKey('onboarding-remote-next'),
        onPressed: () => _go(4),
        child: Text(
          st.remote.isPaired || st.remote.bridgeOn
              ? tx(context, 'Seuraava', 'Next')
              : tx(context, 'Ei nyt – vain kotona', 'Not now – home only'),
          style: const TextStyle(fontSize: 18),
        ),
      ),
    );
  }

  Widget _done(BuildContext context) {
    final cs = Theme.of(context).colorScheme;
    return _page(
      context,
      [
        Icon(Icons.celebration_outlined, size: 72, color: cs.primary),
        const SizedBox(height: 12),
        Text(
          tx(context, 'Valmista!', 'All set!'),
          style: Theme.of(context).textTheme.headlineMedium?.copyWith(fontWeight: FontWeight.w700),
        ),
        const SizedBox(height: 18),
        _point(
          context,
          Icons.touch_app_outlined,
          tx(context, 'Napauta ruutua', 'Tap a tile'),
          tx(
            context,
            'Kytkin vaihtuu päälle/pois, painike suorittaa komennon.',
            'A switch toggles, a button runs its command.',
          ),
        ),
        _point(
          context,
          Icons.edit_outlined,
          tx(context, 'Kynä-painike ylhäällä', 'Pencil button at the top'),
          tx(
            context,
            'Muokkaa, lisää, poista ja järjestä ruutuja vetämällä.',
            'Edit, add, delete and drag tiles around.',
          ),
        ),
        _point(
          context,
          Icons.info_outline,
          tx(context, 'Paina ruutua pitkään', 'Long-press a tile'),
          tx(
            context,
            'Näet lisätiedot ja selityksen, jos jokin ei toimi.',
            'See details and an explanation if something is wrong.',
          ),
        ),
        _point(
          context,
          Icons.settings_outlined,
          tx(context, 'Asetukset', 'Settings'),
          tx(
            context,
            'Sieltä löydät tämän oppaan, etäyhteyden ja varmuuskopioinnin.',
            'Find this guide, remote access and backups there.',
          ),
        ),
      ],
      action: FilledButton(
        key: const ValueKey('onboarding-done'),
        onPressed: _finish,
        child: Text(tx(context, 'Siirry omaan näkymään', 'Go to my dashboard'), style: const TextStyle(fontSize: 18)),
      ),
    );
  }
}
