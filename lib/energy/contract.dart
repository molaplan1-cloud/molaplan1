/// Electricity contract (energy + transfer + tax + VAT) and consumer prices.
///
/// Every price can be typed with or without VAT ([PriceInput.vatIncluded]); costs are always
/// reported both ways. Energy: 'spot' (day-ahead + margin), 'fixed', or 'daynight' (time windows).
/// Transfer: 'fixed' or 'daynight'. Monthly fees for both. Electricity tax per kWh.
library;

/// VAT % by country (general rate applied to electricity, 2026).
const vatByCountry = <String, double>{
  'FI': 25.5,
  'SE': 25,
  'NO': 25,
  'DK': 25,
  'EE': 24,
  'LV': 21,
  'LT': 21,
  'DE': 19,
  'NL': 21,
  'BE': 6,
  'FR': 20,
  'AT': 20,
  'PL': 23,
  'ES': 21,
  'PT': 23,
  'IT': 10,
  'CZ': 21,
  'SK': 23,
  'HU': 27,
  'SI': 22,
  'HR': 13,
  'RO': 19,
  'BG': 20,
  'GR': 6,
  'IE': 9,
  'LU': 8,
  'CH': 8.1,
};

/// Electricity tax c/kWh incl. VAT for households (Finland class I: 2.253 c + VAT 25.5 % ≈ 2.83 c).
const defaultTaxByCountry = <String, double>{'FI': 2.83};

/// Country of a bidding zone ("SE3" -> "SE", "DE-LU" -> "DE").
String countryOfZone(String zone) => zone.length >= 2 ? zone.substring(0, 2).toUpperCase() : 'FI';

/// A price as the user typed it.
class PriceInput {
  PriceInput(this.value, {this.vatIncluded = true});
  double value;
  bool vatIncluded;

  /// (without VAT, with VAT) for [vat] %.
  (double, double) split(double vat) {
    final f = 1 + vat / 100;
    return vatIncluded ? (value / f, value) : (value, value * f);
  }

  Map<String, dynamic> toJson() => {'v': value, 'inc': vatIncluded};
  static PriceInput fromJson(Object? j, double def, {bool inc = true}) {
    if (j is Map) {
      return PriceInput((j['v'] as num?)?.toDouble() ?? def, vatIncluded: j['inc'] != false);
    }
    if (j is num) return PriceInput(j.toDouble(), vatIncluded: inc);
    return PriceInput(def, vatIncluded: inc);
  }
}

/// Money both ways (c/kWh or €, depending on the context).
class Vat2 {
  const Vat2(this.ex, this.inc);
  final double ex;
  final double inc;
  static const zero = Vat2(0, 0);
  Vat2 operator +(Vat2 o) => Vat2(ex + o.ex, inc + o.inc);
  Vat2 operator *(double k) => Vat2(ex * k, inc * k);
  @override
  String toString() => '${ex.toStringAsFixed(3)}/${inc.toStringAsFixed(3)}';
}

class ElectricityContract {
  ElectricityContract({
    this.country = 'FI',
    double? vat,
    this.energyType = 'spot',
    PriceInput? margin,
    PriceInput? fixed,
    PriceInput? day,
    PriceInput? night,
    PriceInput? energyFee,
    this.nightFrom = 22,
    this.nightTo = 7,
    this.transferType = 'fixed',
    PriceInput? transfer,
    PriceInput? transferDay,
    PriceInput? transferNight,
    PriceInput? transferFee,
    PriceInput? tax,
    this.sellType = 'none',
    PriceInput? sellMargin,
    PriceInput? sellFixed,
  }) : vat = vat ?? vatByCountry[country] ?? 25.5,
       sellMargin = sellMargin ?? PriceInput(0.3, vatIncluded: false),
       sellFixed = sellFixed ?? PriceInput(5, vatIncluded: false),
       margin = margin ?? PriceInput(0.5),
       fixed = fixed ?? PriceInput(10),
       day = day ?? PriceInput(11),
       night = night ?? PriceInput(8),
       energyFee = energyFee ?? PriceInput(3),
       transfer = transfer ?? PriceInput(5),
       transferDay = transferDay ?? PriceInput(6),
       transferNight = transferNight ?? PriceInput(3.5),
       transferFee = transferFee ?? PriceInput(15),
       tax = tax ?? PriceInput(defaultTaxByCountry[country] ?? 0);

  String country;
  double vat;

  /// 'spot' | 'fixed' | 'daynight'
  String energyType;
  PriceInput margin; // c/kWh on top of spot
  PriceInput fixed; // c/kWh
  PriceInput day; // c/kWh
  PriceInput night; // c/kWh
  PriceInput energyFee; // €/month
  int nightFrom;
  int nightTo;

  /// 'fixed' | 'daynight' (uses the same night window)
  String transferType;
  PriceInput transfer; // c/kWh
  PriceInput transferDay;
  PriceInput transferNight;
  PriceInput transferFee; // €/month
  PriceInput tax; // c/kWh

  /// R685 (t337u): what sold (exported) electricity earns: 'none' (unknown – no income shown),
  /// 'spot' (spot price − [sellMargin]) or 'fixed' ([sellFixed]). A household seller pays no VAT
  /// on it, so both are used without VAT.
  String sellType;
  PriceInput sellMargin; // c/kWh off the spot price
  PriceInput sellFixed; // c/kWh

  /// Income c/kWh for exported electricity at [t]; null = no sell price (or spot missing).
  double? sellAt(DateTime t, {double? spotEurMwh}) {
    switch (sellType) {
      case 'fixed':
        return sellFixed.split(vat).$1;
      case 'spot':
        if (spotEurMwh == null) return null;
        return spotEurMwh / 10 - sellMargin.split(vat).$1;
      default:
        return null;
    }
  }

  bool isNight(DateTime t) {
    final h = t.hour;
    return nightFrom <= nightTo ? h >= nightFrom && h < nightTo : h >= nightFrom || h < nightTo;
  }

  /// Energy part c/kWh at [t]; null when the spot price is needed but missing.
  Vat2? energyAt(DateTime t, {double? spotEurMwh}) {
    switch (energyType) {
      case 'fixed':
        final (e, i) = fixed.split(vat);
        return Vat2(e, i);
      case 'daynight':
        final (e, i) = (isNight(t) ? night : day).split(vat);
        return Vat2(e, i);
      default:
        if (spotEurMwh == null) return null;
        final spot = spotEurMwh / 10;
        final (me, mi) = margin.split(vat);
        // No VAT on negative spot prices (the seller credits them as such).
        return Vat2(spot + me, spot > 0 ? spot * (1 + vat / 100) + mi : spot + mi);
    }
  }

  /// Transfer + electricity tax c/kWh at [t].
  Vat2 gridAt(DateTime t) {
    final tr = transferType == 'daynight' ? (isNight(t) ? transferNight : transferDay) : transfer;
    final (te, ti) = tr.split(vat);
    final (xe, xi) = tax.split(vat);
    return Vat2(te + xe, ti + xi);
  }

  /// Everything per kWh at [t] (c/kWh); null when the spot price is missing.
  Vat2? unitAt(DateTime t, {double? spotEurMwh}) {
    final e = energyAt(t, spotEurMwh: spotEurMwh);
    return e == null ? null : e + gridAt(t);
  }

  /// Monthly fees (energy + transfer), €.
  Vat2 get monthlyFees {
    final (a, b) = energyFee.split(vat);
    final (c, d) = transferFee.split(vat);
    return Vat2(a + c, b + d);
  }

  /// Monthly fees for one day of [day]'s month, €.
  Vat2 dailyFees(DateTime day) {
    final days = DateTime(day.year, day.month + 1, 0).day;
    return monthlyFees * (1 / days);
  }

  Map<String, dynamic> toJson() => {
    'country': country,
    'vat': vat,
    'energyType': energyType,
    'margin': margin.toJson(),
    'fixed': fixed.toJson(),
    'day': day.toJson(),
    'night': night.toJson(),
    'energyFee': energyFee.toJson(),
    'nightFrom': nightFrom,
    'nightTo': nightTo,
    'transferType': transferType,
    'transfer': transfer.toJson(),
    'transferDay': transferDay.toJson(),
    'transferNight': transferNight.toJson(),
    'transferFee': transferFee.toJson(),
    'tax': tax.toJson(),
    if (sellType != 'none') 'sellType': sellType,
    'sellMargin': sellMargin.toJson(),
    'sellFixed': sellFixed.toJson(),
  };

  factory ElectricityContract.fromJson(Map<String, dynamic> j) {
    final country = '${j['country'] ?? 'FI'}';
    return ElectricityContract(
      country: country,
      vat: (j['vat'] as num?)?.toDouble(),
      energyType: '${j['energyType'] ?? 'spot'}',
      margin: PriceInput.fromJson(j['margin'], 0.5),
      fixed: PriceInput.fromJson(j['fixed'], 10),
      day: PriceInput.fromJson(j['day'], 11),
      night: PriceInput.fromJson(j['night'], 8),
      energyFee: PriceInput.fromJson(j['energyFee'], 3),
      nightFrom: (j['nightFrom'] as num?)?.toInt() ?? 22,
      nightTo: (j['nightTo'] as num?)?.toInt() ?? 7,
      transferType: '${j['transferType'] ?? 'fixed'}',
      transfer: PriceInput.fromJson(j['transfer'], 5),
      transferDay: PriceInput.fromJson(j['transferDay'], 6),
      transferNight: PriceInput.fromJson(j['transferNight'], 3.5),
      transferFee: PriceInput.fromJson(j['transferFee'], 15),
      tax: PriceInput.fromJson(j['tax'], defaultTaxByCountry[country] ?? 0),
      sellType: const ['spot', 'fixed'].contains(j['sellType']) ? j['sellType'] as String : 'none',
      sellMargin: PriceInput.fromJson(j['sellMargin'], 0.3, inc: false),
      sellFixed: PriceInput.fromJson(j['sellFixed'], 5, inc: false),
    );
  }
}
