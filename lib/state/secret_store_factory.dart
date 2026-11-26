/// R251: the secret store for this target – OS secure storage in the apps
/// (flutter_secure_storage), [WebSecretStore] in the browser.
library;

import 'stores.dart';
import 'web/secret_store_io.dart' if (dart.library.js_interop) 'web/secret_store_web.dart' as impl;

SecretStore platformSecretStore() => impl.create();
