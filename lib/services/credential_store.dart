import 'package:flutter_secure_storage/flutter_secure_storage.dart';

abstract interface class CredentialStore {
  Future<String?> read(String key);
  Future<void> writeVerified(String key, String value);
  Future<void> delete(String key);
}

class SecureCredentialStore implements CredentialStore {
  SecureCredentialStore({FlutterSecureStorage? storage})
    : _storage = storage ?? const FlutterSecureStorage();

  static final SecureCredentialStore instance = SecureCredentialStore();

  final FlutterSecureStorage _storage;

  static String instanceSecretKey(String instanceId) =>
      'setsuna.instance.$instanceId.rpc_secret';
  static String instanceHeadersKey(String instanceId) =>
      'setsuna.instance.$instanceId.rpc_headers';
  static const String builtinSecretKey = 'setsuna.builtin.rpc_secret';

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> writeVerified(String key, String value) async {
    if (value.isEmpty) {
      await delete(key);
      return;
    }
    await _storage.write(key: key, value: value);
    final verified = await _storage.read(key: key);
    if (verified != value) {
      throw StateError('Secure credential verification failed for $key');
    }
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}
