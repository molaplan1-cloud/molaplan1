import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import '../core/fields.dart';
import '../core/template.dart';
import 'driver.dart';

/// Minimal Modbus TCP client (functions 1,2,3,4,5,6,15,16 and 43/14 device identification).
/// [rtu] = Modbus RTU frames (unit + PDU + CRC) over a TCP socket, as cheap RS485 gateways
/// in "transparent" mode use (t154u).
class ModbusTcpClient {
  ModbusTcpClient(
    this.host,
    this.port, {
    this.timeout = const Duration(seconds: 3),
    this.rtu = false,
    this.requestDelay = Duration.zero,
    this.connectDelay = Duration.zero,
    this.closeOnError = true,
    this.retryOnEmpty = false,
  });
  final String host;
  final int port;
  Duration timeout;
  final bool rtu;

  /// t155u (gentle polling, HA "message_wait_milliseconds"): pause between two requests.
  Duration requestDelay;

  /// HA "delay": wait after opening the connection before the first request.
  Duration connectDelay;

  /// HA "close_comm_on_error": drop the TCP connection after a timeout. Off for devices that
  /// allow only one client – reconnecting is what trips their lockout.
  bool closeOnError;

  /// HA "retry_on_empty": an empty answer is asked once more.
  bool retryOnEmpty;

  DateTime _lastDone = DateTime.fromMillisecondsSinceEpoch(0);

  /// Health of this host (shared by every tile on it): lockout/backoff state.
  final health = ModbusHostHealth();

  /// Register cache + batch queue for [ModbusDriver] (shared per host).
  final regCache = <String, (List<int>, DateTime)>{};
  final batch = <_BatchReq>[];
  Timer? batchTimer;

  // ---- one connection per host, shared by all tiles / drivers (t155u)
  static final _pool = <String, ModbusTcpClient>{};
  static final _refs = <String, int>{};

  static ModbusTcpClient acquire(String host, int port, {required bool rtu}) {
    final key = '$host:$port:${rtu ? 'rtu' : 'tcp'}';
    _refs[key] = (_refs[key] ?? 0) + 1;
    return _pool[key] ??= ModbusTcpClient(host, port, rtu: rtu);
  }

  static Future<void> release(ModbusTcpClient c) async {
    final key = '${c.host}:${c.port}:${c.rtu ? 'rtu' : 'tcp'}';
    final n = (_refs[key] ?? 1) - 1;
    if (n > 0) {
      _refs[key] = n;
      return;
    }
    _refs.remove(key);
    if (identical(_pool[key], c)) _pool.remove(key);
    c.batchTimer?.cancel();
    await c.close();
  }

  /// Test hook: forget all pooled clients.
  static void resetPool() {
    for (final c in _pool.values) {
      c.batchTimer?.cancel();
      c._fail('reset');
    }
    _pool.clear();
    _refs.clear();
  }

  Completer<Uint8List>? _rtuPending;

  Socket? _socket;
  StreamSubscription<Uint8List>? _sub;
  final _buf = BytesBuilder();
  int _tid = 0;
  final _pending = <int, Completer<Uint8List>>{};
  Future<void> _queue = Future.value();

  Future<void> _ensure() async {
    if (_socket != null) return;
    final Socket sock;
    try {
      sock = await Socket.connect(host, port, timeout: timeout);
    } catch (e) {
      throw modbusConnectError(e, host, port);
    }
    sock.setOption(SocketOption.tcpNoDelay, true);
    _socket = sock;
    _sub = sock.listen(_onData, onError: (Object e) => _fail(e), onDone: () => _fail('closed'));
    if (connectDelay > Duration.zero) await Future<void>.delayed(connectDelay);
  }

  void _fail(Object e) {
    for (final c in [..._pending.values, ?_rtuPending]) {
      if (!c.isCompleted) c.completeError(DriverException('Modbus: $e'));
    }
    _pending.clear();
    _rtuPending = null;
    _sub?.cancel();
    _socket?.destroy();
    _socket = null;
    _sub = null;
    _buf.clear();
  }

  void _onData(Uint8List data) {
    _buf.add(data);
    if (rtu) {
      // RTU has no length header: the frame is complete when its CRC matches.
      final b = _buf.toBytes();
      if (b.length >= 5 && modbusCrc(b.sublist(0, b.length - 2)) == (b[b.length - 2] | (b[b.length - 1] << 8))) {
        _buf.clear();
        final c = _rtuPending;
        _rtuPending = null;
        if (c != null && !c.isCompleted) c.complete(Uint8List.fromList(b.sublist(0, b.length - 2)));
      } else if (b.length > 300) {
        _buf.clear();
      }
      return;
    }
    while (true) {
      final b = _buf.toBytes();
      if (b.length < 7) return;
      final len = (b[4] << 8) | b[5];
      if (b.length < 6 + len) return;
      final tid = (b[0] << 8) | b[1];
      final frame = Uint8List.fromList(b.sublist(6, 6 + len)); // unit + pdu
      _buf.clear();
      _buf.add(b.sublist(6 + len));
      _pending.remove(tid)?.complete(frame);
    }
  }

  /// Sends a PDU and returns the response PDU (without unit id).
  Future<Uint8List> request(int unit, Uint8List pdu) {
    final result = _queue.then((_) async {
      if (requestDelay > Duration.zero) {
        final wait = _lastDone.add(requestDelay).difference(DateTime.now());
        if (wait > Duration.zero) await Future<void>.delayed(wait);
      }
      try {
        try {
          return await _doRequest(unit, pdu);
        } on DriverException catch (e) {
          if (retryOnEmpty && e.message.contains('empty reply')) return await _doRequest(unit, pdu);
          rethrow;
        }
      } finally {
        _lastDone = DateTime.now();
      }
    });
    _queue = result.then((_) {}, onError: (_) {});
    return result;
  }

  Future<Uint8List> _doRequest(int unit, Uint8List pdu) async {
    await _ensure();
    if (rtu) return _doRtu(unit, pdu);
    _tid = (_tid + 1) & 0xFFFF;
    final tid = _tid;
    final frame = BytesBuilder()
      ..add([tid >> 8, tid & 0xFF, 0, 0, (pdu.length + 1) >> 8, (pdu.length + 1) & 0xFF, unit])
      ..add(pdu);
    final c = Completer<Uint8List>();
    _pending[tid] = c;
    _socket!.add(frame.toBytes());
    Uint8List resp;
    try {
      resp = await c.future.timeout(timeout);
    } on TimeoutException {
      _pending.remove(tid);
      if (closeOnError) _fail('timeout');
      throw DriverException('Modbus: timeout');
    }
    return _check(resp.sublist(1));
  }

  static Uint8List _check(Uint8List r) {
    if (r.isEmpty) throw DriverException('Modbus: empty reply');
    if (r[0] & 0x80 != 0) {
      throw DriverException('Modbus exception ${r.length > 1 ? r[1] : '?'} (function ${r[0] & 0x7F})');
    }
    return r;
  }

  Future<Uint8List> _doRtu(int unit, Uint8List pdu) async {
    final body = [unit, ...pdu];
    final crc = modbusCrc(body);
    final c = Completer<Uint8List>();
    _buf.clear();
    _rtuPending = c;
    _socket!.add([...body, crc & 0xFF, crc >> 8]);
    Uint8List resp;
    try {
      resp = await c.future.timeout(timeout);
    } on TimeoutException {
      _rtuPending = null;
      _buf.clear();
      throw DriverException('Modbus: timeout');
    }
    return _check(resp.sublist(1));
  }

  /// FC 43 / MEI 14: Read Device Identification (basic: vendor, product code, revision).
  Future<Map<int, String>> readDeviceId(int unit) async {
    final r = await request(unit, Uint8List.fromList([0x2B, 0x0E, 0x01, 0x00]));
    return parseDeviceId(r);
  }

  Future<List<int>> readRegisters(int unit, int fn, int address, int count) async {
    final r = await request(unit, Uint8List.fromList([fn, address >> 8, address & 0xFF, count >> 8, count & 0xFF]));
    final n = r[1] ~/ 2;
    return List.generate(n, (i) => (r[2 + i * 2] << 8) | r[3 + i * 2]);
  }

  Future<List<bool>> readBits(int unit, int fn, int address, int count) async {
    final r = await request(unit, Uint8List.fromList([fn, address >> 8, address & 0xFF, count >> 8, count & 0xFF]));
    return List.generate(count, (i) => (r[2 + (i >> 3)] >> (i & 7)) & 1 == 1);
  }

  Future<void> writeCoil(int unit, int address, bool on) =>
      request(unit, Uint8List.fromList([5, address >> 8, address & 0xFF, on ? 0xFF : 0, 0]));

  Future<void> writeRegister(int unit, int address, int value) =>
      request(unit, Uint8List.fromList([6, address >> 8, address & 0xFF, (value >> 8) & 0xFF, value & 0xFF]));

  Future<void> writeRegisters(int unit, int address, List<int> values) {
    final b = BytesBuilder()
      ..add([16, address >> 8, address & 0xFF, values.length >> 8, values.length & 0xFF, values.length * 2]);
    for (final v in values) {
      b.add([(v >> 8) & 0xFF, v & 0xFF]);
    }
    return request(unit, b.toBytes());
  }

  Future<void> close() async => _fail('closed by client');
}

/// Clock hook for tests (backoff / minimum interval).
DateTime Function() modbusClock = DateTime.now;

/// t155u: lockout handling for devices that block clients that poll too often. After a
/// timeout, dropped connection or a "busy"-type exception the host is left alone for
/// [current] (30 s → 60 s → … → 5 min); the first good answer resets it.
class ModbusHostHealth {
  DateTime? blockedUntil;
  Duration current = Duration.zero;
  int failures = 0;

  bool get blocked => blockedUntil != null && modbusClock().isBefore(blockedUntil!);

  void ok() {
    blockedUntil = null;
    current = Duration.zero;
    failures = 0;
  }

  void fail(Duration start, Duration max) {
    failures++;
    current = current == Duration.zero ? start : current * 2;
    if (current > max) current = max;
    blockedUntil = modbusClock().add(current);
  }

  DriverException blockedError() {
    final t = blockedUntil!;
    String two(int v) => v.toString().padLeft(2, '0');
    return DriverException('Modbus: blocked until ${two(t.hour)}:${two(t.minute)}');
  }
}

/// Errors that mean "the device is unhappy" (back off) – not configuration mistakes such as
/// a wrong register (exceptions 1–3), which back-off would not fix.
bool modbusShouldBackOff(Object e) {
  final s = e.toString().toLowerCase();
  if (s.contains('modbus exception 1 ') || s.contains('modbus exception 2 ') || s.contains('modbus exception 3 ')) {
    return false;
  }
  if (s.contains('port closed') || s.contains('host unreachable') || s.contains('no host')) return false;
  return s.contains('timeout') ||
      s.contains('timed out') ||
      s.contains('closed') ||
      s.contains('reset') ||
      s.contains('modbus exception') ||
      s.contains('empty reply') ||
      s.contains('cannot connect');
}

class _BatchReq {
  _BatchReq(this.unit, this.fn, this.address, this.count);
  final int unit, fn, address, count;
  final done = Completer<List<int>>();
}

/// Groups register reads into contiguous ranges: same unit + function, gaps of at most
/// [maxGap] registers, at most [maxBatch] registers per request (AirFi: 20).
List<(int unit, int fn, int start, int count, List<int> members)> planModbusBatches(
  List<(int unit, int fn, int address, int count)> reqs, {
  int maxGap = 4,
  int maxBatch = 20,
}) {
  final idx = List.generate(reqs.length, (i) => i)
    ..sort((a, b) {
      final x = reqs[a], y = reqs[b];
      return x.$1 != y.$1 ? x.$1 - y.$1 : (x.$2 != y.$2 ? x.$2 - y.$2 : x.$3 - y.$3);
    });
  final out = <(int, int, int, int, List<int>)>[];
  for (final i in idx) {
    final r = reqs[i];
    if (out.isNotEmpty) {
      final last = out.last;
      final end = last.$3 + last.$4;
      final newEnd = r.$3 + r.$4 > end ? r.$3 + r.$4 : end;
      if (last.$1 == r.$1 && last.$2 == r.$2 && r.$3 <= end + maxGap && newEnd - last.$3 <= maxBatch) {
        out[out.length - 1] = (last.$1, last.$2, last.$3, newEnd - last.$3, [...last.$5, i]);
        continue;
      }
    }
    out.add((r.$1, r.$2, r.$3, r.$4, [i]));
  }
  return out;
}

/// Modbus RTU CRC-16 (poly 0xA001, init 0xFFFF).
int modbusCrc(List<int> data) {
  var crc = 0xFFFF;
  for (final b in data) {
    crc ^= b & 0xFF;
    for (var i = 0; i < 8; i++) {
      crc = (crc & 1) != 0 ? (crc >> 1) ^ 0xA001 : crc >> 1;
    }
  }
  return crc & 0xFFFF;
}

/// Parses a FC43/14 answer PDU: [0x2B, 0x0E, code, conformity, more, next, n, (id, len, bytes)…].
Map<int, String> parseDeviceId(List<int> r) {
  final out = <int, String>{};
  if (r.length < 7 || r[0] != 0x2B || r[1] != 0x0E) return out;
  var i = 7;
  for (var k = 0; k < r[6] && i + 2 <= r.length; k++) {
    final id = r[i], len = r[i + 1];
    if (i + 2 + len > r.length) break;
    out[id] = String.fromCharCodes(r.sublist(i + 2, i + 2 + len)).trim();
    i += 2 + len;
  }
  return out;
}

/// t154u: a failed TCP connect, said the Modbus way: "port closed" (device there, Modbus TCP
/// off / other port), "host unreachable" (nothing at that IP) or "connect timeout".
DriverException modbusConnectError(Object e, String host, int port) {
  final s = e.toString().toLowerCase();
  final code = e is SocketException ? e.osError?.errorCode : null;
  final where = '$host:$port';
  if (code == 111 || code == 10061 || code == 61 || s.contains('connection refused')) {
    return DriverException('Modbus TCP: port closed ($where) – $e');
  }
  if (code == 113 ||
      code == 10065 ||
      code == 65 ||
      code == 101 ||
      code == 10051 ||
      s.contains('no route to host') ||
      s.contains('network is unreachable') ||
      s.contains('host is unreachable')) {
    return DriverException('Modbus TCP: host unreachable ($where) – $e');
  }
  if (code == 110 || code == 10060 || code == 60 || s.contains('timed out') || e is TimeoutException) {
    return DriverException('Modbus TCP: connect timeout ($where) – $e');
  }
  return DriverException('Modbus TCP: cannot connect ($where) – $e');
}

/// Converts register words to a number by data type.
num decodeRegisters(List<int> regs, String type, {bool swapWords = false}) {
  List<int> w = regs;
  if (swapWords && w.length >= 2) w = [w[1], w[0], ...w.skip(2)];
  final bd = ByteData(8);
  switch (type) {
    case 'int16':
      return w[0] >= 0x8000 ? w[0] - 0x10000 : w[0];
    case 'uint32':
    case 'int32':
    case 'float32':
      bd.setUint16(0, w[0]);
      bd.setUint16(2, w[1]);
      if (type == 'uint32') return bd.getUint32(0);
      if (type == 'int32') return bd.getInt32(0);
      return bd.getFloat32(0);
    default:
      return w[0];
  }
}

List<int> encodeRegisters(num value, String type, {bool swapWords = false}) {
  final bd = ByteData(4);
  List<int> w;
  switch (type) {
    case 'int16':
    case 'uint16':
      return [value.round() & 0xFFFF];
    case 'uint32':
    case 'int32':
      bd.setInt32(0, value.round());
      w = [bd.getUint16(0), bd.getUint16(2)];
    case 'float32':
      bd.setFloat32(0, value.toDouble());
      w = [bd.getUint16(0), bd.getUint16(2)];
    default:
      return [value.round() & 0xFFFF];
  }
  return swapWords ? [w[1], w[0]] : w;
}

int registerCount(String type) => type.endsWith('32') ? 2 : 1;

class ModbusDriver extends Driver {
  ModbusDriver(super.config);
  ModbusTcpClient? _c;
  ModbusTcpClient get client {
    final host = s.str('host').trim();
    if (host.isEmpty) {
      throw DriverException('Modbus: no host – laitteen osoite puuttuu / the device address is missing');
    }
    final c = _c ??= ModbusTcpClient.acquire(host, s.integer('port', 502), rtu: s.str('framing', 'tcp') == 'rtu');
    // Gentle defaults (t155u); every value can be changed under Edistyneet.
    c.timeout = Duration(milliseconds: s.integer('timeoutMs', 3000));
    c.requestDelay = Duration(milliseconds: s.integer('requestDelayMs', 100).clamp(0, 10000));
    c.connectDelay = Duration(milliseconds: s.integer('connectDelayMs', 0).clamp(0, 30000));
    c.closeOnError = s.flag('closeOnError');
    c.retryOnEmpty = s['retryOnEmpty'] != false;
    return c;
  }

  Duration get _minInterval => Duration(seconds: s.integer('minIntervalS', 10).clamp(0, 3600));
  Duration get _backoffStart => Duration(seconds: s.integer('backoffStartS', 30).clamp(1, 3600));
  Duration get _backoffMax => Duration(seconds: s.integer('backoffMaxS', 300).clamp(1, 86400));

  /// Runs [op] unless the host is in its lockout pause; failures that mean "leave me alone"
  /// start / extend the pause, a good answer ends it.
  Future<T> _guard<T>(Future<T> Function(ModbusTcpClient c) op) async {
    final c = client;
    if (c.health.blocked) throw c.health.blockedError();
    try {
      final r = await op(c);
      c.health.ok();
      return r;
    } catch (e) {
      if (modbusShouldBackOff(e)) {
        c.health.fail(_backoffStart, _backoffMax);
        throw DriverException('$e – ${c.health.blockedError().message}');
      }
      if (e.toString().contains('Modbus exception')) c.health.ok(); // it answered
      rethrow;
    }
  }

  /// Reads [count] registers with the per-host cache (minimum interval) and batching.
  Future<List<int>> _registers(int unit, int fn, int address, int count) {
    final c = client;
    final key = '$unit:$fn:$address:$count';
    final hit = c.regCache[key];
    if (hit != null && modbusClock().difference(hit.$2) < _minInterval) return Future.value(hit.$1);
    if (s['batchReads'] == false) {
      return _guard((c) => c.readRegisters(unit, fn, address, count)).then((v) {
        c.regCache[key] = (v, modbusClock());
        return v;
      });
    }
    final req = _BatchReq(unit, fn, address, count);
    c.batch.add(req);
    c.batchTimer ??= Timer(const Duration(milliseconds: 40), () => _flush(c));
    return req.done.future.then((v) {
      c.regCache[key] = (v, modbusClock());
      return v;
    });
  }

  Future<void> _flush(ModbusTcpClient c) async {
    c.batchTimer = null;
    final reqs = [...c.batch];
    c.batch.clear();
    final plan = planModbusBatches(
      [for (final r in reqs) (r.unit, r.fn, r.address, r.count)],
      maxGap: s.integer('maxGap', 4).clamp(0, 50),
      maxBatch: s.integer('maxBatch', 20).clamp(1, 125),
    );
    for (final (unit, fn, start, count, members) in plan) {
      try {
        final v = await _guard((c) => c.readRegisters(unit, fn, start, count));
        for (final i in members) {
          final r = reqs[i];
          final from = r.address - start;
          if (from + r.count <= v.length) {
            r.done.complete(v.sublist(from, from + r.count));
          } else {
            r.done.completeError(DriverException('Modbus: short reply'));
          }
        }
      } catch (e) {
        // A merged range can include a register the device does not have (exception 2):
        // fall back to the single reads so one gap does not break every tile.
        final illegal = e.toString().contains('Modbus exception 2 ') && members.length > 1;
        for (final i in members) {
          final r = reqs[i];
          if (!illegal) {
            r.done.completeError(e);
            continue;
          }
          try {
            r.done.complete(await _guard((c) => c.readRegisters(r.unit, r.fn, r.address, r.count)));
          } catch (e2) {
            r.done.completeError(e2);
          }
        }
      }
    }
  }

  static const _tables = ['holding', 'input', 'coil', 'discrete'];
  static const _types = ['uint16', 'int16', 'uint32', 'int32', 'float32'];

  static const descriptor = DriverDescriptor(
    type: 'modbus',
    fi: 'Modbus TCP',
    en: 'Modbus TCP',
    create: ModbusDriver.new,
    connectionFields: [
      FieldSpec('host', 'IP-osoite', 'Host', hint: '192.168.x.x', required: true),
      FieldSpec('port', 'Portti', 'Port', kind: FieldKind.number, defaultValue: 502),
      FieldSpec('unitId', 'Laitteen osoite (unit id)', 'Unit id', kind: FieldKind.number, defaultValue: 1),
      FieldSpec('timeoutMs', 'Aikakatkaisu (ms)', 'Timeout (ms)', kind: FieldKind.number, defaultValue: 3000),
      FieldSpec(
        'framing',
        'Kehystys',
        'Framing',
        kind: FieldKind.choice,
        options: ['tcp', 'rtu'],
        defaultValue: 'tcp',
        optionLabels: {
          'tcp': ('Modbus TCP (tavallinen)', 'Modbus TCP (normal)'),
          'rtu': ('Modbus RTU TCP:n yli (RS485-yhdyskäytävä)', 'Modbus RTU over TCP (RS485 gateway)'),
        },
        advanced: true,
        helpFi: 'Halpa RS485–wifi/ethernet-muunnin läpinäkyvässä tilassa käyttää RTU-kehyksiä.',
        helpEn: 'A cheap RS485 to Wi-Fi/Ethernet converter in transparent mode uses RTU frames.',
      ),
      // t155u: gentle polling – a device that allows one client / locks out fast pollers.
      FieldSpec(
        'minIntervalS',
        'Lukuväli vähintään (s)',
        'Minimum read interval (s)',
        kind: FieldKind.number,
        defaultValue: 10,
        advanced: true,
        helpFi: 'Samaa rekisteriä ei lueta tätä useammin, vaikka laattoja olisi monta.',
        helpEn: 'The same register is never read more often, however many tiles show it.',
      ),
      FieldSpec(
        'requestDelayMs',
        'Tauko kyselyjen välissä (ms)',
        'Pause between requests (ms)',
        kind: FieldKind.number,
        defaultValue: 100,
        advanced: true,
      ),
      FieldSpec(
        'connectDelayMs',
        'Odotus yhdistämisen jälkeen (ms)',
        'Wait after connecting (ms)',
        kind: FieldKind.number,
        defaultValue: 0,
        advanced: true,
      ),
      FieldSpec(
        'batchReads',
        'Yhdistä peräkkäiset luvut',
        'Batch adjacent reads',
        kind: FieldKind.boolean,
        defaultValue: true,
        advanced: true,
      ),
      FieldSpec(
        'maxBatch',
        'Rekistereitä yhdessä luvussa enintään',
        'Max registers per read',
        kind: FieldKind.number,
        defaultValue: 20,
        advanced: true,
      ),
      FieldSpec(
        'backoffStartS',
        'Estotilan tauko alussa (s)',
        'Lockout pause at first (s)',
        kind: FieldKind.number,
        defaultValue: 30,
        advanced: true,
        helpFi: 'Kun laite ei vastaa, sitä ei kysytä hetkeen. Tauko kaksinkertaistuu enimmäisarvoon asti.',
        helpEn: 'When the device does not answer, it is left alone for a while. The pause doubles up to the maximum.',
      ),
      FieldSpec(
        'backoffMaxS',
        'Estotilan tauko enintään (s)',
        'Lockout pause at most (s)',
        kind: FieldKind.number,
        defaultValue: 300,
        advanced: true,
      ),
      FieldSpec(
        'closeOnError',
        'Sulje yhteys virheen jälkeen',
        'Close the connection after an error',
        kind: FieldKind.boolean,
        defaultValue: false,
        advanced: true,
      ),
      FieldSpec(
        'retryOnEmpty',
        'Kysy uudelleen tyhjän vastauksen jälkeen',
        'Retry on an empty reply',
        kind: FieldKind.boolean,
        defaultValue: true,
        advanced: true,
      ),
    ],
    readFields: [
      FieldSpec(
        'table',
        'Rekisterityyppi',
        'Register table',
        kind: FieldKind.choice,
        options: _tables,
        optionLabels: {
          'holding': ('Pitorekisteri (4x)', 'Holding register (4x)'),
          'coil': ('Kela (0x)', 'Coil (0x)'),
          'input': ('Syöttörekisteri (3x)', 'Input register (3x)'),
          'discrete': ('Diskreetti tulo (1x)', 'Discrete input (1x)'),
        },
        defaultValue: 'holding',
      ),
      FieldSpec('address', 'Osoite (0-pohjainen)', 'Address (0-based)', kind: FieldKind.number, defaultValue: 0),
      FieldSpec(
        'dataType',
        'Tietotyyppi',
        'Data type',
        kind: FieldKind.choice,
        options: _types,
        defaultValue: 'uint16',
      ),
      FieldSpec('swapWords', 'Sanajärjestys käänteinen (CDAB)', 'Swap words (CDAB)', kind: FieldKind.boolean),
      FieldSpec('scale', 'Kerroin', 'Scale', kind: FieldKind.number, defaultValue: 1, hint: '0.1'),
      FieldSpec('offset', 'Siirtymä', 'Offset', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('unitId', 'Unit id (tyhjä = yhteyden)', 'Unit id (empty = connection)', kind: FieldKind.number),
    ],
    commandFields: [
      FieldSpec(
        'table',
        'Kirjoitettava',
        'Write to',
        kind: FieldKind.choice,
        options: ['holding', 'coil'],
        optionLabels: {
          'holding': ('Pitorekisteri (4x)', 'Holding register (4x)'),
          'coil': ('Kela (0x)', 'Coil (0x)'),
          'input': ('Syöttörekisteri (3x)', 'Input register (3x)'),
          'discrete': ('Diskreetti tulo (1x)', 'Discrete input (1x)'),
        },
        defaultValue: 'holding',
      ),
      FieldSpec('address', 'Osoite (0-pohjainen)', 'Address (0-based)', kind: FieldKind.number, defaultValue: 0),
      FieldSpec(
        'value',
        'Arvo ({{value}} = liukusäädin/kytkin)',
        'Value ({{value}} = slider/toggle)',
        defaultValue: '{{value}}',
      ),
      FieldSpec(
        'dataType',
        'Tietotyyppi',
        'Data type',
        kind: FieldKind.choice,
        options: _types,
        defaultValue: 'uint16',
      ),
      FieldSpec('swapWords', 'Sanajärjestys käänteinen (CDAB)', 'Swap words (CDAB)', kind: FieldKind.boolean),
      FieldSpec('scale', 'Kerroin', 'Scale', kind: FieldKind.number, defaultValue: 1),
      FieldSpec('offset', 'Siirtymä', 'Offset', kind: FieldKind.number, defaultValue: 0),
      FieldSpec('unitId', 'Unit id (tyhjä = yhteyden)', 'Unit id (empty = connection)', kind: FieldKind.number),
    ],
  );

  int _unit(Map<String, dynamic> spec) => spec.integer('unitId', s.integer('unitId', 1));

  @override
  Future<Object?> read(Map<String, dynamic> spec) async {
    final table = spec.str('table', 'holding');
    final addr = spec.integer('address', 0);
    final unit = _unit(spec);
    if (table == 'coil' || table == 'discrete') {
      final bits = await _guard((c) => c.readBits(unit, table == 'coil' ? 1 : 2, addr, 1));
      return bits.first ? 1 : 0;
    }
    final type = spec.str('dataType', 'uint16');
    final regs = await _registers(unit, table == 'input' ? 4 : 3, addr, registerCount(type));
    final raw = decodeRegisters(regs, type, swapWords: spec.flag('swapWords'));
    final scale = spec.dbl('scale', 1);
    final offset = spec.dbl('offset', 0);
    final v = raw * scale + offset;
    return (scale == 1 && offset == 0 && type != 'float32') ? raw : v;
  }

  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) async {
    final table = spec.str('table', 'holding');
    final addr = spec.integer('address', 0);
    final unit = _unit(spec);
    final text = applyTemplate(spec.str('value', '{{value}}'), value);
    if (table == 'coil') {
      final on = isTruthy(coerce(text));
      await _guard((c) => c.writeCoil(unit, addr, on));
      client.regCache.clear();
      return on;
    }
    final n = num.tryParse(text.trim());
    if (n == null) throw DriverException('Modbus: value "$text" is not a number');
    final scale = spec.dbl('scale', 1);
    final offset = spec.dbl('offset', 0);
    final raw = (n - offset) / (scale == 0 ? 1 : scale);
    final type = spec.str('dataType', 'uint16');
    final regs = encodeRegisters(raw, type, swapWords: spec.flag('swapWords'));
    if (regs.length == 1) {
      await _guard((c) => c.writeRegister(unit, addr, regs.first)); // FC6
    } else {
      await _guard((c) => c.writeRegisters(unit, addr, regs));
    }
    client.regCache.removeWhere((k, _) => k.startsWith('$unit:3:'));
    return raw;
  }

  @override
  Future<String> test() async {
    try {
      final v = await _guard((c) => c.readRegisters(s.integer('unitId', 1), 3, 0, 1));
      return 'OK, HR0 = ${v.first}';
    } on DriverException catch (e) {
      // Device answered with a Modbus exception -> the connection itself works.
      if (e.message.contains('exception')) return 'OK (${e.message})';
      rethrow;
    }
  }

  @override
  Future<void> dispose() async {
    final c = _c;
    _c = null;
    if (c != null) await ModbusTcpClient.release(c);
  }
}
