import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../services/credential_store.dart';
import '../utils/app_paths.dart';
import '../utils/atomic_file.dart';
import '../utils/logging.dart';

class SettingsLoadResult {
  const SettingsLoadResult({
    required this.values,
    required this.credentialsBlocked,
  });

  final Map<String, dynamic>? values;
  final bool credentialsBlocked;
}

class SettingsRepository with Loggable {
  SettingsRepository({AppPaths? paths, CredentialStore? credentialStore})
    : _providedPaths = paths,
      _credentialStore = credentialStore ?? SecureCredentialStore.instance;

  static const int schemaVersion = 2;

  final AppPaths? _providedPaths;
  final CredentialStore _credentialStore;

  AppPaths get _paths => _providedPaths ?? AppPaths.instance;
  File get _file => File(p.join(_paths.configDirectory.path, 'settings.json'));

  Future<SettingsLoadResult> load() async {
    await AtomicFile.recover(_file);
    if (!await _file.exists()) {
      return const SettingsLoadResult(values: null, credentialsBlocked: false);
    }

    try {
      final decoded = jsonDecode(await _file.readAsString());
      if (decoded is! Map) {
        throw const FormatException('Invalid settings file root');
      }
      final root = Map<String, dynamic>.from(decoded);
      final values = root['settings'] is Map
          ? Map<String, dynamic>.from(root['settings'] as Map)
          : root;
      final legacySecret = values['rpcSecret']?.toString() ?? '';
      var credentialsBlocked = false;
      final needsRewrite =
          root['settings'] is! Map ||
          root['schemaVersion'] != schemaVersion ||
          values.containsKey('rpcSecret');

      try {
        final storedSecret = await _credentialStore.read(
          SecureCredentialStore.builtinSecretKey,
        );
        if (storedSecret == null && legacySecret.isNotEmpty) {
          await _credentialStore.writeVerified(
            SecureCredentialStore.builtinSecretKey,
            legacySecret,
          );
        }
        values['rpcSecret'] = storedSecret ?? legacySecret;
      } catch (error, stackTrace) {
        credentialsBlocked = true;
        w(
          'Built-in RPC secret migration failed',
          error: error,
          stackTrace: stackTrace,
        );
        values['rpcSecret'] = legacySecret;
      }

      if (needsRewrite && !credentialsBlocked) {
        await save(values);
      }
      return SettingsLoadResult(
        values: values,
        credentialsBlocked: credentialsBlocked,
      );
    } on FormatException catch (error, stackTrace) {
      await _backupCorruptFile();
      e(
        'Settings configuration is invalid; a backup was created',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> save(
    Map<String, dynamic> values, {
    bool credentialsBlocked = false,
  }) async {
    if (credentialsBlocked) {
      throw StateError(
        'Built-in RPC secret is not securely persisted; refusing to rewrite settings',
      );
    }

    final secret = values['rpcSecret']?.toString() ?? '';
    await _credentialStore.writeVerified(
      SecureCredentialStore.builtinSecretKey,
      secret,
    );
    final persisted = Map<String, dynamic>.from(values)..remove('rpcSecret');
    await AtomicFile.writeString(
      _file,
      jsonEncode({'schemaVersion': schemaVersion, 'settings': persisted}),
    );
  }

  Future<void> _backupCorruptFile() async {
    if (!await _file.exists()) {
      return;
    }
    await _file.copy(
      '${_file.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}',
    );
  }
}
