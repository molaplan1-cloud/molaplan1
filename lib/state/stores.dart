/// Storage interfaces (pure Dart: also used by the headless bridge).
abstract class SecretStore {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

abstract class ConfigStore {
  Future<String?> load();
  Future<void> save(String json);
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
