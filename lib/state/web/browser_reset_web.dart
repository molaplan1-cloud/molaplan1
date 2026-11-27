import 'package:web/web.dart' as web;

import 'secret_store_web.dart';

Future<void> wipeSecrets() => WebSecretStore.wipe();

Future<void> reload() async => web.window.location.reload();
