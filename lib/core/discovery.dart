import 'dart:async';
import 'plat.dart';
import 'dart:io';

import 'package:flutter/services.dart';
import 'package:multicast_dns/multicast_dns.dart';

/// A device found on the local network via mDNS / Bonjour.
class FoundDevice {
  final String name;
  final String service;
  final String host;
  final String? ip;
  final int port;
  const FoundDevice({required this.name, required this.service, required this.host, this.ip, required this.port});

  /// Address to put into a template (IP preferred, port only if non-default).
  String get address {
    final h = ip ?? host.replaceAll(RegExp(r'\.$'), '');
    final defaultPort = service.startsWith('_home-assistant') ? 8123 : 80;
    return port == defaultPort || port == 0 || service.startsWith('_esphomelib') ? h : '$h:$port';
  }

  /// Friendly label: "shellyplus1-a8032ab1" -> kept, strips the service suffix.
  String get label {
    final i = name.indexOf('._');
    return i > 0 ? name.substring(0, i) : name;
  }

  String get kind {
    final n = name.toLowerCase();
    if (service.startsWith('_esphomelib')) return 'esphome';
    if (service.startsWith('_home-assistant')) return 'homeassistant';
    if (service.startsWith('_shelly') || n.startsWith('shelly')) return 'shelly';
    if (n.contains('tasmota')) return 'tasmota';
    if (n.contains('esp32') || n.contains('cam')) return 'esp32cam';
    return 'http';
  }
}

/// Which discovered devices make sense for a template.
bool deviceMatchesTemplate(FoundDevice d, String templateId) {
  switch (templateId) {
    case 'shelly':
      return d.kind == 'shelly';
    case 'esphome':
      return d.kind == 'esphome';
    case 'homeassistant':
    case 'heatpump_ha':
      return d.kind == 'homeassistant';
    case 'tasmota':
      return d.kind == 'tasmota' || d.kind == 'http';
    case 'esp32cam':
      return d.kind == 'esp32cam' || d.kind == 'http';
    default:
      return true;
  }
}

const _lock = MethodChannel('molaplan/multicast');

const _txtServices = {
  '_home-assistant._tcp',
  '_ewelink._tcp',
  '_device-info._tcp',
  '_airplay._tcp',
  '_raop._tcp',
  '_googlecast._tcp',
  '_ipp._tcp',
  '_printer._tcp',
};

/// This device's name and the default gateway (Android; null fields elsewhere).
Future<Map<String, Object?>> nativeNetInfo() async {
  if (!Plat.isAndroid) return const {};
  try {
    final m = await _lock.invokeMethod<Map>('netInfo');
    return {for (final e in (m ?? const {}).entries) '${e.key}': e.value};
  } catch (_) {
    return const {};
  }
}

// Android's WifiManager.MulticastLock is not reference counted here, so nested users
// (the network scan around mDNS) count in Dart.
var _lockDepth = 0;

Future<void> _acquireLock() async {
  if (!Plat.isAndroid) return;
  if (_lockDepth++ > 0) return;
  try {
    await _lock.invokeMethod<void>('acquire');
  } catch (_) {}
}

Future<void> _releaseLock() async {
  if (!Plat.isAndroid || _lockDepth == 0) return;
  if (--_lockDepth > 0) return;
  try {
    await _lock.invokeMethod<void>('release');
  } catch (_) {}
}

/// Holds the Android multicast lock while [body] runs (SSDP, WS-Discovery, mDNS).
Future<T> withMulticastLock<T>(Future<T> Function() body) async {
  await _acquireLock();
  try {
    return await body();
  } finally {
    await _releaseLock();
  }
}

Future<RawDatagramSocket> _bind(
  dynamic host,
  int port, {
  bool reuseAddress = true,
  bool reusePort = false,
  int ttl = 1,
}) async {
  try {
    return await RawDatagramSocket.bind(
      host,
      port,
      reuseAddress: reuseAddress,
      reusePort: reusePort && !Plat.isWindows,
      ttl: ttl,
    );
  } catch (_) {
    return RawDatagramSocket.bind(host, port, reuseAddress: reuseAddress, reusePort: false, ttl: ttl);
  }
}

/// Browses the given service types for [timeout]. Never throws: returns what
/// was found (possibly nothing) and the error text if mDNS was unavailable.
Future<(List<FoundDevice>, String?)> discoverDevices({
  List<String> services = const ['_esphomelib._tcp', '_shelly._tcp', '_home-assistant._tcp', '_http._tcp'],
  Duration timeout = const Duration(seconds: 4),
  void Function(FoundDevice d, Map<String, String> txt)? onRecord,
}) async {
  final found = <String, FoundDevice>{};
  final client = MDnsClient(rawDatagramSocketFactory: _bind);
  await _acquireLock();
  try {
    await client.start();
    await Future.wait(
      services.map((svc) async {
        final ptrs = await client
            .lookup<PtrResourceRecord>(ResourceRecordQuery.serverPointer('$svc.local'), timeout: timeout)
            .toList();
        for (final ptr in ptrs) {
          final txt = <String, String>{};
          if (onRecord != null && _txtServices.contains(svc)) {
            final t = await client
                .lookup<TxtResourceRecord>(
                  ResourceRecordQuery.text(ptr.domainName),
                  timeout: const Duration(seconds: 1),
                )
                .toList()
                .catchError((_) => <TxtResourceRecord>[]);
            for (final r in t) {
              for (final kv in r.text.split('\n')) {
                final i = kv.indexOf('=');
                if (i > 0) txt[kv.substring(0, i).toLowerCase()] = kv.substring(i + 1);
              }
            }
          }
          // _device-info has no SRV: the instance is the host name ("Ennin-iPhone").
          if (onRecord != null && svc == '_device-info._tcp') {
            final inst = ptr.domainName.split('._').first;
            final ips = await client
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4('$inst.local'),
                  timeout: const Duration(seconds: 1),
                )
                .toList()
                .catchError((_) => <IPAddressResourceRecord>[]);
            if (ips.isNotEmpty) {
              onRecord(
                FoundDevice(
                  name: ptr.domainName,
                  service: svc,
                  host: '$inst.local',
                  ip: ips.first.address.address,
                  port: 0,
                ),
                txt,
              );
            }
            continue;
          }
          final srvs = await client
              .lookup<SrvResourceRecord>(
                ResourceRecordQuery.service(ptr.domainName),
                timeout: const Duration(seconds: 2),
              )
              .toList();
          for (final srv in srvs) {
            final ips = await client
                .lookup<IPAddressResourceRecord>(
                  ResourceRecordQuery.addressIPv4(srv.target),
                  timeout: const Duration(seconds: 2),
                )
                .toList();
            final d = FoundDevice(
              name: ptr.domainName,
              service: svc,
              host: srv.target,
              ip: ips.isEmpty ? null : ips.first.address.address,
              port: srv.port,
            );
            onRecord?.call(d, txt);
            // Prefer the more specific service if a device advertises several.
            final key = d.ip ?? d.host;
            if (!found.containsKey(key) || found[key]!.service == '_http._tcp') found[key] = d;
          }
        }
      }),
    );
    return (found.values.toList()..sort((a, b) => a.label.compareTo(b.label)), null);
  } catch (e) {
    return (found.values.toList(), e.toString());
  } finally {
    client.stop();
    await _releaseLock();
  }
}
