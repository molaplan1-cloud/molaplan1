/// t172u: built-in room pictures (own stylised illustrations, CC0 – see assets/rooms/LICENSE.md),
/// light and dark variants, suggested by the view's name in all five languages.
library;

import 'package:material_ui/material_ui.dart';

import '../l10n/l10n.dart';

/// A preset is stored as `headerImage = 'preset:<id>'` (no upload, no image-limit slot).
const presetPrefix = 'preset:';

class RoomPreset {
  const RoomPreset(this.id, this.fi, this.en, this.words);
  final String id, fi, en;

  /// Lower-case name fragments in fi / en / sv / et / es that suggest this picture.
  final List<String> words;

  /// Literal tr() calls so the l10n extractor translates them to sv / et / es.
  String label(String lang) => switch (id) {
    'bedroom' => tr(lang, 'Makuuhuone', 'Bedroom'),
    'kitchen' => tr(lang, 'Keittiö', 'Kitchen'),
    'living' => tr(lang, 'Olohuone', 'Living room'),
    'bathroom' => tr(lang, 'Kylpyhuone', 'Bathroom'),
    'sauna' => tr(lang, 'Sauna', 'Sauna'),
    'hallway' => tr(lang, 'Eteinen', 'Hallway'),
    'garage' => tr(lang, 'Autotalli', 'Garage'),
    'yard' => tr(lang, 'Piha / puutarha', 'Yard / garden'),
    'technical' => tr(lang, 'Tekninen tila', 'Technical room'),
    'office' => tr(lang, 'Työhuone', 'Office'),
    'kids' => tr(lang, 'Lastenhuone', 'Kids\' room'),
    'cottage' => tr(lang, 'Mökki', 'Cottage'),
    _ => tr(lang, fi, en),
  };
  String asset(Brightness b, {bool thumb = false}) =>
      'assets/rooms/${id}_${b == Brightness.dark ? 'dark' : 'light'}${thumb ? '_thumb' : ''}.webp';
}

const roomPresets = <RoomPreset>[
  RoomPreset('bedroom', 'Makuuhuone', 'Bedroom', [
    'makuu',
    'makkari',
    'bedroom',
    'bed room',
    'sovrum',
    'magamis',
    'dormitorio',
    'habitación',
    'alkoovi',
  ]),
  RoomPreset('kitchen', 'Keittiö', 'Kitchen', [
    'keittiö',
    'keittio',
    'kitchen',
    'kök',
    'kok',
    'köök',
    'kook',
    'cocina',
  ]),
  RoomPreset('living', 'Olohuone', 'Living room', [
    'olohuone',
    'olkkari',
    'tupa',
    'living',
    'lounge',
    'vardagsrum',
    'elutuba',
    'salon',
    'salón',
    'sala de estar',
    'sala',
  ]),
  RoomPreset('bathroom', 'Kylpyhuone', 'Bathroom', [
    'kylpy',
    'pesuhuone',
    'wc',
    'vessa',
    'bath',
    'bathroom',
    'toilet',
    'badrum',
    'toalett',
    'vannituba',
    'vannitoa',
    'baño',
    'aseo',
  ]),
  RoomPreset('sauna', 'Sauna', 'Sauna', ['sauna', 'bastu', 'saun', 'löyly']),
  RoomPreset('hallway', 'Eteinen', 'Hallway', [
    'eteinen',
    'aula',
    'käytävä',
    'hall',
    'hallway',
    'entrance',
    'corridor',
    'hall',
    'tambur',
    'esik',
    'koridor',
    'pasillo',
    'entrada',
    'recibidor',
    'farstu',
  ]),
  RoomPreset('garage', 'Autotalli', 'Garage', [
    'autotalli',
    'talli',
    'autokatos',
    'garage',
    'garaget',
    'garaaž',
    'garaaz',
    'garaje',
    'cochera',
  ]),
  RoomPreset('yard', 'Piha / puutarha', 'Yard / garden', [
    'piha',
    'puutarha',
    'terassi',
    'parveke',
    'ulko',
    'yard',
    'garden',
    'patio',
    'outdoor',
    'balcony',
    'trädgård',
    'gård',
    'altan',
    'aed',
    'õu',
    'rõdu',
    'jardín',
    'jardin',
    'terraza',
    'balcón',
  ]),
  RoomPreset('technical', 'Tekninen tila', 'Technical room', [
    'tekninen',
    'tekn',
    'lämmönjako',
    'kattila',
    'pannu',
    'kellari',
    'boiler',
    'utility',
    'technical',
    'plant room',
    'basement',
    'pannrum',
    'teknik',
    'källare',
    'katla',
    'tehnoruum',
    'kelder',
    'caldera',
    'sala técnica',
    'sótano',
  ]),
  RoomPreset('office', 'Työhuone', 'Office', [
    'työhuone',
    'toimisto',
    'kirjasto',
    'office',
    'study',
    'den',
    'kontor',
    'arbetsrum',
    'kabinet',
    'töötuba',
    'oficina',
    'despacho',
    'estudio',
  ]),
  RoomPreset('kids', 'Lastenhuone', 'Kids\' room', [
    'lasten',
    'lapsi',
    'nuoren',
    'kids',
    'child',
    'nursery',
    'barn',
    'barnrum',
    'habitación infantil',
    'cuarto de niños',
    'lekrum',
    'laste',
    'lastetuba',
    'infantil',
    'niños',
    'niñ',
  ]),
  RoomPreset('cottage', 'Mökki', 'Cottage', [
    'mökki',
    'mokki',
    'kesämökki',
    'huvila',
    'cottage',
    'cabin',
    'summer house',
    'stuga',
    'sommarstuga',
    'suvila',
    'maakodu',
    'cabaña',
    'casa de campo',
  ]),
];

RoomPreset? roomPreset(String? headerImage) {
  if (headerImage == null || !headerImage.startsWith(presetPrefix)) return null;
  final id = headerImage.substring(presetPrefix.length);
  return roomPresets.where((p) => p.id == id).firstOrNull;
}

/// The best preset for a view called [name] (any of the five languages), or null.
RoomPreset? suggestRoomPreset(String name) {
  final n = name.toLowerCase().trim();
  if (n.isEmpty) return null;
  RoomPreset? best;
  var bestLen = 0;
  for (final p in roomPresets) {
    for (final w in p.words) {
      // Longest matching word wins ("kesämökki" over "mökki", "sala de estar" over "sala").
      if (w.length > bestLen && _hasWord(n, w)) {
        best = p;
        bestLen = w.length;
      }
    }
  }
  return best;
}

bool _hasWord(String n, String w) {
  // Short words (wc, den, sala, aed…) must be whole words; longer ones may be a part of a
  // Finnish / Swedish / Estonian compound ("Alakerran kylpyhuone", "Gästbadrum").
  if (w.length <= 4) return RegExp('(^|[^a-zåäöõüéíóúñ])${RegExp.escape(w)}(\$|[^a-zåäöõüéíóúñ])').hasMatch(n);
  return n.contains(w);
}
