/// R510–R514 (t314u / t315u): "Pikakomento ja kotinäyttö" for EVERY tile – links that open
/// the tile or run its command, a one-tile home-screen web app (the iPhone version of a tile),
/// an iPhone widget script for the free Scriptable app and iOS Shortcuts / Siri recipes.
library;

import 'package:flutter/services.dart';
import 'package:material_ui/material_ui.dart';
import 'package:url_launcher/url_launcher.dart';

import '../models/models.dart';
import '../sharing/tile_links.dart';
import '../state/home_launcher.dart' show tileCanRun;
import 'app_scope.dart';

Future<void> showTileShortcuts(BuildContext context, TileConfig tile) =>
    Navigator.of(context).push(MaterialPageRoute(builder: (_) => TileShortcutsPage(tile: tile)));

class TileShortcutsPage extends StatefulWidget {
  const TileShortcutsPage({super.key, required this.tile});
  final TileConfig tile;

  @override
  State<TileShortcutsPage> createState() => _TileShortcutsPageState();
}

class _TileShortcutsPageState extends State<TileShortcutsPage> {
  TileConfig get t => widget.tile;

  Future<void> _copy(String text, {String? what}) async {
    await Clipboard.setData(ClipboardData(text: text));
    if (mounted) showSnack(context, what ?? tx(context, 'Kopioitu', 'Copied'));
  }

  Future<void> _setFeed(String? topic) async {
    final st = AppScope.read(context);
    final old = t.feed;
    await st.updateTileLook(t, (x) => x.feed = topic);
    if (old != null && old != topic) {
      await st.tileFeeds.revoke(old, title: t.title, lang: st.lang);
    }
    // Publish the current value at once so the widget has something to show.
    if (topic != null) {
      await st.tileFeeds.onValue(t, st.lastTileValue(t.id), lang: st.lang);
    }
    if (mounted) setState(() {});
  }

  Widget _link(String key, String label, String url, {String? help}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(14, 12, 8, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: Theme.of(context).textTheme.titleSmall),
          if (help != null) ...[const SizedBox(height: 4), Text(help, style: Theme.of(context).textTheme.bodySmall)],
          const SizedBox(height: 6),
          SelectableText(url, key: ValueKey('$key-url'), style: const TextStyle(fontSize: 12)),
          Wrap(
            spacing: 4,
            children: [
              TextButton.icon(
                key: ValueKey('$key-copy'),
                onPressed: () => _copy(url, what: tx(context, 'Linkki kopioitu', 'Link copied')),
                icon: const Icon(Icons.copy, size: 18),
                label: Text(tx(context, 'Kopioi', 'Copy')),
              ),
              TextButton.icon(
                key: ValueKey('$key-open'),
                onPressed: () => launchUrl(Uri.parse(url), webOnlyWindowName: '_blank'),
                icon: const Icon(Icons.open_in_new, size: 18),
                label: Text(tx(context, 'Avaa', 'Open link')),
              ),
            ],
          ),
        ],
      ),
    ),
  );

  Widget _copyBlock(String key, String label, String text, {String? help}) => Card(
    margin: const EdgeInsets.symmetric(vertical: 6),
    child: ExpansionTile(
      key: ValueKey(key),
      title: Text(label),
      subtitle: help == null ? null : Text(help, style: Theme.of(context).textTheme.bodySmall),
      childrenPadding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
      children: [
        Align(
          alignment: Alignment.centerLeft,
          child: FilledButton.tonalIcon(
            key: ValueKey('$key-copy'),
            onPressed: () => _copy(text),
            icon: const Icon(Icons.copy, size: 18),
            label: Text(tx(context, 'Kopioi', 'Copy')),
          ),
        ),
        const SizedBox(height: 8),
        Container(
          constraints: const BoxConstraints(maxHeight: 260),
          width: double.infinity,
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            borderRadius: BorderRadius.circular(8),
          ),
          child: SingleChildScrollView(
            child: SelectableText(text, style: const TextStyle(fontFamily: 'monospace', fontSize: 11)),
          ),
        ),
      ],
    ),
  );

  Widget _h(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 18, 4, 4),
    child: Text(text, style: Theme.of(context).textTheme.titleMedium),
  );

  Widget _p(String text) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
    child: Text(text, style: Theme.of(context).textTheme.bodyMedium),
  );

  @override
  Widget build(BuildContext context) {
    final st = AppScope.of(context);
    final lang = st.lang;
    final conn = st.connection(t.connectionId);
    final price = isPriceTile(t, conn) ? priceParamsFor(t, conn!, lang: lang) : null;
    final canRun = tileCanRun(t);
    final feed = t.feed;
    return Scaffold(
      key: const ValueKey('tile-shortcuts-page'),
      appBar: AppBar(title: Text(tx(context, 'Pikakomento ja kotinäyttö', 'Shortcut and home screen'))),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(12, 4, 12, 32),
        children: [
          _p(
            tx(
              context,
              'Tee laatasta "{p0}" linkki, oma kotinäytön kuvake tai iPhonen widget. Linkit ja skriptit eivät koskaan sisällä PIN-koodia tai salasanaa – komennot kysyvät vahvistuksen ja PIN-koodin joka kerta.',
              'Turn the tile "{p0}" into a link, its own home-screen icon or an iPhone widget. Links and scripts never contain a PIN or password – commands ask for confirmation and the PIN every time.',
            ).replaceFirst('{p0}', t.title),
          ),
          _h(tx(context, 'Linkit', 'Links')),
          _link(
            'link-open',
            tx(context, 'Avaa laatta', 'Open the tile'),
            webOpenLink(t.id),
            help: tx(context, 'Avaa molaplan.comin suoraan tähän laattaan.', 'Opens molaplan.com directly on this tile.'),
          ),
          if (canRun)
            _link(
              'link-run',
              tx(context, 'Suorita komento', 'Run the command'),
              webRunLink(t.id),
              help: tx(
                context,
                'Avaa Molaplanin ja suorittaa laatan komennon vahvistuksen (ja tarvittaessa PIN-koodin) jälkeen.',
                'Opens Molaplan and runs the tile\'s command after confirmation (and the PIN, if needed).',
              ),
            ),
          _h(tx(context, 'Oma kotinäytön kuvake', 'Own home-screen icon')),
          if (price != null)
            _link(
              'link-price',
              tx(context, 'Sähkön hinta -näkymä (ei kirjautumista)', 'Electricity price view (no sign-in)'),
              webPriceLink(price),
              help: tx(
                context,
                'Hinta nyt ja tämän päivän ja huomisen pylväät. Toimii kenellä tahansa ilman tiliä: linkissä on vain hinta-alue, ALV, marginaali ja siirto.',
                'The price now and today\'s and tomorrow\'s bars. Works for anyone without an account: the link holds only the price area, VAT, margin and transfer.',
              ),
            ),
          _link(
            'link-view',
            tx(context, 'Laatta koko näytöllä', 'Tile full screen'),
            webViewLink(t.id, name: t.title),
            help: tx(
              context,
              'Pelkkä tämä laatta, päivittyy itsestään. Vaatii kirjautumisen samalla tilillä.',
              'Only this tile, updates by itself. Needs sign-in with the same account.',
            ),
          ),
          _p(
            tx(
              context,
              'iPhone: avaa linkki Safarissa → Jaa → Lisää Koti-valikkoon. Android: Chrome → ⋮ → Lisää aloitusnäytölle. PC: Chrome tai Edge → Asenna sovellus. Kotivalikon sovelluksella on oma tallennustila: kirjaudu siinä kerran.',
              'iPhone: open the link in Safari → Share → Add to Home Screen. Android: Chrome → ⋮ → Add to home screen. PC: Chrome or Edge → Install app. A home-screen app has its own storage: sign in there once.',
            ),
          ),
          _h(tx(context, 'iPhonen widget', 'iPhone widget')),
          _p(
            tx(
              context,
              'iPhonen widgetit vaativat sovelluksen. Molaplanilla ei ole App Store -sovellusta, joten widget tehdään ilmaisella Scriptable-sovelluksella: asenna Scriptable, paina +, liitä skripti ja nimeä se. Lisää kotinäytölle Scriptable-widget, paina sitä pitkään → Muokkaa widgetiä → Script: valitse skripti.',
              'iPhone widgets need an app. Molaplan has no App Store app, so the widget uses the free Scriptable app: install Scriptable, tap +, paste the script and name it. Add a Scriptable widget to the home screen, long-press it → Edit Widget → Script: pick the script.',
            ),
          ),
          if (price != null)
            _copyBlock(
              'script-price',
              tx(context, 'Sähkön hinta -widget (Scriptable)', 'Electricity price widget (Scriptable)'),
              scriptablePriceScript(price),
              help: tx(
                context,
                'Hakee hinnat suoraan Molaplanin hintapalvelusta – ei tarvitse tiliä eikä päällä olevaa laitetta.',
                'Fetches prices straight from Molaplan\'s price service – no account or device left on needed.',
              ),
            ),
          SwitchListTile(
            key: const ValueKey('feed-switch'),
            contentPadding: const EdgeInsets.symmetric(horizontal: 4),
            value: feed != null,
            title: Text(tx(context, 'Tilasyöte widgetille', 'Status feed for the widget')),
            subtitle: Text(
              tx(
                context,
                'Molaplan julkaisee laatan tilan (teksti, väri) satunnaiseen, vain lukemiseen tarkoitettuun osoitteeseen. Syötettä päivittää laite, jossa laatta on näkyvissä (esim. kotisilta). Kuka tahansa, jolla on osoite, näkee tilan, mutta ei voi ohjata mitään.',
                'Molaplan publishes the tile\'s state (text, colour) to a random, read-only address. The feed is updated by a device where the tile is shown (e.g. the home bridge). Anyone with the address can see the state but cannot control anything.',
              ),
            ),
            onChanged: (on) => _setFeed(on ? newFeedTopic() : null),
          ),
          if (feed != null) ...[
            _copyBlock(
              'script-feed',
              tx(context, 'Laatan widget (Scriptable)', 'Tile widget (Scriptable)'),
              scriptableFeedScript(topic: feed, title: t.title, tileId: t.id, lang: lang),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                key: const ValueKey('feed-renew'),
                onPressed: () => _setFeed(newFeedTopic()),
                icon: const Icon(Icons.autorenew, size: 18),
                label: Text(tx(context, 'Uusi osoite (vanha lakkaa toimimasta)', 'New address (the old one stops working)')),
              ),
            ),
          ],
          _h(tx(context, 'Pikakomennot ja Siri (iPhone)', 'Shortcuts and Siri (iPhone)')),
          if (canRun)
            _copyBlock(
              'recipe-run',
              tx(context, 'Pikakomento: suorita komento', 'Shortcut: run the command'),
              shortcutRunRecipe(t, lang),
            ),
          _copyBlock(
            'recipe-open',
            tx(context, 'Pikakomento: avaa laatta', 'Shortcut: open the tile'),
            shortcutOpenRecipe(t, lang),
          ),
          if (feed != null)
            _copyBlock(
              'recipe-read',
              tx(context, 'Pikakomento: lue arvo ääneen', 'Shortcut: read the value aloud'),
              shortcutReadRecipe(t, feed, lang),
            ),
          _h(tx(context, 'Mikä on natiivia, mikä kiertotie', 'What is native, what is a workaround')),
          _p(
            tx(
              context,
              'Android: oikeat kotinäytön widgetit ja pikakuvakkeet Molaplan-sovelluksesta (Lisää aloitusnäytölle). iPhone: kotinäytön kuvake on verkkosovellus (Safari), widget toimii Scriptable-sovelluksen kautta ja Siri Pikakomentojen kautta. Komennot avaavat aina Molaplanin, joka kysyy vahvistuksen ja PIN-koodin.',
              'Android: real home-screen widgets and shortcuts from the Molaplan app (Add to home screen). iPhone: the home-screen icon is a web app (Safari), the widget runs through the Scriptable app and Siri through Shortcuts. Commands always open Molaplan, which asks for confirmation and the PIN.',
            ),
          ),
        ],
      ),
    );
  }
}
