/// R289: common model for EV chargers. Every brand backend (Easee, Zaptec, Wallbox clouds and the
/// local OCPP 1.6J server) maps to the same state, so tiles and automations are brand-independent.
library;

import '../drivers/driver.dart';

/// Normalised charger status.
enum EvStatus { disconnected, connected, charging, paused, finished, error, offline }

const evStatusText = <EvStatus, (String, String)>{
  EvStatus.disconnected: ('Ei autoa', 'No car'),
  EvStatus.connected: ('Auto kytketty', 'Car connected'),
  EvStatus.charging: ('Lataa', 'Charging'),
  EvStatus.paused: ('Tauolla', 'Paused'),
  EvStatus.finished: ('Valmis', 'Finished'),
  EvStatus.error: ('Vika', 'Error'),
  EvStatus.offline: ('Ei yhteyttä', 'Offline'),
};

class EvCharger {
  const EvCharger({required this.id, required this.name, this.model = '', this.meta = const {}});
  final String id, name, model;

  /// Brand specific extras (Zaptec installation id…).
  final Map<String, dynamic> meta;

  Map<String, dynamic> toJson() => {'id': id, 'name': name, 'model': model, 'meta': meta};
  factory EvCharger.fromJson(Map j) => EvCharger(
    id: '${j['id']}',
    name: '${j['name'] ?? j['id']}',
    model: '${j['model'] ?? ''}',
    meta: Map<String, dynamic>.from((j['meta'] as Map?) ?? const {}),
  );
}

class EvState {
  EvState({
    this.status = EvStatus.offline,
    this.power,
    this.session,
    this.total,
    this.current,
    this.minCurrent = 6,
    this.maxCurrent = 32,
  });
  EvStatus status;

  /// W, kWh, kWh, A (current limit set now).
  num? power, session, total, current;
  num minCurrent, maxCurrent;

  bool get charging => status == EvStatus.charging;

  Object? value(String key) => switch (key) {
    'status' => dtx(evStatusText[status]!.$1, evStatusText[status]!.$2),
    'state' => status.name,
    'charging' => charging ? 1 : 0,
    'connected' => status == EvStatus.disconnected || status == EvStatus.offline ? 0 : 1,
    'power' => power ?? (charging ? null : 0),
    'session' => session,
    'total' => total,
    'current' => current,
    _ => throw DriverException('EV: unknown reading "$key"'),
  };

  Map<String, dynamic> toJson() => {
    'status': status.name,
    'power': power,
    'session': session,
    'total': total,
    'current': current,
    'min': minCurrent,
    'max': maxCurrent,
  };
  factory EvState.fromJson(Map j) => EvState(
    status: EvStatus.values.where((e) => e.name == j['status']).firstOrNull ?? EvStatus.offline,
    power: j['power'] as num?,
    session: j['session'] as num?,
    total: j['total'] as num?,
    current: j['current'] as num?,
    minCurrent: (j['min'] as num?) ?? 6,
    maxCurrent: (j['max'] as num?) ?? 32,
  );
}

class EvAuthError extends DriverException {
  EvAuthError(super.message);
}

abstract class EvBackend {
  EvBackend(this.s);
  final Map<String, dynamic> s;
  Future<List<EvCharger>> chargers();
  Future<EvState> state(EvCharger c);
  Future<void> start(EvCharger c);
  Future<void> stop(EvCharger c);
  Future<void> setCurrent(EvCharger c, num amps);
  Future<void> close() async {}
}

num? evNum(Object? v) => v is num ? v : num.tryParse('${v ?? ''}');
