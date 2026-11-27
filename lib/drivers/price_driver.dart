import '../prices/price_summary.dart';
import '../core/fields.dart';
import '../core/friendly_error.dart';
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
        'hourly',
        'Näytä tuntikeskiarvona',
        'Show as hourly average',
        kind: FieldKind.boolean,
        defaultValue: false,
        helpFi: 'Tuntihinnoitellulle sopimukselle. Pois: 15 min hinnat, kun alueen data on 15 min (EU:n päivämarkkina 1.10.2025 alkaen).',
        helpEn: 'For hourly-billed contracts. Off: 15-min prices where the area publishes them (EU day-ahead since 1 Oct 2025).',
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
        optionLabels: {
          'now': ('Hinta nyt', 'Price now'),
          'min': ('Päivän halvin', 'Lowest today'),
          'max': ('Päivän kallein', 'Highest today'),
          'avg': ('Päivän keskihinta', 'Average today'),
          'next_cheap': ('Seuraava halpa tunti', 'Next cheap hour'),
          'chart': (
            'Hintakaavio (tänään ja huomenna)',
            'Price chart (today and tomorrow)',
          ),
        },
        helpFi: 'Mikä hinnan tieto ruudussa näkyy: hinta nyt, päivän halvin / kallein / keskihinta, seuraava halpa tunti tai kaavio.',
        helpEn: 'Which price figure the tile shows: now, today\'s lowest / highest / average, the next cheap hour or the chart.',
      ),
    ],
    commandFields: [],
    create: PriceDriver.new,
  );

  String get zone => s.str('zone', 'FI');
  PriceSettings get settings => PriceSettings(
    vat:
        double.tryParse(
          s.str('vat', '${priceZones[zone]?.$2 ?? 25.5}').replaceAll(',', '.'),
        ) ??
        25.5,
    margin: double.tryParse(s.str('margin', '0').replaceAll(',', '.')) ?? 0,
    transfer: double.tryParse(s.str('transfer', '0').replaceAll(',', '.')) ?? 0,
  );

  Future<PriceSeries> _series({bool force = false}) async {
    final srv = s.str('server', defaultPriceServer);
    try {
      if (custom == null && srv != defaultPriceServer) {
        return await PriceService(server: srv).get(zone, force: force);
      }
      return await service.get(zone, force: force);
    } catch (e) {
      throw priceCloudError(e);
    }
  }

  /// Price failures are internet-service failures, never "device not found" (t151u).
  static CloudError priceCloudError(Object e) {
    if (e is CloudError) return e;
    final tried = e is PriceException ? e.tried : const <String>[];
    final tech = tried.isEmpty ? e.toString() : tried.join('\n');
    if (e is PriceException && e.message == 'unknown_zone') {
      return CloudError(
        ErrorKind.cloudService,
        'Hintapalvelu',
        'The price service',
        'unknown_zone',
      );
    }
    if (e is PriceException && e.offline) {
      return CloudError(
        ErrorKind.cloudOffline,
        'Hintapalvelu',
        'The price service',
        tech,
      );
    }
    final c = cloudErrorFrom(
      e,
      'Hintapalvelu',
      'The price service',
      fallbackTried: tried.length > 1,
    );
    return CloudError(
      c.kind,
      c.serviceFi,
      c.serviceEn,
      tech,
      fallbackTried: tried.length > 1,
    );
  }

  static double _r(double v) => (v * 100).round() / 100;

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final raw = await _series();
    // t168u: the data's own resolution (15 min where published) unless "Näytä tuntikeskiarvona".
    final hourly = s['hourly'] == true;
    final se = hourly && raw.resolution < 3600 ? raw.hourly() : raw;
    final now = DateTime.now();
    final st = settings;
    final today = se.day(now, 0);
    if (today.isEmpty) {
      throw DriverException(
        dtx(
          'Tämän päivän hintoja ei ole vielä saatavilla.',
          'No prices for today yet.',
        ),
      );
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
        // t166u / t168u: the cheapest slot still ahead (next 24 h) at the shown resolution.
        final w = priceWindowAhead(
          se.points,
          now,
          quarters: se.resolution < 3600,
          toCents: st.cents,
        );
        if (w == null) return '–';
        return '${windowRange(w, now, driverLang)} (${centsText(w.cents, driverLang)} c)';
      case 'chart':
        // Raw points: the tile averages them itself when "hourly" is set (and can still show 15 min).
        final pts = [...raw.day(now, 0), ...raw.day(now, 1)];
        return {
          'now': now.millisecondsSinceEpoch,
          'fetched': se.fetched.millisecondsSinceEpoch,
          if (se.stale) 'stale': true,
          'res': raw.resolution,
          if (hourly) 'hourly': true,
          'unit': 'c/kWh',
          'vat': st.vat,
          'margin': st.margin,
          'transfer': st.transfer,
          'points': [
            for (final p in pts)
              [
                p.start.millisecondsSinceEpoch,
                _r(st.cents(p.eurMwh)),
                _r(p.eurMwh),
              ],
          ],
        };
      default:
        final p = se.at(now);
        if (p == null) {
          throw DriverException(
            dtx('Hintaa ei ole tälle hetkelle.', 'No price for now.'),
          );
        }
        return _r(st.cents(p.eurMwh));
    }
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) =>
      throw DriverException(
        dtx(
          'Sähkön hinta on vain luettava.',
          'Electricity price is read-only.',
        ),
      );

  @override
  Future<String> test() async {
    final se = await _series(force: true);
    if (se.stale) {
      // Only an old copy was available: the test must not say "OK".
      throw CloudError(
        ErrorKind.cloudService,
        'Hintapalvelu',
        'The price service',
        se.tried.join('\n'),
        fallbackTried: true,
      );
    }
    final now = DateTime.now();
    if (se.day(now, 0).isEmpty) {
      throw CloudError(
        ErrorKind.cloudService,
        'Hintapalvelu',
        'The price service',
        'no prices for today (${se.points.length} points from ${se.source})',
      );
    }
    final tomorrow = se.hasTomorrow(now)
        ? dtx('Huominen: kyllä.', 'Tomorrow: yes.')
        : dtx(
            'Huominen: ei vielä (julkaistaan n. klo 14).',
            'Tomorrow: not yet (published around 14:00).',
          );
    return '${dtx('✓ Hinnat haettu alueelle $zone (${se.points.length} jaksoa, ${se.resolution ~/ 60} min, lähde ${se.source}).', '✓ Prices for $zone (${se.points.length} slots, ${se.resolution ~/ 60} min, source ${se.source}).')} $tomorrow';
  }
}
