import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/fields.dart';
import '../core/template.dart';
import 'driver.dart';

const _sendFields = [
  FieldSpec(
    'payload',
    'Viesti ({{value}} = arvo)',
    'Payload ({{value}} = value)',
    kind: FieldKind.multiline,
    hint: r'STATUS\r\n',
    required: true,
  ),
  FieldSpec('hex', 'Viesti heksana', 'Payload is hex', kind: FieldKind.boolean),
  FieldSpec('expectResponse', 'Odota vastausta', 'Wait for response', kind: FieldKind.boolean, defaultValue: true),
  FieldSpec('responseHex', 'Vastaus heksana', 'Response as hex', kind: FieldKind.boolean),
  FieldSpec('regex', 'Regex (ryhmä 1)', 'Regex (group 1)', hint: r'TEMP=([\d.]+)'),
  FieldSpec('jsonPath', 'JSON-polku', 'JSON path'),
  FieldSpec('timeoutMs', 'Aikakatkaisu (ms)', 'Timeout (ms)', kind: FieldKind.number, defaultValue: 2000),
];

const _hostFields = [
  FieldSpec('host', 'IP-osoite', 'Host', required: true),
  FieldSpec('port', 'Portti', 'Port', kind: FieldKind.number, required: true),
];

String _decode(List<int> bytes, Map<String, dynamic> spec) =>
    spec.flag('responseHex') ? toHex(bytes) : utf8.decode(bytes, allowMalformed: true);

/// Raw TCP: opens a socket per request, sends payload, optionally reads reply
/// until the socket goes idle (or closes) for a short moment.
class TcpDriver extends Driver {
  TcpDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'tcp',
    fi: 'TCP (raaka)',
    en: 'TCP (raw)',
    create: TcpDriver.new,
    connectionFields: _hostFields,
    readFields: _sendFields,
    commandFields: _sendFields,
  );

  Future<List<int>> exchange(List<int> payload, {required bool wait, required Duration timeout}) async {
    final sock = await Socket.connect(s.str('host'), s.integer('port', 0), timeout: timeout);
    try {
      sock.add(payload);
      await sock.flush();
      if (!wait) return const [];
      final out = <int>[];
      final done = Completer<void>();
      Timer? idle;
      final deadline = Timer(timeout, () {
        if (!done.isCompleted) done.complete();
      });
      final sub = sock.listen(
        (d) {
          out.addAll(d);
          idle?.cancel();
          idle = Timer(const Duration(milliseconds: 150), () {
            if (!done.isCompleted) done.complete();
          });
        },
        onDone: () {
          if (!done.isCompleted) done.complete();
        },
        onError: (_) {
          if (!done.isCompleted) done.complete();
        },
      );
      await done.future;
      idle?.cancel();
      deadline.cancel();
      await sub.cancel();
      if (out.isEmpty) throw DriverException('TCP: no response');
      return out;
    } finally {
      sock.destroy();
    }
  }

  Future<Object?> _run(Map<String, dynamic> spec, Object? value, bool defWait) async {
    final payload = encodePayload(applyTemplate(spec.str('payload'), value), hex: spec.flag('hex'));
    final wait = spec.flag('expectResponse', defWait);
    final r = await exchange(
      payload,
      wait: wait,
      timeout: Duration(milliseconds: spec.integer('timeoutMs', 2000)),
    );
    return wait ? extractValue(_decode(r, spec), spec) : null;
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) => _run(spec, null, true);
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => _run(spec, value, false);

  @override
  Future<String> test() async {
    final sock = await Socket.connect(s.str('host'), s.integer('port', 0), timeout: const Duration(seconds: 3));
    sock.destroy();
    return 'OK, TCP port open';
  }
}

class UdpDriver extends Driver {
  UdpDriver(super.config);

  static const descriptor = DriverDescriptor(
    type: 'udp',
    fi: 'UDP',
    en: 'UDP',
    create: UdpDriver.new,
    connectionFields: _hostFields,
    readFields: _sendFields,
    commandFields: _sendFields,
  );

  Future<Object?> _run(Map<String, dynamic> spec, Object? value, bool defWait) async {
    final payload = encodePayload(applyTemplate(spec.str('payload'), value), hex: spec.flag('hex'));
    final wait = spec.flag('expectResponse', defWait);
    final addrs = await InternetAddress.lookup(s.str('host'));
    if (addrs.isEmpty) throw DriverException('UDP: cannot resolve host');
    final target = addrs.first;
    final sock = await RawDatagramSocket.bind(
      target.type == InternetAddressType.IPv6 ? InternetAddress.anyIPv6 : InternetAddress.anyIPv4,
      0,
    );
    try {
      sock.send(payload, target, s.integer('port', 0));
      if (!wait) return null;
      final c = Completer<List<int>>();
      sock.listen((ev) {
        if (ev == RawSocketEvent.read) {
          final d = sock.receive();
          if (d != null && !c.isCompleted) c.complete(d.data);
        }
      });
      final data = await c.future.timeout(
        Duration(milliseconds: spec.integer('timeoutMs', 2000)),
        onTimeout: () => throw DriverException('UDP: no response'),
      );
      return extractValue(_decode(data, spec), spec);
    } finally {
      sock.close();
    }
  }

  @override
  Future<Object?> read(Map<String, dynamic> spec) => _run(spec, null, true);
  @override
  Future<Object?> send(Map<String, dynamic> spec, {Object? value}) => _run(spec, value, false);

  @override
  Future<String> test() async {
    final addrs = await InternetAddress.lookup(s.str('host'));
    return 'OK, ${addrs.first.address} (UDP is connectionless)';
  }
}
