// Pairs with a running molaplan-bridge by code and reads a value through it.
import 'dart:io';

import 'package:molaplan/remote/remote_client.dart';

Future<void> main(List<String> a) async {
  final p = await pairWithHome(relay: a[0], code: a[1], deviceName: 'cli-smoke');
  stdout.writeln('paired with "${p.name}"');
  final c = RemoteClient(p);
  stdout.writeln('ping -> ${await c.call('ping')}');
  final v = await c.call(
    'read',
    conn: {
      'id': 'x',
      'name': 'relay',
      'type': 'http',
      'settings': {'baseUrl': a[2]},
    },
    spec: {'path': '/health', 'jsonPath': 'service'},
  );
  stdout.writeln('read via bridge -> $v');
  await c.dispose();
  exit(0);
}
