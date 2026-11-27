// R470/R471 (t309u): home-screen widget – security label, panel time, price c/kWh + bars, never 'Tila'.
import 'package:flutter_test/flutter_test.dart';
import 'package:molaplan/drivers/driver.dart';
import 'package:molaplan/models/models.dart';
import 'package:molaplan/state/home_launcher.dart';

void main() {
  final sec = TileConfig(
    id: 'kv',
    type: TileType.value,
    title: 'Kameravalvonta – tila',
    read: {'jsonPath': r'$.state', 'security': true},
  );

  test('security tile: shared label and colour, panel message time, TimedValue unwrapped', () {
    final at = DateTime.now().subtract(const Duration(minutes: 20));
    final p = launcherWidgetPayload(sec, TimedValue('away', at), lang: 'fi');
    expect(p['value'], 'Valvonta päällä');
    expect(p['color'], 0xFF009688);
    expect(p['updated'], '${at.hour.toString().padLeft(2, '0')}:${at.minute.toString().padLeft(2, '0')}');
    expect(launcherWidgetPayload(sec, 'home', lang: 'fi')['value'], 'Valvonta pois');
    expect(launcherWidgetPayload(sec, 'entry_delay', lang: 'en')['value'], 'Entry delay – enter PIN');
    final alarm = launcherWidgetPayload(sec, 'alarm', lang: 'fi');
    expect(alarm['value'], 'HÄLYTYS!');
    expect(alarm['color'], 0xFFF44336);
    expect(launcherWidgetPayload(sec, 'away', lang: 'fi', at: at)['updated'], p['updated']);
  });

  test('price chart tile: current c/kWh with level colour and today+tomorrow bars', () {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final pts = [
      for (var h = 0; h < 48; h++)
        [day.add(Duration(hours: h)).millisecondsSinceEpoch, (h % 24) < 6 ? 2.0 : ((h % 24) > 16 ? 20.0 : 8.0)],
    ];
    final t = TileConfig(id: 'p', type: TileType.value, title: 'Sähkö', read: {'field': 'chart', 'zone': 'FI'});
    final p = launcherWidgetPayload(t, {'points': pts, 'res': 3600}, lang: 'fi');
    final h = now.hour;
    final cur = h < 6 ? 2.0 : (h > 16 ? 20.0 : 8.0);
    expect(p['value'], '${cur.toStringAsFixed(2)} c/kWh');
    expect(p['value'], isNot(contains('Tila')));
    expect(p['bars'], hasLength(48));
    expect(p['barColors'], hasLength(48));
    expect(p['nowBar'], h);
    expect(p['color'], (p['barColors'] as List)[h]);
    expect((p['barColors'] as List)[20], launcherPriceLevelColors[2]);
    expect((p['barColors'] as List)[2], launcherPriceLevelColors[0]);
    expect(launcherWidgetPayload(t, {'points': [], 'res': 3600}, lang: 'fi')['value'], 'Ei hintoja');
  });

  test('a JSON value never shows the placeholder Tila – the real primary value instead', () {
    final t = TileConfig(id: 'j', type: TileType.value, title: 'Laite', unit: '°C');
    expect(launcherStatusText(t, {'temperature': 21.5, 'humidity': 40}, 'fi'), '21.5 °C');
    expect(launcherStatusText(t, {'state': 'on'}, 'fi'), 'on °C');
    expect(launcherStatusText(t, {'nested': {}}, 'fi'), '–');
    for (final v in [{'a': 1}, {'x': {'y': 1}}, <String, dynamic>{}]) {
      expect(launcherStatusText(t, v, 'fi'), isNot('Tila'));
    }
  });
}
