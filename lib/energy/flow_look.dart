/// R670–R676 (t336u): how an "Energiavirta" tile looks – node icons, colours, background, lines,
/// motion and node size. Stored per tile (read['look']); every field has a default, and only
/// changed fields are written, so an untouched tile keeps a tiny config.
library;

import '../models/models.dart';

/// Node kinds that get a colour of their own.
const flowColorKinds = ['grid', 'solar', 'battery', 'home', 'ev', 'consumer'];

/// Colour presets ('default' = the built-in palette).
const flowPresets = ['default', 'vivid', 'soft', 'mono'];

/// Backgrounds: the tile's normal card, none (transparent), dark, or a chosen colour.
const flowBackgrounds = ['card', 'transparent', 'dark', 'custom'];

/// Line shapes.
const flowCurves = ['curved', 'straight', 'ortho'];

/// Flow animation: moving dots, pulsing lines, or none (static arrows).
const flowAnims = ['dots', 'pulse', 'none'];

double _clamp(Object? v, double lo, double hi, double def) {
  if (v is! num || !v.isFinite) return def;
  return v.toDouble().clamp(lo, hi);
}

int? _argb(Object? v) => v is int && v >= 0 && v <= 0xFFFFFFFF ? v : null;

class FlowLook {
  FlowLook({
    this.preset = 'default',
    Map<String, int>? colors,
    this.lineColor,
    this.bg = 'card',
    this.bgColor,
    this.curve = 'curved',
    this.dashed = false,
    this.anim = 'dots',
    this.thick = 1,
    this.size = 1,
    Map<String, String>? icons,
  }) : colors = colors ?? {},
       icons = icons ?? {};

  String preset;

  /// Per-kind colour (ARGB) over the preset.
  Map<String, int> colors;

  /// One colour for every line (null = each line in its node's colour).
  int? lineColor;
  String bg;
  int? bgColor;
  String curve;
  bool dashed;
  String anim;

  /// Line thickness scale 0.5–2.
  double thick;

  /// Node size scale 0.7–1.4.
  double size;

  /// Icon key per consumer / charger by its (first) tile id; missing = suggested automatically.
  Map<String, String> icons;

  Map<String, dynamic> toJson() => {
    if (preset != 'default') 'preset': preset,
    if (colors.isNotEmpty) 'colors': {...colors},
    'line': ?lineColor,
    if (bg != 'card') 'bg': bg,
    if (bg == 'custom') 'bgColor': ?bgColor,
    if (curve != 'curved') 'curve': curve,
    if (dashed) 'dashed': true,
    if (anim != 'dots') 'anim': anim,
    if (thick != 1) 'thick': thick,
    if (size != 1) 'size': size,
    if (icons.isNotEmpty) 'icons': {...icons},
  };

  static FlowLook fromJson(Object? j) {
    if (j is! Map) return FlowLook();
    String pick(Object? v, List<String> ok, String def) => v is String && ok.contains(v) ? v : def;
    return FlowLook(
      preset: pick(j['preset'], flowPresets, 'default'),
      colors: {
        if (j['colors'] is Map)
          for (final e in (j['colors'] as Map).entries)
            if (flowColorKinds.contains(e.key) && _argb(e.value) != null) e.key as String: _argb(e.value)!,
      },
      lineColor: _argb(j['line']),
      bg: pick(j['bg'], flowBackgrounds, 'card'),
      bgColor: _argb(j['bgColor']),
      curve: pick(j['curve'], flowCurves, 'curved'),
      dashed: j['dashed'] == true,
      anim: pick(j['anim'], flowAnims, 'dots'),
      thick: _clamp(j['thick'], 0.5, 2, 1),
      size: _clamp(j['size'], 0.7, 1.4, 1),
      icons: {
        if (j['icons'] is Map)
          for (final e in (j['icons'] as Map).entries)
            if (e.key is String && flowIconKeys.contains(e.value)) e.key as String: e.value as String,
      },
    );
  }

  bool get isDefault => toJson().isEmpty;
  FlowLook copy() => fromJson(toJson());
}

// ---------------------------------------------------------------- device icons

/// R671: device icons for chargers and consumers, in picker order.
const flowIconKeys = [
  'plug',
  'lamp',
  'sauna',
  'stove',
  'oven',
  'microwave',
  'ev',
  'heatpump',
  'waterheater',
  'heater',
  'washer',
  'dishwasher',
  'dryer',
  'fridge',
  'ac',
  'pump',
  'fan',
  'tv',
  'pc',
  'coffee',
  'router',
  'garage',
];

/// Keywords (fi, en, sv, et, es) → icon. Order matters: the more specific word first. A keyword
/// of 4 letters or less matches a whole word or the end of one (a compound such as "sähköauto"),
/// a longer one anywhere in the name.
const _iconWords = <(String, List<String>)>[
  ('dishwasher', ['astianpesu', 'dishwasher', 'diskmaskin', 'nõudepesu', 'lavavajillas', 'lavaplatos']),
  ('dryer', ['kuivausrumpu', 'kuivaaja', 'kuivain', 'dryer', 'tumble', 'torktumlare', 'kuivati', 'secadora']),
  ('washer', ['pesukone', 'pyykin', 'washer', 'washing', 'tvättmaskin', 'pesumasin', 'lavadora']),
  (
    'heatpump',
    ['lämpöpumppu', 'lampopumppu', 'ilp', 'maalämpö', 'heat pump', 'heatpump', 'värmepump', 'soojuspump', 'bomba de calor', 'aerotermia'],
  ),
  (
    'waterheater',
    ['lämminvesi', 'lvv', 'varaaja', 'boileri', 'water heater', 'boiler', 'varmvatten', 'beredare', 'veeboiler', 'calentador', 'termo'],
  ),
  ('sauna', ['kiuas', 'sauna', 'bastu', 'keris', 'aggregaat']),
  ('microwave', ['mikro', 'microwave', 'mikrovåg', 'mikrolaine', 'microondas']),
  ('oven', ['uuni', 'oven', 'ugn', 'ahi', 'ahju', 'horno']),
  ('stove', ['liesi', 'hella', 'keittotaso', 'induktio', 'stove', 'cooker', 'hob', 'spis', 'häll', 'pliit', 'cocina', 'placa', 'vitro']),
  ('fridge', ['jääkaappi', 'pakastin', 'pakkanen', 'fridge', 'freezer', 'kylskåp', 'frys', 'külmkapp', 'sügavkülm', 'nevera', 'frigor', 'congelador']),
  ('ev', ['sähköauto', 'autolaturi', 'auto', 'latauspiste', 'laturi', 'car', 'ev', 'charger', 'wallbox', 'bil', 'laddbox', 'laddare', 'laadija', 'coche', 'cargador']),
  ('ac', ['ilmastointi', 'jäähdytin', 'ac', 'aircon', 'air condition', 'luftkonditionering', 'konditsioneer', 'aire acondicionado', 'climatizador']),
  ('pump', ['pumppu', 'kaivo', 'pump', 'pumpa', 'bomba', 'allas', 'pool', 'piscina']),
  ('fan', ['tuuletin', 'puhallin', 'ilmanvaihto', 'iv-kone', 'fan', 'ventilation', 'fläkt', 'ventilaator', 'ventilador', 'ventilación']),
  ('heater', ['lämmitin', 'patteri', 'lattialämmitys', 'heater', 'radiator', 'element', 'golvvärme', 'kütte', 'radiaator', 'põrandaküte', 'calefactor', 'radiador', 'estufa']),
  ('lamp', ['valaisin', 'lamppu', 'valot', 'valo', 'light', 'lamp', 'bulb', 'ljus', 'lampa', 'belysning', 'valgus', 'tuli', 'luz', 'lámpara', 'luces']),
  ('tv', ['televisio', 'telkkari', 'tv', 'television', 'teve', 'teler', 'televisor']),
  ('pc', ['tietokone', 'pc', 'computer', 'dator', 'arvuti', 'ordenador', 'server', 'palvelin', 'nas']),
  ('coffee', ['kahvinkeitin', 'kahvi', 'coffee', 'kaffe', 'kohvi', 'cafetera', 'café']),
  ('router', ['reititin', 'modeemi', 'router', 'modem', 'ruuter', 'enrutador']),
  ('garage', ['autotalli', 'garage', 'garaget', 'garaaž', 'garaje']),
];

bool _hasWord(String name, String w) {
  if (w.length > 4 || w.contains(' ')) return name.contains(w);
  final re = RegExp('${RegExp.escape(w)}(?![\\p{L}\\d])', unicode: true);
  return re.hasMatch(name);
}

/// R672: the icon for a device named [name] (any of the five languages), or null.
String? flowIconFromName(String name) {
  final n = name.toLowerCase();
  for (final (key, words) in _iconWords) {
    if (words.any((w) => _hasWord(n, w))) return key;
  }
  return null;
}

/// R672: an icon suggestion for tile [t] (a charger when [ev]): its name first, then what kind
/// of device it is; a plain plug otherwise. Connection type [connType] helps (heat pump, charger…).
String suggestFlowIcon(TileConfig? t, {bool ev = false, String? connType}) {
  final byName = t == null ? null : flowIconFromName(t.title);
  if (byName != null) return byName;
  if (ev || t?.read.containsKey('ev') == true || connType == 'evcharger') return 'ev';
  if (t?.read.containsKey('hp') == true || connType == 'heatpump' || t?.read['kind'] == 'climate') return 'heatpump';
  if (t?.read.containsKey('ir') == true || connType == 'ir') return 'ac';
  // The tile's own icon, when it says what the device is.
  return switch (t?.icon) {
    'lightbulb' => 'lamp',
    'heatpump' => 'heatpump',
    'fan' => 'fan',
    'fire' => 'heater',
    'snow' => 'ac',
    'garage' => 'garage',
    _ => 'plug',
  };
}
