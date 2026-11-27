import 'connections_page.dart';
import '../core/plat.dart';
import 'ha_picker.dart';
import 'energy_pages.dart';

import 'dart:convert';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:material_ui/material_ui.dart';

import '../models/models.dart' hide Threshold;
import '../state/examples.dart';
import '../state/app_state.dart' show AppState;
import '../state/migrations.dart' show connectionUses;
import '../state/update_state.dart' show UpdatePhase;
import 'account_page.dart';
import 'account_nudge.dart';
import 'app_scope.dart';
import 'web_info.dart';
import 'guides_page.dart';
import 'onboarding_page.dart';
import 'remote_pages.dart';
import 'share_pages.dart';
import 'installer_pages.dart';
import 'update_ui.dart';
import '../version.dart';
import 'language_picker.dart';

export '../version.dart' show appVersion;

class SettingsPage extends StatefulWidget {
  const SettingsPage({super.key});
  @override
  State<SettingsPage> createState() => _SettingsPageState();
}

class _SettingsPageState extends State<SettingsPage> {
  bool _includeSecrets = false;

  Future<void> _export() async {
    final st = AppScope.read(context);
    final json = st.exportJson(includeSecrets: _includeSecrets);
    try {
      final uri = await FilePicker.saveFile(
        fileName: 'molaplan-config.json',
        bytes: Uint8List.fromList(utf8.encode(json)),
        mimeType: 'application/json',
        dialogTitle: tx(context, 'Vie asetukset', 'Export configuration'),
      );
      if (uri != null && mounted) showSnack(context, tx(context, 'Asetukset viety', 'Configuration exported'));
    } catch (e) {
      if (mounted) showSnack(context, e.toString(), error: true);
    }
  }

  Future<void> _import() async {
    final st = AppScope.read(context);
    try {
      final f = await FilePicker.pickFile(
        type: FileType.any,
        dialogTitle: tx(context, 'Tuo asetukset', 'Import configuration'),
      );
      if (f == null || !mounted) return;
      final text = utf8.decode(await f.readAsBytes());
      if (!mounted) return;
      final ok = await confirmDialog(
        context,
        tx(context, 'Korvataanko nykyiset asetukset?', 'Replace current configuration?'),
        tx(
          context,
          'Kaikki nykyiset yhteydet ja näkymät korvataan tiedoston sisällöllä.',
          'All current connections and dashboards are replaced by the file contents.',
        ),
        ok: tx(context, 'Tuo', 'Import'),
      );
      if (!ok) return;
      await st.importJson(text);
      if (mounted) showSnack(context, tx(context, 'Asetukset tuotu', 'Configuration imported'));
    } catch (e) {
      if (mounted) showSnack(context, '${tx(context, 'Tuonti epäonnistui', 'Import failed')}: $e', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final text = Theme.of(context).textTheme;
    return Scaffold(
      appBar: AppBar(title: Text(tx(context, 'Asetukset', 'Settings'))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 640),
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              const NoAccountBanner(margin: EdgeInsets.only(bottom: 14)),
              Text(tx(context, 'Tili', 'Account'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                st.account.signedIn
                    ? tx(
                        context,
                        'Samat kodit ja ruudut kaikilla laitteillasi.',
                        'The same homes and tiles on all your devices.',
                      )
                    : tx(
                        context,
                        'Kirjaudu, niin kodit, laitteet ja ruudut ovat samat PC:llä, tabletilla ja puhelimella. Vapaaehtoinen.',
                        'Sign in to have the same homes, devices and tiles on PC, tablet and phone. Optional.',
                      ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('settings-account'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AccountPage())),
                  icon: Icon(st.account.signedIn ? Icons.account_circle : Icons.login),
                  label: Text(
                    st.account.signedIn
                        ? '${tx(context, 'Tili', 'Account')}: ${st.account.email}'
                        : tx(context, 'Kirjaudu tai luo tili', 'Sign in or create an account'),
                  ),
                ),
              ),
              if (Plat.isWeb && !st.account.signedIn) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('web-wipe-local'),
                    onPressed: () => confirmWipeBrowser(context, st),
                    icon: const Icon(Icons.delete_outline),
                    label: Text(tx(context, 'Poista selaimen tiedot', 'Delete browser data')),
                  ),
                ),
              ],
              if (Plat.isWeb) ...[
                const SizedBox(height: 28),
                Text(tx(context, 'Lataukset', 'Downloads'), style: text.titleMedium),
                const SizedBox(height: 4),
                if (!st.account.signedIn)
                  const NeedsAccountNote(
                    reasonFi: 'PC-sovelluksen lataus kaupan sivulta vaatii tilin (saman kuin tilauksessa).',
                    reasonEn: 'Downloading the PC app from the shop requires an account (the same one as on the order).',
                  )
                else
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonalIcon(
                      key: const ValueKey('settings-downloads'),
                      onPressed: () => openMolaplanUrl(molaplanDownloads),
                      icon: const Icon(Icons.download_outlined),
                      label: Text(tx(context, 'Avaa lataukset', 'Open downloads')),
                    ),
                  ),
              ],
              const SizedBox(height: 28),
              Text(tx(context, 'Kieli', 'Language'), style: text.titleMedium),
              const SizedBox(height: 8),
              const LanguagePicker(),
              const SizedBox(height: 28),
              // t162u: Ulkoasu › Teema.
              Text(tx(context, 'Ulkoasu', 'Appearance'), style: text.titleMedium),
              const SizedBox(height: 8),
              Text(tx(context, 'Teema', 'Theme'), style: text.bodyMedium),
              const SizedBox(height: 6),
              SegmentedButton<String>(
                key: const ValueKey('settings-theme'),
                segments: [
                  ButtonSegment(
                    value: 'light',
                    icon: const Icon(Icons.light_mode_outlined),
                    label: Text(tx(context, 'Vaalea', 'Light')),
                  ),
                  ButtonSegment(
                    value: 'dark',
                    icon: const Icon(Icons.dark_mode_outlined),
                    label: Text(tx(context, 'Tumma', 'Dark')),
                  ),
                  ButtonSegment(
                    value: 'system',
                    icon: const Icon(Icons.brightness_auto_outlined),
                    label: Text(tx(context, 'Automaattinen', 'Automatic')),
                  ),
                ],
                selected: {st.themeChoice == 'sun' ? 'system' : st.themeChoice},
                onSelectionChanged: (v) => st.setTheme(v.first),
              ),
              if (st.themeChoice == 'system' || st.themeChoice == 'sun')
                SwitchListTile(
                  key: const ValueKey('settings-theme-sun'),
                  contentPadding: EdgeInsets.zero,
                  value: st.themeChoice == 'sun',
                  onChanged: (v) => st.setTheme(v ? 'sun' : 'system'),
                  title: Text(tx(context, 'Auringonnousun ja -laskun mukaan', 'By sunrise and sunset')),
                  subtitle: Text(
                    st.config.energy.home == null
                        ? tx(
                            context,
                            'Vaatii kodin sijainnin (Energia › Koti). Siihen asti seurataan laitteen asetusta.',
                            'Needs the home location (Energy › Home). Until then the device setting is followed.',
                          )
                        : tx(
                            context,
                            'Vaalea päivällä, tumma illalla. Pois päältä: seuraa laitteen asetusta.',
                            'Light by day, dark in the evening. Off: follows the device setting.',
                          ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                  tx(
                    context,
                    'Valinta koskee tätä laitetta ja tallentuu tiliisi uusien laitteiden oletukseksi.',
                    'The choice applies to this device and is saved to your account as the default for new devices.',
                  ),
                  style: text.bodySmall,
                ),
              ),
              if (st.config.connections.any((c) => c.type == 'price'))
                SwitchListTile(
                  key: const ValueKey('settings-price-hourly'),
                  contentPadding: EdgeInsets.zero,
                  value: priceHourlyOf(st.config),
                  onChanged: (v) => st.setPriceHourly(v),
                  title: Text(tx(context, 'Näytä tuntikeskiarvona', 'Show as hourly average')),
                  subtitle: Text(
                    tx(
                      context,
                      'Sähkön hinta, halvimmat tunnit ja hintaohjaukset tunneittain (tuntihinnoiteltu sopimus). Pois: 15 min, kun alueen hinnat ovat 15 min.',
                      'Price, cheapest hours and price control per hour (hourly-billed contract). Off: 15 min where the area publishes 15-min prices.',
                    ),
                  ),
                ),
              SwitchListTile(
                key: const ValueKey('settings-morning-priciest'),
                contentPadding: EdgeInsets.zero,
                value: st.automations.settings.morningPriciest,
                onChanged: (v) async {
                  await st.automations.setMorningPriciest(v);
                  if (context.mounted) setState(() {});
                },
                title: Text(
                  tx(context, 'Aamukortti: näytä myös kallein tunti', 'Morning card: also show the priciest hour'),
                ),
                subtitle: Text(
                  tx(
                    context,
                    'Halvin tunti näytetään aina seuraavalta 24 tunnilta hintoineen.',
                    'The cheapest hour of the next 24 h is always shown with its price.',
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(tx(context, 'Laattakoko', 'Tile size'), style: text.titleMedium),
              const SizedBox(height: 8),
              SegmentedButton<String>(
                key: const ValueKey('settings-tile-density'),
                segments: [
                  ButtonSegment(value: 'small', label: Text(tx(context, 'Pieni', 'Small'))),
                  ButtonSegment(value: 'normal', label: Text(tx(context, 'Normaali', 'Normal'))),
                  ButtonSegment(value: 'large', label: Text(tx(context, 'Iso', 'Large'))),
                ],
                selected: {st.config.tileDensity},
                onSelectionChanged: (v) => st.setTileDensity(v.first),
              ),
              const SizedBox(height: 12),
              SwitchListTile(
                key: const ValueKey('settings-hide-away'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Piilota etänä toimimattomat', 'Hide tiles that don\'t work remotely')),
                subtitle: Text(
                  tx(
                    context,
                    'Kotiverkon ulkopuolella vain kotiverkossa toimivat ruudut piilotetaan. Oletuksena ne näkyvät harmaina paikallaan.',
                    'Away from home, tiles that only work on the home network are hidden. By default they stay in place, greyed out.',
                  ),
                ),
                value: st.config.hideAwayTiles,
                onChanged: st.setHideAwayTiles,
              ),
              SwitchListTile(
                key: const ValueKey('settings-strip'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Kello ja sää etusivulla', 'Clock and weather on the home screen')),
                subtitle: Text(
                  tx(
                    context,
                    'Kellonaika, päivä, sää ja sähkön hinta näkymän yläreunassa. Koskee vain tätä laitetta.',
                    'Time, date, weather and electricity price at the top of the view. This device only.',
                  ),
                ),
                value: st.config.homeStrip,
                onChanged: (v) => st.setDeviceFlag('homeStrip', v),
              ),
              SwitchListTile(
                key: const ValueKey('settings-animations'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Animaatiot', 'Animations')),
                subtitle: Text(
                  tx(
                    context,
                    'Pehmeät siirtymät, kun laite vaihtaa tilaa. Pois päältä = rauhallisempi ja kevyempi vanhalle tabletille. Koskee vain tätä laitetta.',
                    'Soft transitions when a device changes state. Off = calmer and lighter for an older tablet. This device only.',
                  ),
                ),
                value: st.config.animations,
                onChanged: (v) => st.setDeviceFlag('animations', v),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                key: const ValueKey('settings-advanced'),
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Edistyneet', 'Advanced')),
                subtitle: Text(
                  tx(
                    context,
                    'Näyttää tekniset asetukset: yhteydet (HTTP, MQTT, Modbus…), viestit, JSON-polut ja ruutujen lähteet. Useimmat eivät tarvitse näitä.',
                    'Shows technical settings: connections (HTTP, MQTT, Modbus…), payloads, JSON paths and tile sources. Most people don\'t need these.',
                  ),
                ),
                value: st.config.advanced,
                onChanged: st.setAdvanced,
              ),
              const SizedBox(height: 20),
              const EnergySettingsSection(),
              // t237u: ONE Home Assistant button (a picker when there are several servers),
              // under its own "Laitteet ja integraatiot" heading instead of inside Energia.
              const SizedBox(height: 20),
              Text(tx(context, 'Laitteet ja integraatiot', 'Devices and integrations'), style: text.titleMedium),
              const SizedBox(height: 8),
              // t245u: connections (PIN, reply topic…) without the Edistyneet switch.
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  key: const ValueKey('settings-connections'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const ConnectionsPage())),
                  icon: const Icon(Icons.device_hub),
                  label: Text('${tx(context, 'Yhteydet', 'Connections')} (${st.config.connections.length})'),
                ),
              ),
              if (haServers(st).isNotEmpty) ...[
                const SizedBox(height: 8),
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('settings-ha'),
                    onPressed: () => openHaPicker(context),
                    icon: const Icon(Icons.home_outlined),
                    label: Text(tx(context, 'Home Assistant: lisää laitteita', 'Home Assistant: add devices')),
                  ),
                ),
              ],
              const SizedBox(height: 20),
              Text(tx(context, 'Etäkäyttö', 'Remote access'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(context, 'Ohjaa kotia myös kodin ulkopuolelta.', 'Control your home from outside too.'),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              // t174u: which device is the bridge, online / offline, last seen.
              const BridgeStatusLine(),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('settings-remote'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const RemoteHubPage())),
                    icon: const Icon(Icons.cloud_outlined),
                    label: Text(
                      st.remote.isPaired || st.remote.bridgeOn
                          ? '${tx(context, 'Etäkäyttö', 'Remote access')}: ${RemoteStatusChip.describe(context).$3}'
                          : tx(context, 'Ota etäkäyttö käyttöön', 'Set up remote access'),
                    ),
                  ),
                  OutlinedButton.icon(
                    key: const ValueKey('settings-guides'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const GuidesPage())),
                    icon: const Icon(Icons.menu_book_outlined),
                    label: Text(
                      tx(context, 'Ohjeet: VPN, Nabu Casa, pilvi-MQTT', 'Guides: VPN, Nabu Casa, cloud MQTT'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              // R215–R217: sharing + installer.
              Text(tx(context, 'Jakaminen', 'Sharing'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Anna toiselle tai asentajalle pääsy valitsemiisi laitteisiin.',
                  'Give someone, or an installer, access to the devices you choose.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    key: const ValueKey('settings-sharing'),
                    onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SharingPage())),
                    icon: Badge(
                      isLabelVisible: st.sharing.badge > 0,
                      label: Text('${st.sharing.badge}'),
                      child: const Icon(Icons.share_outlined),
                    ),
                    label: Text(
                      st.sharing.badge > 0
                          ? tx(context, 'Jakaminen – uusi kutsu', 'Sharing – new invite')
                          : tx(context, 'Jakaminen', 'Sharing'),
                    ),
                  ),
                  // R258: customers give an installer access here; approved installers find
                  // their ID and customers here too.
                  OutlinedButton.icon(
                    key: const ValueKey('settings-installer'),
                    onPressed: () =>
                        Navigator.push(context, MaterialPageRoute(builder: (_) => const InstallerHubPage())),
                    icon: const Icon(Icons.engineering_outlined),
                    label: Text(tx(context, 'Asentaja', 'Installer')),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Ohjeet', 'Help'), style: text.titleMedium),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: FilledButton.tonalIcon(
                  key: const ValueKey('settings-onboarding'),
                  onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const OnboardingPage())),
                  icon: const Icon(Icons.school_outlined),
                  label: Text(tx(context, 'Näytä aloitusopas', 'Show the getting-started guide')),
                ),
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Varmuuskopio ja siirto', 'Backup and transfer'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Vie asetukset JSON-tiedostoon ja tuo ne toiselle laitteelle (esim. PC → puhelin).',
                  'Export the configuration to a JSON file and import it on another device (e.g. PC → phone).',
                ),
                style: text.bodySmall,
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx(context, 'Sisällytä salasanat ja tokenit', 'Include passwords and tokens')),
                subtitle: Text(
                  tx(
                    context,
                    'Tiedosto on silloin salaamaton – säilytä se turvassa.',
                    'The file is then unencrypted – keep it safe.',
                  ),
                ),
                value: _includeSecrets,
                onChanged: (v) => setState(() => _includeSecrets = v),
              ),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                children: [
                  FilledButton.tonalIcon(
                    onPressed: _export,
                    icon: const Icon(Icons.upload_file),
                    label: Text(tx(context, 'Vie', 'Export')),
                  ),
                  FilledButton.tonalIcon(
                    onPressed: _import,
                    icon: const Icon(Icons.download),
                    label: Text(tx(context, 'Tuo', 'Import')),
                  ),
                ],
              ),
              const SizedBox(height: 28),
              Text(tx(context, 'Esimerkki', 'Example'), style: text.titleMedium),
              const SizedBox(height: 4),
              Text(
                tx(
                  context,
                  'Lisää esimerkkinäkymä (kamera, hälytys, valot, IV-kone). Esimerkkilaitteet eivät ota yhteyttä mihinkään – lisää omat laitteesi Lisää laite -painikkeella.',
                  'Add an example dashboard (camera, alarm, lights, ventilation). The example devices never connect anywhere – add your own with Add device.',
                ),
                style: text.bodySmall,
              ),
              const SizedBox(height: 8),
              Align(
                alignment: Alignment.centerLeft,
                child: OutlinedButton.icon(
                  onPressed: () async {
                    await st.merge(exampleConfig(st.lang));
                    if (context.mounted) Navigator.pop(context, 'example');
                  },
                  icon: const Icon(Icons.auto_awesome_outlined),
                  label: Text(tx(context, 'Lisää esimerkkinäkymä', 'Add example dashboard')),
                ),
              ),
              const SizedBox(height: 28),
              Text(
                Plat.isWeb
                    ? 'Molaplan $appVersion – ${tx(context, 'selainversio', 'browser version')}'
                    : 'Molaplan $appVersion',
                style: text.titleMedium,
              ),
              const SizedBox(height: 8),
              // R253: the web app updates itself on reload; its about box says what it can do.
              if (Plat.isWeb)
                const WebLimitsCard()
              else
                Align(
                  alignment: Alignment.centerLeft,
                  child: OutlinedButton.icon(
                    key: const ValueKey('settings-check-updates'),
                    onPressed: st.update.phase == UpdatePhase.checking ? null : () => manualUpdateCheck(context),
                    icon: st.update.phase == UpdatePhase.checking
                        ? const SizedBox.square(dimension: 18, child: CircularProgressIndicator(strokeWidth: 2))
                        : const Icon(Icons.system_update_alt),
                    label: Text(tx(context, 'Tarkista päivitykset', 'Check for updates')),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                tx(
                  context,
                  'Oma ohjauspääte: HTTP, MQTT, Modbus TCP, Home Assistant, kamerat, WebSocket, TCP ja UDP. Ilman tiliä kaikki asetukset pysyvät tällä laitteella.',
                  'Your own control terminal: HTTP, MQTT, Modbus TCP, Home Assistant, cameras, WebSocket, TCP and UDP. Without an account all settings stay on this device.',
                ),
                style: text.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// t237u: the Home Assistant servers you can add devices from (demo examples excluded).
List<ConnectionConfig> haServers(AppState st) =>
    st.config.connections.where((c) => c.type == 'homeassistant' && c.settings['demo'] != true).toList();

/// Opens the entity picker; with several HA servers first asks which one (by name + address).
Future<void> openHaPicker(BuildContext context) async {
  final st = AppScope.read(context);
  final list = haServers(st);
  if (list.isEmpty) return;
  ConnectionConfig? pick = list.length == 1 ? list.first : null;
  pick ??= await showModalBottomSheet<ConnectionConfig>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, setSheet) {
        final now = haServers(st);
        return SafeArea(
          child: ListView(
            key: const ValueKey('ha-picker'),
            shrinkWrap: true,
            children: [
              ListTile(
                title: Text(tx(ctx, 'Mistä Home Assistantista?', 'Which Home Assistant?')),
                subtitle: Text(
                  tx(
                    ctx,
                    'Sinulla on useampi Home Assistant -yhteys. Käyttämättömän (ei ruutuja) voi poistaa.',
                    'You have more than one Home Assistant connection. An unused one (no tiles) can be removed.',
                  ),
                ),
              ),
              for (final c in now)
                ListTile(
                  key: ValueKey('ha-pick-${c.id}'),
                  leading: const Icon(Icons.home_outlined),
                  title: Text(c.name),
                  subtitle: Text(
                    '${_haHost(c)} · ${connectionUses(st.config, c.id) == 0 ? tx(ctx, 'ei ruutuja', 'no tiles') : '${connectionUses(st.config, c.id)} ${tx(ctx, 'ruutua', 'tiles')}'}',
                  ),
                  onTap: () => Navigator.pop(ctx, c),
                  trailing: connectionUses(st.config, c.id) == 0 && now.length > 1
                      ? IconButton(
                          key: ValueKey('ha-remove-${c.id}'),
                          tooltip: tx(ctx, 'Poista käyttämätön yhteys', 'Remove unused connection'),
                          icon: const Icon(Icons.delete_outline),
                          onPressed: () async {
                            final ok = await confirmDialog(
                              ctx,
                              tx(ctx, 'Poistetaanko yhteys?', 'Remove the connection?'),
                              '${c.name} (${_haHost(c)})',
                            );
                            if (!ok) return;
                            await st.deleteConnection(c.id);
                            if (haServers(st).isEmpty && ctx.mounted) {
                              Navigator.pop(ctx);
                            } else {
                              setSheet(() {});
                            }
                          },
                        )
                      : null,
                ),
            ],
          ),
        );
      },
    ),
  );
  if (pick == null || !context.mounted) return;
  final c = pick;
  await Navigator.push(context, MaterialPageRoute(builder: (_) => HaEntityPickerPage(connection: c)));
}

String _haHost(ConnectionConfig c) {
  final u = Uri.tryParse('${c.settings['baseUrl'] ?? ''}');
  if (u == null || u.host.isEmpty) return '${c.settings['baseUrl'] ?? '-'}';
  return u.hasPort ? '${u.host}:${u.port}' : u.host;
}
