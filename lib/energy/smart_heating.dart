/// 'Älykäs lämmitys' (R194, t187u/t188u): a site survey, recommended settings per heating type,
/// templates (cheapest hours, skip expensive hours, weather-based pre-heating, holiday mode), a
/// fireplace mode and safety limits. Runs on the home bridge ([SmartHeatingRunner]) next to the
/// price rules and thermostats, so it works with every app closed. Prices come from the shared
/// [PriceService] cache (fetched once, used by everything), the forecast from [WeatherService].
library;

import 'dart:async';
import 'dart:math' as math;

import '../models/models.dart';
import '../prices/prices.dart';
import 'contract.dart';
import 'heating_plan.dart';
import 'thermostat.dart';
import 'weather.dart';

// ------------------------------------------------------------------ heating types

class HeatingTypeInfo {
  const HeatingTypeInfo(
    this.id, {
    required this.fi,
    required this.en,
    required this.space,
    required this.template,
    required this.fullHours,
    required this.minHours,
    required this.maxOff,
    required this.skipHours,
    required this.planPreset,
    required this.whyFi,
    required this.whyEn,
  });
  final String id;
  final String fi;
  final String en;

  /// Heats the rooms (false: domestic hot water only).
  final bool space;

  /// Recommended template.
  final String template;

  /// Full-power hours a day at the design temperature (−25 °C), average insulation.
  final double fullHours;
  final int minHours;

  /// How long it may stay off in one go (h), average insulation, 1.5 °C allowed swing.
  final double maxOff;

  /// Most expensive hours skipped a day ('skip_expensive').
  final int skipHours;

  /// Heating plan preset for thermostat-controlled loads ('weather').
  final String planPreset;
  final String whyFi;
  final String whyEn;
}

const heatingTypes = [
  HeatingTypeInfo(
    'concrete_floor',
    fi: 'Varaava lattialämmitys (betoni)',
    en: 'Storage floor heating (concrete)',
    space: true,
    template: 'weather',
    fullHours: 12,
    minHours: 2,
    maxOff: 12,
    skipHours: 8,
    planPreset: 'eco',
    whyFi: 'Betonilaatta varaa lämpöä pitkään: lämmitys keskitetään päivän halvimpiin tunteihin, ja tuntimäärä seuraa sääennustetta.',
    whyEn: 'A concrete slab stores heat for a long time: heating is moved to the cheapest hours, and the number of hours follows the forecast.',
  ),
  HeatingTypeInfo(
    'light_floor',
    fi: 'Kevyt lattialämmitys',
    en: 'Light floor heating',
    space: true,
    template: 'skip_expensive',
    fullHours: 20,
    minHours: 4,
    maxOff: 2,
    skipHours: 4,
    planPreset: 'balanced',
    whyFi: 'Kevyt lattia varaa vähän: ohitetaan päivän kalleimmat tunnit, mutta katko on lyhyt.',
    whyEn: 'A light floor stores little heat: the most expensive hours are skipped, with short breaks only.',
  ),
  HeatingTypeInfo(
    'radiator',
    fi: 'Suorat sähköpatterit',
    en: 'Direct electric radiators',
    space: true,
    template: 'skip_expensive',
    fullHours: 20,
    minHours: 4,
    maxOff: 1,
    skipHours: 3,
    planPreset: 'balanced',
    whyFi: 'Patterit eivät varaa lämpöä: vain kalleimmat tunnit ohitetaan, yksi tunti kerrallaan.',
    whyEn: 'Radiators do not store heat: only the most expensive hours are skipped, one hour at a time.',
  ),
  HeatingTypeInfo(
    'ilp',
    fi: 'Ilmalämpöpumppu',
    en: 'Air-source heat pump',
    space: true,
    template: 'weather',
    fullHours: 20,
    minHours: 4,
    maxOff: 2,
    skipHours: 3,
    planPreset: 'comfort',
    whyFi: 'Ilmalämpöpumppu toimii parhaiten tasaisella lämmöllä: tavoitelämpö nousee hieman ennen kallista tai kylmää jaksoa ja laskee kalliina tunteina.',
    whyEn: 'A heat pump works best at an even temperature: the target rises a little before expensive or cold spells and drops in expensive hours.',
  ),
  HeatingTypeInfo(
    'gshp',
    fi: 'Maalämpöpumppu',
    en: 'Ground-source heat pump',
    space: true,
    template: 'skip_expensive',
    fullHours: 18,
    minHours: 4,
    maxOff: 3,
    skipHours: 5,
    planPreset: 'eco',
    whyFi: 'Maalämpö ja vesikiertoinen lämmitys varaavat jonkin verran: kalleimmat tunnit ohitetaan enintään muutaman tunnin katkoina.',
    whyEn: 'Ground-source heat with water circulation stores some heat: the most expensive hours are skipped in breaks of a few hours at most.',
  ),
  HeatingTypeInfo(
    'water_heater',
    fi: 'Lämminvesivaraaja',
    en: 'Water heater',
    space: false,
    template: 'cheapest',
    fullHours: 4,
    minHours: 2,
    maxOff: 22,
    skipHours: 8,
    planPreset: 'eco',
    whyFi: 'Varaaja pysyy lämpimänä vuorokauden: se lämmitetään päivän halvimpina tunteina.',
    whyEn: 'A water heater stays hot for a day: it is heated in the cheapest hours of the day.',
  ),
];

HeatingTypeInfo heatingType(String? id) => heatingTypes.firstWhere((t) => t.id == id, orElse: () => heatingTypes[2]);

const heatingTemplates = ['cheapest', 'skip_expensive', 'weather'];

// ------------------------------------------------------------------ survey + config

class SiteSurvey {
  SiteSurvey({
    List<String>? types,
    this.insulation = 'average',
    this.area = 120,
    this.swing = 1.5,
    this.fireplace = false,
  }) : types = types ?? [];

  /// Heating types in the home (ids of [heatingTypes]).
  List<String> types;

  /// 'poor' | 'average' | 'good'
  String insulation;

  /// Heated floor area m².
  double area;

  /// Allowed temperature swing (°C) around the comfort temperature.
  double swing;

  /// A fireplace / storing stove (supplementary heat, not controlled).
  bool fireplace;

  double get insulationFactor => switch (insulation) {
    'poor' => 1.25,
    'good' => 0.75,
    _ => 1.0,
  };

  /// Good insulation keeps the heat longer.
  double get holdFactor => switch (insulation) {
    'poor' => 0.75,
    'good' => 1.5,
    _ => 1.0,
  };

  /// Heat loss W/m² at the design temperature (rough, for the energy estimate).
  double get lossWm2 => switch (insulation) {
    'poor' => 60,
    'good' => 25,
    _ => 40,
  };

  Map<String, dynamic> toJson() => {
    'types': types,
    'insulation': insulation,
    'area': area,
    'swing': swing,
    'fireplace': fireplace,
  };

  factory SiteSurvey.fromJson(Object? j) {
    if (j is! Map) return SiteSurvey();
    return SiteSurvey(
      types: [for (final t in (j['types'] as List? ?? const [])) '$t'],
      insulation: const ['poor', 'average', 'good'].contains(j['insulation']) ? '${j['insulation']}' : 'average',
      area: (j['area'] as num?)?.toDouble() ?? 120,
      swing: ((j['swing'] as num?)?.toDouble() ?? 1.5).clamp(0.5, 4.0),
      fireplace: j['fireplace'] == true,
    );
  }
}

/// One heating device controlled by smart heating.
class HeatLoad {
  HeatLoad({
    String? id,
    this.name = '',
    required this.type,
    this.control = 'switch',
    this.tileId,
    this.thermostatId,
    this.sensorTileId,
    this.template,
    this.hours,
    this.skipHours,
    this.maxOffHours,
    this.comfort = 21,
    this.fireplace,
    this.enabled = true,
  }) : id = id ?? newId();
  String id;
  String name;
  String type;

  /// 'switch' (relay / plug toggle tile) or 'thermostat' (a Molaplan thermostat: its target is set).
  String control;
  String? tileId;
  String? thermostatId;

  /// Room temperature for the safety limits and the comfort cap (switch loads).
  String? sensorTileId;

  /// null = the recommendation for the site.
  String? template;
  int? hours;
  int? skipHours;
  double? maxOffHours;

  /// Comfort temperature (switch loads with a sensor; thermostats use their own setpoint).
  double comfort;

  /// Lowered in fireplace mode (null = space heating yes, water heater no).
  bool? fireplace;
  bool enabled;

  HeatingTypeInfo get info => heatingType(type);
  bool get followsFireplace => fireplace ?? info.space;

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'type': type,
    'control': control,
    'tileId': ?tileId,
    'thermostatId': ?thermostatId,
    'sensorTileId': ?sensorTileId,
    'template': ?template,
    'hours': ?hours,
    'skipHours': ?skipHours,
    'maxOffHours': ?maxOffHours,
    'comfort': comfort,
    'fireplace': ?fireplace,
    'enabled': enabled,
  };

  factory HeatLoad.fromJson(Map<String, dynamic> j) => HeatLoad(
    id: j['id'] as String?,
    name: '${j['name'] ?? ''}',
    type: '${j['type'] ?? 'radiator'}',
    control: j['control'] == 'thermostat' ? 'thermostat' : 'switch',
    tileId: j['tileId'] as String?,
    thermostatId: j['thermostatId'] as String?,
    sensorTileId: j['sensorTileId'] as String?,
    template: heatingTemplates.contains(j['template']) ? '${j['template']}' : null,
    hours: (j['hours'] as num?)?.toInt(),
    skipHours: (j['skipHours'] as num?)?.toInt(),
    maxOffHours: (j['maxOffHours'] as num?)?.toDouble(),
    comfort: (j['comfort'] as num?)?.toDouble() ?? 21,
    fireplace: j['fireplace'] as bool?,
    enabled: j['enabled'] != false,
  );
}

class HeatingSafety {
  HeatingSafety({this.minTemp = 15, this.frost = true, this.frostTemp = 5, this.maxOffHours});

  /// Rooms never below this (needs a temperature sensor).
  double minTemp;
  bool frost;
  double frostTemp;

  /// Upper limit for any off period of space heating (null = per heating type).
  double? maxOffHours;

  Map<String, dynamic> toJson() => {
    'minTemp': minTemp,
    'frost': frost,
    'frostTemp': frostTemp,
    'maxOffHours': ?maxOffHours,
  };

  factory HeatingSafety.fromJson(Object? j) {
    if (j is! Map) return HeatingSafety();
    return HeatingSafety(
      minTemp: (j['minTemp'] as num?)?.toDouble() ?? 15,
      frost: j['frost'] != false,
      frostTemp: (j['frostTemp'] as num?)?.toDouble() ?? 5,
      maxOffHours: (j['maxOffHours'] as num?)?.toDouble(),
    );
  }
}

class HolidayMode {
  HolidayMode({this.on = false, this.from, this.to, this.temp = 17});
  bool on;
  DateTime? from;
  DateTime? to;

  /// Room temperature kept while away.
  double temp;

  bool activeAt(DateTime t) => on && (from == null || !t.isBefore(from!)) && (to == null || t.isBefore(to!));

  Map<String, dynamic> toJson() => {
    'on': on,
    if (from != null) 'from': from!.millisecondsSinceEpoch,
    if (to != null) 'to': to!.millisecondsSinceEpoch,
    'temp': temp,
  };

  factory HolidayMode.fromJson(Object? j) {
    if (j is! Map) return HolidayMode();
    DateTime? t(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return HolidayMode(
      on: j['on'] == true,
      from: t(j['from']),
      to: t(j['to']),
      temp: (j['temp'] as num?)?.toDouble() ?? 17,
    );
  }
}

class SmartHeatingConfig {
  SmartHeatingConfig({
    this.enabled = true,
    SiteSurvey? site,
    List<HeatLoad>? loads,
    HeatingSafety? safety,
    HolidayMode? holiday,
    this.fireplaceHours = 18,
    this.fireplaceUntilCool = true,
    this.fireplaceDrop = 2,
    this.fireplaceSensorTileId,
    this.notify = true,
  }) : site = site ?? SiteSurvey(),
       loads = loads ?? [],
       safety = safety ?? HeatingSafety(),
       holiday = holiday ?? HolidayMode();
  bool enabled;
  SiteSurvey site;
  List<HeatLoad> loads;
  HeatingSafety safety;
  HolidayMode holiday;

  /// Default fireplace-mode length, 12–24 h.
  int fireplaceHours;

  /// End fireplace mode early when the linked sensor shows the room cooling.
  bool fireplaceUntilCool;

  /// Thermostat targets are lowered this much in fireplace mode (°C).
  double fireplaceDrop;
  String? fireplaceSensorTileId;

  /// Smart heating notifications via ntfy (the same topic and quiet hours as automations).
  bool notify;

  Map<String, dynamic> toJson() => {
    'enabled': enabled,
    'site': site.toJson(),
    'loads': [for (final l in loads) l.toJson()],
    'safety': safety.toJson(),
    'holiday': holiday.toJson(),
    'fireplaceHours': fireplaceHours,
    'fireplaceUntilCool': fireplaceUntilCool,
    'fireplaceDrop': fireplaceDrop,
    'fireplaceSensorTileId': ?fireplaceSensorTileId,
    'notify': notify,
  };

  factory SmartHeatingConfig.fromJson(Object? j) {
    if (j is! Map) return SmartHeatingConfig();
    return SmartHeatingConfig(
      enabled: j['enabled'] != false,
      site: SiteSurvey.fromJson(j['site']),
      loads: [
        for (final l in (j['loads'] as List? ?? const []))
          if (l is Map) HeatLoad.fromJson(Map<String, dynamic>.from(l)),
      ],
      safety: HeatingSafety.fromJson(j['safety']),
      holiday: HolidayMode.fromJson(j['holiday']),
      fireplaceHours: ((j['fireplaceHours'] as num?)?.toInt() ?? 18).clamp(12, 24),
      fireplaceUntilCool: j['fireplaceUntilCool'] != false,
      fireplaceDrop: (j['fireplaceDrop'] as num?)?.toDouble() ?? 2,
      fireplaceSensorTileId: j['fireplaceSensorTileId'] as String?,
      notify: j['notify'] != false,
    );
  }
}

// ------------------------------------------------------------------ recommendations

/// Share of the design heat demand at [outdoor] °C (21 °C inside, −25 °C design).
double heatDemand(double outdoor) => ((21 - outdoor) / 46).clamp(0.1, 1.0);

class Recommendation {
  Recommendation({
    required this.template,
    required this.hours,
    required this.skipHours,
    required this.maxOff,
    required this.kWhPerDay,
    required this.whyFi,
    required this.whyEn,
  });
  final String template;

  /// Heating hours a day ('cheapest'; 'weather' uses this at 0 °C and adjusts by the forecast).
  final int hours;
  final int skipHours;
  final double maxOff;

  /// Rough daily energy at 0 °C (null for the water heater).
  final double? kWhPerDay;
  final String whyFi;
  final String whyEn;
}

/// Hours a day a switch load of [t] needs at [outdoor] °C on this site.
int hoursFor(HeatingTypeInfo t, SiteSurvey s, double outdoor) {
  if (!t.space) return t.fullHours.round();
  return (t.fullHours * s.insulationFactor * heatDemand(outdoor)).round().clamp(t.minHours, 24);
}

/// Recommended settings for one heating type on this site.
Recommendation recommend(String type, SiteSurvey s, {String control = 'switch'}) {
  final t = heatingType(type);
  final swingK = (s.swing / 1.5).clamp(0.5, 2.0);
  var template = t.template;
  // A switch-only heat pump cannot follow a target temperature: skip the expensive hours instead.
  if (template == 'weather' && control == 'switch' && t.id == 'ilp') template = 'skip_expensive';
  final maxOff = t.space ? (t.maxOff * s.holdFactor * swingK).clamp(1.0, 24.0) : t.maxOff;
  final skip = t.space ? (t.skipHours * swingK * s.holdFactor).round().clamp(1, 12) : t.skipHours;
  return Recommendation(
    template: template,
    hours: hoursFor(t, s, 0),
    skipHours: skip,
    maxOff: (maxOff * 2).round() / 2,
    kWhPerDay: t.space ? s.area * s.lossWm2 * heatDemand(0) * 24 / 1000 : null,
    whyFi: t.whyFi,
    whyEn: t.whyEn,
  );
}

// ------------------------------------------------------------------ decisions (pure)

/// Hour starts of the local day containing [t] with their cost (null = prices incomplete).
List<(DateTime, double)>? dayCosts(DateTime t, double? Function(DateTime hour) cost) {
  final out = <(DateTime, double)>[];
  final seen = <int>{};
  for (var h = 0; h < 24; h++) {
    final s = DateTime(t.year, t.month, t.day, h);
    if (s.day != t.day || !seen.add(s.millisecondsSinceEpoch)) continue;
    final c = cost(s);
    if (c == null) return null;
    out.add((s, c));
  }
  return out;
}

DateTime hourOf(DateTime t) => DateTime(t.year, t.month, t.day, t.hour);

/// The [n] cheapest hours; then long gaps (> [maxOff] h) get their cheapest hour added.
Set<DateTime> cheapestHours(List<(DateTime, double)> day, int n, {double? maxOff}) {
  final sorted = [...day]..sort((a, b) => a.$2.compareTo(b.$2));
  final chosen = {for (final x in sorted.take(n.clamp(0, day.length))) x.$1};
  if (maxOff == null || chosen.isEmpty) return chosen;
  final limit = maxOff.floor();
  for (var guard = 0; guard < 24; guard++) {
    // Longest run of unchosen hours.
    var bestStart = -1, bestLen = 0, runStart = -1;
    for (var i = 0; i <= day.length; i++) {
      final off = i < day.length && !chosen.contains(day[i].$1);
      if (off && runStart < 0) runStart = i;
      if (!off && runStart >= 0) {
        if (i - runStart > bestLen) {
          bestLen = i - runStart;
          bestStart = runStart;
        }
        runStart = -1;
      }
    }
    if (bestLen <= limit) break;
    final gap = day.sublist(bestStart, bestStart + bestLen)..sort((a, b) => a.$2.compareTo(b.$2));
    chosen.add(gap.first.$1);
  }
  return chosen;
}

/// The [k] most expensive hours, never more than [maxRun] of them in a row.
Set<DateTime> expensiveHours(List<(DateTime, double)> day, int k, {double maxRun = 24}) {
  final sorted = [...day]..sort((a, b) => b.$2.compareTo(a.$2));
  final idx = {for (var i = 0; i < day.length; i++) day[i].$1: i};
  final picked = <int>{};
  final limit = math.max(1, maxRun.floor());
  for (final x in sorted) {
    if (picked.length >= k) break;
    final i = idx[x.$1]!;
    var left = 0, right = 0;
    while (picked.contains(i - left - 1)) {
      left++;
    }
    while (picked.contains(i + right + 1)) {
      right++;
    }
    if (left + right + 1 > limit) continue;
    picked.add(i);
  }
  return {for (final i in picked) day[i].$1};
}

/// Inputs of one decision.
class HeatInputs {
  HeatInputs({
    required this.now,
    required this.cost,
    required this.outdoor,
    this.temp,
    this.holiday = false,
    this.holidayEnd,
    this.fireplace = false,
  });
  final DateTime now;
  final double? Function(DateTime hour) cost;
  final double? Function(DateTime hour) outdoor;

  /// Room temperature (null = no sensor or no reading).
  final double? temp;
  final bool holiday;
  final DateTime? holidayEnd;
  final bool fireplace;
}

class HeatDecision {
  HeatDecision({this.on, this.target, required this.reason, this.safety = false});

  /// Switch loads.
  final bool? on;

  /// Thermostat loads.
  final double? target;

  /// cheap | not_cheap | expensive | normal | noprice | holiday | holiday_return | fireplace | warm |
  /// min_temp | frost | preheat | coast
  final String reason;

  /// Forced by a safety limit.
  final bool safety;
}

/// Hours a day for a switch load now ('weather': from the day's average forecast).
int loadHours(HeatLoad l, SiteSurvey s, String template, HeatInputs x) {
  final rec = recommend(l.type, s, control: l.control);
  if (template == 'weather' && l.info.space) {
    final temps = [for (var h = 0; h < 24; h++) x.outdoor(DateTime(x.now.year, x.now.month, x.now.day, h))]
        .whereType<double>()
        .toList();
    if (temps.isNotEmpty) {
      final avg = temps.reduce((a, b) => a + b) / temps.length;
      final base = hoursFor(l.info, s, avg);
      // A user-set hour count scales with the weather the same way.
      return l.hours == null ? base : (l.hours! * base / math.max(1, rec.hours)).round().clamp(1, 24);
    }
  }
  return l.hours ?? rec.hours;
}

/// What a switch load should do now (before the runtime max-off guard).
HeatDecision decideSwitch(SmartHeatingConfig c, HeatLoad l, HeatInputs x) {
  final s = c.site;
  final rec = recommend(l.type, s, control: l.control);
  final template = l.template ?? rec.template;
  final space = l.info.space;
  final t = x.temp;
  // Safety first (space heating with a sensor).
  if (space && t != null) {
    if (c.safety.frost && t < c.safety.frostTemp) return HeatDecision(on: true, reason: 'frost', safety: true);
    if (t < c.safety.minTemp) return HeatDecision(on: true, reason: 'min_temp', safety: true);
  }
  if (x.fireplace && l.followsFireplace) return HeatDecision(on: false, reason: 'fireplace');
  final maxOff = l.maxOffHours ?? c.safety.maxOffHours ?? rec.maxOff;
  if (x.holiday) {
    if (!space) {
      // Water heater: off while away, back on in time for the return.
      final end = x.holidayEnd;
      if (end == null || end.difference(x.now) > const Duration(hours: 24)) {
        return HeatDecision(on: false, reason: 'holiday');
      }
    } else if (t != null) {
      final keep = math.max(c.holiday.temp, c.safety.minTemp);
      return HeatDecision(on: t < keep, reason: 'holiday');
    }
  }
  // Comfort cap: warm enough already.
  if (space && t != null && t >= l.comfort + s.swing) return HeatDecision(on: false, reason: 'warm');
  final day = dayCosts(x.now, x.cost);
  if (day == null) return HeatDecision(on: true, reason: 'noprice');
  final h = hourOf(x.now);
  if (template == 'skip_expensive') {
    final k = l.skipHours ?? rec.skipHours;
    final skip = expensiveHours(day, x.holiday ? k * 2 : k, maxRun: maxOff);
    final off = skip.contains(h);
    return HeatDecision(on: !off, reason: off ? 'expensive' : (x.holiday ? 'holiday' : 'normal'));
  }
  var n = loadHours(l, s, template, x);
  if (x.holiday && space) n = (n / 2).ceil();
  final on = cheapestHours(day, n, maxOff: maxOff).contains(h);
  final reason = x.holiday && space ? 'holiday' : (x.holiday ? 'holiday_return' : (on ? 'cheap' : 'not_cheap'));
  return HeatDecision(on: on, reason: reason);
}

/// Target for a thermostat load. [comfort] is the thermostat's own setpoint; [plan] the cached
/// weather plan ('weather' template).
HeatDecision decideThermostat(
  SmartHeatingConfig c,
  HeatLoad l,
  HeatInputs x,
  double comfort, {
  List<PlanHour> plan = const [],
}) {
  final s = c.site;
  final rec = recommend(l.type, s, control: l.control);
  final template = l.template ?? rec.template;
  final floor = math.max(c.safety.minTemp, c.safety.frost ? c.safety.frostTemp : -50);
  HeatDecision done(double v, String r) {
    final safe = v < floor;
    return HeatDecision(target: (math.max(v, floor) * 2).round() / 2, reason: safe ? 'min_temp' : r, safety: safe);
  }

  if (x.holiday) return done(math.max(c.holiday.temp, c.safety.minTemp), 'holiday');
  var target = comfort;
  var reason = 'normal';
  final day = dayCosts(x.now, x.cost);
  final h = hourOf(x.now);
  if (template == 'weather') {
    final p = plan
        .where((p) => !x.now.isBefore(p.start) && x.now.isBefore(p.start.add(const Duration(hours: 1))))
        .firstOrNull;
    if (p != null) {
      target = p.target;
      reason = p.reason == 'noprice' ? 'noprice' : (p.reason == 'normal' ? 'normal' : p.reason);
    } else if (day == null) {
      reason = 'noprice';
    }
  } else if (day == null) {
    reason = 'noprice';
  } else if (template == 'skip_expensive') {
    final maxOff = l.maxOffHours ?? c.safety.maxOffHours ?? rec.maxOff;
    if (expensiveHours(day, l.skipHours ?? rec.skipHours, maxRun: maxOff).contains(h)) {
      target = comfort - s.swing;
      reason = 'expensive';
    }
  } else {
    final on = cheapestHours(day, loadHours(l, s, template, x)).contains(h);
    target = on ? comfort + s.swing / 2 : comfort - s.swing / 2;
    reason = on ? 'cheap' : 'not_cheap';
  }
  if (x.fireplace && l.followsFireplace) {
    target -= c.fireplaceDrop;
    reason = 'fireplace';
  }
  return done(target, reason);
}

/// Plan settings for a thermostat load's 'weather' template.
HeatingPlanSettings weatherPlanSettings(SmartHeatingConfig c, HeatLoad l) =>
    HeatingPlanSettings(enabled: true, preset: l.info.planPreset, upper: c.site.swing / 2, lower: c.site.swing / 2);

// ------------------------------------------------------------------ notices

/// One smart-heating notice (also shown later in the general 'Ilmoitukset ja muistutukset').
class HeatingNotice {
  HeatingNotice({
    required this.at,
    required this.kind,
    this.loadId,
    required this.fi,
    required this.en,
    this.priority = 3,
  });
  final DateTime at;

  /// fireplace_on | fireplace_off | holiday_on | holiday_off | min_temp | frost | max_off |
  /// sensor_lost | noprice | error
  final String kind;
  final String? loadId;
  final String fi;
  final String en;
  final int priority;
  String get source => 'heating';

  Map<String, dynamic> toJson() => {
    'at': at.millisecondsSinceEpoch,
    'kind': kind,
    'source': source,
    'loadId': ?loadId,
    'fi': fi,
    'en': en,
    'priority': priority,
  };

  factory HeatingNotice.fromJson(Map<String, dynamic> j) => HeatingNotice(
    at: DateTime.fromMillisecondsSinceEpoch((j['at'] as num).toInt()),
    kind: '${j['kind']}',
    loadId: j['loadId'] as String?,
    fi: '${j['fi'] ?? ''}',
    en: '${j['en'] ?? ''}',
    priority: (j['priority'] as num?)?.toInt() ?? 3,
  );
}

// ------------------------------------------------------------------ bridge job

/// What the bridge needs: the config plus resolved commands (connections with secrets – the
/// package is end-to-end encrypted to the bridge and stored only there).
class SmartHeatingJob {
  SmartHeatingJob(
    this.config, {
    this.on = const {},
    this.off = const {},
    this.sensors = const {},
    this.fireSensor,
    this.names = const {},
    this.zone,
    this.contract,
    this.home,
    this.lang = 'fi',
  });
  final SmartHeatingConfig config;
  final Map<String, ThermoCommand> on;
  final Map<String, ThermoCommand> off;

  /// loadId -> room temperature read.
  final Map<String, ThermoCommand> sensors;
  final ThermoCommand? fireSensor;

  /// loadId -> display name (tile title when the load has none).
  final Map<String, String> names;
  final String? zone;
  final ElectricityContract? contract;
  final HomeLocation? home;
  final String lang;

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'on': {for (final e in on.entries) e.key: e.value.toJson()},
    'off': {for (final e in off.entries) e.key: e.value.toJson()},
    'sensors': {for (final e in sensors.entries) e.key: e.value.toJson()},
    if (fireSensor != null) 'fireSensor': fireSensor!.toJson(),
    'names': names,
    'zone': ?zone,
    if (contract != null) 'contract': contract!.toJson(),
    if (home != null) 'home': home!.toJson(),
    'lang': lang,
  };

  factory SmartHeatingJob.fromJson(Map<String, dynamic> j) {
    Map<String, ThermoCommand> cmds(Object? m) => {
      for (final e in (m as Map? ?? const {}).entries)
        if (ThermoCommand.fromJson(e.value) != null) '${e.key}': ThermoCommand.fromJson(e.value)!,
    };
    return SmartHeatingJob(
      SmartHeatingConfig.fromJson(j['config']),
      on: cmds(j['on']),
      off: cmds(j['off']),
      sensors: cmds(j['sensors']),
      fireSensor: ThermoCommand.fromJson(j['fireSensor']),
      names: {for (final e in (j['names'] as Map? ?? const {}).entries) '${e.key}': '${e.value}'},
      zone: j['zone'] as String?,
      contract: j['contract'] is Map
          ? ElectricityContract.fromJson(Map<String, dynamic>.from(j['contract'] as Map))
          : null,
      home: HomeLocation.fromJson(j['home']),
      lang: '${j['lang'] ?? 'fi'}',
    );
  }

  /// From the app configuration (null when smart heating is not set up).
  static SmartHeatingJob? fromConfig(AppConfig c) {
    final sh = c.energy.smartHeating;
    if (sh == null) return null;
    final tiles = {
      for (final d in c.dashboards)
        for (final t in d.tiles) t.id: t,
    };
    final conns = {for (final x in c.connections) x.id: x};
    ThermoCommand? cmd(CommandStep? s) {
      final conn = s == null ? null : conns[s.connectionId];
      return conn == null ? null : ThermoCommand(conn.toJson(includeSecrets: true), s!.spec);
    }

    ThermoCommand? read(String? tileId) {
      final t = tiles[tileId];
      final conn = t == null ? null : conns[t.connectionId];
      return conn == null ? null : ThermoCommand(conn.toJson(includeSecrets: true), t!.read);
    }

    final names = <String, String>{};
    for (final l in sh.loads) {
      names[l.id] = l.name.isNotEmpty
          ? l.name
          : (l.control == 'thermostat'
                ? (c.energy.thermostats.where((t) => t.id == l.thermostatId).firstOrNull?.name ?? '')
                : (tiles[l.tileId]?.title ?? ''));
    }
    final fs = sh.fireplaceSensorTileId ?? sh.loads.map((l) => l.sensorTileId).whereType<String>().firstOrNull;
    return SmartHeatingJob(
      sh,
      on: {
        for (final l in sh.loads)
          if (l.control == 'switch' && cmd(tiles[l.tileId]?.onCommand) != null) l.id: cmd(tiles[l.tileId]?.onCommand)!,
      },
      off: {
        for (final l in sh.loads)
          if (l.control == 'switch' && cmd(tiles[l.tileId]?.offCommand) != null)
            l.id: cmd(tiles[l.tileId]?.offCommand)!,
      },
      sensors: {
        for (final l in sh.loads)
          if (read(l.sensorTileId) != null) l.id: read(l.sensorTileId)!,
      },
      fireSensor: read(fs),
      names: names,
      zone: energyZoneOf(c),
      contract: c.energy.contract,
      home: c.energy.home,
      lang: c.language,
    );
  }
}

// ------------------------------------------------------------------ fireplace state (bridge)

class FireplaceState {
  FireplaceState({this.since, this.until, this.untilCool = true, this.peak});
  DateTime? since;
  DateTime? until;
  bool untilCool;
  double? peak;

  bool activeAt(DateTime t) => since != null && until != null && t.isBefore(until!);

  Map<String, dynamic> toJson() => {
    if (since != null) 'since': since!.millisecondsSinceEpoch,
    if (until != null) 'until': until!.millisecondsSinceEpoch,
    'untilCool': untilCool,
    'peak': ?peak,
  };

  factory FireplaceState.fromJson(Object? j) {
    if (j is! Map) return FireplaceState();
    DateTime? t(Object? v) => v is num ? DateTime.fromMillisecondsSinceEpoch(v.toInt()) : null;
    return FireplaceState(
      since: t(j['since']),
      until: t(j['until']),
      untilCool: j['untilCool'] != false,
      peak: (j['peak'] as num?)?.toDouble(),
    );
  }
}

// ------------------------------------------------------------------ runner (bridge)

class LoadStatus {
  bool? on;
  double? target;
  String reason = '';
  bool safety = false;
  double? temp;
  String? error;
  DateTime? at;
  DateTime? offSince;
  DateTime? forcedUntil;

  /// Upcoming ON periods (switch loads), for the app.
  List<(DateTime, DateTime)> plan = [];

  Map<String, dynamic> toJson() => {
    'on': ?on,
    'target': ?target,
    'reason': reason,
    if (safety) 'safety': true,
    'temp': ?temp,
    'error': ?error,
    if (at != null) 'at': at!.millisecondsSinceEpoch,
    'plan': [
      for (final p in plan) [p.$1.millisecondsSinceEpoch, p.$2.millisecondsSinceEpoch],
    ],
  };
}

typedef HeatRead = Future<Object?> Function(Map<String, dynamic> conn, Map<String, dynamic> spec);
typedef HeatSend = Future<void> Function(Map<String, dynamic> conn, Map<String, dynamic> spec, Object? value);
typedef HeatNotify = Future<void> Function(String title, String body, int priority);

class SmartHeatingRunner {
  SmartHeatingRunner({
    required this.read,
    required this.send,
    this.notify,
    PriceService? prices,
    WeatherService? weather,
    this.every = const Duration(minutes: 1),
    DateTime Function()? clock,
    this.log,
    this.saveState,
    this.thermoTemp,
  }) : prices = prices ?? PriceService.shared,
       weather = weather ?? WeatherService.shared,
       clock = clock ?? DateTime.now;
  final HeatRead read;
  final HeatSend send;
  final HeatNotify? notify;
  final PriceService prices;
  final WeatherService weather;
  final Duration every;
  final DateTime Function() clock;
  final void Function(String)? log;

  /// Persists the fireplace state and the notices (bridge store).
  final void Function(Map<String, dynamic> state)? saveState;

  /// Current temperature of a Molaplan thermostat (from the thermostat runner).
  final double? Function(String thermostatId)? thermoTemp;

  SmartHeatingJob? job;
  FireplaceState fireplace = FireplaceState();
  final notices = <HeatingNotice>[];
  final loads = <String, LoadStatus>{};
  final _plans = <String, List<PlanHour>>{};
  final _planAt = <String, DateTime>{};
  final _planSp = <String, double>{};
  final _lastNotice = <String, DateTime>{};
  bool? _holidayWas;
  PriceSeries? _series;
  Forecast? _forecast;
  Timer? _timer;
  bool _running = false;
  static const sensorTimeout = Duration(minutes: 10);
  final _lastTemp = <String, (double, DateTime)>{};

  /// Cooling seen by the fireplace sensor that ends fireplace mode (°C below the peak).
  static const coolDrop = 1.0;
  static const minFireplace = Duration(hours: 2);

  void loadState(Map<String, dynamic>? s) {
    if (s == null) return;
    fireplace = FireplaceState.fromJson(s['fireplace']);
    notices
      ..clear()
      ..addAll([
        for (final n in (s['notices'] as List? ?? const []))
          if (n is Map) HeatingNotice.fromJson(Map<String, dynamic>.from(n)),
      ]);
  }

  Map<String, dynamic> stateJson() => {
    'fireplace': fireplace.toJson(),
    'notices': [for (final n in notices.take(100)) n.toJson()],
  };

  void update(SmartHeatingJob? j) {
    job = j;
    loads.removeWhere((id, _) => j == null || !j.config.loads.any((l) => l.id == id));
    _planAt.clear();
    unawaited(tick());
  }

  void start() {
    _timer ??= Timer.periodic(every, (_) => tick());
    unawaited(tick());
  }

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }

  bool get _active => job != null && job!.config.enabled;

  double? cost(DateTime h) {
    final p = _series?.hourly().at(h);
    if (p == null) return null;
    return job?.contract?.unitAt(h, spotEurMwh: p.eurMwh)?.inc ?? p.eurMwh / 10;
  }

  double? outdoor(DateTime h) => _forecast?.at(h);

  String _t(String fi, String en) => job?.lang == 'fi' || job == null ? fi : en;

  void _notice(
    String kind,
    String fi,
    String en, {
    String? loadId,
    int priority = 3,
    Duration every = const Duration(hours: 6),
  }) {
    final key = '$kind:${loadId ?? ''}';
    final now = clock();
    final last = _lastNotice[key];
    if (last != null && now.difference(last) < every) return;
    _lastNotice[key] = now;
    final n = HeatingNotice(at: now, kind: kind, loadId: loadId, fi: fi, en: en, priority: priority);
    notices.insert(0, n);
    if (notices.length > 100) notices.removeRange(100, notices.length);
    log?.call('smart heating: $kind ${loadId ?? ''}');
    if (job?.config.notify == true && notify != null) {
      unawaited(notify!(_t('Älykäs lämmitys', 'Smart heating'), _t(fi, en), priority).catchError((Object _) {}));
    }
    saveState?.call(stateJson());
  }

  String _name(String loadId) => job?.names[loadId]?.isNotEmpty == true ? job!.names[loadId]! : loadId;

  // ---- fireplace
  void startFireplace({int? hours, bool? untilCool}) {
    final now = clock();
    final h = (hours ?? job?.config.fireplaceHours ?? 18).clamp(12, 24);
    fireplace = FireplaceState(
      since: now,
      until: now.add(Duration(hours: h)),
      untilCool: untilCool ?? job?.config.fireplaceUntilCool ?? true,
    );
    _notice(
      'fireplace_on',
      'Takka-tila päällä $h h: sähkölämmitystä vähennetään.',
      'Fireplace mode on for $h h: electric heating is reduced.',
      every: Duration.zero,
    );
    unawaited(tick());
  }

  void stopFireplace({String why = 'stopped'}) {
    if (fireplace.since == null) return;
    fireplace = FireplaceState();
    final (fi, en) = switch (why) {
      'cooled' => (
        'Takka-tila päättyi: huone on alkanut jäähtyä. Lämmitys palaa normaaliksi.',
        'Fireplace mode ended: the room is cooling. Heating is back to normal.',
      ),
      'time' => (
        'Takka-tila päättyi (aika täynnä). Lämmitys palaa normaaliksi.',
        'Fireplace mode ended (time is up). Heating is back to normal.',
      ),
      _ => (
        'Takka-tila lopetettiin. Lämmitys palaa normaaliksi.',
        'Fireplace mode stopped. Heating is back to normal.',
      ),
    };
    _notice('fireplace_off', fi, en, every: Duration.zero);
    unawaited(tick());
  }

  Future<double?> _readTemp(String key, ThermoCommand? c, DateTime now) async {
    if (c != null) {
      try {
        final v = _num(await read(c.conn, c.spec));
        if (v != null) _lastTemp[key] = (v, now);
      } catch (_) {}
    }
    final l = _lastTemp[key];
    return l != null && now.difference(l.$2) < sensorTimeout ? l.$1 : null;
  }

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is Map && v['value'] is num) return (v['value'] as num).toDouble();
    return double.tryParse('${v ?? ''}'.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  /// Thermostat hook: the target smart heating wants for [c] now (null = leave it alone).
  double? thermostatTarget(ThermostatConfig c, DateTime now, double base, double? temp) {
    if (!_active || c.mode == 'off' || c.mode == 'cool' || !c.enabled) return null;
    final l = job!.config.loads
        .where((x) => x.enabled && x.control == 'thermostat' && x.thermostatId == c.id)
        .firstOrNull;
    if (l == null) return null;
    // Weather plan from the thermostat's own setpoint (rebuilt every 15 min or when it changes).
    final pa = _planAt[l.id];
    if (pa == null || now.difference(pa) >= const Duration(minutes: 15) || _planSp[l.id] != c.setpoint) {
      _plans[l.id] = planHeating(
        now: now,
        comfort: c.setpoint,
        settings: weatherPlanSettings(job!.config, l),
        price: cost,
        outdoor: outdoor,
      );
      _planAt[l.id] = now;
      _planSp[l.id] = c.setpoint;
    }
    final d = decideThermostat(job!.config, l, _inputs(now, temp), c.setpoint, plan: _plans[l.id] ?? const []);
    final st = loads.putIfAbsent(l.id, LoadStatus.new)
      ..target = d.target
      ..reason = d.reason
      ..safety = d.safety
      ..temp = temp
      ..at = now;
    if (d.safety) {
      _notice(
        'min_temp',
        '${_name(l.id)}: lämpötila alle turvarajan – tavoite nostettu ${d.target!.toStringAsFixed(1)} °C:een.',
        '${_name(l.id)}: temperature below the safety limit – target raised to ${d.target!.toStringAsFixed(1)} °C.',
        loadId: l.id,
        priority: 4,
      );
    }
    st.safety = d.safety;
    return d.target;
  }

  HeatInputs _inputs(DateTime now, double? temp) {
    final c = job!.config;
    return HeatInputs(
      now: now,
      cost: cost,
      outdoor: outdoor,
      temp: temp,
      holiday: c.holiday.activeAt(now),
      holidayEnd: c.holiday.to,
      fireplace: fireplace.activeAt(now),
    );
  }

  /// One evaluation. A call while one runs waits for it and then evaluates again (so the caller
  /// sees a run that started after its own changes).
  Future<void> tick() async {
    while (_current != null) {
      await _current;
    }
    final f = _current = _tick();
    try {
      await f;
    } finally {
      if (identical(_current, f)) _current = null;
    }
  }

  Future<void>? _current;

  Future<void> _tick() async {
    if (_running) return;
    _running = true;
    try {
      if (!_active) return;
      final j = job!;
      final c = j.config;
      final now = clock();
      try {
        if (j.zone != null) _series = await prices.get(j.zone!);
      } catch (_) {}
      try {
        if (j.home != null) _forecast = await weather.forecast(j.home!);
      } catch (_) {}
      if (_series == null || dayCosts(now, cost) == null) {
        _notice(
          'noprice',
          'Sähkön hintoja ei saatu: lämmitys toimii tavallisesti, kunnes hinnat tulevat.',
          'No electricity prices: heating runs normally until prices are available.',
          every: const Duration(hours: 12),
        );
      }
      // Fireplace mode: time or cooling ends it.
      if (fireplace.since != null) {
        if (!fireplace.activeAt(now)) {
          stopFireplace(why: 'time');
        } else if (fireplace.untilCool) {
          final t = await _readTemp('_fire', j.fireSensor, now);
          if (t != null) {
            fireplace.peak = math.max(fireplace.peak ?? t, t);
            if (now.difference(fireplace.since!) >= minFireplace && t <= fireplace.peak! - coolDrop) {
              stopFireplace(why: 'cooled');
            }
          }
        }
      }
      // Holiday transitions.
      final hol = c.holiday.activeAt(now);
      if (_holidayWas != null && hol != _holidayWas) {
        hol
            ? _notice(
                'holiday_on',
                'Lomatila alkoi: lämpö pidetään ${c.holiday.temp.toStringAsFixed(0)} °C:ssa.',
                'Holiday mode started: rooms kept at ${c.holiday.temp.toStringAsFixed(0)} °C.',
                every: Duration.zero,
              )
            : _notice(
                'holiday_off',
                'Lomatila päättyi: lämmitys palaa normaaliksi.',
                'Holiday mode ended: heating is back to normal.',
                every: Duration.zero,
              );
      }
      _holidayWas = hol;
      for (final l in c.loads) {
        if (!l.enabled || l.control != 'switch') continue;
        final st = loads.putIfAbsent(l.id, LoadStatus.new);
        final hasSensor = j.sensors.containsKey(l.id);
        final temp = await _readTemp(l.id, j.sensors[l.id], now);
        if (hasSensor && temp == null && l.info.space) {
          _notice(
            'sensor_lost',
            '${_name(l.id)}: lämpöanturi ei vastaa – turvarajat eivät ole käytössä.',
            '${_name(l.id)}: the temperature sensor is not answering – safety limits are not active.',
            loadId: l.id,
            priority: 4,
            every: const Duration(hours: 12),
          );
        }
        final x = _inputs(now, temp);
        var d = decideSwitch(c, l, x);
        // Max-off guard: never off longer than allowed (not in fireplace mode – the fire heats).
        final maxOff = l.maxOffHours ?? c.safety.maxOffHours ?? recommend(l.type, c.site, control: l.control).maxOff;
        if (st.forcedUntil != null && now.isBefore(st.forcedUntil!) && d.on == false && d.reason != 'warm') {
          d = HeatDecision(on: true, reason: 'max_off', safety: true);
        } else if (d.on == false &&
            !x.fireplace &&
            d.reason != 'warm' &&
            !(x.holiday && !l.info.space) &&
            st.offSince != null &&
            now.difference(st.offSince!) >= Duration(minutes: (maxOff * 60).round())) {
          st.forcedUntil = now.add(const Duration(hours: 1));
          d = HeatDecision(on: true, reason: 'max_off', safety: true);
          _notice(
            'max_off',
            '${_name(l.id)}: ollut pois ${maxOff.toStringAsFixed(maxOff % 1 == 0 ? 0 : 1)} h – lämmitetään tunti.',
            '${_name(l.id)}: off for ${maxOff.toStringAsFixed(maxOff % 1 == 0 ? 0 : 1)} h – heating for an hour.',
            loadId: l.id,
            priority: 2,
            every: const Duration(hours: 12),
          );
        }
        if (d.reason == 'frost' || d.reason == 'min_temp') {
          _notice(
            d.reason,
            d.reason == 'frost'
                ? '${_name(l.id)}: jäätymisvaara (${temp!.toStringAsFixed(1)} °C) – lämmitys päällä.'
                : '${_name(l.id)}: lämpötila ${temp!.toStringAsFixed(1)} °C on alle turvarajan – lämmitys päällä.',
            d.reason == 'frost'
                ? '${_name(l.id)}: frost risk (${temp.toStringAsFixed(1)} °C) – heating on.'
                : '${_name(l.id)}: ${temp.toStringAsFixed(1)} °C is below the safety limit – heating on.',
            loadId: l.id,
            priority: d.reason == 'frost' ? 5 : 4,
          );
        }
        st
          ..temp = temp
          ..reason = d.reason
          ..safety = d.safety
          ..at = now
          ..plan = _planFor(c, l, now);
        final want = d.on!;
        if (want != st.on) {
          final cmd = want ? j.on[l.id] : j.off[l.id];
          if (cmd == null) {
            st.error = 'no command';
            continue;
          }
          try {
            await send(cmd.conn, cmd.spec, want ? 1 : 0);
            st
              ..on = want
              ..error = null;
            log?.call('smart heating "${_name(l.id)}": ${want ? 'ON' : 'OFF'} (${d.reason})');
          } catch (e) {
            st.error = '$e';
            continue;
          }
        }
        if (want) {
          st.offSince = null;
        } else {
          st.offSince ??= now;
        }
      }
    } finally {
      _running = false;
    }
  }

  /// Upcoming ON periods of a switch load for the next 36 h (no sensor, no runtime guards).
  List<(DateTime, DateTime)> _planFor(SmartHeatingConfig c, HeatLoad l, DateTime now) {
    final out = <(DateTime, DateTime)>[];
    DateTime? start;
    final t = hourOf(now);
    var last = t;
    for (var i = 0; i < 36; i++) {
      final h = DateTime(t.year, t.month, t.day, t.hour + i);
      final x = HeatInputs(
        now: h,
        cost: cost,
        outdoor: outdoor,
        holiday: c.holiday.activeAt(h),
        holidayEnd: c.holiday.to,
        fireplace: fireplace.activeAt(h),
      );
      final d = decideSwitch(c, l, x);
      if (d.reason == 'noprice') break;
      last = DateTime(h.year, h.month, h.day, h.hour + 1);
      final on = d.on == true;
      if (on && start == null) start = h;
      if (!on && start != null) {
        out.add((start, h));
        start = null;
      }
    }
    if (start != null) out.add((start, last));
    return out;
  }

  Map<String, dynamic> statusJson() {
    final now = clock();
    final c = job?.config;
    return {
      'enabled': _active,
      'mode': !_active
          ? 'off'
          : fireplace.activeAt(now)
          ? 'fireplace'
          : (c!.holiday.activeAt(now) ? 'holiday' : 'normal'),
      'fireplace': fireplace.toJson(),
      'loads': {for (final e in loads.entries) e.key: e.value.toJson()},
      'notices': [for (final n in notices.take(30)) n.toJson()],
    };
  }
}
