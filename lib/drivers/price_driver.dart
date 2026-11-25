import '../core/fields.dart';
import '../prices/prices.dart';
import 'driver.dart';

/// Electricity spot price (day-ahead) for one bidding zone, in c/kWh incl. VAT, margin and transfer.
/// Read spec: {'field': 'now'|'min'|'max'|'avg'|'next_cheap'|'chart'}.
class PriceDriver extends Driver {
  PriceDriver(super.config, {this.custom});

  /// Injected price service (tests); default is the shared one.
  final PriceService? custom;
  PriceService get service => custom ?? PriceService.shared;

  static const descriptor = DriverDescriptor(
    type: 'price',
    fi: 'Sähkön hinta',
    en: 'Electricity price',
    connectionFields: [
      FieldSpec(
        'zone',
        'Hinta-alue',
        'Price area',
        kind: FieldKind.choice,
        options: [
          'FI',
          'EE',
          'LV',
          'LT',
          'SE1',
          'SE2',
          'SE3',
          'SE4',
          'NO1',
          'NO2',
          'NO3',
          'NO4',
          'NO5',
          'DK1',
          'DK2',
          'DE-LU',
          'NL',
          'BE',
          'FR',
          'AT',
          'CH',
          'PL',
          'CZ',
          'SK',
          'HU',
          'SI',
          'HR',
          'RO',
          'BG',
          'GR',
          'ES',
          'PT',
          'IT-North',
          'IT-Centre-North',
          'IT-Centre-South',
          'IT-South',
          'IT-Calabria',
          'IT-Sicily',
          'IT-Sardinia',
        ],
        defaultValue: 'FI',
        helpFi: 'Suomi on yksi alue (FI). Ruotsissa ja Norjassa alue riippuu asuinpaikasta.',
        helpEn: 'Finland is one area (FI). In Sweden and Norway it depends on where you live.',
      ),
      FieldSpec(
        'vat',
        'ALV %',
        'VAT %',
        kind: FieldKind.number,
        defaultValue: 25.5,
        helpFi: 'Suomessa 25,5 %.',
        helpEn: 'Your country\'s VAT.',
      ),
      FieldSpec(
        'margin',
        'Myyjän marginaali (c/kWh)',
        'Seller margin (c/kWh)',
        kind: FieldKind.number,
        defaultValue: 0,
        helpFi: 'Pörssisähkösopimuksen marginaali ilman ALV:tä, esim. 0,5.',
        helpEn: 'Spot contract margin without VAT.',
      ),
      FieldSpec(
        'transfer',
        'Siirto + sähkövero (c/kWh)',
        'Transfer + tax (c/kWh)',
        kind: FieldKind.number,
        defaultValue: 0,
        helpFi: 'Laskun mukaan ALV:n kanssa. Jätä 0, jos haluat nähdä pelkän energian hinnan.',
        helpEn: 'From your bill, incl. VAT. Leave 0 for energy only.',
      ),
      FieldSpec(
        'server',
        'Hintapalvelin',
        'Price server',
        defaultValue: defaultPriceServer,
        advanced: true,
        helpFi: 'Molaplanin oma palvelin hakee hinnat avoimista lähteistä.',
        helpEn: 'Molaplan\'s server fetches prices from open sources.',
      ),
    ],
    readFields: [
      FieldSpec(
        'field',
        'Mitä näytetään',
        'What to show',
        kind: FieldKind.choice,
        options: ['now', 'min', 'max', 'avg', 'next_cheap', 'chart'],
        defaultValue: 'now',
        helpFi: 'now = hinta nyt, chart = kaavio tälle ja huomiselle päivälle.',
        helpEn: 'now = current price, chart = today and tomorrow.',
      ),
    ],
    commandFields: [],
    create: PriceDriver.new,
  );

  String get zone => s.str('zone', 'FI');
  PriceSettings get settings => PriceSettings(
    vat: double.tryParse(s.str('vat', '${priceZones[zone]?.$2 ?? 25.5}').replaceAll(',', '.')) ?? 25.5,
    margin: double.tryParse(s.str('margin', '0').replaceAll(',', '.')) ?? 0,
    transfer: double.tryParse(s.str('transfer', '0').replaceAll(',', '.')) ?? 0,
  );

  Future<PriceSeries> _series() {
    final srv = s.str('server', defaultPriceServer);
    if (custom == null && srv != defaultPriceServer) return PriceService(server: srv).get(zone);
    return service.get(zone);
  }

  static double _r(double v) => (v * 100).round() / 100;

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final se = await _series();
    final now = DateTime.now();
    final st = settings;
    final today = se.day(now, 0);
    if (today.isEmpty) {
      throw DriverException(dtx('Tämän päivän hintoja ei ole vielä saatavilla.', 'No prices for today yet.'));
    }
    final cents = today.map((p) => st.cents(p.eurMwh)).toList();
    switch (spec.str('field', 'now')) {
      case 'min':
        return _r(cents.reduce((a, b) => a < b ? a : b));
      case 'max':
        return _r(cents.reduce((a, b) => a > b ? a : b));
      case 'avg':
        return _r(cents.reduce((a, b) => a + b) / cents.length);
      case 'next_cheap':
        final ahead = se.hourly().between(now.subtract(const Duration(hours: 1)), now.add(const Duration(hours: 36)))
          ..retainWhere((p) => p.end.isAfter(now));
        if (ahead.isEmpty) return '–';
        ahead.sort((a, b) => a.eurMwh.compareTo(b.eurMwh));
        final b = ahead.first;
        final day = b.start.day == now.day ? '' : dtx('huomenna ', 'tomorrow ');
        return '$day${b.start.hour.toString().padLeft(2, '0')}–${b.end.hour.toString().padLeft(2, '0')} (${st.cents(b.eurMwh).toStringAsFixed(1)} c)';
      case 'chart':
        final pts = [...today, ...se.day(now, 1)];
        return {
          'now': now.millisecondsSinceEpoch,
          'fetched': se.fetched.millisecondsSinceEpoch,
          if (se.stale) 'stale': true,
          'res': se.resolution,
          'unit': 'c/kWh',
          'points': [
            for (final p in pts) [p.start.millisecondsSinceEpoch, _r(st.cents(p.eurMwh))],
          ],
        };
      default:
        final p = se.at(now);
        if (p == null) throw DriverException(dtx('Hintaa ei ole tälle hetkelle.', 'No price for now.'));
        return _r(st.cents(p.eurMwh));
    }
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) =>
      throw DriverException(dtx('Sähkön hinta on vain luettava.', 'Electricity price is read-only.'));

  @override
  Future<String> test() async {
    final se = await service.get(zone, force: true);
    final now = DateTime.now();
    final tomorrow = se.hasTomorrow(now)
        ? dtx('Huominen: kyllä.', 'Tomorrow: yes.')
        : dtx('Huominen: ei vielä (julkaistaan n. klo 14).', 'Tomorrow: not yet (published around 14:00).');
    return '${dtx('✓ Hinnat haettu alueelle $zone (${se.points.length} jaksoa, ${se.resolution ~/ 60} min, lähde ${se.source}).', '✓ Prices for $zone (${se.points.length} slots, ${se.resolution ~/ 60} min, source ${se.source}).')} $tomorrow';
  }
}
