/// Generic "add a device" framework (pure Dart, also runs on the bridge).
///
/// Each brand is a [DeviceProvider]: find (LAN scan / mDNS / cloud login) ->
/// pair (password / press the button / cloud key) -> list what it has ->
/// generate tiles. All device traffic goes through a [Driver] from
/// [AddContext.driver], so it works at home (LAN) and away (relay -> bridge).
library;

import 'dart:async';
import 'dart:convert';
import 'dart:io';

import '../core/io_http.dart';

import '../drivers/driver.dart';
import '../models/models.dart';
import '../l10n/l10n.dart';

enum ProviderKind { local, cloud }

enum PairMode { none, password, button, cloudKey }

enum AddProblem {
  noNetwork,
  unreachable,
  notThisBrand,
  needsPassword,
  wrongPassword,

  /// A detail the device does not tell by itself (Sonoff DIY device id); see [DeviceProvider.credFields].
  needsDetails,
  buttonNotPressed,
  nothingToAdd,

  /// A camera answered, but no video address was found (ONVIF without profiles, no usual RTSP path).
  cameraNoStream,
  cloudBadKey,
  cloudOffline,
  cloudRateLimit,
  bridgeOld,
  bridgeOffline,
  unknown,
}

class AddDeviceError implements Exception {
  AddDeviceError(this.problem, [this.detail = '']);
  final AddProblem problem;
  final String detail;
  @override
  String toString() => 'AddDevice: ${problem.name} $detail';
}

/// Something found on the network (or typed in by the user).
class Candidate {
  Candidate({
    required this.provider,
    required this.address,
    this.id = '',
    this.model = '',
    this.name,
    this.viaBridge = false,
  });
  final String provider;
  final String address;
  final String id;
  final String model;
  final String? name;
  final bool viaBridge;

  String get title => (name?.isNotEmpty ?? false) ? name! : (model.isNotEmpty ? model : address);

  Map<String, dynamic> toJson() => {'provider': provider, 'address': address, 'id': id, 'model': model, 'name': ?name};
  factory Candidate.fromJson(Map j, {bool viaBridge = false}) => Candidate(
    provider: '${j['provider'] ?? ''}',
    address: '${j['address'] ?? ''}',
    id: '${j['id'] ?? ''}',
    model: '${j['model'] ?? ''}',
    name: j['name'] as String?,
    viaBridge: viaBridge,
  );
}

/// One thing the user can get a tile for (a relay channel, a lamp, a plug...).
class AddItem {
  AddItem({
    required this.key,
    required this.name,
    this.kind = 'switch',
    this.hasPower = false,
    this.subtitle = '',
    this.preselect = true,
    this.group = '',
  });
  final String key;

  /// Heading in the add list (type or room); empty = no headings.
  final String group;
  final bool preselect;
  final String name;
  final String kind;

  /// Power metering (or brightness for lamps): gets an extra tile when "extras" is on.
  final bool hasPower;
  final String subtitle;
}

class Connected {
  Connected({required this.connection, required this.label, required this.items, this.data = const {}});
  final ConnectionConfig connection;
  final String label;
  final List<AddItem> items;
  final Map<String, dynamic> data;
}

class CredField {
  const CredField(
    this.key,
    this.fi,
    this.en, {
    this.helpFi = '',
    this.helpEn = '',
    this.secret = false,
    this.hint = '',
    this.optional = false,
  });
  final String key, fi, en, helpFi, helpEn, hint;
  final bool secret;
  final bool optional;
}

class AddContext {
  AddContext({required this.driver, this.lang = 'fi'});

  /// Creates a driver for a connection (the app passes the LAN/relay router).
  final Driver Function(ConnectionConfig) driver;
  final String lang;
}

abstract class DeviceProvider {
  String get id;
  String get fi;
  String get en;
  String get descFi;
  String get descEn;
  String get category; // 'power', 'light', 'hub', 'cloud'
  List<String> get keywords;

  /// t298u: needs a technical middleman (MQTT broker, Z-Wave JS server): shown in simple mode only
  /// when the user searches (e.g. "aqara"), always in advanced mode.
  bool get advanced => false;
  ProviderKind get kind => ProviderKind.local;
  PairMode get pairMode;
  List<String> get mdnsTypes => const [];

  /// Where to find the address (shown under "type the address").
  String get addressHelpFi;
  String get addressHelpEn;
  String get addressHint => '192.168.x.x';

  /// Button pairing: what to press and how long the user has.
  String get pairHelpFi => '';
  String get pairHelpEn => '';
  Duration get pairWindow => const Duration(seconds: 60);

  /// Cloud login fields (server, key, ...). For local devices: extra fields shown together with
  /// the password (camera username) or when [AddProblem.needsDetails] is raised.
  List<CredField> get credFields => const [];

  /// A device found with mDNS ([label] = instance name without the service). Null = not this brand.
  Candidate? fromMdns(String address, String label, String service) =>
      Candidate(provider: id, address: address, id: label, name: label);

  String name(String lang) => tr(lang, fi, en);
  String desc(String lang) => tr(lang, descFi, descEn);

  /// LAN scan (pure Dart; also runs on the bridge for remote discovery).
  Future<List<Candidate>> scan(List<String> locals) async => const [];

  /// Button pairing: returns credentials once the user pressed the button.
  Future<Map<String, String>> pair(AddContext ctx, Candidate c, {void Function(int secondsLeft)? tick}) async =>
      const {};

  /// R541 (t322u): button pairing that also needs a password typed first (Bosch Smart Home
  /// system password) or shows a code to the user while waiting (Home Connect device flow,
  /// [message]). [creds] has what the user typed ('password' + cloud fields). Default: [pair].
  Future<Map<String, String>> pairWith(
    AddContext ctx,
    Candidate c,
    Map<String, String> creds, {
    void Function(int secondsLeft)? tick,
    void Function(String fi, String en)? message,
  }) => pair(ctx, c, tick: tick);

  /// The password must be typed before the button is pressed ([pairWith] gets it).
  bool get pairNeedsPassword => false;

  /// Replaces the generic "the device asks for a password" text (empty = generic).
  String get passwordHelpFi => '';
  String get passwordHelpEn => '';

  /// True when [creds] already hold the result of pairing (no button press needed).
  bool isPaired(Map<String, String> creds) => (creds['token'] ?? '').isNotEmpty;

  /// Drops the pairing result so the next connect pairs again.
  void forgetPairing(Map<String, String> creds) => creds.remove('token');

  /// Connects (with [creds]) and lists what can be added.
  Future<Connected> connect(AddContext ctx, Candidate c, Map<String, String> creds);

  List<TileConfig> tiles(
    Connected r, {
    Map<String, String> names = const {},
    Set<String> skip = const {},
    bool power = true,
    String lang = 'fi',
  });
}

// ---------------------------------------------------------------- helpers

bool isAuthError(Object e) {
  final s = e.toString();
  return s.contains('HTTP 401') || s.contains('HTTP 403') || s.toLowerCase().contains('unauthorized');
}

bool isNetError(Object e) {
  final s = e.toString().toLowerCase();
  return e is SocketException ||
      e is TimeoutException ||
      s.contains('socketexception') ||
      s.contains('timeout') ||
      s.contains('connection refused') ||
      s.contains('no route') ||
      s.contains('unreachable') ||
      s.contains('failed host lookup') ||
      s.startsWith('remote: ');
}

/// Turns a driver error into a problem a beginner can act on.
AddDeviceError explain(Object e, {bool havePassword = false}) {
  if (e is AddDeviceError) return e;
  final s = e.toString();
  if (s.toLowerCase().contains('remote: ')) {
    return AddDeviceError(s.contains('bridge_offline') ? AddProblem.bridgeOffline : AddProblem.unreachable, s);
  }
  if (s.contains('Connection missing') || s.contains('Unknown op')) return AddDeviceError(AddProblem.bridgeOld, s);
  if (isAuthError(e)) return AddDeviceError(havePassword ? AddProblem.wrongPassword : AddProblem.needsPassword, s);
  if (isNetError(e)) return AddDeviceError(AddProblem.unreachable, s);
  if (e is FormatException || s.contains('HTTP 404')) return AddDeviceError(AddProblem.notThisBrand, s);
  return AddDeviceError(AddProblem.unknown, s);
}

Future<String> getText(Driver d, String path) async => '${await d.send({'method': 'GET', 'path': path})}';

Object? decodeJson(String body) {
  try {
    return jsonDecode(body);
  } on FormatException {
    throw AddDeviceError(AddProblem.notThisBrand, 'not JSON');
  }
}

/// This device's private IPv4 addresses (Wi-Fi / Ethernet). Empty = not on a home network.
Future<List<String>> localIPv4s() async {
  try {
    final ifs = await NetworkInterface.list(type: InternetAddressType.IPv4, includeLoopback: false);
    return [
      for (final i in ifs)
        if (!i.name.toLowerCase().startsWith('rmnet') &&
            !i.name.startsWith('ccmni') &&
            !i.name.startsWith('tun') &&
            !isVirtualAdapter(i.name))
          for (final a in i.addresses)
            if (isPrivateIPv4(a.address)) a.address,
    ];
  } catch (_) {
    return const [];
  }
}

/// Hyper-V / WSL / VM host-only adapters (Windows "vEthernet (WSL)", VirtualBox, VMware,
/// Docker): not the home network – scanning them only slows the scan down (t157u).
bool isVirtualAdapter(String name) {
  final n = name.toLowerCase();
  // "vEthernet (External…)" can be the real LAN behind a Hyper-V external switch – keep it.
  return n.contains('wsl') ||
      n.contains('default switch') ||
      n.contains('virtualbox') ||
      n.contains('vmware') ||
      n.startsWith('docker') ||
      n.startsWith('br-') ||
      (n.startsWith('veth') && !n.startsWith('vethernet'));
}

bool isPrivateIPv4(String ip) {
  final p = ip.split('.').map(int.tryParse).toList();
  if (p.length != 4 || p.any((x) => x == null)) return false;
  return p[0] == 10 || (p[0] == 172 && p[1]! >= 16 && p[1]! <= 31) || (p[0] == 192 && p[1] == 168);
}

bool isIPv4(String s) => RegExp(r'^\d{1,3}(\.\d{1,3}){3}$').hasMatch(s);

/// "http://192.168.1.5:80/x" -> "192.168.1.5"
String hostOf(String input) {
  var s = input.trim();
  final i = s.indexOf('://');
  if (i >= 0) s = s.substring(i + 3);
  final slash = s.indexOf('/');
  if (slash >= 0) s = s.substring(0, slash);
  if (!s.startsWith('[') && s.split(':').length == 2) s = s.split(':').first;
  return s;
}

/// "192.168.1.5" / "192.168.1.5:8080" / "http://x/" -> base URL (keeps a port, no trailing slash).
String httpBase(String address, {String scheme = 'http'}) {
  var a = address.trim().replaceAll(RegExp(r'/+$'), '');
  if (!a.contains('://')) a = '$scheme://$a';
  return a;
}

/// Same /24 as one of [locals]? (Home routers almost always use /24.)
bool sameSubnet(String ip, List<String> locals) {
  if (!isIPv4(ip)) return true; // host names: can't tell
  String net(String a) => a.substring(0, a.lastIndexOf('.'));
  return locals.any((l) => net(l) == net(ip));
}

/// Probes every address of the local /24 networks in parallel.
Future<List<T>> scanSubnet<T>(
  List<String> locals,
  Future<T?> Function(HttpClient client, String ip) probe, {
  List<String>? hosts,
  Duration timeout = const Duration(milliseconds: 1500),
  int parallel = 48,
}) async {
  final targets = <String>[...?hosts];
  if (hosts == null) {
    for (final l in locals.toSet()) {
      final base = l.substring(0, l.lastIndexOf('.'));
      for (var i = 1; i < 255; i++) {
        if ('$base.$i' != l) targets.add('$base.$i');
      }
    }
  }
  final client = requireIoHttpClient(timeout: timeout, allowSelfSigned: true);
  final out = <T>[];
  var next = 0;
  Future<void> worker() async {
    while (next < targets.length) {
      final ip = targets[next++];
      try {
        final r = await probe(client, ip).timeout(timeout * 2);
        if (r != null) out.add(r);
      } catch (_) {}
    }
  }

  await Future.wait(List.generate(parallel, (_) => worker()));
  client.close(force: true);
  return out;
}

/// GET helper for scanners: JSON body of http(s)://ip/path, or null.
Future<Object?> probeJson(HttpClient c, Uri uri, {Duration timeout = const Duration(milliseconds: 1500)}) async {
  final req = await c.getUrl(uri).timeout(timeout);
  final res = await req.close().timeout(timeout);
  final body = await res.transform(utf8.decoder).join().timeout(timeout);
  if (res.statusCode != 200) return null;
  try {
    return jsonDecode(body);
  } catch (_) {
    return null;
  }
}

enum AddressIssue { ok, badFormat, notPrivate, otherSubnet }

/// Checks a typed device address ("192.168.0.172", "http://shelly.local").
/// [suggestion] is a likely intended address for typos like 191.168.1.20.
({AddressIssue issue, String? suggestion}) checkAddress(String input, List<String> locals) {
  final h = hostOf(input);
  if (h.isEmpty) return (issue: AddressIssue.badFormat, suggestion: null);
  final looksNumeric = RegExp(r'^[\d.]+$').hasMatch(h);
  if (!looksNumeric) return (issue: AddressIssue.ok, suggestion: null); // host name
  final parts = h.split('.');
  final nums = parts.map(int.tryParse).toList();
  if (parts.length != 4 || nums.any((n) => n == null || n > 255)) {
    return (issue: AddressIssue.badFormat, suggestion: null);
  }
  if (!isPrivateIPv4(h)) {
    String? s;
    if (nums[1] == 168) {
      s = '192.168.${nums[2]}.${nums[3]}';
    } else if (locals.isNotEmpty) {
      final net = locals.first.substring(0, locals.first.lastIndexOf('.'));
      s = '$net.${nums[3]}';
    }
    return (issue: AddressIssue.notPrivate, suggestion: s);
  }
  if (locals.isNotEmpty && !sameSubnet(h, locals)) return (issue: AddressIssue.otherSubnet, suggestion: null);
  return (issue: AddressIssue.ok, suggestion: null);
}

/// One-line plain-Finnish/English hint for [checkAddress], or null when fine.
/// t156u: an obviously-placeholder address hint: the detected subnet (e.g. "10.0.0.x") or
/// [fallback] ("192.168.x.x"). Hints are hintText only – never copied into a value.
String subnetHint(List<String> locals, [String fallback = '192.168.x.x']) {
  for (final l in locals) {
    final p = l.split('.');
    if (p.length == 4 && !l.startsWith('127.') && !l.startsWith('169.254.')) return '${p[0]}.${p[1]}.${p[2]}.x';
  }
  return fallback;
}

String? addressHint(String input, List<String> locals, String lang) {
  if (input.trim().isEmpty) return null;
  final r = checkAddress(input, locals);
  switch (r.issue) {
    case AddressIssue.ok:
      return null;
    case AddressIssue.badFormat:
      return tr(
        lang,
        'Osoite näyttää vajaalta. Muoto on neljä numeroa pisteillä, esim. 192.168.1.50.',
        'The address looks incomplete. Use four numbers with dots, e.g. 192.168.1.50.',
      );
    case AddressIssue.notPrivate:
      final s = r.suggestion == null ? '' : tr(lang, ' Tarkoititko ${r.suggestion}?', ' Did you mean ${r.suggestion}?');
      return tr(
        lang,
        'Tämä ei ole kotiverkon osoite (kotiverkon osoitteet alkavat yleensä 192.168.).$s',
        'This is not a home network address (they usually start with 192.168.).$s',
      );
    case AddressIssue.otherSubnet:
      final mine = locals.first.substring(0, locals.first.lastIndexOf('.'));
      return tr(
        lang,
        'Huom: tämä laite on verkossa $mine.x – laite ei ehkä ole samassa wifissä.',
        'Note: this device is on $mine.x – the device may be on another Wi-Fi.',
      );
  }
}
