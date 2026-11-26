/// Virtual thermostat: heat/cool sources (relays with hysteresis and minimum on/off times, or
/// climate devices controlled by setpoint + mode), one or more temperature sources, heat / cool /
/// heat+cool modes with a deadband, a safety fallback when the sensor is lost, and an optional
/// predictive heating plan (price + weather). Runs on the home bridge ([ThermostatRunner]).
library;

import 'dart:async';

import '../models/models.dart';
import '../prices/prices.dart';
import 'contract.dart';
import 'heating_plan.dart';
import 'weather.dart';

/// One heat/cool source.
class ThermoSource {
  ThermoSource({
    String? id,
    required this.kind,
    required this.tileId,
    this.role = 'heat',
    this.backup = false,
    this.powerTileId,
    this.heatTileId,
    this.coolTileId,
  }) : id = id ?? newId();
  String id;

  /// 'switch' (relay/plug toggle tile) or 'climate' (setpoint slider tile of a heat pump / AC).
  String kind;

  /// Toggle tile (switch) or setpoint slider tile (climate).
  String tileId;

  /// 'heat' | 'cool' | 'both' (climate only)
  String role;

  /// Backup heater: only when the main source is not enough (temperature well below target).
  bool backup;

  /// Climate: optional power toggle and heat / cool mode button tiles of the same device.
  String? powerTileId;
  String? heatTileId;
  String? coolTileId;

  Map<String, dynamic> toJson() => {
    'id': id,
    'kind': kind,
    'tileId': tileId,
    'role': role,
    if (backup) 'backup': true,
    'powerTileId': ?powerTileId,
    'heatTileId': ?heatTileId,
    'coolTileId': ?coolTileId,
  };
  factory ThermoSource.fromJson(Map<String, dynamic> j) => ThermoSource(
    id: j['id'] as String?,
    kind: j['kind'] == 'climate' ? 'climate' : 'switch',
    tileId: '${j['tileId'] ?? ''}',
    role: '${j['role'] ?? 'heat'}',
    backup: j['backup'] == true,
    powerTileId: j['powerTileId'] as String?,
    heatTileId: j['heatTileId'] as String?,
    coolTileId: j['coolTileId'] as String?,
  );
}

class ThermostatConfig {
  ThermostatConfig({
    String? id,
    this.name = '',
    this.mode = 'heat',
    this.setpoint = 21,
    this.hysteresis = 0.5,
    this.deadband = 2,
    this.minOnMinutes = 5,
    this.minOffMinutes = 5,
    this.backupDelta = 1.5,
    List<ThermoSource>? sources,
    List<String>? sensors,
    this.combine = 'first',
    this.onSensorLost = 'off',
    this.sensorTimeoutMinutes = 10,
    HeatingPlanSettings? plan,
    this.enabled = true,
  }) : id = id ?? newId(),
       sources = sources ?? [],
       sensors = sensors ?? [],
       plan = plan ?? HeatingPlanSettings();
  String id;
  String name;

  /// 'heat' | 'cool' | 'auto' (heat+cool with a deadband) | 'off'
  String mode;
  double setpoint;
  double hysteresis;

  /// Heat+cool: heat below setpoint − deadband/2, cool above setpoint + deadband/2.
  double deadband;
  int minOnMinutes;
  int minOffMinutes;

  /// Backup heaters switch on below target − backupDelta.
  double backupDelta;
  List<ThermoSource> sources;

  /// Temperature value tiles, in fallback order.
  List<String> sensors;

  /// 'first' (first working sensor) | 'avg' (average of working sensors)
  String combine;

  /// 'off' (everything off) | 'keep' (keep the current state)
  String onSensorLost;
  int sensorTimeoutMinutes;
  HeatingPlanSettings plan;
  bool enabled;

  /// Climate-only thermostats can work without a separate sensor (the device regulates itself).
  bool get needsSensor => sources.any((s) => s.kind == 'switch');

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    'mode': mode,
    'setpoint': setpoint,
    'hysteresis': hysteresis,
    'deadband': deadband,
    'minOn': minOnMinutes,
    'minOff': minOffMinutes,
    'backupDelta': backupDelta,
    'sources': [for (final s in sources) s.toJson()],
    'sensors': sensors,
    'combine': combine,
    'onSensorLost': onSensorLost,
    'sensorTimeout': sensorTimeoutMinutes,
    'plan': plan.toJson(),
    'enabled': enabled,
  };

  factory ThermostatConfig.fromJson(Map<String, dynamic> j) => ThermostatConfig(
    id: j['id'] as String?,
    name: '${j['name'] ?? ''}',
    mode: '${j['mode'] ?? 'heat'}',
    setpoint: (j['setpoint'] as num?)?.toDouble() ?? 21,
    hysteresis: (j['hysteresis'] as num?)?.toDouble() ?? 0.5,
    deadband: (j['deadband'] as num?)?.toDouble() ?? 2,
    minOnMinutes: (j['minOn'] as num?)?.toInt() ?? 5,
    minOffMinutes: (j['minOff'] as num?)?.toInt() ?? 5,
    backupDelta: (j['backupDelta'] as num?)?.toDouble() ?? 1.5,
    sources: [
      for (final s in (j['sources'] as List? ?? const []))
        if (s is Map) ThermoSource.fromJson(Map<String, dynamic>.from(s)),
    ],
    sensors: [for (final s in (j['sensors'] as List? ?? const [])) '$s'],
    combine: j['combine'] == 'avg' ? 'avg' : 'first',
    onSensorLost: j['onSensorLost'] == 'keep' ? 'keep' : 'off',
    sensorTimeoutMinutes: (j['sensorTimeout'] as num?)?.toInt() ?? 10,
    plan: HeatingPlanSettings.fromJson(j['plan']),
    enabled: j['enabled'] != false,
  );
}

/// What the controller wants a source to do.
class ThermoAction {
  ThermoAction(this.sourceId, this.what, [this.value]);
  final String sourceId;

  /// 'on' | 'off' (switch, or climate power), 'setpoint' (value °C), 'mode' (value 'heat'/'cool')
  final String what;
  final Object? value;
  @override
  String toString() => '$sourceId:$what${value == null ? '' : '=$value'}';
}

/// Per-source memory of the controller.
class SourceState {
  bool? on;
  DateTime? changed;
  double? setpoint;
  String? mode;
  DateTime? sent;
  Map<String, dynamic> toJson() => {
    'on': ?on,
    if (changed != null) 'changed': changed!.millisecondsSinceEpoch,
    'sp': ?setpoint,
    'mode': ?mode,
  };
}

/// Pure control logic (no I/O) – unit-tested.
class ThermostatController {
  ThermostatController(this.config);
  ThermostatConfig config;
  final states = <String, SourceState>{};

  /// Climate devices are told again every hour (IR is one-way; a missed command is repaired).
  static const resend = Duration(hours: 1);

  /// One control step. [temp] is the combined sensor temperature (null = no sensor / lost),
  /// [target] the effective setpoint (user setpoint or the heating plan for this hour).
  List<ThermoAction> step(DateTime now, double? temp, double target) {
    final c = config;
    final out = <ThermoAction>[];
    final lost = temp == null && c.needsSensor;
    for (final s in c.sources) {
      final st = states.putIfAbsent(s.id, SourceState.new);
      if (c.mode == 'off' || !c.enabled || (lost && c.onSensorLost == 'off')) {
        if (s.kind == 'switch') {
          if (st.on != false) _switch(out, s, st, false, now, force: true);
        } else if (st.on != false) {
          out.add(ThermoAction(s.id, 'off'));
          st
            ..on = false
            ..changed = now
            ..sent = now;
        }
        continue;
      }
      if (lost) continue; // keep the current state
      if (s.kind == 'switch') {
        final heat = s.role != 'cool';
        final mode = c.mode;
        if ((heat && mode == 'cool') || (!heat && mode == 'heat')) {
          if (st.on != false) _switch(out, s, st, false, now);
          continue;
        }
        var t = target;
        if (mode == 'auto') t = heat ? target - c.deadband / 2 : target + c.deadband / 2;
        if (s.backup && heat) t = t - c.backupDelta;
        final h = c.hysteresis / 2;
        final want = heat
            ? (temp! <= t - h ? true : (temp >= t + h ? false : st.on ?? false))
            : (temp! >= t + h ? true : (temp <= t - h ? false : st.on ?? false));
        if (want != st.on) _switch(out, s, st, want, now);
      } else {
        // Climate device: mode + setpoint; it regulates itself.
        String? mode;
        if (c.mode == 'heat' && s.role != 'cool') mode = 'heat';
        if (c.mode == 'cool' && s.role != 'heat') mode = 'cool';
        if (c.mode == 'auto') {
          if (s.role == 'heat') {
            mode = 'heat';
          } else if (s.role == 'cool') {
            mode = 'cool';
          } else if (temp == null) {
            mode = st.mode ?? 'heat';
          } else if (temp < target - c.deadband / 2) {
            mode = 'heat';
          } else if (temp > target + c.deadband / 2) {
            mode = 'cool';
          } else {
            mode = st.mode ?? 'heat';
          }
        }
        if (mode == null) {
          if (st.on != false) {
            out.add(ThermoAction(s.id, 'off'));
            st
              ..on = false
              ..changed = now;
          }
          continue;
        }
        final due = st.sent == null || now.difference(st.sent!) >= resend;
        if (st.on != true || due) {
          out.add(ThermoAction(s.id, 'on'));
          st.on = true;
        }
        if (st.mode != mode || due) out.add(ThermoAction(s.id, 'mode', mode));
        if (st.setpoint != target || due) out.add(ThermoAction(s.id, 'setpoint', target));
        if (st.mode != mode || st.setpoint != target || due) st.sent = now;
        st
          ..mode = mode
          ..setpoint = target;
      }
    }
    return out;
  }

  void _switch(List<ThermoAction> out, ThermoSource s, SourceState st, bool on, DateTime now, {bool force = false}) {
    // Protect compressors / relays: respect the minimum on and off times.
    if (!force && st.changed != null && st.on != null) {
      final min = Duration(minutes: st.on! ? config.minOnMinutes : config.minOffMinutes);
      if (now.difference(st.changed!) < min) return;
    }
    out.add(ThermoAction(s.id, on ? 'on' : 'off'));
    st
      ..on = on
      ..changed = now;
  }
}

/// Combines sensor readings: first working one, or the average. Readings older than the timeout count as lost.
double? combineTemps(List<(double?, DateTime?)> readings, String combine, DateTime now, Duration timeout) {
  final ok = [
    for (final r in readings)
      if (r.$1 != null && r.$2 != null && now.difference(r.$2!) <= timeout) r.$1!,
  ];
  if (ok.isEmpty) return null;
  return combine == 'avg' ? ok.reduce((a, b) => a + b) / ok.length : ok.first;
}

/// A command the bridge can run: connection json (with secrets) + spec (+ value).
class ThermoCommand {
  ThermoCommand(this.conn, this.spec);
  final Map<String, dynamic> conn;
  final Map<String, dynamic> spec;
  Map<String, dynamic> toJson() => {'conn': conn, 'spec': spec};
  static ThermoCommand? fromJson(Object? j) => j is Map
      ? ThermoCommand(Map<String, dynamic>.from(j['conn'] as Map), Map<String, dynamic>.from(j['spec'] as Map))
      : null;
}

/// Everything a bridge needs for one thermostat (commands resolved from the tiles).
class ThermostatJob {
  ThermostatJob(this.config, {required this.commands, required this.reads, this.zone, this.contract, this.home});
  final ThermostatConfig config;

  /// sourceId -> {'on','off','setpoint','heat','cool'} -> command
  final Map<String, Map<String, ThermoCommand>> commands;

  /// Sensor reads (in config.sensors order).
  final List<ThermoCommand> reads;

  /// Price zone for the heating plan (from the price tile / contract), contract and home location.
  final String? zone;
  final ElectricityContract? contract;
  final HomeLocation? home;

  Map<String, dynamic> toJson() => {
    'config': config.toJson(),
    'commands': {
      for (final e in commands.entries) e.key: {for (final c in e.value.entries) c.key: c.value.toJson()},
    },
    'reads': [for (final r in reads) r.toJson()],
    'zone': ?zone,
    if (contract != null) 'contract': contract!.toJson(),
    if (home != null) 'home': home!.toJson(),
  };

  factory ThermostatJob.fromJson(Map<String, dynamic> j) => ThermostatJob(
    ThermostatConfig.fromJson(Map<String, dynamic>.from(j['config'] as Map)),
    commands: {
      for (final e in (j['commands'] as Map? ?? const {}).entries)
        '${e.key}': {
          for (final c in (e.value as Map).entries)
            if (ThermoCommand.fromJson(c.value) != null) '${c.key}': ThermoCommand.fromJson(c.value)!,
        },
    },
    reads: [
      for (final r in (j['reads'] as List? ?? const []))
        if (ThermoCommand.fromJson(r) != null) ThermoCommand.fromJson(r)!,
    ],
    zone: j['zone'] as String?,
    contract: j['contract'] is Map
        ? ElectricityContract.fromJson(Map<String, dynamic>.from(j['contract'] as Map))
        : null,
    home: HomeLocation.fromJson(j['home']),
  );

  /// Builds the jobs from the app configuration.
  static List<ThermostatJob> fromConfig(AppConfig c) {
    final tiles = {
      for (final d in c.dashboards)
        for (final t in d.tiles) t.id: t,
    };
    final conns = {for (final x in c.connections) x.id: x};
    ThermoCommand? cmd(CommandStep? s) {
      final conn = s == null ? null : conns[s.connectionId];
      return conn == null ? null : ThermoCommand(conn.toJson(includeSecrets: true), s!.spec);
    }

    ThermoCommand? firstCmd(TileConfig? t) => t == null
        ? null
        : cmd(
            t.commands.firstOrNull ??
                (t.connectionId == null ? null : CommandStep(connectionId: t.connectionId!, spec: t.read)),
          );

    final e = c.energy;
    return [
      for (final th in e.thermostats)
        ThermostatJob(
          th,
          zone: energyZoneOf(c),
          contract: e.contract,
          home: e.home,
          commands: {
            for (final s in th.sources)
              s.id: {
                if (s.kind == 'switch') ...{
                  'on': ?cmd(tiles[s.tileId]?.onCommand),
                  'off': ?cmd(tiles[s.tileId]?.offCommand),
                } else ...{
                  'setpoint': ?firstCmd(tiles[s.tileId]),
                  'on': ?cmd(tiles[s.powerTileId]?.onCommand),
                  'off': ?cmd(tiles[s.powerTileId]?.offCommand),
                  'heat': ?firstCmd(tiles[s.heatTileId]),
                  'cool': ?firstCmd(tiles[s.coolTileId]),
                },
              },
          },
          reads: [
            for (final id in th.sensors)
              if (tiles[id] != null && conns[tiles[id]!.connectionId] != null)
                ThermoCommand(conns[tiles[id]!.connectionId]!.toJson(includeSecrets: true), tiles[id]!.read),
          ],
        ),
    ];
  }
}

class ThermostatStatus {
  double? temp;
  double? target;
  bool sensorOk = true;
  String? error;
  DateTime? at;
  List<PlanHour> plan = [];
  Map<String, SourceState> sources = {};

  /// 'heating' | 'cooling' | 'idle' | 'off'
  String state = 'idle';

  Map<String, dynamic> toJson() => {
    'temp': ?temp,
    'target': ?target,
    'sensorOk': sensorOk,
    'error': ?error,
    if (at != null) 'at': at!.millisecondsSinceEpoch,
    'state': state,
    'plan': [for (final p in plan.take(36)) p.toJson()],
    'sources': {for (final e in sources.entries) e.key: e.value.toJson()},
  };
}

typedef ThermoRead = Future<Object?> Function(Map<String, dynamic> conn, Map<String, dynamic> spec);
typedef ThermoSend = Future<void> Function(Map<String, dynamic> conn, Map<String, dynamic> spec, Object? value);

/// Effective target for [now]: the plan's hour (predictive heating) or the user setpoint.
double targetFor(ThermostatConfig c, List<PlanHour> plan, DateTime now) {
  if (!c.plan.enabled || c.mode == 'off') return c.setpoint;
  for (final p in plan) {
    if (!now.isBefore(p.start) && now.isBefore(p.start.add(const Duration(hours: 1)))) return p.target;
  }
  return c.setpoint;
}

/// Builds the plan for a thermostat from cached/fetched prices and weather.
Future<List<PlanHour>> buildPlan(
  ThermostatConfig c,
  DateTime now, {
  required PriceService prices,
  required WeatherService weather,
  String? zone,
  ElectricityContract? contract,
  HomeLocation? home,
}) async {
  PriceSeries? s;
  Forecast? f;
  try {
    if (zone != null) s = await prices.get(zone);
  } catch (_) {}
  try {
    if (home != null) f = await weather.forecast(home);
  } catch (_) {}
  final hourly = s?.hourly();
  return planHeating(
    now: now,
    comfort: c.setpoint,
    settings: c.plan,
    cooling: c.mode == 'cool',
    price: (h) {
      final p = hourly?.at(h);
      if (p == null) return null;
      return contract?.unitAt(h, spotEurMwh: p.eurMwh)?.inc ?? p.eurMwh / 10;
    },
    outdoor: (h) => f?.at(h),
  );
}

/// Runs the thermostats every [every] on the bridge.
class ThermostatRunner {
  ThermostatRunner({
    required this.read,
    required this.send,
    PriceService? prices,
    WeatherService? weather,
    this.every = const Duration(minutes: 1),
    DateTime Function()? clock,
    this.log,
  }) : prices = prices ?? PriceService.shared,
       weather = weather ?? WeatherService.shared,
       clock = clock ?? DateTime.now;
  final ThermoRead read;
  final ThermoSend send;
  final PriceService prices;
  final WeatherService weather;
  final Duration every;
  final DateTime Function() clock;
  final void Function(String)? log;
  List<ThermostatJob> jobs = [];

  /// R194: smart heating's target for a thermostat (null = keep the thermostat's own target).
  double? Function(ThermostatConfig c, DateTime now, double base, double? temp)? adjust;
  final controllers = <String, ThermostatController>{};
  final status = <String, ThermostatStatus>{};
  final _lastReading = <String, List<(double?, DateTime?)>>{};
  final _planAt = <String, DateTime>{};
  Timer? _timer;
  bool _running = false;

  void update(List<ThermostatJob> j) {
    jobs = j;
    for (final job in j) {
      final c = controllers[job.config.id];
      if (c == null) {
        controllers[job.config.id] = ThermostatController(job.config);
      } else {
        c.config = job.config;
      }
      _planAt.remove(job.config.id);
    }
    controllers.removeWhere((id, _) => !j.any((x) => x.config.id == id));
    status.removeWhere((id, _) => !j.any((x) => x.config.id == id));
    unawaited(tick());
  }

  void start() {
    _timer ??= Timer.periodic(every, (_) => tick());
    unawaited(tick());
  }

  static double? _num(Object? v) {
    if (v is num) return v.toDouble();
    if (v is Map && v['value'] is num) return (v['value'] as num).toDouble();
    return double.tryParse('${v ?? ''}'.replaceAll(',', '.').replaceAll(RegExp(r'[^0-9.\-]'), ''));
  }

  Future<void> tick() async {
    if (_running) return;
    _running = true;
    try {
      final now = clock();
      for (final j in jobs) {
        final c = j.config;
        final ctl = controllers.putIfAbsent(c.id, () => ThermostatController(c));
        final st = status.putIfAbsent(c.id, ThermostatStatus.new);
        try {
          // Sensors.
          final last = _lastReading.putIfAbsent(c.id, () => List.filled(j.reads.length, (null, null)));
          if (last.length != j.reads.length) {
            last
              ..clear()
              ..addAll(List.filled(j.reads.length, (null, null)));
          }
          for (var i = 0; i < j.reads.length; i++) {
            try {
              final v = _num(await read(j.reads[i].conn, j.reads[i].spec));
              if (v != null) last[i] = (v, now);
            } catch (_) {}
          }
          final temp = combineTemps(last, c.combine, now, Duration(minutes: c.sensorTimeoutMinutes));
          // Plan (every 15 min).
          final pa = _planAt[c.id];
          if (c.plan.enabled && (pa == null || now.difference(pa) >= const Duration(minutes: 15))) {
            st.plan = await buildPlan(
              c,
              now,
              prices: prices,
              weather: weather,
              zone: j.zone,
              contract: j.contract,
              home: j.home,
            );
            _planAt[c.id] = now;
          }
          if (!c.plan.enabled) st.plan = [];
          final base = targetFor(c, st.plan, now);
          // R194: smart heating may set the target (templates, holiday, fireplace, safety).
          final target = adjust?.call(c, now, base, temp) ?? base;
          final actions = ctl.step(now, temp, target);
          st.error = null;
          for (final a in actions) {
            final cmds = j.commands[a.sourceId] ?? const {};
            final key = switch (a.what) {
              'mode' => '${a.value}',
              _ => a.what,
            };
            final cmd = cmds[key];
            if (cmd == null) continue; // e.g. no separate power or mode tile
            try {
              await send(cmd.conn, cmd.spec, a.what == 'setpoint' ? a.value : (a.what == 'on' ? 1 : 0));
            } catch (e) {
              st.error = '$e';
              // Let the next tick retry.
              final s = ctl.states[a.sourceId];
              if (s != null && a.what != 'setpoint') s.on = null;
              if (s != null && a.what == 'setpoint') s.setpoint = null;
            }
          }
          if (actions.isNotEmpty) log?.call('thermostat "${c.name}": ${actions.join(', ')}');
          st
            ..temp = temp
            ..target = target
            ..sensorOk = temp != null || !c.needsSensor
            ..at = now
            ..sources = ctl.states
            ..state = c.mode == 'off' || !c.enabled
                ? 'off'
                : ctl.states.entries.any((e) => e.value.on == true && _role(c, e.key) != 'cool' && c.mode != 'cool')
                ? 'heating'
                : ctl.states.entries.any((e) => e.value.on == true && (c.mode == 'cool' || _role(c, e.key) == 'cool'))
                ? 'cooling'
                : 'idle';
        } catch (e) {
          st.error = '$e';
        }
      }
    } finally {
      _running = false;
    }
  }

  static String _role(ThermostatConfig c, String sourceId) =>
      c.sources.where((s) => s.id == sourceId).firstOrNull?.role ?? 'heat';

  Map<String, dynamic> statusJson() => {for (final e in status.entries) e.key: e.value.toJson()};

  void dispose() {
    _timer?.cancel();
    _timer = null;
  }
}
