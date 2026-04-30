import 'dart:async';
import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/aria2_instance.dart';
import '../utils/app_data_dir.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';
import 'builtin_instance_service.dart';

/// Unified instance management service class, combining the functionality of InstanceManager and NotifiableInstanceManager
class InstanceManager extends ChangeNotifier with Loggable {
  List<Aria2Instance> _instances = [];
  final String _fileName = 'aria2_instances.json';
  final BuiltinInstanceService _builtinInstanceService =
      BuiltinInstanceService();

  InstanceManager() {}

  List<Aria2Instance> get instances => _instances;

  /// Get the first connected instance
  Aria2Instance? getConnectedInstance() {
    try {
      return _instances.firstWhere(
        (instance) => instance.status == ConnectionStatus.connected,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get all connected instances
  List<Aria2Instance> getConnectedInstances() {
    return _instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList();
  }

  /// Get the built-in instance if it exists
  Aria2Instance? getBuiltinInstance() {
    try {
      return _instances.firstWhere(
        (instance) => instance.type == InstanceType.builtin,
      );
    } catch (e) {
      return null;
    }
  }

  /// Prefer the connected built-in instance, otherwise use the first connected instance.
  Aria2Instance? getPreferredTargetInstance() {
    final connectedInstances = getConnectedInstances();
    for (final instance in connectedInstances) {
      if (instance.type == InstanceType.builtin) {
        return instance;
      }
    }
    return connectedInstances.isNotEmpty ? connectedInstances.first : null;
  }

  /// Get program data directory
  Directory _getDataDirectory() {
    return getAppDataDirectory();
  }

  /// Initialize instance manager
  Future<void> initialize() async {
    try {
      await _loadInstances();

      // Ensure built-in instance always exists
      final hasBuiltinInstance = _instances.any(
        (instance) => instance.id == 'builtin',
      );
      if (!hasBuiltinInstance) {
        // Add built-in instance
        _instances.insert(
          0,
          Aria2Instance(
            id: 'builtin',
            name: '内建实例',
            type: InstanceType.builtin,
            protocol: 'ws',
            host: '127.0.0.1',
            port: 16800,
            secret: '',
            status: ConnectionStatus.disconnected,
          ),
        );
        await _saveInstances();
        this.i('Added missing built-in instance record');
      }

      // Migrate builtin instance protocol from http to ws
      final builtinIndex = _instances.indexWhere((i) => i.id == 'builtin');
      if (builtinIndex != -1 &&
          _instances[builtinIndex].protocol == 'http' &&
          _instances[builtinIndex].type == InstanceType.builtin) {
        _instances[builtinIndex] = _instances[builtinIndex].copyWith(
          protocol: 'ws',
        );
        await _saveInstances();
        this.i('Migrated built-in instance protocol from http to ws');
      }

      await refreshBuiltinInstanceConfig();

      // Automatically connect to built-in instance on startup (non-blocking)
      final builtinInstance = _instances.firstWhere(
        (instance) => instance.id == 'builtin',
      );
      unawaited(connectInstance(builtinInstance));

      this.i(
        'Instance manager initialization completed, loaded ${_instances.length} instances',
      );
    } catch (e, stackTrace) {
      this.e(
        'Failed to initialize instance manager',
        error: e,
        stackTrace: stackTrace,
      );
    }
    // Schedule notifyListeners to run after the current frame is built
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  /// Load instance data
  Future<void> _loadInstances() async {
    try {
      final dataDir = _getDataDirectory();
      final configDir = Directory('${dataDir.path}/config');
      if (!configDir.existsSync()) {
        configDir.createSync(recursive: true);
      }
      final filePath = '${configDir.path}/$_fileName';
      final file = File(filePath);

      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        // Load instances and set all instance statuses to disconnected
        _instances = jsonList
            .map((e) => Aria2Instance.fromJson(e))
            .map(
              (instance) =>
                  instance.copyWith(status: ConnectionStatus.disconnected),
            )
            .toList();

        this.i('Loaded ${_instances.length} instance records');
      } else {
        await _createDefaultInstance();
      }
    } catch (e, stackTrace) {
      this.e('Failed to load instance data', error: e, stackTrace: stackTrace);
      await _createDefaultInstance();
    }
  }

  /// Create default instance
  Future<void> _createDefaultInstance() async {
    _instances = [
      Aria2Instance(
        id: 'builtin',
        name: '内建实例',
        type: InstanceType.builtin,
        protocol: 'ws',
        host: '127.0.0.1',
        port: 16800,
        secret: '',
        status: ConnectionStatus.disconnected,
      ),
    ];
    await _saveInstances();
    this.i('Created default built-in instance record');
  }

  /// Save instance data to file
  Future<void> _saveInstances() async {
    try {
      final dataDir = _getDataDirectory();
      final configDir = Directory('${dataDir.path}/config');
      if (!configDir.existsSync()) {
        await configDir.create(recursive: true);
      }
      final filePath = '${configDir.path}/$_fileName';
      final file = File(filePath);

      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await file.writeAsString(jsonString);
      // Verify file was successfully written
      if (!file.existsSync()) {
        this.w(
          'Instance data file write verification failed because the file does not exist after save',
        );
      }
    } catch (e, stackTrace) {
      this.e('Failed to save instance data', error: e, stackTrace: stackTrace);
    }
  }

  /// Add instance
  Future<void> addInstance(Aria2Instance instance) async {
    try {
      // Only allow adding remote instances
      if (instance.type != InstanceType.remote) {
        throw Exception('只能添加远程实例');
      }

      // Ensure ID is unique
      if (_instances.any((i) => i.id == instance.id)) {
        instance = instance.copyWith(
          id: DateTime.now().millisecondsSinceEpoch.toString(),
        );
      }

      // Ensure instance status is disconnected
      final newInstance = instance.copyWith(
        status: ConnectionStatus.disconnected,
      );

      _instances.add(newInstance);
      await _saveInstances();
      this.i('Added instance ${newInstance.name}');

      // Notify listeners
      notifyListeners();
    } catch (e, stackTrace) {
      this.e('Failed to add instance', error: e, stackTrace: stackTrace);
      throw Exception('Failed to add instance: $e');
    }
  }

  /// Update instance
  Future<void> updateInstance(Aria2Instance updatedInstance) async {
    try {
      // Can't update built-in instance
      if (updatedInstance.id == 'builtin') {
        throw Exception('不能编辑内建实例');
      }

      final index = _instances.indexWhere((i) => i.id == updatedInstance.id);
      if (index != -1) {
        _instances[index] = updatedInstance;

        await _saveInstances();
        this.i('Updated instance ${updatedInstance.name}');
        notifyListeners();
      } else {
        this.w(
          'Cannot update instance because ${updatedInstance.id} was not found',
        );
        throw Exception('Cannot find instance to update');
      }
    } catch (e, stackTrace) {
      this.e('Failed to update instance', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete instance
  Future<void> deleteInstance(String instanceId) async {
    // Can't delete built-in instance
    if (instanceId == 'builtin') {
      throw Exception('不能删除内建实例');
    }

    // Can't delete the last instance
    if (_instances.length <= 1) {
      throw Exception('Cannot delete the only instance');
    }

    _instances.removeWhere((i) => i.id == instanceId);
    await _saveInstances();
    notifyListeners();
  }

  /// Check instance connection status
  Future<bool> checkConnection(Aria2Instance instance) async {
    try {
      final client = Aria2RpcClient(instance);
      final isConnected = await client.testConnection();
      client.close();
      return isConnected;
    } catch (e, stackTrace) {
      this.w(
        'Connection test failed for instance ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    }
  }

  /// Connect to instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      var resolvedInstance = instance;
      updateInstanceInList(
        instance.id,
        ConnectionStatus.connecting,
        version: instance.version,
        errorMessage: '',
      );

      // If it's a built-in instance, start the process first
      if (instance.type == InstanceType.builtin) {
        await refreshBuiltinInstanceConfig(
          preserveStatus: ConnectionStatus.connecting,
          preserveVersion: instance.version,
        );
        resolvedInstance = getBuiltinInstance() ?? instance;
        final validationError = _builtinInstanceService.validateBuiltinFiles();
        if (validationError != null) {
          this.e('Built-in instance validation failed: $validationError');
          updateInstanceInList(
            instance.id,
            ConnectionStatus.failed,
            errorMessage: validationError,
          );
          return false;
        }
        this.i('Starting built-in Aria2 process before connecting');
        final isStarted = await _builtinInstanceService.startInstance();
        if (!isStarted) {
          this.e('Failed to start built-in Aria2 instance');
          final startFailureMessage =
              _builtinInstanceService.validateBuiltinFiles() ??
              'Failed to start built-in Aria2 instance';
          updateInstanceInList(
            instance.id,
            ConnectionStatus.failed,
            errorMessage: startFailureMessage,
          );
          return false;
        }

        // Give some time for the process to start
        await Future.delayed(const Duration(seconds: 1));
      }

      // Test connection
      final canConnect = await checkConnection(resolvedInstance);
      if (!canConnect) {
        this.w(
          'Connection test failed, so instance ${resolvedInstance.name} was not connected',
        );

        // If it's a built-in instance, stop the process if it was started
        if (instance.type == InstanceType.builtin) {
          await _builtinInstanceService.stopInstance();
        }

        updateInstanceInList(
          instance.id,
          ConnectionStatus.failed,
          errorMessage: instance.type == InstanceType.builtin
              ? 'Built-in instance is offline or unreachable'
              : null,
        );
        return false;
      }

      // Create RPC client to get version information
      final client = Aria2RpcClient(resolvedInstance);
      String? version;
      try {
        version = await client.getVersion();
        this.i(
          'Retrieved aria2 version $version for instance ${resolvedInstance.name}',
        );
      } catch (e, stackTrace) {
        this.w(
          'Failed to get Aria2 version for instance ${resolvedInstance.name}',
          error: e,
          stackTrace: stackTrace,
        );
      } finally {
        client.close();
      }

      // Update status in instance list
      updateInstanceInList(
        instance.id,
        ConnectionStatus.connected,
        version: version,
        errorMessage: '',
      );

      if (instance.type == InstanceType.builtin) {
        _builtinInstanceService.onConnected();
      }

      await _saveInstances();
      this.i('Connected to instance ${resolvedInstance.name}');
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      this.e('Failed to connect to instance', error: e, stackTrace: stackTrace);

      // If it's a built-in instance, stop the process if it was started
      if (instance.type == InstanceType.builtin) {
        await _builtinInstanceService.stopInstance();
      }

      // Update instance status to failed
      updateInstanceInList(
        instance.id,
        ConnectionStatus.failed,
        version: instance.version,
        errorMessage: instance.type == InstanceType.builtin ? '$e' : null,
      );
      return false;
    }
  }

  /// Disconnect instance
  Future<void> disconnectInstance(Aria2Instance instance) async {
    // For built-in instances, stop the Aria2 process
    if (instance.type == InstanceType.builtin) {
      this.i(
        'Stopping built-in Aria2 process while disconnecting the built-in instance',
      );
      await _builtinInstanceService.stopInstance();
    }

    // Update instance status to disconnected
    updateInstanceInList(
      instance.id,
      ConnectionStatus.disconnected,
      version: instance.version,
      errorMessage: '',
    );

    notifyListeners();
  }

  /// Check if instance is online
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    return await checkConnection(instance);
  }

  /// Update instance status in instance list
  void updateInstanceInList(
    String instanceId,
    ConnectionStatus status, {
    String? version,
    String? errorMessage,
  }) {
    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(
        status: status,
        version: version,
        errorMessage: errorMessage,
      );
      // Schedule notifyListeners to run after the current frame is built
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  /// Get instance by ID
  Aria2Instance? getInstanceById(String instanceId) {
    try {
      return _instances.firstWhere((instance) => instance.id == instanceId);
    } catch (e) {
      return null;
    }
  }

  Future<void> refreshBuiltinInstanceConfig({
    ConnectionStatus? preserveStatus,
    String? preserveVersion,
  }) async {
    final builtinIndex = _instances.indexWhere(
      (instance) => instance.id == 'builtin',
    );
    if (builtinIndex == -1) {
      return;
    }

    final current = _instances[builtinIndex];
    final refreshed = _builtinInstanceService
        .getBuiltinInstanceConfig()
        .copyWith(
          status: preserveStatus ?? current.status,
          version: preserveVersion ?? current.version,
          errorMessage: current.errorMessage,
        );

    _instances[builtinIndex] = refreshed;
    await _saveInstances();
    notifyListeners();
  }

  @override
  void dispose() {
    _builtinInstanceService.dispose();
    super.dispose();
  }
}
