import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import 'app_scope.dart';
import 'heatpump_pages.dart';
import 'remote_pages.dart';
import '../l10n/l10n.dart';

typedef Txt = (String fi, String en);

class Guide {
  const Guide({
    required this.id,
    required this.icon,
    required this.title,
    required this.summary,
    required this.good,
    required this.steps,
    this.links = const [],
    this.note,
  });
  final String id;
  final IconData icon;
  final Txt title;
  final Txt summary;
  final Txt good;
  final List<Txt> steps;
  final List<(String label, String url)> links;
  final Txt? note;
}

const remoteGuides = <Guide>[
  Guide(
    id: 'tailscale',
    icon: Icons.vpn_lock_outlined,
    title: ('Tailscale (helppo VPN)', 'Tailscale (easy VPN)'),
    summary: (
      'Ilmainen henkilökäyttöön. Puhelin ja koti ovat kuin samassa verkossa – Molaplan toimii samoilla osoitteilla kuin kotona.',
      'Free for personal use. Your phone and home act like one network – Molaplan works with the same addresses as at home.',
    ),
    good: (
      'Sopii, jos sinulla on kotona aina päällä PC, Raspberry Pi tai Home Assistant.',
      'Good if you have an always-on PC, Raspberry Pi or Home Assistant at home.',
    ),
    steps: [
      (
        'Tee Tailscale-tili osoitteessa tailscale.com (Google-, Microsoft- tai Apple-tunnuksella).',
        'Create a Tailscale account at tailscale.com (Google, Microsoft or Apple sign-in).',
      ),
      (
        'Asenna Tailscale kotona aina päällä olevaan laitteeseen. Home Assistantissa: Asetukset → Lisäosat → Tailscale.',
        'Install Tailscale on the always-on device at home. In Home Assistant: Settings → Add-ons → Tailscale.',
      ),
      (
        'Ota siinä käyttöön "subnet router" ja kerro kotiverkkosi, esim. 192.168.1.0/24. Silloin kaikki kodin laitteet näkyvät.',
        'Turn on "subnet router" there and enter your home network, e.g. 192.168.1.0/24. Then all your home devices are reachable.',
      ),
      (
        'Hyväksy reitti Tailscalen hallintasivulla (Machines → laite → Edit route settings).',
        'Approve the route in the Tailscale admin console (Machines → device → Edit route settings).',
      ),
      (
        'Asenna Tailscale-sovellus puhelimeen ja kirjaudu samalla tilillä. Laita VPN päälle.',
        'Install the Tailscale app on your phone and sign in with the same account. Switch the VPN on.',
      ),
      (
        'Valmis! Molaplan käyttää samoja osoitteita kuin kotona. Etäyhteyttä ei tarvitse muuttaa.',
        'Done! Molaplan uses the same addresses as at home. Nothing else to change.',
      ),
    ],
    links: [
      ('tailscale.com/download', 'https://tailscale.com/download'),
      ('Subnet router -ohje / guide', 'https://tailscale.com/kb/1019/subnets'),
    ],
  ),
  Guide(
    id: 'ha_tailscale',
    icon: Icons.home_outlined,
    title: ('Etäyhteys Tailscalella (Home Assistant)', 'Remote access with Tailscale (Home Assistant)'),
    summary: (
      'Yhdistä Molaplan Home Assistantiin myös kodin ulkopuolelta Tailscalen kautta. Paikallinen osoite ja Tailscale-osoite tallennetaan samaan yhteyteen; tunnus kysytään vain kerran.',
      'Reach Home Assistant from Molaplan even away from home, through Tailscale. The local address and the Tailscale address are stored on the same connection; the token is asked only once.',
    ),
    good: (
      'Sopii, kun Home Assistant pyörii kotona ja haluat avata sen turvallisesti ilman porttiohjauksia. Selainversiossa https-osoite (Tailscale Serve) välttää selaimen eston http-osoitteeseen.',
      'A good fit when Home Assistant runs at home and you want a secure path without port forwarding. In the web app an https address (Tailscale Serve) avoids the browser blocking http.',
    ),
    steps: [
      (
        'Home Assistantissa: Asetukset → Lisäosat → Lisäosakauppa. Hae "Tailscale" (virallinen lisäosa), asenna, ota käyttöön Käynnistä käynnistyksen yhteydessä ja Watchdog, käynnistä lisäosa, avaa Web UI ja kirjaudu sisään tai hyväksy laite.',
        'In Home Assistant: Settings → Add-ons → Add-on store. Search for "Tailscale" (the official add-on), install it, enable Start on boot and Watchdog, start it, open the Web UI and sign in or approve the machine.',
      ),
      (
        'Tailscalen hallinnassa (login.tailscale.com → Machines): etsi Home Assistantin kone ja sen 100.x-osoite. Ota koneella käyttöön "Disable key expiry" ja laita MagicDNS päälle.',
        'In the Tailscale admin console (login.tailscale.com → Machines): find the Home Assistant machine and its 100.x IP. Turn on "Disable key expiry" for that machine and enable MagicDNS.',
      ),
      (
        'Asenna Tailscale-sovellus laitteisiin, joissa Molaplan on, kirjaudu samalle tilille ja yhdistä. Kokeile selaimessa osoitetta http://homeassistant:8123.',
        'Install the Tailscale app on the devices that run Molaplan, sign in with the same account and connect. Test in a browser with http://homeassistant:8123.',
      ),
      (
        'Valinnainen HTTPS selainversiota ja PWA:ta varten: ota hallinnan DNS-asetuksissa käyttöön HTTPS-varmenteet, aseta lisäosassa proxy: true, käynnistä lisäosa uudelleen. Osoite on muotoa https://nimi.tailnet.ts.net. Lisää configuration.yaml-tiedostoon: http: use_x_forwarded_for: true ja trusted_proxies: [127.0.0.1]. Selain estää http-yhteyden https-sivulta, joten web-sovellus tarvitsee tämän https-osoitteen tai yhteyden kotisillan kautta.',
        'Optional HTTPS for the web app and PWA: enable HTTPS certificates in the admin DNS settings, set the add-on option proxy: true, and restart the add-on. The address looks like https://name.tailnet.ts.net. In configuration.yaml add http: use_x_forwarded_for: true and trusted_proxies: [127.0.0.1]. The browser blocks http from an https page, so the web app needs this https address or a connection through the home bridge.',
      ),
      (
        'Molaplanissa: kirjoita paikallinen osoite ja Tailscale-osoite samaan Home Assistant -yhteyteen (Tailscale-osoite on kohdassa Edistyneet) ja sama pitkäikäinen tunnus. Molaplan kokeilee ensin paikallista osoitetta ja käyttää Tailscale-osoitetta, kun et ole kotiverkossa.',
        'In Molaplan: enter the local address and the Tailscale address on the same Home Assistant connection (the Tailscale address is under Advanced) and the same long-lived token. Molaplan tries the local address first and uses the Tailscale address when you are away from the home network.',
      ),
    ],
    links: [
      ('tailscale.com/download', 'https://tailscale.com/download'),
      ('login.tailscale.com', 'https://login.tailscale.com'),
    ],
    note: (
      'Tämän laitteen, jossa Molaplan on, pitää olla yhdistettynä samaan tailnetiin kuin Home Assistant. Ohje on yleinen eikä viittaa tiettyyn asennukseen.',
      'The device running Molaplan must be connected to the same tailnet as Home Assistant. This guide is generic and does not refer to a particular installation.',
    ),
  ),
  Guide(
    id: 'wireguard',
    icon: Icons.shield_outlined,
    title: ('WireGuard (reitittimen VPN)', 'WireGuard (router VPN)'),
    summary: (
      'Jos reitittimesi tukee WireGuardia (esim. ASUS, FRITZ!Box, UniFi, OpenWrt), puhelin liittyy kotiverkkoon suoraan.',
      'If your router supports WireGuard (e.g. ASUS, FRITZ!Box, UniFi, OpenWrt), your phone joins the home network directly.',
    ),
    good: (
      'Sopii, jos reitittimessä on WireGuard ja liittymässä julkinen IP-osoite.',
      'Good if the router has WireGuard and your connection has a public IP address.',
    ),
    steps: [
      (
        'Avaa reitittimen asetukset ja etsi "VPN-palvelin" → "WireGuard".',
        'Open the router settings and look for "VPN server" → "WireGuard".',
      ),
      (
        'Ota palvelin käyttöön ja lisää uusi laite (peer) puhelimelle.',
        'Enable the server and add a new device (peer) for the phone.',
      ),
      (
        'Reititin näyttää QR-koodin. Asenna puhelimeen WireGuard-sovellus ja skannaa koodi.',
        'The router shows a QR code. Install the WireGuard app on the phone and scan it.',
      ),
      (
        'Tarkista että "Allowed IPs" sisältää kotiverkon (esim. 192.168.1.0/24).',
        'Check that "Allowed IPs" includes the home network (e.g. 192.168.1.0/24).',
      ),
      (
        'Laita VPN päälle puhelimessa – Molaplan toimii kuten kotona.',
        'Switch the VPN on in the phone – Molaplan works as at home.',
      ),
    ],
    links: [('wireguard.com/install', 'https://www.wireguard.com/install/')],
    note: (
      'Monissa mobiililaajakaistoissa (4G/5G-kotinetti) ei ole julkista IP-osoitetta (CGNAT), eikä WireGuard silloin toimi ulkoa. Käytä silloin Molaplan-etäyhteyttä tai Tailscalea.',
      'Many mobile broadband (4G/5G home internet) connections have no public IP (CGNAT) and WireGuard then cannot be reached from outside. Use Molaplan remote access or Tailscale instead.',
    ),
  ),
  Guide(
    id: 'nabucasa',
    icon: Icons.home_outlined,
    title: ('Home Assistant Cloud (Nabu Casa)', 'Home Assistant Cloud (Nabu Casa)'),
    summary: (
      'Maksullinen kuukausitilaus Home Assistantin tekijöiltä. Antaa turvallisen etäosoitteen Home Assistantiin.',
      'A paid monthly subscription from the makers of Home Assistant. Gives a secure remote address to Home Assistant.',
    ),
    good: ('Sopii, jos laitteesi ovat jo Home Assistantissa.', 'Good if your devices are already in Home Assistant.'),
    steps: [
      (
        'Home Assistantissa: Asetukset → Home Assistant Cloud → aloita kokeilu tai kirjaudu.',
        'In Home Assistant: Settings → Home Assistant Cloud → start the trial or sign in.',
      ),
      ('Ota "Remote control / Etäohjaus" päälle.', 'Turn "Remote control" on.'),
      (
        'Kopioi etäosoite, joka näyttää tältä: https://abcd1234.ui.nabu.casa',
        'Copy the remote address, which looks like: https://abcd1234.ui.nabu.casa',
      ),
      (
        'Molaplanissa: Yhteydet → Home Assistant → vaihda osoitteeksi tuo etäosoite. Token pysyy samana.',
        'In Molaplan: Connections → Home Assistant → change the address to the remote address. The token stays the same.',
      ),
      ('Valmis! Home Assistant -ruudut toimivat nyt kaikkialla.', 'Done! Home Assistant tiles now work everywhere.'),
    ],
    links: [('nabucasa.com', 'https://www.nabucasa.com/')],
    note: (
      'Tämä koskee vain Home Assistantin kautta ohjattavia laitteita. Muille (Modbus, kamerat suoraan) käytä Molaplan-etäyhteyttä tai VPN:ää.',
      'This only covers devices controlled through Home Assistant. For others (Modbus, cameras directly) use Molaplan remote access or a VPN.',
    ),
  ),
  Guide(
    id: 'hivemq',
    icon: Icons.hub_outlined,
    title: ('Pilvi-MQTT (esim. HiveMQ Cloud)', 'Cloud MQTT (e.g. HiveMQ Cloud)'),
    summary: (
      'Laitteet ja Molaplan puhuvat saman pilvipalvelimen kautta. HiveMQ Cloudissa on ilmainen taso, joka riittää kotikäyttöön.',
      'Devices and Molaplan talk through the same cloud server. HiveMQ Cloud has a free tier that is enough for home use.',
    ),
    good: (
      'Sopii MQTT-laitteille: Tasmota, ESPHome, Shelly, Zigbee2MQTT, omat ESP-laitteet.',
      'Good for MQTT devices: Tasmota, ESPHome, Shelly, Zigbee2MQTT, your own ESP boards.',
    ),
    steps: [
      (
        'Tee ilmainen tili osoitteessa console.hivemq.cloud ja luo ilmainen klusteri (Free/Serverless).',
        'Create a free account at console.hivemq.cloud and create a free cluster (Free/Serverless).',
      ),
      (
        'Kohdassa "Access Management" luo käyttäjätunnus ja salasana.',
        'Under "Access Management" create a username and password.',
      ),
      (
        'Kopioi palvelimen osoite (esim. abcd.s1.eu.hivemq.cloud). Portti on 8883 ja TLS on päällä.',
        'Copy the server address (e.g. abcd.s1.eu.hivemq.cloud). The port is 8883 with TLS on.',
      ),
      (
        'Vaihda laitteidesi MQTT-asetuksiin tämä palvelin, tunnus ja salasana (TLS päälle).',
        'Put this server, username and password in your devices\' MQTT settings (TLS on).',
      ),
      (
        'Molaplanissa: Yhteydet → MQTT → osoite, portti 8883, TLS päälle, tunnus ja salasana. Valmis – toimii kaikkialla.',
        'In Molaplan: Connections → MQTT → address, port 8883, TLS on, username and password. Done – works everywhere.',
      ),
    ],
    links: [('console.hivemq.cloud', 'https://console.hivemq.cloud/')],
    note: (
      'Valitse vahva salasana: kuka tahansa salasanan tietävä voi ohjata laitteitasi.',
      'Pick a strong password: anyone who knows it can control your devices.',
    ),
  ),
];

class GuidesPage extends StatelessWidget {
  const GuidesPage({super.key});
  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    String t(Txt x) => tr(lang, x.$1, x.$2);
    final cs = Theme.of(context).colorScheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Etäkäytön ohjeet', 'Remote access guides'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: cs.primaryContainer,
                child: ListTile(
                  key: const ValueKey('guide-molaplan'),
                  contentPadding: const EdgeInsets.all(14),
                  leading: Icon(Icons.auto_awesome, color: cs.onPrimaryContainer, size: 32),
                  title: Text(
                    tx(context, 'Helpoin: Molaplan-etäyhteys', 'Easiest: Molaplan remote access'),
                    style: TextStyle(color: cs.onPrimaryContainer, fontWeight: FontWeight.w700),
                  ),
                  subtitle: Text(
                    tx(
                      context,
                      'Ei tilejä, ei reititinasetuksia. Tarvitset vain kotona aina päällä olevan tabletin tai PC:n.',
                      'No accounts, no router settings. You only need a tablet or PC that stays on at home.',
                    ),
                    style: TextStyle(color: cs.onPrimaryContainer),
                  ),
                  onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
                ),
              ),
              const SizedBox(height: 12),
              Text(tx(context, 'Muut tavat', 'Other ways'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              for (final g in remoteGuides)
                Card(
                  child: ListTile(
                    key: ValueKey('guide-${g.id}'),
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                    leading: Icon(g.icon, size: 32, color: cs.primary),
                    title: Text(t(g.title)),
                    subtitle: Text(t(g.summary)),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuideDetailPage(guide: g))),
                  ),
                ),
              const SizedBox(height: 12),
              Text(tx(context, 'Laiteohjeet', 'Device guides'), style: Theme.of(context).textTheme.titleMedium),
              const SizedBox(height: 6),
              Card(
                child: ListTile(
                  key: const ValueKey('guide-heatpump-service'),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  leading: Icon(Icons.heat_pump_outlined, size: 32, color: cs.primary),
                  title: Text(
                    tx(context, 'Ilmalämpöpumppu (huoltoliitäntä/ESPHome)', 'Heat pump (service port/ESPHome)'),
                  ),
                  subtitle: Text(
                    tx(
                      context,
                      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Molaplan löytää lämpöpumpun itse.',
                      'Mitsubishi CN105, Daikin S21/X50A (Faikin), Panasonic CN-CNT, Toshiba. Found automatically.',
                    ),
                  ),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () =>
                      Navigator.push(context, MaterialPageRoute(builder: (_) => const HeatPumpServiceGuidePage())),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class GuideDetailPage extends StatelessWidget {
  const GuideDetailPage({super.key, required this.guide});
  final Guide guide;
  @override
  Widget build(BuildContext context) {
    final lang = AppScope.of(context).lang;
    String t(Txt x) => tr(lang, x.$1, x.$2);
    final text = Theme.of(context).textTheme;
    final cs = Theme.of(context).colorScheme;
    final g = guide;
    return Scaffold(
      appBar: AppBar(title: Text(t(g.title))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(t(g.summary), style: text.bodyLarge),
              const SizedBox(height: 8),
              Row(
                children: [
                  Icon(Icons.thumb_up_alt_outlined, color: cs.primary),
                  const SizedBox(width: 8),
                  Expanded(child: Text(t(g.good), style: text.bodyMedium)),
                ],
              ),
              const SizedBox(height: 18),
              for (var i = 0; i < g.steps.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 14),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: 16,
                        child: Text('${i + 1}', style: const TextStyle(fontWeight: FontWeight.w700)),
                      ),
                      const SizedBox(width: 12),
                      Expanded(child: Text(t(g.steps[i]), style: text.bodyLarge)),
                    ],
                  ),
                ),
              if (g.note != null)
                Card(
                  color: Colors.amber.withValues(alpha: 0.12),
                  child: Padding(
                    padding: const EdgeInsets.all(14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Icon(Icons.info_outline, color: Colors.amber.shade300),
                        const SizedBox(width: 10),
                        Expanded(child: Text(t(g.note!))),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  for (final (label, url) in g.links)
                    OutlinedButton.icon(
                      onPressed: () => launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication),
                      icon: const Icon(Icons.open_in_new),
                      label: Text(label),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}


Guide? guideById(String id) => remoteGuides.where((g) => g.id == id).firstOrNull;

/// Link / entry from the Home Assistant connection form: "Etäyhteys Tailscalella – ohje".
class HaTailscaleGuideLink extends StatelessWidget {
  const HaTailscaleGuideLink({super.key});

  @override
  Widget build(BuildContext context) {
    final g = guideById('ha_tailscale');
    if (g == null) return const SizedBox.shrink();
    return ListTile(
      key: const ValueKey('ha-tailscale-guide'),
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.menu_book_outlined),
      title: Text(tx(context, 'Etäyhteys Tailscalella – ohje', 'Remote access with Tailscale – guide')),
      subtitle: Text(
        tx(
          context,
          'Lisäosa Home Assistantiin, MagicDNS ja osoitteet Molaplanissa.',
          'The Home Assistant add-on, MagicDNS, and the addresses in Molaplan.',
        ),
      ),
      trailing: const Icon(Icons.chevron_right),
      onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => GuideDetailPage(guide: g))),
    );
  }
}
