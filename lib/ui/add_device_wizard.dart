import 'dart:async';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';

import '../devices/find.dart';
import '../devices/registry.dart';
import '../models/models.dart';
import '../templates/device_templates.dart' show TemplateResult;
import 'app_scope.dart';
import 'remote_pages.dart';

enum WizStep { remote, find, connect, choose, done }

IconData providerIcon(DeviceProvider p) => switch (p.category) {
  'light' => Icons.lightbulb_outline,
  'hub' => Icons.hub_outlined,
  'cloud' => Icons.cloud_outlined,
  'camera' => Icons.videocam_outlined,
  _ => Icons.power_outlined,
};

Color providerColor(DeviceProvider p) => switch (p.id) {
  'hue' => const Color(0xFFFFB74D),
  'dirigera' => const Color(0xFF42A5F5),
  'shelly_cloud' => const Color(0xFF7E57C2),
  'sonoff' => const Color(0xFF1E88E5),
  _ when p.category == 'camera' => const Color(0xFF5C6BC0),
  _ => const Color(0xFF26A69A),
};

/// Plain-language title + what to do, for every problem.
(String, String) problemText(BuildContext context, AddProblem p, {String brand = 'laite', String address = ''}) {
  String t(String fi, String en) => tx(context, fi, en);
  return switch (p) {
    AddProblem.noNetwork => (
      t('Tämä laite ei ole yhteydessä wifiin', 'This device is not on Wi-Fi'),
      t(
        'Yhdistä tämä laite kodin wifiin (samaan, jossa $brand on). Tai jos olet kodin ulkopuolella, ota käyttöön kotisilta – silloin haku tehdään kotona olevan laitteen kautta.',
        'Connect this device to your home Wi-Fi (the one $brand uses). Or, if you are away, set up the home bridge so the search runs on a device at home.',
      ),
    ),
    AddProblem.unreachable => (
      address.isEmpty
          ? t('Laitetta ei tavoitettu', 'Could not reach the device')
          : t('Laitetta ei tavoitettu osoitteesta $address', 'Could not reach the device at $address'),
      t(
        '1. Tarkista että $brand on päällä (valo palaa).\n2. Tämän laitteen (tai kotisillan) pitää olla samassa wifissä kuin $brand.\n3. Tarkista osoite – se voi vaihtua. Paina "Takaisin" ja hae uudelleen.',
        '1. Check that $brand is powered.\n2. This device (or the home bridge) must be on the same Wi-Fi.\n3. Check the address – it can change. Tap "Back" and search again.',
      ),
    ),
    AddProblem.notThisBrand => (
      t('Osoitteessa on jokin muu laite', 'A different device answered'),
      t(
        'Osoitteesta vastasi laite, joka ei ole $brand. Tarkista osoite ja kokeile uudelleen.',
        'The device at that address is not $brand. Check the address.',
      ),
    ),
    AddProblem.needsPassword => (
      t('Laite pyytää salasanaa', 'The device asks for a password'),
      t(
        'Olet asettanut laitteeseen salasanan. Kirjoita se alle ja paina "Yhdistä".',
        'A password is set on the device. Type it below and tap "Connect".',
      ),
    ),
    AddProblem.needsDetails => (
      t('Tarvitaan vielä yksi tieto', 'One more detail is needed'),
      t(
        '$brand ei kerro tätä itse. Kirjoita se alle ja paina "Yhdistä".',
        '$brand does not tell this by itself. Type it below and tap "Connect".',
      ),
    ),
    AddProblem.wrongPassword => (
      t('Salasana ei kelpaa', 'Wrong password'),
      t(
        'Tarkista salasana (isot ja pienet kirjaimet). Sen voi vaihtaa laitteen omasta sovelluksesta.',
        'Check the password (case matters). You can change it in the device app.',
      ),
    ),
    AddProblem.buttonNotPressed => (
      t('Painiketta ei painettu ajoissa', 'The button was not pressed in time'),
      t(
        'Paina "Yritä uudelleen" ja paina sitten painiketta heti.',
        'Tap "Try again" and then press the button right away.',
      ),
    ),
    AddProblem.nothingToAdd => (
      t('Laitteelta ei löytynyt ohjattavaa', 'Nothing to control was found'),
      t(
        'Laite vastasi, mutta siinä ei ollut kytkimiä tai valoja. Jos käytät pilveä, kirjoita laitteen tunnus (Device ID) käsin.',
        'The device answered but has no switches or lights. For the cloud, type the Device ID.',
      ),
    ),
    AddProblem.cloudBadKey => (
      t('Pilviavain tai palvelin ei kelpaa', 'Cloud key or server not accepted'),
      t(
        'Kopioi avain ja palvelimen osoite uudelleen Shelly-sovelluksesta (Käyttäjäasetukset → Authorization cloud key).',
        'Copy the key and server again from the Shelly app (User settings → Authorization cloud key).',
      ),
    ),
    AddProblem.cloudOffline => (
      t('Pilveen ei saatu yhteyttä', 'Could not reach the cloud'),
      t('Tarkista nettiyhteys ja yritä uudelleen.', 'Check the internet connection.'),
    ),
    AddProblem.cloudRateLimit => (
      t('Liian monta pyyntöä', 'Too many requests'),
      t('Pilvi rajoittaa pyyntöjä. Odota hetki ja yritä uudelleen.', 'The cloud limits requests. Wait a moment.'),
    ),
    AddProblem.bridgeOld => (
      t('Kotisilta on vanha versio', 'The home bridge is out of date'),
      t(
        'Päivitä kotisillan Molaplan (Asetukset → Tarkista päivitykset) ja yritä uudelleen.',
        'Update Molaplan on the bridge (Settings → Check for updates).',
      ),
    ),
    AddProblem.bridgeOffline => (
      t('Kotisilta ei ole päällä', 'The home bridge is off'),
      t(
        'Tarkista että kotona oleva kotisilta (tabletti tai PC) on päällä, Molaplan on auki ja sillä on netti.',
        'Check that the bridge at home is on, Molaplan is open and it has internet.',
      ),
    ),
    AddProblem.unknown => (
      t('Laitteeseen ei saatu yhteyttä', 'Could not connect to the device'),
      t(
        'Tarkista osoite ja että laite on päällä, ja yritä uudelleen. Tarkempi syy näkyy teknisissä tiedoissa.',
        'Check the address and that the device is on, then try again. The technical details show the exact reason.',
      ),
    ),
  };
}

/// Step-by-step: (remote setup) -> find -> connect/pair -> choose tiles -> done.
class AddDeviceWizard extends StatefulWidget {
  const AddDeviceWizard({
    super.key,
    required this.provider,
    this.dashboard,
    this.initial,
    this.finder,
    this.locals,
    this.driverFor,
  });
  final DeviceProvider provider;
  final Dashboard? dashboard;

  /// Already found (network scan "Etsi laitteet"): skip the search and connect to it.
  final Candidate? initial;

  /// Test hooks.
  final Future<List<Candidate>> Function(DeviceProvider p)? finder;
  final Future<List<String>> Function()? locals;
  final AddContext Function(BuildContext)? driverFor;

  @override
  State<AddDeviceWizard> createState() => _AddDeviceWizardState();
}

class _AddDeviceWizardState extends State<AddDeviceWizard> {
  late DeviceProvider p = widget.provider;
  WizStep step = WizStep.find;
  List<Candidate> found = [];
  List<String> locals = [];
  bool searching = false;
  bool searchedViaBridge = false;
  AddDeviceError? searchError;
  bool manual = false;
  final addrCtl = TextEditingController();
  final pwCtl = TextEditingController();
  final cred = <String, TextEditingController>{};
  Candidate? picked;
  bool busy = false;
  int? countdown;
  AddDeviceError? error;
  Connected? connected;
  final names = <String, TextEditingController>{};
  final skip = <String>{};
  bool extras = true;
  int added = 0;
  Map<String, String> creds = {};
  bool _cancel = false;

  bool get cloud => p.kind == ProviderKind.cloud;
  String get brand => p.name(AppScope.read(context).lang);

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final st = AppScope.read(context);
      if (widget.initial != null) {
        addrCtl.text = widget.initial!.address;
        _pick(widget.initial!);
        return;
      }
      final needRemote = !cloud && !st.remote.isPaired && !st.remote.bridgeOn;
      setState(() => step = needRemote ? WizStep.remote : WizStep.find);
      if (!needRemote) _search();
    });
  }

  @override
  void dispose() {
    _cancel = true;
    addrCtl.dispose();
    pwCtl.dispose();
    for (final c in [...cred.values, ...names.values]) {
      c.dispose();
    }
    super.dispose();
  }

  AddContext _ctx() {
    if (widget.driverFor != null) return widget.driverFor!(context);
    final st = AppScope.read(context);
    return AddContext(driver: st.remote.router.wrap, lang: st.lang);
  }

  Future<void> _search() async {
    if (cloud) return;
    final st = AppScope.read(context);
    setState(() {
      searching = true;
      searchError = null;
    });
    locals = await (widget.locals ?? localIPv4s)();
    final results = <Candidate>[];
    AddDeviceError? err;
    final viaBridge = st.remote.isPaired && !st.remote.bridgeOn;
    await Future.wait([
      (widget.finder != null ? widget.finder!(p) : findLocal(p, locals: locals))
          .then(results.addAll)
          .catchError((_) {}),
      if (viaBridge && widget.finder == null)
        findViaBridge(st.remote.router, p).then(results.addAll).catchError((Object e) {
          err = explain(e);
        }),
    ]);
    if (!mounted) return;
    setState(() {
      searching = false;
      searchedViaBridge = viaBridge;
      found = mergeCandidates(results);
      searchError = found.isEmpty ? err : null;
      if (found.isEmpty) manual = true;
    });
  }

  void _go(WizStep s) {
    _cancel = false;
    setState(() {
      step = s;
      error = null;
    });
  }

  Future<void> _pick(Candidate c) async {
    picked = c;
    creds = {};
    pwCtl.clear();
    _go(WizStep.connect);
    await _connect();
  }

  Future<void> _manualNext() async {
    final a = addrCtl.text.trim();
    if (a.isEmpty) {
      showSnack(context, tx(context, 'Kirjoita ensin osoite', 'Type the address first'), error: true);
      return;
    }
    final st = AppScope.read(context);
    final chk = checkAddress(a, locals);
    if (chk.issue == AddressIssue.badFormat) {
      showSnack(context, addressHint(a, locals, st.lang)!, error: true);
      return;
    }
    if (chk.issue == AddressIssue.notPrivate) {
      final fix = chk.suggestion;
      final r = await showDialog<String>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.spellcheck, size: 36),
          title: Text(tx(c, 'Tarkista osoite', 'Check the address')),
          content: Text(
            tx(
                  c,
                  '${hostOf(a)} ei ole kotiverkon osoite. Kotiverkon osoitteet alkavat yleensä 192.168. – katso osoite uudelleen $brand-sovelluksesta.',
                  '${hostOf(a)} is not a home network address. They usually start with 192.168. – check it again in the $brand app.',
                ) +
                (fix == null ? '' : '\n\n${tx(c, 'Tarkoititko $fix?', 'Did you mean $fix?')}'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c), child: Text(tx(c, 'Korjaan itse', 'I\'ll fix it'))),
            TextButton(onPressed: () => Navigator.pop(c, 'as-is'), child: Text(tx(c, 'Kokeile silti', 'Try anyway'))),
            if (fix != null)
              FilledButton(
                key: const ValueKey('wiz-use-fix'),
                onPressed: () => Navigator.pop(c, 'fix'),
                child: Text(tx(c, 'Käytä $fix', 'Use $fix')),
              ),
          ],
        ),
      );
      if (r == null || !mounted) return;
      if (r == 'fix') {
        addrCtl.text = a.replaceFirst(hostOf(a), fix!);
        return _manualNext();
      }
    }
    final h = hostOf(addrCtl.text.trim());
    if (!st.remote.isPaired && locals.isNotEmpty && isIPv4(h) && !sameSubnet(h, locals)) {
      final mine = locals.first.substring(0, locals.first.lastIndexOf('.'));
      final go = await showDialog<bool>(
        context: context,
        builder: (c) => AlertDialog(
          icon: const Icon(Icons.wifi_off, size: 36),
          title: Text(tx(c, 'Osoite on eri verkossa', 'The address is on another network')),
          content: Text(
            tx(
              c,
              'Osoite $h ei ole samassa verkossa kuin tämä laite ($mine.x). Yleensä se tarkoittaa, että tämä laite on eri wifissä kuin $brand.\n\nYhdistä tämä laite samaan wifiin kuin $brand, tai ota kotisilta käyttöön.',
              'Address $h is not on the same network as this device ($mine.x). Usually this device is on a different Wi-Fi than $brand.\n\nJoin the same Wi-Fi, or set up the home bridge.',
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(c, false), child: Text(tx(c, 'Takaisin', 'Back'))),
            FilledButton(onPressed: () => Navigator.pop(c, true), child: Text(tx(c, 'Kokeile silti', 'Try anyway'))),
          ],
        ),
      );
      if (go != true) return;
    }
    await _pick(Candidate(provider: p.id, address: addrCtl.text.trim()));
  }

  Future<void> _connect() async {
    final st = AppScope.read(context);
    final c = picked!;
    setState(() {
      busy = true;
      error = null;
      countdown = null;
    });
    try {
      if (!cloud && !st.remote.isPaired && !c.viaBridge && widget.locals == null && (await localIPv4s()).isEmpty) {
        throw AddDeviceError(AddProblem.noNetwork);
      }
      final ctx = _ctx();
      if (p.pairMode == PairMode.button && (creds['token'] ?? '').isEmpty) {
        setState(() => countdown = p.pairWindow.inSeconds);
        creds = {
          ...creds,
          ...await p.pair(
            ctx,
            c,
            tick: (s) {
              if (mounted && !_cancel) setState(() => countdown = s);
            },
          ),
        };
        if (!mounted || _cancel) return;
        setState(() => countdown = null);
      }
      if (p.pairMode == PairMode.password && pwCtl.text.isNotEmpty) creds['password'] = pwCtl.text;
      // Local devices: extra details typed with the password (camera user, Sonoff device id).
      if (!cloud) {
        for (final e in cred.entries) {
          if (e.value.text.trim().isNotEmpty) creds[e.key] = e.value.text.trim();
        }
      }
      final r = await p.connect(ctx, c, creds);
      if (!mounted || _cancel) return;
      connected = r;
      skip
        ..clear()
        ..addAll(r.items.where((i) => !i.preselect).map((i) => i.key));
      for (final it in r.items) {
        (names[it.key] ??= TextEditingController()).text = it.name;
      }
      _go(WizStep.choose);
    } catch (e) {
      if (!mounted) return;
      setState(() => error = explain(e, havePassword: pwCtl.text.isNotEmpty));
    } finally {
      if (mounted) {
        setState(() {
          busy = false;
          countdown = null;
        });
      }
    }
  }

  Future<void> _cloudNext() async {
    for (final f in p.credFields.where((f) => !f.optional)) {
      if ((cred[f.key]?.text.trim() ?? '').isEmpty) {
        showSnack(context, '${tx(context, 'Täytä ensin', 'Fill in first')}: ${tx(context, f.fi, f.en)}', error: true);
        return;
      }
    }
    creds = {for (final e in cred.entries) e.key: e.value.text.trim()};
    picked = Candidate(provider: p.id, address: creds['server'] ?? '');
    _go(WizStep.connect);
    await _connect();
  }

  Future<void> _add() async {
    final st = AppScope.read(context);
    final r = connected!;
    final tiles = p.tiles(
      r,
      names: {for (final e in names.entries) e.key: e.value.text},
      skip: skip,
      power: extras,
      lang: st.lang,
    );
    if (tiles.isEmpty) {
      showSnack(context, tx(context, 'Valitse vähintään yksi', 'Pick at least one'), error: true);
      return;
    }
    await st.applyTemplate(TemplateResult([r.connection], tiles), into: widget.dashboard);
    added = tiles.length;
    _go(WizStep.done);
  }

  // ---------------------------------------------------------------- UI

  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    final idx = WizStep.values.indexOf(step);
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Lisää: ${p.name(lang)}', 'Add: ${p.name(lang)}'))),
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 640),
            child: Column(
              children: [
                LinearProgressIndicator(value: (idx + 1) / WizStep.values.length, minHeight: 4),
                Expanded(
                  child: ListView(
                    padding: const EdgeInsets.all(20),
                    children: switch (step) {
                      WizStep.remote => _remote(context),
                      WizStep.find => cloud ? _cloudForm(context) : _find(context),
                      WizStep.connect => _connecting(context),
                      WizStep.choose => _choose(context),
                      WizStep.done => _done(context),
                    },
                  ),
                ),
                _bottom(context),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _bottom(BuildContext context) {
    Widget? next;
    VoidCallback? back = () => Navigator.maybePop(context);
    switch (step) {
      case WizStep.remote:
        break;
      case WizStep.find:
        final st = AppScope.read(context);
        if (!cloud && !st.remote.isPaired && !st.remote.bridgeOn) back = () => _go(WizStep.remote);
        next = cloud
            ? FilledButton.icon(
                key: const ValueKey('wiz-next'),
                onPressed: _cloudNext,
                icon: const Icon(Icons.arrow_forward),
                label: Text(tx(context, 'Seuraava', 'Next')),
              )
            : manual
            ? FilledButton.icon(
                key: const ValueKey('wiz-next'),
                onPressed: _manualNext,
                icon: const Icon(Icons.arrow_forward),
                label: Text(tx(context, 'Seuraava', 'Next')),
              )
            : null;
      case WizStep.connect:
        back = () {
          _cancel = true;
          _go(WizStep.find);
        };
      case WizStep.choose:
        back = () => _go(WizStep.find);
        final n = connected!.items.where((i) => !skip.contains(i.key)).length;
        next = FilledButton.icon(
          key: const ValueKey('wiz-add'),
          onPressed: n == 0 ? null : _add,
          icon: const Icon(Icons.check),
          label: Text(tx(context, 'Lisää kotinäkymään', 'Add to home view')),
        );
      case WizStep.done:
        back = null;
        next = FilledButton.icon(
          key: const ValueKey('wiz-finish'),
          onPressed: () => Navigator.pop(context, true),
          icon: const Icon(Icons.home_outlined),
          label: Text(tx(context, 'Näytä kotinäkymä', 'Show home view')),
        );
    }
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        children: [
          if (back != null)
            OutlinedButton.icon(
              key: const ValueKey('wiz-back'),
              onPressed: back,
              icon: const Icon(Icons.arrow_back),
              label: Text(tx(context, 'Takaisin', 'Back')),
            ),
          const Spacer(),
          ?next,
        ],
      ),
    );
  }

  Widget _title(BuildContext context, String t, [String? sub]) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(t, style: Theme.of(context).textTheme.headlineSmall),
        if (sub != null) ...[const SizedBox(height: 8), Text(sub, style: Theme.of(context).textTheme.bodyLarge)],
      ],
    ),
  );

  Widget _bigChoice(
    BuildContext context, {
    required Key key,
    required IconData icon,
    required String title,
    required String body,
    required VoidCallback onTap,
  }) => Card(
    key: key,
    margin: const EdgeInsets.only(bottom: 12),
    child: InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, size: 36, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 4),
                  Text(body, style: Theme.of(context).textTheme.bodyMedium),
                ],
              ),
            ),
            const Icon(Icons.chevron_right),
          ],
        ),
      ),
    ),
  );

  List<Widget> _remote(BuildContext context) {
    final st = AppScope.read(context);
    final text = Theme.of(context).textTheme;
    Widget section(String s) => Padding(
      padding: const EdgeInsets.only(top: 10, bottom: 8),
      child: Text(s, style: text.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary)),
    );
    final cloud = p.id == 'shelly'
        ? [
            section(tx(context, 'A) Ilman kotisiltaa', 'A) Without a home bridge')),
            _bigChoice(
              context,
              key: const ValueKey('wiz-use-cloud'),
              icon: Icons.cloud_outlined,
              title: tx(context, 'Käytä Shelly Cloudia (ei kotisiltaa)', 'Use Shelly Cloud (no bridge)'),
              body: tx(
                context,
                'Paras, jos mikään laite ei ole aina kotona – esim. kun tabletti kulkee mukanasi. Ohjaus kulkee Shellyn oman pilven kautta. Tarvitset avaimen Shelly-sovelluksesta (näytämme mistä).',
                'Best if no device always stays at home – e.g. your tablet travels with you. Control goes via Shelly\'s own cloud. You need a key from the Shelly app (we show where).',
              ),
              onTap: () => setState(() {
                p = providerById('shelly_cloud')!;
                step = WizStep.find;
              }),
            ),
            section(tx(context, 'B) Kotisillan kautta', 'B) Through a home bridge')),
          ]
        : <Widget>[];
    return [
      _title(
        context,
        tx(context, 'Miten ohjaat kotia muualta?', 'How will you control your home when away?'),
        tx(
              context,
              'Kotisilta on laite, joka on AINA kotona, päällä ja samassa wifissä kuin $brand – esim. vanha puhelin, tabletti tai PC. Muut laitteesi ottavat siihen yhteyden netin yli (salattu, ei porttiohjauksia). Jos laite lähtee mukaasi, se ei sovi kotisillaksi.',
              'A home bridge is a device that ALWAYS stays at home, switched on and on the same Wi-Fi as $brand – e.g. an old phone, tablet or PC. Your other devices reach it over the internet (encrypted, no port forwarding). A device you carry around is not a good bridge.',
            ) +
            (st.account.signedIn
                ? ' ${tx(context, 'Koska olet kirjautunut, kotiyhteys siirtyy kaikille laitteillesi automaattisesti.', 'As you are signed in, the home connection reaches all your devices automatically.')}'
                : ''),
      ),
      ...cloud,
      _bigChoice(
        context,
        key: const ValueKey('wiz-make-bridge'),
        icon: Icons.router_outlined,
        title: tx(
          context,
          'Tämä laite jää aina kotiin – tee siitä kotisilta',
          'This device always stays home – make it the bridge',
        ),
        body: tx(
          context,
          'Pidä laite laturissa ja Molaplan auki. Muut laitteet yhdistetään siihen QR-koodilla tai kirjautumalla samalle tilille.',
          'Keep it charging with Molaplan open. Other devices connect with a QR code or by signing in to the same account.',
        ),
        onTap: () async {
          await st.setBridgeMode(true);
          await keepScreenOn(true);
          if (!mounted) return;
          _go(WizStep.find);
          unawaited(_search());
        },
      ),
      _bigChoice(
        context,
        key: const ValueKey('wiz-pair'),
        icon: Icons.qr_code_scanner,
        title: tx(
          context,
          'Kotisilta on jo toisella laitteella – yhdistä siihen',
          'The bridge is on another device – connect to it',
        ),
        body: tx(
          context,
          'Skannaa kotisillan QR-koodi. Sen jälkeen laitteet haetaan kotisillan kautta, vaikka olisit muualla.',
          'Scan the bridge QR code. Devices are then found through the bridge, even when you are away.',
        ),
        onTap: () async {
          await Navigator.push(context, MaterialPageRoute(builder: (_) => const PairPage()));
          if (!mounted) return;
          _go(WizStep.find);
          unawaited(_search());
        },
      ),
      TextButton(
        key: const ValueKey('wiz-skip-remote'),
        onPressed: () {
          _go(WizStep.find);
          _search();
        },
        child: Text(
          tx(
            context,
            'Ohita nyt – lisään laitteen kotiverkossa (etäyhteyden voi ottaa käyttöön myöhemmin)',
            'Skip for now – add on the home network (remote access can be set up later)',
          ),
        ),
      ),
    ];
  }

  Widget _banner(
    BuildContext context, {
    required IconData icon,
    required Color color,
    required String text,
    List<Widget> actions = const [],
  }) => Container(
    margin: const EdgeInsets.only(bottom: 14),
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: color.withValues(alpha: 0.12),
      borderRadius: BorderRadius.circular(12),
      border: Border.all(color: color.withValues(alpha: 0.5)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: color),
            const SizedBox(width: 10),
            Expanded(child: Text(text, style: const TextStyle(fontSize: 15, height: 1.35))),
          ],
        ),
        if (actions.isNotEmpty)
          Padding(
            padding: const EdgeInsets.only(top: 8),
            child: Wrap(spacing: 8, runSpacing: 8, children: actions),
          ),
      ],
    ),
  );

  List<Widget> _find(BuildContext context) {
    final st = AppScope.read(context);
    final noWifi = !searching && locals.isEmpty && !st.remote.isPaired;
    return [
      _title(
        context,
        tx(context, 'Etsitään: $brand', 'Finding: $brand'),
        searchedViaBridge || (st.remote.isPaired && searching)
            ? tx(
                context,
                'Haku tehdään kotisillan kautta, joten tämä toimii myös kodin ulkopuolella.',
                'Searching through the home bridge, so this works away from home too.',
              )
            : tx(context, 'Etsin laitteita kodin wifistä. Napauta omaasi.', 'Looking on your home Wi-Fi. Tap yours.'),
      ),
      if (noWifi)
        _banner(
          context,
          icon: Icons.wifi_off,
          color: Colors.redAccent,
          text:
              '${problemText(context, AddProblem.noNetwork, brand: brand).$1}\n${problemText(context, AddProblem.noNetwork, brand: brand).$2}',
          actions: [
            if (Platform.isAndroid)
              FilledButton.tonalIcon(
                key: const ValueKey('wiz-wifi-settings'),
                onPressed: () => const MethodChannel('molaplan/multicast').invokeMethod('wifiSettings'),
                icon: const Icon(Icons.wifi),
                label: Text(tx(context, 'Avaa wifi-asetukset', 'Open Wi-Fi settings')),
              ),
            OutlinedButton.icon(
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: Text(tx(context, 'Yhdistin – etsi uudelleen', 'Connected – search again')),
            ),
          ],
        ),
      if (searchError != null)
        _banner(
          context,
          icon: Icons.error_outline,
          color: Colors.orange,
          text:
              '${problemText(context, searchError!.problem, brand: brand).$1}\n${problemText(context, searchError!.problem, brand: brand).$2}',
        ),
      if (searching)
        Padding(
          padding: const EdgeInsets.symmetric(vertical: 24),
          child: Column(
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 12),
              Text(tx(context, 'Etsitään… (noin 5 sekuntia)', 'Searching… (about 5 seconds)')),
            ],
          ),
        )
      else ...[
        for (final c in found)
          Card(
            margin: const EdgeInsets.only(bottom: 10),
            child: ListTile(
              key: ValueKey('wiz-found-${c.address}'),
              minVerticalPadding: 14,
              leading: Icon(providerIcon(p), size: 32, color: providerColor(p)),
              title: Text(c.title, style: Theme.of(context).textTheme.titleMedium),
              subtitle: Text(
                [
                  if (c.model.isNotEmpty && c.model != c.title) c.model,
                  c.address,
                  if (c.viaBridge) tx(context, 'kotisillan kautta', 'via home bridge'),
                ].join(' · '),
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => _pick(c),
            ),
          ),
        if (found.isEmpty && !noWifi)
          _banner(
            context,
            icon: Icons.search_off,
            color: Colors.blueGrey,
            text: tx(
              context,
              'Laitteita ei löytynyt automaattisesti. Tarkista että $brand on päällä ja samassa wifissä${st.remote.isPaired ? ' kuin kotisilta' : ''}. Voit myös kirjoittaa osoitteen alle.',
              'Nothing found automatically. Check that $brand is on and on the same Wi-Fi. You can also type the address below.',
            ),
          ),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            OutlinedButton.icon(
              key: const ValueKey('wiz-search-again'),
              onPressed: _search,
              icon: const Icon(Icons.refresh),
              label: Text(tx(context, 'Etsi uudelleen', 'Search again')),
            ),
            if (!manual)
              TextButton.icon(
                key: const ValueKey('wiz-manual'),
                onPressed: () => setState(() => manual = true),
                icon: const Icon(Icons.keyboard),
                label: Text(tx(context, 'Kirjoita osoite itse', 'Type the address')),
              ),
          ],
        ),
      ],
      if (manual) ...[
        const SizedBox(height: 20),
        Text(
          tx(context, 'Tai kirjoita osoite itse', 'Or type the address'),
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 8),
        TextField(
          key: const ValueKey('wiz-address'),
          controller: addrCtl,
          keyboardType: TextInputType.url,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: tx(context, 'IP-osoite', 'IP address'),
            hintText: p.addressHint,
            border: const OutlineInputBorder(),
            helperText: addressHint(addrCtl.text, locals, AppScope.read(context).lang),
            helperMaxLines: 3,
            helperStyle: TextStyle(color: Theme.of(context).colorScheme.tertiary),
          ),
          onChanged: (_) => setState(() {}),
          onSubmitted: (_) => _manualNext(),
        ),
        const SizedBox(height: 8),
        Text(
          '${tx(context, 'Mistä löydän sen?', 'Where do I find it?')} ${tx(context, p.addressHelpFi, p.addressHelpEn)}',
          style: Theme.of(context).textTheme.bodyMedium,
        ),
      ],
    ];
  }

  List<Widget> _cloudForm(BuildContext context) => [
    _title(context, p.name(AppScope.read(context).lang), tx(context, p.descFi, p.descEn)),
    for (final f in p.credFields) ...[
      TextField(
        key: ValueKey('wiz-cred-${f.key}'),
        controller: cred[f.key] ??= TextEditingController(),
        obscureText: f.secret,
        decoration: InputDecoration(
          labelText: tx(context, f.fi, f.en) + (f.optional ? tx(context, ' (vapaaehtoinen)', ' (optional)') : ''),
          hintText: f.hint,
          border: const OutlineInputBorder(),
        ),
      ),
      Padding(
        padding: const EdgeInsets.fromLTRB(4, 6, 4, 16),
        child: Text(tx(context, f.helpFi, f.helpEn), style: Theme.of(context).textTheme.bodySmall),
      ),
    ],
  ];

  List<Widget> _connecting(BuildContext context) {
    final c = picked!;
    final e = error;
    final out = <Widget>[];
    if (countdown != null) {
      out.addAll([
        _title(
          context,
          tx(context, 'Paina painiketta nyt', 'Press the button now'),
          tx(context, p.pairHelpFi, p.pairHelpEn),
        ),
        Icon(Icons.touch_app, size: 96, color: providerColor(p)),
        const SizedBox(height: 16),
        LinearProgressIndicator(value: countdown! / p.pairWindow.inSeconds, minHeight: 10),
        const SizedBox(height: 8),
        Center(
          child: Text(
            tx(context, 'Aikaa jäljellä $countdown s', '$countdown s left'),
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      ]);
      return out;
    }
    if (busy) {
      out.addAll([
        _title(
          context,
          tx(context, 'Yhdistetään…', 'Connecting…'),
          '${c.title}${c.address != c.title && !cloud ? ' (${c.address})' : ''}',
        ),
        const Center(
          child: Padding(padding: EdgeInsets.all(24), child: CircularProgressIndicator()),
        ),
      ]);
      return out;
    }
    if (e == null) return out;
    var (title, body) = problemText(context, e.problem, brand: brand, address: cloud ? '' : c.address);
    final st = AppScope.read(context);
    final login = e.problem == AddProblem.needsPassword || e.problem == AddProblem.wrongPassword;
    final details = !cloud && (login || e.problem == AddProblem.needsDetails);
    if (p.category == 'camera' && e.problem == AddProblem.needsPassword) {
      title = tx(context, 'Kirjaudu kameraan', 'Sign in to the camera');
      body = tx(context, p.pairHelpFi, p.pairHelpEn);
    } else if (details && p.pairHelpFi.isNotEmpty) {
      body = '$body\n\n${tx(context, p.pairHelpFi, p.pairHelpEn)}';
    }
    out.addAll([
      _title(context, title),
      _banner(context, icon: Icons.info_outline, color: Colors.orange, text: body),
      if (details)
        for (final f in p.credFields)
          if (e.problem == AddProblem.needsDetails || p.category == 'camera') ...[
            TextField(
              key: ValueKey('wiz-cred-${f.key}'),
              controller: cred[f.key] ??= TextEditingController(),
              obscureText: f.secret,
              style: const TextStyle(fontSize: 18),
              decoration: InputDecoration(
                labelText: tx(context, f.fi, f.en),
                hintText: f.hint,
                helperText: f.helpFi.isEmpty ? null : tx(context, f.helpFi, f.helpEn),
                helperMaxLines: 3,
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
          ],
      if (login) ...[
        TextField(
          key: const ValueKey('wiz-password'),
          controller: pwCtl,
          obscureText: true,
          autofocus: true,
          style: const TextStyle(fontSize: 18),
          decoration: InputDecoration(
            labelText: tx(context, 'Laitteen salasana', 'Device password'),
            border: const OutlineInputBorder(),
          ),
          onSubmitted: (_) => _connect(),
        ),
        const SizedBox(height: 12),
      ],
      Wrap(
        spacing: 8,
        runSpacing: 8,
        children: [
          FilledButton.icon(
            key: const ValueKey('wiz-retry'),
            onPressed: () {
              if (e.problem == AddProblem.needsPassword && pwCtl.text.isEmpty) return;
              if (e.problem == AddProblem.needsDetails && cred.values.every((c) => c.text.trim().isEmpty)) return;
              if (p.pairMode == PairMode.button && e.problem == AddProblem.needsPassword) creds.remove('token');
              _connect();
            },
            icon: Icon(details ? Icons.login : Icons.refresh),
            label: Text(details ? tx(context, 'Yhdistä', 'Connect') : tx(context, 'Yritä uudelleen', 'Try again')),
          ),
          if ((e.problem == AddProblem.unreachable || e.problem == AddProblem.noNetwork) &&
              !st.remote.isPaired &&
              !st.remote.bridgeOn)
            OutlinedButton.icon(
              onPressed: () => _go(WizStep.remote),
              icon: const Icon(Icons.router_outlined),
              label: Text(tx(context, 'Olen kodin ulkopuolella', 'I am away from home')),
            ),
          if (e.problem == AddProblem.noNetwork && Platform.isAndroid)
            OutlinedButton.icon(
              onPressed: () => const MethodChannel('molaplan/multicast').invokeMethod('wifiSettings'),
              icon: const Icon(Icons.wifi),
              label: Text(tx(context, 'Avaa wifi-asetukset', 'Open Wi-Fi settings')),
            ),
        ],
      ),
      const SizedBox(height: 12),
      ExpansionTile(
        tilePadding: EdgeInsets.zero,
        title: Text(tx(context, 'Tekniset tiedot', 'Technical details'), style: Theme.of(context).textTheme.bodySmall),
        children: [
          SelectableText(e.detail.isEmpty ? e.problem.name : e.detail, style: Theme.of(context).textTheme.bodySmall),
        ],
      ),
    ]);
    return out;
  }

  List<Widget> _choose(BuildContext context) {
    final r = connected!;
    final hasExtras = r.items.any((i) => i.hasPower);
    final light = r.items.any((i) => i.kind == 'light');
    return [
      _title(
        context,
        tx(context, 'Löytyi: ${r.label}', 'Found: ${r.label}'),
        tx(
          context,
          'Valitse mitkä tulevat kotinäkymään ja anna niille nimet (esim. Lämmitys, Ulkovalot).',
          'Pick what goes on the home view and name them.',
        ),
      ),
      if (r.items.length > 3)
        Align(
          alignment: Alignment.centerRight,
          child: TextButton(
            key: const ValueKey('wiz-select-all'),
            onPressed: () => setState(() => skip.isEmpty ? skip.addAll(r.items.map((i) => i.key)) : skip.clear()),
            child: Text(
              skip.isEmpty
                  ? tx(context, 'Poista valinnat', 'Select none')
                  : tx(context, 'Valitse kaikki (${r.items.length})', 'Select all (${r.items.length})'),
            ),
          ),
        ),
      for (final (i, it) in r.items.indexed) ...[
        if (it.group.isNotEmpty && (i == 0 || r.items[i - 1].group != it.group))
          Padding(
            key: ValueKey('wiz-group-${it.group}'),
            padding: const EdgeInsets.fromLTRB(4, 12, 4, 6),
            child: Text(
              it.group,
              style: Theme.of(context).textTheme.titleSmall?.copyWith(color: Theme.of(context).colorScheme.primary),
            ),
          ),
        Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(4, 8, 12, 8),
            child: Row(
              children: [
                Checkbox(
                  key: ValueKey('wiz-item-${it.key}'),
                  value: !skip.contains(it.key),
                  onChanged: (v) => setState(() => v == true ? skip.remove(it.key) : skip.add(it.key)),
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      TextField(
                        key: ValueKey('wiz-name-${it.key}'),
                        controller: names[it.key],
                        style: const TextStyle(fontSize: 17),
                        decoration: InputDecoration(isDense: true, labelText: tx(context, 'Nimi', 'Name')),
                      ),
                      if (it.subtitle.isNotEmpty)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: Text(it.subtitle, style: Theme.of(context).textTheme.bodySmall),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
      if (hasExtras)
        SwitchListTile(
          key: const ValueKey('wiz-extras'),
          contentPadding: EdgeInsets.zero,
          value: extras,
          onChanged: (v) => setState(() => extras = v),
          title: Text(
            light
                ? tx(context, 'Lisää myös kirkkaus / teho', 'Also add brightness / power')
                : tx(context, 'Näytä myös teho (W)', 'Also show power (W)'),
          ),
        ),
    ];
  }

  List<Widget> _done(BuildContext context) {
    final st = AppScope.read(context);
    final remoteOk = cloud || st.remote.isPaired || st.remote.bridgeOn;
    return [
      const Icon(Icons.check_circle, size: 96, color: Colors.green),
      const SizedBox(height: 12),
      _title(
        context,
        tx(context, 'Valmis! $added ruutua lisätty', 'Done! $added tiles added'),
        remoteOk
            ? (cloud
                  ? tx(
                      context,
                      'Ruudut toimivat kotona ja kodin ulkopuolella pilven kautta – mitään muuta ei tarvitse tehdä.',
                      'The tiles work at home and away through the cloud – nothing else to do.',
                    )
                  : tx(
                      context,
                      'Ruudut toimivat kotona ja kodin ulkopuolella kotisillan kautta – mitään muuta ei tarvitse tehdä.',
                      'The tiles work at home and away through the home bridge – nothing else to do.',
                    ))
            : tx(
                context,
                'Ruudut toimivat nyt kotiverkossa. Jotta voit ohjata kotia mistä tahansa, ota kotisilta käyttöön.',
                'The tiles work on your home network. To control from anywhere, set up the home bridge.',
              ),
      ),
      if (!remoteOk)
        OutlinedButton.icon(
          key: const ValueKey('wiz-setup-remote'),
          onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
          icon: const Icon(Icons.cloud_outlined),
          label: Text(tx(context, 'Ota etäyhteys käyttöön', 'Set up remote access')),
        ),
    ];
  }
}
