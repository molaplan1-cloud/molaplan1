/// Finding devices from the app: own LAN (scan + mDNS) and, when paired, the home bridge's LAN.
library;

import 'scanner.dart';

import 'dart:async';

import '../core/discovery.dart';
import '../remote/router.dart';
import 'registry.dart';

/// mDNS + LAN scan on this device's own network.
Future<List<Candidate>> findLocal(DeviceProvider p, {List<String>? locals}) async {
  final ips = locals ?? await localIPv4s();
  if (ips.isEmpty || p.kind == ProviderKind.cloud) return const [];
  final results = await Future.wait([
    p.scan(ips).catchError((_) => <Candidate>[]),
    if (p.mdnsTypes.isNotEmpty)
      discoverDevices(services: p.mdnsTypes, timeout: const Duration(seconds: 3))
          .then((r) {
            final (found, _) = r;
            return [
              for (final d in found)
                if (p.id != 'shelly' || d.kind == 'shelly') ?p.fromMdns(d.address, d.label, d.service),
            ];
          })
          .catchError((_) => <Candidate>[]),
  ]);
  return mergeCandidates(results.expand((x) => x)).map((c) => c.copyWith(local: true)).toList();
}

/// One entry per device. The same address found by this device's own network AND by the home
/// bridge is one entry that remembers both sources (R558); the one with more detail (model, name)
/// wins. Two entries with the same address but clearly different names stay separate – they can
/// be two homes that happen to use the same private address.
List<Candidate> mergeCandidates(Iterable<Candidate> all) {
  final byAddr = <String, Candidate>{};
  bool differs(Candidate a, Candidate b) {
    final x = (a.name ?? '').trim().toLowerCase(), y = (b.name ?? '').trim().toLowerCase();
    return x.isNotEmpty && y.isNotEmpty && x != y && a.local != b.local;
  }

  for (final c in all) {
    var k = hostOf(c.address);
    final old = byAddr[k];
    if (old == null) {
      byAddr[k] = c;
      continue;
    }
    if (differs(old, c)) {
      byAddr['$k#${c.local ? 'local' : 'bridge'}'] = c;
      continue;
    }
    final best = old.model.isEmpty && c.model.isNotEmpty ? c : old;
    byAddr[k] = best.copyWith(local: old.local || c.local, bridge: old.bridge || c.bridge);
  }
  return byAddr.values.toList()..sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
}

/// Asks the home bridge to search its LAN (works from anywhere).
Future<List<Candidate>> findViaBridge(RemoteRouter router, DeviceProvider p) async {
  final v = await router.viaRemote((c) => c.call('discover', spec: {'provider': p.id}));
  return [for (final m in (v is List ? v : const []).whereType<Map>()) Candidate.fromJson(m, viaBridge: true)];
}

/// Bridge side: the executor's discover hook (scan + mDNS).
Future<List<Map<String, dynamic>>> bridgeDiscover(String provider) async {
  final p = providerById(provider);
  if (p == null) return const [];
  return [for (final c in await findLocal(p)) c.toJson()];
}

/// "Etsi laitteet" through the home bridge: the bridge scans its LAN and returns the list.
Future<List<ScanHit>> scanViaBridge(RemoteRouter router) async {
  final v = await router.viaRemote((c) => c.call('scan'));
  return [for (final m in (v is List ? v : const []).whereType<Map>()) ScanHit.fromJson(m, viaBridge: true)];
}
