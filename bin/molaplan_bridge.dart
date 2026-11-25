// Headless Molaplan home bridge for Raspberry Pi / Linux / Windows servers.
//
//   dart compile exe bin/molaplan_bridge.dart -o molaplan-bridge
//   ./molaplan-bridge --name "Mökki" --pair
//
// Commands while running: pair | devices | remove <id> | status | rules | quit
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:molaplan/remote/bridge_core.dart';
import 'package:molaplan/remote/executor.dart';
import 'package:molaplan/remote/protocol.dart';
import 'package:molaplan/state/stores.dart';
import 'package:qr/qr.dart';

/// Secrets in one JSON file readable only by the owner.
class FileSecretStore implements SecretStore {
  FileSecretStore(this.file);
  final File file;
  Map<String, String> _read() {
    if (!file.existsSync()) return {};
    return Map<String, String>.from(jsonDecode(file.readAsStringSync()) as Map);
  }

  void _write(Map<String, String> m) {
    file.parent.createSync(recursive: true);
    final tmp = File('${file.path}.tmp')..writeAsStringSync(jsonEncode(m));
    if (!Platform.isWindows) Process.runSync('chmod', ['600', tmp.path]);
    tmp.renameSync(file.path);
  }

  @override
  Future<String?> read(String key) async => _read()[key];
  @override
  Future<void> write(String key, String value) async => _write(_read()..[key] = value);
  @override
  Future<void> delete(String key) async => _write(_read()..remove(key));
}

String qrText(String data) {
  final qr = QrImage(QrCode.fromData(data: data, errorCorrectLevel: QrErrorCorrectLevel.L));
  final n = qr.moduleCount;
  bool dark(int x, int y) => x >= 0 && y >= 0 && x < n && y < n && qr.isDark(y, x);
  final b = StringBuffer();
  for (var y = -2; y < n + 2; y += 2) {
    for (var x = -2; x < n + 2; x++) {
      final top = dark(x, y), bottom = dark(x, y + 1);
      // Light modules are drawn as blocks so the code works on dark terminals.
      b.write(!top && !bottom ? '█' : (!top ? '▀' : (!bottom ? '▄' : ' ')));
    }
    b.writeln();
  }
  return b.toString();
}

void usage() {
  stdout.writeln('''
molaplan-bridge – Molaplan home bridge (remote access without port forwarding)

Options:
  --data DIR       where the bridge identity is kept (default ~/.molaplan-bridge)
  --relay URL      relay server (default $defaultRelayUrl)
  --name NAME      home name shown on phones (default "Koti")
  --config FILE    Molaplan export (JSON) offered to phones as "Copy home dashboards"
  --pair           show a pairing code right after start
  -h, --help

While running, type: pair | devices | remove <id> | status | rules | quit''');
}

Future<void> main(List<String> args) async {
  String? arg(String name) {
    final i = args.indexOf(name);
    return i >= 0 && i + 1 < args.length ? args[i + 1] : null;
  }

  if (args.contains('-h') || args.contains('--help')) return usage();
  final home = Platform.environment['HOME'] ?? Platform.environment['USERPROFILE'] ?? '.';
  final dataDir = arg('--data') ?? '$home/.molaplan-bridge';
  final configFile = arg('--config');

  final lines = stdin.transform(utf8.decoder).transform(const LineSplitter()).asBroadcastStream();
  Completer<bool>? approval;

  final bridge = BridgeCore(
    store: FileSecretStore(File('$dataDir/bridge.json')),
    executor: RemoteExecutor(
      configProvider: configFile == null
          ? null
          : () => jsonDecode(File(configFile).readAsStringSync()) as Map<String, dynamic>,
    ),
    approve: (name) {
      stdout.writeln('\n>>> "$name" wants to pair with the 6-digit code. Accept? [y/N]');
      approval = Completer<bool>();
      return approval!.future;
    },
    log: (m) => stdout.writeln('[${DateTime.now().toIso8601String().substring(11, 19)}] $m'),
  );
  await bridge.init(relayUrl: arg('--relay') ?? defaultRelayUrl, name: arg('--name') ?? 'Koti');
  if (arg('--relay') != null && bridge.relay != arg('--relay')) await bridge.setRelay(arg('--relay')!);
  if (arg('--name') != null && bridge.homeName != arg('--name')) await bridge.rename(arg('--name')!);
  stdout.writeln('Molaplan bridge "${bridge.homeName}" – home ${bridge.home} – relay ${bridge.relay}');
  bridge.start();

  Future<void> pair() async {
    if (bridge.link != BridgeLink.online) {
      await bridge.changes.firstWhere((_) => bridge.link == BridgeLink.online).timeout(const Duration(seconds: 30));
    }
    final w = await bridge.startPairing();
    stdout.writeln(qrText(w.invite.toUri()));
    stdout.writeln('Scan the QR code in Molaplan (Settings → Remote access → Connect this device to home)');
    stdout.writeln('or type the code:  ${w.code.substring(0, 3)} ${w.code.substring(3)}   (valid 10 min)');
  }

  bridge.onPaired.listen((d) => stdout.writeln('Paired: ${d.name} (${d.id})'));
  if (args.contains('--pair')) unawaited(pair().catchError((Object e) => stdout.writeln('pairing failed: $e')));

  ProcessSignal.sigint.watch().listen((_) async {
    await bridge.dispose();
    exit(0);
  });

  await for (final l in lines) {
    final cmd = l.trim();
    final a = approval;
    if (a != null && !a.isCompleted) {
      a.complete(cmd.toLowerCase().startsWith('y') || cmd.toLowerCase().startsWith('k'));
      continue;
    }
    if (cmd == 'pair') {
      await pair().catchError((Object e) => stdout.writeln('pairing failed: $e'));
    } else if (cmd == 'devices') {
      for (final d in bridge.devices) {
        stdout.writeln('${d.id}  ${d.name}  added ${d.added.toIso8601String().substring(0, 10)}');
      }
      if (bridge.devices.isEmpty) stdout.writeln('(no paired devices)');
    } else if (cmd.startsWith('remove ')) {
      await bridge.removeDevice(cmd.substring(7).trim());
      stdout.writeln('removed');
    } else if (cmd == 'status') {
      stdout.writeln('relay: ${bridge.link.name}${bridge.lastError == null ? '' : ' (${bridge.lastError})'}');
    } else if (cmd == 'rules') {
      // Price rules and thermostats pushed from the app; they run here every minute.
      final jobs = bridge.rules.jobs;
      if (jobs.isEmpty) stdout.writeln('(no price rules – add one in the app: long-press a tile → Price control)');
      for (final j in jobs) {
        final s = bridge.rules.status[j.rule.id];
        final next = s == null || s.plan.isEmpty ? '' : '  next on ${_hm(s.plan.first.$1)}–${_hm(s.plan.first.$2)}';
        final state = s?.on == null ? 'waiting for prices' : (s!.on! ? 'ON' : 'off');
        stdout.writeln('${j.title}: ${j.rule.describe()}  [$state]${s?.error == null ? '' : '  error: ${s!.error}'}$next');
      }
    } else if (cmd == 'quit' || cmd == 'exit') {
      break;
    } else if (cmd.isNotEmpty) {
      stdout.writeln('commands: pair | devices | remove <id> | status | rules | quit');
    }
  }
  await bridge.dispose();
  exit(0);
}

String _hm(DateTime t) => '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}';
