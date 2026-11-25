import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';

abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract class ConfigStore {
  Future<String?> load();
  Future<void> save(String json);
}

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

class MemorySecretStore implements SecretStore {
  final data = <String, String>{};
  @override
  Future<String?> read(String key) async => data[key];
  @override
  Future<void> write(String key, String value) async => data[key] = value;
  @override
  Future<void> delete(String key) async => data.remove(key);
}

class MemoryConfigStore implements ConfigStore {
  String? data;
  @override
  Future<String?> load() async => data;
  @override
  Future<void> save(String json) async => data = json;
}
