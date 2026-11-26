import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:molaplan/l10n/l10n.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/app_state.dart';
import 'package:molaplan/state/storage.dart';
import 'package:molaplan/ui/room_presets.dart';

void main() {
  test('t172u: room picture suggested from the view name in fi / en / sv / et / es', () {
    const names = {
      'kitchen': ['Keittiö', 'Kitchen', 'Kök', 'Köök', 'Cocina'],
      'bedroom': ['Makuuhuone', 'Bedroom', 'Sovrum', 'Magamistuba', 'Dormitorio'],
      'living': ['Olohuone', 'Living room', 'Vardagsrum', 'Elutuba', 'Salón'],
      'bathroom': ['Kylpyhuone', 'Bathroom', 'Badrum', 'Vannituba', 'Baño'],
      'sauna': ['Sauna', 'Sauna', 'Bastu', 'Saun', 'Sauna'],
      'hallway': ['Eteinen', 'Hallway', 'Hall', 'Esik', 'Pasillo'],
      'garage': ['Autotalli', 'Garage', 'Garaget', 'Garaaž', 'Garaje'],
      'yard': ['Piha', 'Garden', 'Trädgård', 'Aed', 'Jardín'],
      'technical': ['Tekninen tila', 'Boiler room', 'Pannrum', 'Tehnoruum', 'Sala técnica'],
      'office': ['Työhuone', 'Office', 'Kontor', 'Töötuba', 'Oficina'],
      'kids': ['Lastenhuone', 'Kids room', 'Barnrum', 'Lastetuba', 'Habitación infantil'],
      'cottage': ['Mökki', 'Cottage', 'Sommarstuga', 'Suvila', 'Casa de campo'],
    };
    for (final e in names.entries) {
      for (final n in e.value) {
        expect(suggestRoomPreset(n)?.id, e.key, reason: n);
      }
    }
    expect(suggestRoomPreset('Alakerran kylpyhuone')?.id, 'bathroom');
    expect(suggestRoomPreset('Gästbadrum')?.id, 'bathroom');
    expect(suggestRoomPreset('Kesämökki')?.id, 'cottage');
    expect(suggestRoomPreset('Koti'), isNull);
    expect(suggestRoomPreset('Garden shed')?.id, 'yard'); // whole word "den" is not inside "garden"
    expect(suggestRoomPreset(''), isNull);
  });

  test('t172u: preset labels are translated in all five languages', () {
    for (final p in roomPresets) {
      for (final lang in ['sv', 'et', 'es']) {
        if (p.id == 'sauna' || (p.id == 'garage' && lang == 'sv')) continue; // same word
        expect(p.label(lang), isNot(p.en), reason: '$lang ${p.id}');
      }
      expect(p.label('fi'), p.fi);
      expect(p.label('en'), p.en);
    }
  });

  test('t172u: presets are bundled WebP light/dark + thumbnails, licensed, < 3 MB in total', () {
    expect(File('pubspec.yaml').readAsStringSync(), contains('- assets/rooms/'));
    expect(File('assets/rooms/LICENSE.md').readAsStringSync(), contains('CC0'));
    expect(File('tool/rooms/gen_rooms.py').existsSync(), isTrue);
    expect(roomPresets.length, 12);
    var total = 0;
    for (final p in roomPresets) {
      for (final b in [Brightness.light, Brightness.dark]) {
        for (final thumb in [false, true]) {
          final f = File(p.asset(b, thumb: thumb));
          expect(f.existsSync(), isTrue, reason: f.path);
          final bytes = f.readAsBytesSync();
          expect(String.fromCharCodes(bytes.sublist(8, 12)), 'WEBP', reason: f.path);
          total += bytes.length;
        }
      }
    }
    expect(total, lessThan(3 * 1024 * 1024));
  });

  test('t172u: dashboard photo mode round-trip, presets need no image slot', () async {
    final d = Dashboard(
      name: 'Keittiö',
      headerImage: 'preset:kitchen',
      photoMode: 'background',
      bgDim: 0.3,
      bgBlur: 12,
    );
    final j = Dashboard.fromJson(d.toJson());
    expect(
      (j.headerImage, j.photoMode, j.bgDim, j.bgBlur, j.photoBackground),
      ('preset:kitchen', 'background', 0.3, 12.0, true),
    );
    final old = Dashboard.fromJson({'name': 'x', 'headerImage': 'abc'});
    expect((old.photoMode, old.photoBackground), ('header', false));
    expect(Dashboard.fromJson({'name': 'x', 'photoMode': 'weird', 'bgDim': 5}).bgDim, 0.9);
    expect(roomPreset('preset:kitchen')?.id, 'kitchen');
    expect(roomPreset('abc'), isNull);
    expect(roomPreset('preset:nope'), isNull);

    final st = AppState(configStore: MemoryConfigStore(), secretStore: MemorySecretStore());
    await st.load();
    final v = st.config.dashboards.first;
    await st.setHeaderPreset(v, 'sauna');
    await st.setRoomPhotoMode(v, mode: 'background', dim: 2, blur: -1);
    expect((v.headerImage, v.photoMode, v.bgDim, v.bgBlur), ('preset:sauna', 'background', 0.9, 0.0));
    expect(st.usedImages, isEmpty);
    expect(tr('fi', 'Koko näkymän tausta', 'Whole view background'), 'Koko näkymän tausta');
  });
}
