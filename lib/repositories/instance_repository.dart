import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;

import '../models/aria2_instance.dart';
import '../services/credential_store.dart';
import '../utils/app_paths.dart';
import '../utils/atomic_file.dart';
import '../utils/logging.dart';

class InstanceLoadResult {
  const InstanceLoadResult({
    required this.instances,
    required this.credentialsBlocked,
  });

  final List<Aria2Instance> instances;
  final bool credentialsBlocked;
}

class InstanceRepository with Loggable {
  InstanceRepository({AppPaths? paths, CredentialStore? credentialStore})
    : _providedPaths = paths,
      _credentialStore = credentialStore ?? SecureCredentialStore.instance;

  static const int schemaVersion = 2;

  final AppPaths? _providedPaths;
  final CredentialStore _credentialStore;

  AppPaths get _paths => _providedPaths ?? AppPaths.instance;

  File get _file =>
      File(p.join(_paths.configDirectory.path, 'aria2_instances.json'));

  Future<InstanceLoadResult> load() async {
    await AtomicFile.recover(_file);
    if (!await _file.exists()) {
      return const InstanceLoadResult(
        instances: <Aria2Instance>[],
        credentialsBlocked: false,
      );
    }

    try {
      final decoded = jsonDecode(await _file.readAsString());
      final rawInstances = decoded is List
          ? decoded
          : decoded is Map<String, dynamic> && decoded['instances'] is List
          ? decoded['instances'] as List
          : throw const FormatException('Invalid instance file root');

      var credentialsBlocked = false;
      var needsRewrite =
          decoded is List ||
          (decoded is Map<String, dynamic> &&
              decoded['schemaVersion'] != schemaVersion);
      final instances = <Aria2Instance>[];

      for (final raw in rawInstances) {
        if (raw is! Map) {
          continue;
        }
        final map = Map<String, dynamic>.from(raw);
        needsRewrite =
            needsRewrite ||
            map.containsKey('secret') ||
            map.containsKey('rpcRequestHeaders') ||
            map.containsKey('status') ||
            map.containsKey('version') ||
            map.containsKey('errorMessage');
        final id = map['id']?.toString() ?? '';
        if (id.isEmpty) {
          continue;
        }

        final legacySecret = map['secret']?.toString() ?? '';
        final legacyHeaders = map['rpcRequestHeaders']?.toString() ?? '';
        String secret = legacySecret;
        String headers = legacyHeaders;
        try {
          if (id == 'builtin') {
            instances.add(
              Aria2Instance.fromJson({
                ...map,
                'secret': '',
                'rpcRequestHeaders': '',
                'status': ConnectionStatus.disconnected.name,
              }),
            );
            continue;
          }
          final secretKey = SecureCredentialStore.instanceSecretKey(id);
          final headersKey = SecureCredentialStore.instanceHeadersKey(id);
          final storedSecret = await _credentialStore.read(secretKey);
          final storedHeaders = await _credentialStore.read(headersKey);

          if (storedSecret == null && legacySecret.isNotEmpty) {
            await _credentialStore.writeVerified(secretKey, legacySecret);
            needsRewrite = true;
          } else if (storedSecret != null) {
            secret = storedSecret;
          }
          if (storedHeaders == null && legacyHeaders.isNotEmpty) {
            await _credentialStore.writeVerified(headersKey, legacyHeaders);
            needsRewrite = true;
          } else if (storedHeaders != null) {
            headers = storedHeaders;
          }
        } catch (error, stackTrace) {
          credentialsBlocked = true;
          w(
            'Secure credential migration failed for instance $id',
            error: error,
            stackTrace: stackTrace,
          );
        }

        instances.add(
          Aria2Instance.fromJson({
            ...map,
            'secret': secret,
            'rpcRequestHeaders': headers,
            'status': ConnectionStatus.disconnected.name,
          }),
        );
      }

      if (needsRewrite && !credentialsBlocked) {
        await save(instances);
      }
      return InstanceLoadResult(
        instances: instances,
        credentialsBlocked: credentialsBlocked,
      );
    } on FormatException catch (error, stackTrace) {
      await _backupCorruptFile();
      e(
        'Instance configuration is invalid; a backup was created',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  Future<void> save(
    List<Aria2Instance> instances, {
    bool credentialsBlocked = false,
  }) async {
    if (credentialsBlocked) {
      throw StateError(
        'Instance credentials are not securely persisted; refusing to rewrite configuration',
      );
    }

    for (final instance in instances) {
      await _persistCredentials(instance);
    }
    final jsonString = jsonEncode({
      'schemaVersion': schemaVersion,
      'instances': instances
          .map((instance) => instance.toPersistenceJson())
          .toList(),
    });
    await AtomicFile.writeString(_file, jsonString);
  }

  Future<void> deleteCredentials(String instanceId) async {
    await _credentialStore.delete(
      SecureCredentialStore.instanceSecretKey(instanceId),
    );
    await _credentialStore.delete(
      SecureCredentialStore.instanceHeadersKey(instanceId),
    );
  }

  Future<void> _persistCredentials(Aria2Instance instance) async {
    if (instance.type == InstanceType.builtin) {
      return;
    }
    await _credentialStore.writeVerified(
      SecureCredentialStore.instanceSecretKey(instance.id),
      instance.secret,
    );
    await _credentialStore.writeVerified(
      SecureCredentialStore.instanceHeadersKey(instance.id),
      instance.rpcRequestHeaders,
    );
  }

  Future<void> _backupCorruptFile() async {
    if (!await _file.exists()) {
      return;
    }
    final backup = File(
      '${_file.path}.corrupt.${DateTime.now().millisecondsSinceEpoch}',
    );
    await _file.copy(backup.path);
  }
}
