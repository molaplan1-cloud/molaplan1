/// Toshiba Home AC Control (cloud). REST login + state from mobileapi.toshibahomeaccontrols.com;
/// commands go to Toshiba's Azure IoT Hub over MQTT (TLS 8883) as the phone app does, with the
/// SAS token the REST API hands out for a registered "mobile device". Endpoints and the 19-byte
/// state layout follow Toshiba-AC-control (Apache-2.0, © 2021 Kamil Sroka) – rewritten in Dart.
/// UNTESTED ON HARDWARE – REST tested against a mock API, MQTT against a local broker.
library;

import 'dart:convert';

import 'package:mqtt_client/mqtt_client.dart';
import 'package:mqtt_client/mqtt_server_client.dart';

import '../drivers/driver.dart';
import 'hp_model.dart';

const _tModes = {0x41: 'auto', 0x42: 'cool', 0x43: 'heat', 0x44: 'dry', 0x45: 'fan_only'};
const _tFans = {0x41: 'auto', 0x31: 'quiet', 0x32: 'low', 0x33: 'medium_low', 0x34: 'medium', 0x35: 'medium_high', 0x36: 'high'};

/// Decoded Toshiba ACStateData (hex). Null = not reported.
class ToshibaState {
  int status = 0xFF, mode = 0xFF, fan = 0xFF;
  int? temp, indoor, outdoor;

  static int? _t(int b) {
    final v = b > 127 ? b - 256 : b;
    if (v == 127 || v == -128 || v == -1) return null;
    return v == 126 ? -1 : v;
  }

  static ToshibaState decode(String hex) {
    final h = hex.trim();
    if (h.length < 20) throw FormatException('Toshiba state too short: $h');
    int byte(int i) => int.parse(h.substring(i, i + 2), radix: 16);
    // Bytes 0..5 are whole bytes, then two half-byte merit fields (chars 12, 13), then whole bytes.
    return ToshibaState()
      ..status = byte(0)
      ..mode = byte(2)
      ..temp = _t(byte(4))
      ..fan = byte(6)
      ..indoor = _t(byte(16))
      ..outdoor = _t(byte(18));
  }

  /// A command: every field 'not set' (ff / f) except the ones given.
  static String command({bool? power, String? mode, int? temp, String? fan}) {
    String b(int v) => (v & 0xFF).toRadixString(16).padLeft(2, '0');
    final s = StringBuffer()
      ..write(power == null ? 'ff' : b(power ? 0x30 : 0x31))
      ..write(mode == null ? 'ff' : b(_tModes.entries.firstWhere((e) => e.value == mode).key))
      ..write(temp == null ? 'ff' : b(temp))
      ..write(fan == null ? 'ff' : b(_tFans.entries.firstWhere((e) => e.value == fan).key))
      ..write('ff') // swing
      ..write('ff') // power selection
      ..write('ff') // merit B + merit A (half bytes)
      ..write('ff') // air pure ion
      ..write('ff') // indoor
      ..write('ff') // outdoor
      ..write('ffffffff')
      ..write('ff') // self cleaning
      ..write('ffffffff');
    return s.toString();
  }
}

class ToshibaBackend extends HpBackend {
  ToshibaBackend(super.s, super.client);

  String get base => baseOverride.isNotEmpty ? baseOverride : 'https://mobileapi.toshibahomeaccontrols.com';
  String? _token, _tokenType, _consumerId, _sas;
  final Map<String, String> _uniqueIds = {};

  String get _deviceId => '${s['username'] ?? ''}_${s['clientId'] ?? '3e6e4eb5f0e5aa46'}';

  Map<String, String> get _h => {'Authorization': '${_tokenType ?? 'Bearer'} ${_token ?? ''}', 'User-Agent': 'Mozilla/5.0'};

  Object? _res(Object? r) {
    if (r is! Map) throw DriverException('Toshiba: ${dtx('outo vastaus', 'odd answer')}');
    if (r['IsSuccess'] != true) {
      if ('${r['StatusCode']}' == 'InvalidUserNameorPassword') {
        throw HpAuthError(dtx('Toshiba: väärä käyttäjätunnus tai salasana', 'Toshiba: wrong username or password'));
      }
      throw DriverException('Toshiba: ${r['Message'] ?? r['StatusCode']}');
    }
    return r['ResObj'];
  }

  Future<void> login() async {
    final r = _res(
      await sendJson('POST', Uri.parse('$base/api/Consumer/Login'), {
        'Username': '${s['username'] ?? ''}',
        'Password': '${s['password'] ?? ''}',
      }, headers: {'User-Agent': 'Mozilla/5.0'}),
    );
    final m = (r as Map?) ?? const {};
    _token = '${m['access_token'] ?? ''}';
    _tokenType = '${m['token_type'] ?? 'Bearer'}';
    _consumerId = '${m['consumerId'] ?? ''}';
    if (_token!.isEmpty) throw HpAuthError('Toshiba: no token');
  }

  Future<T> _authed<T>(Future<T> Function() f) async {
    if (_token == null) await login();
    try {
      return await f();
    } on HpAuthError {
      await login();
      return f();
    }
  }

  @override
  Future<List<HpUnit>> units() => _authed(() async {
    final r = _res(await getJson(Uri.parse('$base/api/AC/GetConsumerACMapping?consumerId=$_consumerId'), headers: _h));
    final out = <HpUnit>[];
    for (final g in (r as List? ?? const [])) {
      for (final d in ((g as Map)['ACList'] as List? ?? const [])) {
        final m = d as Map;
        _uniqueIds['${m['Id']}'] = '${m['DeviceUniqueId']}';
        out.add(
          HpUnit(
            id: '${m['Id']}',
            name: '${m['Name'] ?? 'Toshiba'}',
            model: 'Toshiba ${m['ACModelId'] ?? ''}'.trim(),
            meta: {'uniqueId': '${m['DeviceUniqueId']}'},
          ),
        );
      }
    }
    return out;
  });

  @override
  Future<HpState> state(HpUnit unit) => _authed(() async {
    final r = _res(
      await getJson(Uri.parse('$base/api/AC/GetCurrentACState?ACId=${unit.id}&consumerId=$_consumerId'), headers: _h),
    );
    final hex = (r as Map?)?['ACStateData'];
    if (hex is! String) throw DriverException('Toshiba: no ACStateData');
    final t = ToshibaState.decode(hex);
    return HpState(
      power: t.status == 0x30 ? true : (t.status == 0x31 ? false : null),
      mode: _tModes[t.mode] ?? '',
      target: t.temp?.toDouble(),
      current: t.indoor?.toDouble(),
      outdoor: t.outdoor?.toDouble(),
      fan: _tFans[t.fan] ?? '',
      modes: const ['off', 'heat', 'cool', 'auto', 'dry', 'fan_only'],
      fans: const ['auto', 'quiet', 'low', 'medium_low', 'medium', 'medium_high', 'high'],
      minTarget: 17,
      maxTarget: 30,
      step: 1,
    );
  });

  Future<String> _sasToken() async {
    if (_sas != null) return _sas!;
    final r = _res(
      await _authed(
        () => sendJson('POST', Uri.parse('$base/api/Consumer/RegisterMobileDevice'), {
          'DeviceID': _deviceId,
          'DeviceType': '1',
          'Username': '${s['username'] ?? ''}',
        }, headers: _h),
      ),
    );
    final sas = (r as Map?)?['SasToken'];
    if (sas is! String) throw DriverException('Toshiba: no SasToken');
    return _sas = sas;
  }

  /// IoT Hub host from the SAS token (`SharedAccessSignature sr=<host>%2Fdevices%2F<id>&sig=…`).
  static String hubHost(String sas) {
    final m = RegExp(r'sr=([^&]+)').firstMatch(sas);
    final sr = Uri.decodeComponent(m?.group(1) ?? '');
    return sr.split('/').first;
  }

  /// The message the phone app sends (cmd CMD_FCU_TO_AC).
  Map<String, dynamic> message(String uniqueId, String data) => {
    'sourceId': _deviceId,
    'messageId': '0000000',
    'targetId': [uniqueId],
    'cmd': 'CMD_FCU_TO_AC',
    'payload': {'data': data},
    'timeStamp': '0000000',
  };

  Future<void> publish(String body) async {
    final sas = await _sasToken();
    final host = '${s['iotHost'] ?? ''}'.isNotEmpty ? '${s['iotHost']}' : hubHost(sas);
    final tls = s['iotTls'] != false;
    final port = int.tryParse('${s['iotPort'] ?? ''}') ?? (tls ? 8883 : 1883);
    final c = MqttServerClient.withPort(host, _deviceId, port)
      ..logging(on: false)
      ..keepAlivePeriod = 30
      ..connectTimeoutPeriod = 8000
      ..secure = tls
      ..setProtocolV311()
      ..connectionMessage = MqttConnectMessage().withClientIdentifier(_deviceId).startClean();
    try {
      await c.connect('$host/$_deviceId/?api-version=2021-04-12', sas);
      if (c.connectionStatus?.state != MqttConnectionState.connected) {
        _sas = null;
        throw DriverException('Toshiba IoT: ${c.connectionStatus?.returnCode}');
      }
      final b = MqttClientPayloadBuilder()..addUTF8String(body);
      c.publishMessage(
        'devices/$_deviceId/messages/events/\$.ct=application%2Fjson&\$.ce=utf-8&type=mob',
        MqttQos.atLeastOnce,
        b.payload!,
      );
      await Future<void>.delayed(const Duration(milliseconds: 600));
    } catch (e) {
      if (e is DriverException) rethrow;
      _sas = null;
      throw DriverException('Toshiba IoT: $e');
    } finally {
      c.disconnect();
    }
  }

  @override
  Future<HpState?> apply(HpUnit unit, HpState current, HpChange c) async {
    final uid = '${unit.meta['uniqueId'] ?? _uniqueIds[unit.id] ?? ''}';
    if (uid.isEmpty) throw DriverException('Toshiba: unknown unit');
    final data = ToshibaState.command(
      power: c.mode == 'off' ? false : (c.mode != null ? true : c.power),
      mode: c.mode == null || c.mode == 'off' ? null : c.mode,
      temp: c.target == null ? null : hpRound(c.target!, 1, 17, 30).round(),
      fan: c.fan,
    );
    await publish(jsonEncode(message(uid, data)));
    return null;
  }
}
