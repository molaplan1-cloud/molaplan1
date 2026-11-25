import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'stores.dart';

export 'stores.dart';

class SecureSecretStore implements SecretStore {
  final _s = const FlutterSecureStorage();
  @override
  Future<String?> read(String key) => _s.read(key: key);
  @override
  Future<void> write(String key, String value) => _s.write(key: key, value: value);
  @override
  Future<void> delete(String key) => _s.delete(key: key);
}

class PrefsConfigStore implements ConfigStore {
  static const key = 'molaplan.config.v1';
  @override
  Future<String?> load() async => (await SharedPreferences.getInstance()).getString(key);
  @override
  Future<void> save(String json) async => (await SharedPreferences.getInstance()).setString(key, json);
}
