import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:setsuna/models/aria2_instance.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/repositories/instance_repository.dart';
import 'package:setsuna/repositories/settings_repository.dart';
import 'package:setsuna/services/credential_store.dart';
import 'package:setsuna/services/data_migration_service.dart';
import 'package:setsuna/utils/app_paths.dart';
import 'package:setsuna/utils/atomic_file.dart';

class _MemoryCredentialStore implements CredentialStore {
  final Map<String, String> values = <String, String>{};
  bool failWrites = false;
  int writeCalls = 0;

  @override
  Future<void> delete(String key) async {
    values.remove(key);
  }

  @override
  Future<String?> read(String key) async => values[key];

  @override
  Future<void> writeVerified(String key, String value) async {
    writeCalls++;
    if (failWrites) {
      throw StateError('secure storage unavailable');
    }
    if (value.isEmpty) {
      values.remove(key);
    } else {
      values[key] = value;
    }
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory root;
  late Directory support;
  late Directory legacy;
  late AppPaths paths;

  setUp(() async {
    root = await Directory.systemTemp.createTemp('setsuna_repository_test_');
    support = Directory(p.join(root.path, 'support'));
    legacy = Directory(p.join(root.path, 'legacy'));
    paths = AppPaths.testing(
      supportDirectory: support,
      legacyPortableDirectory: legacy,
    );
    await paths.ensureDirectories();
  });

  tearDown(() async {
    if (await root.exists()) {
      await root.delete(recursive: true);
    }
  });

  test('migrates legacy portable data without deleting the source', () async {
    final legacySettings = File(p.join(legacy.path, 'config', 'settings.json'));
    await legacySettings.parent.create(recursive: true);
    await legacySettings.writeAsString(jsonEncode(<String, Object>{'x': 1}));
    final legacySession = File(p.join(legacy.path, 'core', 'aria2.session'));
    await legacySession.parent.create(recursive: true);
    await legacySession.writeAsString('gid');

    final migrated = await DataMigrationService(
      paths: paths,
    ).migrateLegacyPortableData();

    expect(migrated, isTrue);
    expect(await legacySettings.exists(), isTrue);
    expect(
      await File(
        p.join(support.path, 'config', 'settings.json'),
      ).readAsString(),
      contains('"x":1'),
    );
    expect(
      await File(p.join(support.path, 'core', 'aria2.session')).readAsString(),
      'gid',
    );
    expect(await paths.migrationMarker.exists(), isTrue);
    expect(
      await DataMigrationService(paths: paths).migrateLegacyPortableData(),
      isFalse,
    );
  });

  test(
    'settings repository migrates builtin secret and sanitizes json',
    () async {
      final file = File(p.join(paths.configDirectory.path, 'settings.json'));
      await file.writeAsString(
        jsonEncode(<String, Object>{
          'rpcSecret': 'legacy-secret',
          'autoStart': true,
        }),
      );
      final credentials = _MemoryCredentialStore();
      final repository = SettingsRepository(
        paths: paths,
        credentialStore: credentials,
      );

      final result = await repository.load();

      expect(result.credentialsBlocked, isFalse);
      expect(result.values?['rpcSecret'], 'legacy-secret');
      expect(
        credentials.values[SecureCredentialStore.builtinSecretKey],
        'legacy-secret',
      );
      final persisted = await file.readAsString();
      expect(persisted, contains('"schemaVersion":2'));
      expect(persisted, isNot(contains('legacy-secret')));
      expect(persisted, isNot(contains('rpcSecret')));
    },
  );

  test(
    'settings repository leaves legacy json intact when secure storage fails',
    () async {
      final file = File(p.join(paths.configDirectory.path, 'settings.json'));
      const legacyJson = '{"rpcSecret":"keep-me","autoStart":true}';
      await file.writeAsString(legacyJson);
      final credentials = _MemoryCredentialStore()..failWrites = true;

      final result = await SettingsRepository(
        paths: paths,
        credentialStore: credentials,
      ).load();

      expect(result.credentialsBlocked, isTrue);
      expect(result.values?['rpcSecret'], 'keep-me');
      expect(await file.readAsString(), legacyJson);
    },
  );

  test('settings repository only writes a changed builtin secret', () async {
    final file = File(p.join(paths.configDirectory.path, 'settings.json'));
    await file.writeAsString(
      jsonEncode(<String, Object>{
        'schemaVersion': SettingsRepository.schemaVersion,
        'settings': <String, Object>{'autoStart': false},
      }),
    );
    final credentials = _MemoryCredentialStore();
    final repository = SettingsRepository(
      paths: paths,
      credentialStore: credentials,
    );
    final result = await repository.load();
    final values = Map<String, dynamic>.from(result.values!);

    await repository.save(values);
    await repository.save(values);
    expect(credentials.writeCalls, 0);

    values['rpcSecret'] = 'new-secret';
    await repository.save(values);
    await repository.save(values);
    expect(credentials.writeCalls, 1);

    values['rpcSecret'] = '';
    await repository.save(values);
    expect(credentials.writeCalls, 2);
  });

  test(
    'instance repository stores credentials separately and deletes them',
    () async {
      final file = File(
        p.join(paths.configDirectory.path, 'aria2_instances.json'),
      );
      await file.writeAsString(
        jsonEncode(<Map<String, Object>>[
          <String, Object>{
            'id': 'remote-1',
            'name': 'Remote',
            'type': 'remote',
            'protocol': 'wss',
            'host': 'example.com',
            'port': 443,
            'secret': 'secret-value',
            'rpcRequestHeaders': 'Authorization: Bearer value',
          },
        ]),
      );
      final credentials = _MemoryCredentialStore();
      final repository = InstanceRepository(
        paths: paths,
        credentialStore: credentials,
      );

      final result = await repository.load();

      expect(result.instances.single.secret, 'secret-value');
      expect(
        result.instances.single.rpcRequestHeaders,
        'Authorization: Bearer value',
      );
      final persisted = await file.readAsString();
      expect(persisted, isNot(contains('secret-value')));
      expect(persisted, isNot(contains('Authorization')));
      expect(persisted, isNot(contains('status')));

      await repository.deleteCredentials('remote-1');
      expect(credentials.values, isEmpty);
    },
  );

  test('instance persistence omits runtime state', () async {
    final credentials = _MemoryCredentialStore();
    final repository = InstanceRepository(
      paths: paths,
      credentialStore: credentials,
    );
    await repository.save(<Aria2Instance>[
      Aria2Instance(
        id: 'remote-2',
        name: 'Remote',
        type: InstanceType.remote,
        protocol: 'https',
        host: 'example.com',
        port: 443,
        status: ConnectionStatus.failed,
        version: '1.0',
        errorMessage: 'offline',
      ),
    ]);

    final persisted = await File(
      p.join(paths.configDirectory.path, 'aria2_instances.json'),
    ).readAsString();
    expect(persisted, isNot(contains('failed')));
    expect(persisted, isNot(contains('offline')));
    expect(persisted, isNot(contains('version')));
  });

  test('instance repository skips only malformed records', () async {
    final file = File(
      p.join(paths.configDirectory.path, 'aria2_instances.json'),
    );
    await file.writeAsString(
      jsonEncode(<Map<String, Object>>[
        <String, Object>{
          'id': 'valid',
          'name': 'Valid',
          'type': 'remote',
          'protocol': 'http',
          'host': 'localhost',
          'port': 6800,
        },
        <String, Object>{
          'id': 'malformed',
          'name': 'Malformed',
          'type': 'remote',
          'protocol': 'http',
          'host': 'localhost',
          'port': 'not-a-port',
        },
      ]),
    );

    final result = await InstanceRepository(
      paths: paths,
      credentialStore: _MemoryCredentialStore(),
    ).load();

    expect(result.instances.map((instance) => instance.id), <String>['valid']);
    expect(await file.readAsString(), isNot(contains('malformed')));
  });

  test(
    'atomic writes serialize concurrent updates for the same path',
    () async {
      final file = File(p.join(paths.configDirectory.path, 'concurrent.json'));

      final first = AtomicFile.writeString(file, 'first');
      final second = AtomicFile.writeString(file, 'second');
      await Future.wait(<Future<void>>[first, second]);

      expect(await file.readAsString(), 'second');
      expect(await File('${file.path}.bak').exists(), isFalse);
    },
  );

  test('settings load continues when fallback persistence fails', () async {
    final credentials = _MemoryCredentialStore()..failWrites = true;
    final settings = Settings(
      repository: SettingsRepository(
        paths: paths,
        credentialStore: credentials,
      ),
    );

    await settings.loadSettings();

    expect(settings.isLoaded, isTrue);
    expect(settings.maxConcurrentDownloads, 5);
  });
}
