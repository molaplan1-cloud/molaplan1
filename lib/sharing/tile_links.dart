/// R510–R514 (t314u / t315u): every tile as a link, a home-screen web app and an iPhone widget.
///
/// * Web deep links (Android, iPhone, PC browsers): `https://molaplan.com/?tile=<id>` opens the
///   tile, `?run=<id>` runs its command (the app always asks for confirmation and, when the
///   device needs one, the PIN), `?view=<id>` shows the tile alone, full screen (a home-screen
///   web app of its own).
/// * `?price=<zone>&vat=…&margin=…&transfer=…&h=1&name=…` – a self-contained electricity price
///   view: public day-ahead prices from relay.molaplan.com, no account and no secret needed.
/// * Scriptable (free iOS app) widget scripts: the price widget reads relay.molaplan.com; any
///   other tile reads its "tilasyöte" (feed): a random, revocable ntfy topic on
///   ntfy.molaplan.com where Molaplan publishes the tile's display state (text, colour, bars).
///
/// Links and scripts never contain a PIN, password, token or connection setting. Pure Dart.
library;

import 'dart:convert';
import 'dart:math';

import '../l10n/l10n.dart';
import '../models/models.dart';
import '../prices/prices.dart';

const webAppBase = 'https://molaplan.com/';
const feedServer = 'https://ntfy.molaplan.com';

final _idRe = RegExp(r'^[A-Za-z0-9_-]{1,64}$');
final _feedRe = RegExp(r'^mf-[a-z0-9]{20,40}$');

bool validTileId(String? id) => id != null && _idRe.hasMatch(id);
bool validFeedTopic(String? t) => t != null && _feedRe.hasMatch(t);

/// Opens molaplan.com on the tile (its big view).
String webOpenLink(String tileId) => Uri.parse(webAppBase).replace(queryParameters: {'tile': tileId}).toString();

/// Runs the tile's command (asks confirmation + PIN in the app every time).
String webRunLink(String tileId) => Uri.parse(webAppBase).replace(queryParameters: {'run': tileId}).toString();

/// The tile alone, full screen, kept up to date (add it to the home screen). [name] becomes the
/// home-screen icon's name (the tile title – never a secret).
String webViewLink(String tileId, {String? name}) {
  final n = (name ?? '').trim();
  return Uri.parse(webAppBase)
      .replace(queryParameters: {'view': tileId, if (n.isNotEmpty) 'name': n.length > 40 ? n.substring(0, 40) : n})
      .toString();
}

/// Electricity price settings of a price tile – public data only.
class PriceLinkParams {
  const PriceLinkParams({
    this.zone = 'FI',
    this.vat = 25.5,
    this.margin = 0,
    this.transfer = 0,
    this.hourly = true,
    this.name = '',
    this.lang = 'fi',
  });
  final String zone;
  final double vat, margin, transfer;
  final bool hourly;
  final String name;
  final String lang;

  PriceSettings get settings => PriceSettings(vat: vat, margin: margin, transfer: transfer);

  static String _n(double v) => v == v.roundToDouble() ? '${v.round()}' : '$v';

  Map<String, String> toQuery() => {
    'price': zone,
    'vat': _n(vat),
    if (margin != 0) 'margin': _n(margin),
    if (transfer != 0) 'transfer': _n(transfer),
    'h': hourly ? '1' : '0',
    if (name.isNotEmpty) 'name': name,
    'lang': lang,
  };

  static double _d(String? s, double def, double lo, double hi) {
    final v = double.tryParse((s ?? '').replaceAll(',', '.'));
    if (v == null || !v.isFinite) return def;
    return v.clamp(lo, hi).toDouble();
  }

  /// Null unless `price=` names a supported bidding zone.
  static PriceLinkParams? fromQuery(Map<String, String> q) {
    final zone = q['price'];
    if (zone == null || !priceZones.containsKey(zone)) return null;
    final name = (q['name'] ?? '').trim();
    final lang = appLanguages.containsKey(q['lang']) ? q['lang']! : 'fi';
    return PriceLinkParams(
      zone: zone,
      vat: _d(q['vat'], priceZones[zone]!.$2, 0, 100),
      margin: _d(q['margin'], 0, -100, 100),
      transfer: _d(q['transfer'], 0, -100, 100),
      hourly: q['h'] != '0',
      name: name.length > 60 ? name.substring(0, 60) : name,
      lang: lang,
    );
  }
}

/// True for a tile backed by the electricity price connection.
bool isPriceTile(TileConfig t, ConnectionConfig? c) => c != null && c.type == 'price';

/// The price tile's own settings as link parameters (what the tile shows: VAT / margin off
/// when the tile has them off, hourly or 15 min like the tile).
PriceLinkParams priceParamsFor(TileConfig t, ConnectionConfig c, {required String lang}) {
  final s = c.settings;
  final zone = priceZones.containsKey(s['zone']) ? s['zone'] as String : 'FI';
  double num(String k, double def) => double.tryParse('${s[k] ?? ''}'.replaceAll(',', '.')) ?? def;
  final connHourly = s['hourly'] == true || s['hourly'] == 'true';
  final hourly = switch (t.priceResolution) {
    'hourly' => true,
    '15min' => false,
    _ => connHourly,
  };
  return PriceLinkParams(
    zone: zone,
    vat: t.priceIncludeVat ? num('vat', priceZones[zone]!.$2) : 0,
    margin: t.priceIncludeMargin ? num('margin', 0) : 0,
    transfer: num('transfer', 0),
    hourly: hourly,
    name: t.title,
    lang: lang,
  );
}

String webPriceLink(PriceLinkParams p) => Uri.parse(webAppBase).replace(queryParameters: p.toQuery()).toString();

/// What molaplan.com was opened with.
sealed class WebLaunch {
  const WebLaunch();

  static WebLaunch? parse(Uri u) {
    final q = u.queryParameters;
    final price = PriceLinkParams.fromQuery(q);
    if (price != null) return PriceViewLaunch(price);
    if (validTileId(q['view'])) return TileViewLaunch(q['view']!);
    if (validTileId(q['run'])) return TileRunLaunch(q['run']!);
    if (validTileId(q['tile'])) return TileOpenLaunch(q['tile']!);
    return null;
  }

  /// The molaplan:// link the app's deep-link handler understands (run / open), else null.
  String? get appLink => null;

  /// Run / open links are consumed once: the address bar is reset so a reload does nothing.
  bool get consumeOnce => false;
}

class PriceViewLaunch extends WebLaunch {
  const PriceViewLaunch(this.params);
  final PriceLinkParams params;
}

class TileViewLaunch extends WebLaunch {
  const TileViewLaunch(this.id);
  final String id;
}

class TileRunLaunch extends WebLaunch {
  const TileRunLaunch(this.id);
  final String id;

  /// Always with confirmation: a link can be opened by anyone who has it.
  @override
  String get appLink => 'molaplan://run/${Uri.encodeComponent(id)}?confirm=1';
  @override
  bool get consumeOnce => true;
}

class TileOpenLaunch extends WebLaunch {
  const TileOpenLaunch(this.id);
  final String id;
  @override
  String get appLink => 'molaplan://tile/${Uri.encodeComponent(id)}';
  @override
  bool get consumeOnce => true;
}

// ---------------------------------------------------------------------------------------------
// Tilasyöte (feed): ntfy topic with the tile's latest display state.

/// A new random feed topic ("mf-" + 24 base-36 characters, ~124 bits).
String newFeedTopic([Random? rnd]) {
  final r = rnd ?? Random.secure();
  const abc = 'abcdefghijklmnopqrstuvwxyz0123456789';
  return 'mf-${List.generate(24, (_) => abc[r.nextInt(abc.length)]).join()}';
}

String feedUrl(String topic) => '$feedServer/$topic';

/// The latest feed message (what the widget script and Shortcuts read).
String feedLatestUrl(String topic) => '${feedUrl(topic)}/json?poll=1&since=latest';

/// Feed message body: the same text / colour / bars as the Android widget, plus the
/// molaplan.com link to open. Built from `launcherWidgetPayload` (no secrets there).
Map<String, dynamic> feedPayload(Map<String, dynamic> widgetPayload, {required String tileId, DateTime? now}) {
  const keep = ['title', 'value', 'color', 'updated', 'bars', 'barColors', 'nowBar'];
  return {
    'v': 1,
    for (final k in keep)
      if (widgetPayload[k] != null) k: widgetPayload[k],
    'open': webOpenLink(tileId),
    't': (now ?? DateTime.now()).millisecondsSinceEpoch ~/ 1000,
  };
}

/// Should a new feed message go out? On every change of what the widget shows, at most every
/// [minGap]; and a heartbeat every [heartbeat] so the widget can tell fresh from stale.
bool feedShouldPublish({
  required String body,
  required String? lastBody,
  required DateTime now,
  required DateTime? lastAt,
  Duration minGap = const Duration(seconds: 30),
  Duration heartbeat = const Duration(minutes: 15),
}) {
  if (lastAt == null || lastBody == null) return true;
  final gap = now.difference(lastAt);
  if (gap < minGap) return false;
  return body != lastBody || gap >= heartbeat;
}

/// Compares two payloads ignoring the send time.
String feedComparable(Map<String, dynamic> p) => jsonEncode({...p}..remove('t'));

// ---------------------------------------------------------------------------------------------
// Scriptable (iOS) widget scripts.

String _jsCfg(Map<String, Object?> m) => const JsonEncoder.withIndent('  ').convert(m);

Map<String, String> _scriptWords(String lang) => {
  'noData': tr(lang, 'Ei tietoa', 'No data'),
  'noPrices': tr(lang, 'Ei hintoja', 'No prices'),
  'feedHint': tr(
    lang,
    'Avaa Molaplan laitteella, jossa laatta on näkyvissä',
    'Open Molaplan on a device where the tile is shown',
  ),
  'old': tr(lang, 'min vanha', 'min old'),
  'updated': tr(lang, 'päivitetty', 'updated'),
  'today': tr(lang, 'Tänään', 'Today'),
  'tomorrow': tr(lang, 'Huomenna', 'Tomorrow'),
};

String _header(String what, String lang) =>
    '// Molaplan – $what\n'
    '// ${tr(lang, 'iPhonen widget Scriptable-sovellukseen (ilmainen, App Store). Ohje: molaplan.com → laatta → Pikakomento.', 'iPhone widget for the Scriptable app (free, App Store). Help: molaplan.com → tile → Shortcut.')}\n'
    '// ${tr(lang, 'Ei sisällä PIN-koodeja eikä salasanoja.', 'Contains no PINs or passwords.')}\n';

/// Price widget: current c/kWh in its level colour + today/tomorrow bars (like the tablet).
String scriptablePriceScript(PriceLinkParams p) {
  final title = p.name.isNotEmpty ? p.name : tr(p.lang, 'Sähkön hinta', 'Electricity price');
  final cfg = {
    'title': title,
    'zone': p.zone,
    'vat': p.vat,
    'margin': p.margin,
    'transfer': p.transfer,
    'hourly': p.hourly,
    'server': defaultPriceServer,
    'open': webPriceLink(p),
    'comma': p.lang != 'en',
  };
  return '${_header(title, p.lang)}'
      'const CFG = ${_jsCfg(cfg)};\n'
      'const T = ${_jsCfg(_scriptWords(p.lang))};\n'
      '$_priceJs';
}

/// Any tile: its latest feed message (text, colour, optional bars).
String scriptableFeedScript({required String topic, required String title, required String tileId, required String lang}) {
  final cfg = {
    'title': title,
    'feed': feedLatestUrl(topic),
    'open': webOpenLink(tileId),
  };
  return '${_header(title, lang)}'
      'const CFG = ${_jsCfg(cfg)};\n'
      'const T = ${_jsCfg(_scriptWords(lang))};\n'
      '$_feedJs';
}

const _commonJs = r'''
const LEVEL = ["#5E9E7C", "#C2A15A", "#BF6F68"];
function hex(argb) { return "#" + ((argb >>> 0) & 0xFFFFFF).toString(16).padStart(6, "0"); }
function bars(values, colors, nowIdx, split, w, h) {
  const dc = new DrawContext();
  dc.size = new Size(w, h); dc.opaque = false; dc.respectScreenScale = true;
  if (!values.length) return dc.getImage();
  const lo = Math.min(0, ...values), hi = Math.max(...values, lo + 0.01);
  const bw = w / values.length;
  const zero = h - ((0 - lo) / (hi - lo)) * h;
  values.forEach((v, i) => {
    const y = h - ((v - lo) / (hi - lo)) * h;
    const top = Math.min(y, zero), bh = Math.max(1, Math.abs(zero - y));
    dc.setFillColor(new Color(colors[i] || "#888888", i === nowIdx ? 1 : 0.72));
    dc.fillRect(new Rect(i * bw + bw * 0.12, top, Math.max(1, bw * 0.76), bh));
  });
  if (nowIdx >= 0) { dc.setFillColor(Color.white()); dc.fillRect(new Rect(nowIdx * bw + bw / 2 - 0.75, 0, 1.5, h)); }
  if (split > 0 && split < values.length) { dc.setFillColor(new Color("#ffffff", 0.35)); dc.fillRect(new Rect(split * bw - 0.5, 0, 1, h)); }
  return dc.getImage();
}
function frame(title) {
  const w = new ListWidget();
  w.backgroundColor = new Color("#10161b");
  w.setPadding(12, 12, 10, 12);
  w.url = CFG.open;
  const t = w.addText(title); t.font = Font.mediumSystemFont(12); t.textColor = new Color("#9fb0b8"); t.lineLimit = 1;
  return w;
}
function hm(d) { return String(d.getHours()).padStart(2, "0") + ":" + String(d.getMinutes()).padStart(2, "0"); }
function finish(w) {
  w.refreshAfterDate = new Date(Date.now() + 15 * 60 * 1000);
  if (config.runsInWidget) Script.setWidget(w); else w.presentMedium();
  Script.complete();
}
''';

const _priceJs = '''$_commonJs
function cents(e) {
  const s = e / 10, en = s + CFG.margin;
  return (s > 0 ? en * (1 + CFG.vat / 100) : s + CFG.margin * (1 + CFG.vat / 100)) + CFG.transfer;
}
async function load() {
  const fm = FileManager.local();
  const file = fm.joinPath(fm.documentsDirectory(), "molaplan-price-" + CFG.zone + ".json");
  try {
    const r = new Request(CFG.server + "/v1/prices?zone=" + encodeURIComponent(CFG.zone));
    r.timeoutInterval = 15;
    const j = await r.loadJSON();
    if (j && j.points && j.points.length) { fm.writeString(file, JSON.stringify(j)); return j; }
  } catch (e) {}
  return fm.fileExists(file) ? JSON.parse(fm.readString(file)) : null;
}
function slots(j) {
  const res = (j.resolution || 3600) * 1000;
  let s = j.points.map(p => ({ t: p[0] * 1000, len: res, c: cents(p[1]) }));
  if (CFG.hourly && res < 3600000) {
    const by = new Map();
    for (const x of s) { const h = Math.floor(x.t / 3600000) * 3600000; if (!by.has(h)) by.set(h, []); by.get(h).push(x.c); }
    s = [...by.entries()].sort((a, b) => a[0] - b[0]).map(([t, cs]) => ({ t, len: 3600000, c: cs.reduce((a, b) => a + b, 0) / cs.length }));
  }
  return s;
}
const w = frame(CFG.title);
const j = await load();
const now = Date.now();
const s = j ? slots(j) : [];
const sorted = s.map(x => x.c).sort((a, b) => a - b);
const q = f => sorted.length ? sorted[Math.round((sorted.length - 1) * f)] : 0;
const q1 = q(1 / 3), q2 = q(2 / 3);
const level = c => c <= q1 ? 0 : (c <= q2 ? 1 : 2);
const d0 = new Date(); d0.setHours(0, 0, 0, 0);
const from = d0.getTime(), mid = from + 86400000, to = from + 2 * 86400000;
const win = s.filter(x => x.t + x.len > from && x.t < to);
const cur = s.find(x => x.t <= now && now < x.t + x.len);
w.addSpacer(2);
if (!cur) {
  const e = w.addText(T.noPrices); e.font = Font.boldSystemFont(20); e.textColor = Color.white();
} else {
  const row = w.addStack(); row.bottomAlignContent();
  const txt = cur.c.toFixed(2);
  const v = row.addText(CFG.comma ? txt.replace(".", ",") : txt);
  v.font = Font.boldSystemFont(30); v.textColor = new Color(LEVEL[level(cur.c)]); v.minimumScaleFactor = 0.6;
  row.addSpacer(4);
  const u = row.addText("c/kWh"); u.font = Font.systemFont(12); u.textColor = new Color("#9fb0b8");
}
w.addSpacer(6);
const big = config.widgetFamily !== "small";
const split = win.findIndex(x => x.t >= mid);
const img = w.addImage(bars(win.map(x => x.c), win.map(x => LEVEL[level(x.c)]), win.findIndex(x => x === cur), split, big ? 300 : 130, big ? 60 : 48));
img.resizable = true;
w.addSpacer(4);
const f = w.addText((split > 0 ? T.today + " · " + T.tomorrow : T.today) + " · " + T.updated + " " + hm(new Date()));
f.font = Font.systemFont(10); f.textColor = new Color("#6f8088"); f.lineLimit = 1;
const step = CFG.hourly ? 60 : 15, next = new Date(now);
next.setSeconds(30, 0); next.setMinutes((Math.floor(next.getMinutes() / step) + 1) * step);
w.refreshAfterDate = next;
if (config.runsInWidget) Script.setWidget(w); else w.presentMedium();
Script.complete();
''';

const _feedJs = '''$_commonJs
async function latest() {
  const fm = FileManager.local();
  const file = fm.joinPath(fm.documentsDirectory(), "molaplan-feed-" + CFG.feed.split("/")[3] + ".json");
  try {
    const r = new Request(CFG.feed);
    r.timeoutInterval = 15;
    const lines = (await r.loadString()).split("\\n").filter(x => x.trim());
    for (let i = lines.length - 1; i >= 0; i--) {
      const m = JSON.parse(lines[i]);
      if (m.event === "message" && m.message) { const p = JSON.parse(m.message); fm.writeString(file, JSON.stringify(p)); return p; }
    }
  } catch (e) {}
  return fm.fileExists(file) ? JSON.parse(fm.readString(file)) : null;
}
const p = await latest();
const w = frame((p && p.title) || CFG.title);
w.addSpacer(2);
if (!p) {
  const e = w.addText(T.noData); e.font = Font.boldSystemFont(18); e.textColor = Color.white();
  const h = w.addText(T.feedHint); h.font = Font.systemFont(10); h.textColor = new Color("#9fb0b8");
} else {
  const v = w.addText(String(p.value)); v.font = Font.boldSystemFont(24); v.minimumScaleFactor = 0.5; v.lineLimit = 2;
  v.textColor = new Color(p.color ? hex(p.color) : "#ffffff");
  if (p.bars && p.bars.length) {
    w.addSpacer(6);
    const big = config.widgetFamily !== "small";
    const img = w.addImage(bars(p.bars.map(x => x / 10), (p.barColors || []).map(hex), p.nowBar ?? -1, -1, big ? 300 : 130, big ? 60 : 48));
    img.resizable = true;
  }
  w.addSpacer(4);
  const age = Math.round((Date.now() / 1000 - (p.t || 0)) / 60);
  const f = w.addText((p.updated ? p.updated : "") + (age > 30 ? " · " + age + " " + T.old : ""));
  f.font = Font.systemFont(10); f.textColor = new Color(age > 30 ? "#C2A15A" : "#6f8088");
}
finish(w);
''';

// ---------------------------------------------------------------------------------------------
// iOS Shortcuts (Pikakomennot) recipes – copyable text.

/// Steps for an iPhone Shortcut that runs the tile's command (opens Molaplan, which asks
/// confirmation and PIN) – also "Hei Siri, <title>".
String shortcutRunRecipe(TileConfig t, String lang) {
  final link = webRunLink(t.id);
  return [
    tr(lang, 'Pikakomento: {p0}', 'Shortcut: {p0}').replaceFirst('{p0}', t.title),
    '1. ${tr(lang, 'Avaa Pikakomennot-sovellus ja paina +.', 'Open the Shortcuts app and tap +.')}',
    '2. ${tr(lang, 'Lisää toiminto "Avaa URL-osoitteet" ja liitä osoite:', 'Add the action "Open URLs" and paste the address:')}',
    '   $link',
    '3. ${tr(lang, 'Nimeä pikakomento laatan nimellä – silloin "Hei Siri, {p0}" toimii.', 'Name the shortcut after the tile – then "Hey Siri, {p0}" works.').replaceFirst('{p0}', t.title)}',
    '4. ${tr(lang, 'Jaa → Lisää Koti-valikkoon, niin saat oman kuvakkeen.', 'Share → Add to Home Screen gives it its own icon.')}',
    tr(
      lang,
      'Molaplan avautuu Safarissa ja kysyy joka kerta vahvistuksen ja tarvittaessa PIN-koodin. PIN-koodia ei tallenneta linkkiin. Kirjaudu molaplan.comiin Safarissa kerran.',
      'Molaplan opens in Safari and asks for confirmation and, if needed, the PIN every time. The PIN is never stored in the link. Sign in to molaplan.com in Safari once.',
    ),
  ].join('\n');
}

/// Steps for a Shortcut / home-screen icon that opens the tile.
String shortcutOpenRecipe(TileConfig t, String lang) => [
  tr(lang, 'Pikakomento (avaa laatta): {p0}', 'Shortcut (open the tile): {p0}').replaceFirst('{p0}', t.title),
  '1. ${tr(lang, 'Avaa Pikakomennot-sovellus ja paina +.', 'Open the Shortcuts app and tap +.')}',
  '2. ${tr(lang, 'Lisää toiminto "Avaa URL-osoitteet" ja liitä osoite:', 'Add the action "Open URLs" and paste the address:')}',
  '   ${webOpenLink(t.id)}',
  '3. ${tr(lang, 'Jaa → Lisää Koti-valikkoon, niin saat oman kuvakkeen.', 'Share → Add to Home Screen gives it its own icon.')}',
].join('\n');

/// Steps for a Shortcut that reads the tile's feed aloud / shows it ("Hei Siri, mikä on …").
String shortcutReadRecipe(TileConfig t, String topic, String lang) => [
  tr(lang, 'Pikakomento (lue arvo): {p0}', 'Shortcut (read the value): {p0}').replaceFirst('{p0}', t.title),
  '1. ${tr(lang, 'Lisää toiminto "Hae URL-osoitteen sisältö" osoitteella:', 'Add the action "Get Contents of URL" with the address:')}',
  '   ${feedLatestUrl(topic)}',
  '2. ${tr(lang, 'Lisää "Hae sanakirja syötteestä" ja sitten "Hae sanakirjan arvo": message.', 'Add "Get Dictionary from Input", then "Get Dictionary Value": message.')}',
  '3. ${tr(lang, 'Lisää uudelleen "Hae sanakirja syötteestä" ja "Hae sanakirjan arvo": value.', 'Add "Get Dictionary from Input" again and "Get Dictionary Value": value.')}',
  '4. ${tr(lang, 'Lisää "Puhu teksti" tai "Näytä tulos".', 'Add "Speak Text" or "Show Result".')}',
].join('\n');

// ---------------------------------------------------------------------------------------------
// The `?price=` view: a one-tile configuration built only from the link (no account).

const priceViewTileId = 'price-view';

/// AppConfig JSON with one electricity price connection and its today/tomorrow chart tile.
Map<String, dynamic> priceViewConfigJson(PriceLinkParams p) {
  final c = ConnectionConfig(
    id: 'price-view-conn',
    name: tr(p.lang, 'Sähkön hinta', 'Electricity price'),
    type: 'price',
    settings: {
      'zone': p.zone,
      'vat': '${p.vat}',
      'margin': '${p.margin}',
      'transfer': '${p.transfer}',
      'hourly': p.hourly,
    },
  );
  final t = TileConfig(
    id: priceViewTileId,
    type: TileType.value,
    title: p.name.isNotEmpty ? p.name : tr(p.lang, 'Sähkön hinta', 'Electricity price'),
    icon: 'bolt',
    colSpan: 2,
    rowSpan: 2,
    connectionId: c.id,
    pollSeconds: 300,
    unit: 'c/kWh',
    decimals: 2,
    read: {'field': 'chart'},
    priceResolution: p.hourly ? 'hourly' : '15min',
  );
  return {
    'app': 'molaplan',
    'language': p.lang,
    'onboardingDone': true,
    'connections': [c.toJson()],
    'dashboards': [
      {'id': 'price-view-dash', 'name': t.title, 'tiles': [t.toJson()]},
    ],
  };
}
