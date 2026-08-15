import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:uuid/uuid.dart';
import '../models/aria2_instance.dart';
import '../repositories/instance_repository.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';
import 'builtin_instance_service.dart';

/// Unified instance management service class, combining the functionality of InstanceManager and NotifiableInstanceManager
class InstanceManager extends ChangeNotifier with Loggable {
  InstanceManager({InstanceRepository? repository})
    : _repository = repository ?? InstanceRepository();

  List<Aria2Instance> _instances = [];
  final InstanceRepository _repository;
  final Uuid _uuid = const Uuid();
  final BuiltinInstanceService _builtinInstanceService =
      BuiltinInstanceService();
  List<Aria2Instance>? _cachedConnectedInstances;
  bool _credentialsBlocked = false;
  final Map<String, Future<bool>> _connectionOperations = {};

  List<Aria2Instance> get instances => _instances;

  void _invalidateConnectedCache() {
    _cachedConnectedInstances = null;
  }

  /// Get all connected instances
  List<Aria2Instance> getConnectedInstances() {
    return _cachedConnectedInstances ??= _instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList(growable: false);
  }

  List<Aria2Instance> getRefreshableInstances() {
    return _instances
        .where(
          (instance) =>
              instance.status == ConnectionStatus.connected ||
              instance.status == ConnectionStatus.reconnecting,
        )
        .toList(growable: false);
  }

  /// Get the built-in instance if it exists
  Aria2Instance? getBuiltinInstance() {
    for (final instance in _instances) {
      if (instance.type == InstanceType.builtin) return instance;
    }
    return null;
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
            name: 'Built-in',
            type: InstanceType.builtin,
            protocol: 'ws',
            host: '127.0.0.1',
            port: 16800,
            secret: '',
            status: ConnectionStatus.disconnected,
          ),
        );
        _invalidateConnectedCache();
        await _saveInstances();
        i('Added missing built-in instance record');
      }

      // Migrate builtin instance protocol from http to ws
      final builtinIndex = _instances.indexWhere((i) => i.id == 'builtin');
      if (builtinIndex != -1 &&
          _instances[builtinIndex].protocol == 'http' &&
          _instances[builtinIndex].type == InstanceType.builtin) {
        _instances[builtinIndex] = _instances[builtinIndex].copyWith(
          protocol: 'ws',
        );
        _invalidateConnectedCache();
        await _saveInstances();
        i('Migrated built-in instance protocol from http to ws');
      }

      await refreshBuiltinInstanceConfig();

      // Finish the built-in startup attempt before presenting the main window.
      final builtinInstance = getBuiltinInstance();
      if (builtinInstance != null) {
        await connectInstance(builtinInstance);
      }

      i(
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
      final result = await _repository.load();
      _credentialsBlocked = result.credentialsBlocked;
      if (result.instances.isNotEmpty) {
        _instances = result.instances;
        _invalidateConnectedCache();
        i('Loaded ${_instances.length} instance records');
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
        name: 'Built-in',
        type: InstanceType.builtin,
        protocol: 'ws',
        host: '127.0.0.1',
        port: 16800,
        secret: '',
        status: ConnectionStatus.disconnected,
      ),
    ];
    _invalidateConnectedCache();
    await _saveInstances();
    i('Created default built-in instance record');
  }

  /// Save instance data to file
  Future<void> _saveInstances() async {
    try {
      await _repository.save(
        _instances,
        credentialsBlocked: _credentialsBlocked,
      );
    } catch (e, stackTrace) {
      this.e('Failed to save instance data', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Add instance
  Future<void> addInstance(Aria2Instance instance) async {
    try {
      // Only allow adding remote instances
      if (instance.type != InstanceType.remote) {
        throw Exception('Only remote instances can be added');
      }

      // Ensure ID is unique
      if (instance.id.isEmpty || _instances.any((i) => i.id == instance.id)) {
        instance = instance.copyWith(id: _uuid.v4());
      }

      // Ensure instance status is disconnected
      final newInstance = instance.copyWith(
        status: ConnectionStatus.disconnected,
      );

      _instances.add(newInstance);
      _invalidateConnectedCache();
      await _saveInstances();
      i('Added instance ${newInstance.name}');
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
        throw Exception('Cannot edit the built-in instance');
      }

      final index = _instances.indexWhere((i) => i.id == updatedInstance.id);
      if (index != -1) {
        _instances[index] = updatedInstance;
        _invalidateConnectedCache();

        await _saveInstances();
        i('Updated instance ${updatedInstance.name}');
        notifyListeners();
      } else {
        w('Cannot update instance because ${updatedInstance.id} was not found');
        throw Exception('Cannot find instance to update');
      }
    } catch (e, stackTrace) {
      this.e('Failed to update instance', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete instance
  Future<void> deleteInstance(String instanceId) async {
    try {
      // Can't delete built-in instance
      if (instanceId == 'builtin') {
        throw Exception('Cannot delete the built-in instance');
      }

      // Can't delete the last instance
      if (_instances.length <= 1) {
        throw Exception('Cannot delete the only instance');
      }

      _instances.removeWhere((i) => i.id == instanceId);
      _invalidateConnectedCache();
      await _saveInstances();
      await _repository.deleteCredentials(instanceId);
      notifyListeners();
    } catch (e, stackTrace) {
      this.e(
        'Failed to delete instance $instanceId',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Check instance connection status
  Future<bool> checkConnection(Aria2Instance instance) async {
    final client = Aria2RpcClient(instance);
    try {
      return await client.testConnection();
    } catch (e, stackTrace) {
      w(
        'Connection test failed for instance ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return false;
    } finally {
      await client.close();
    }
  }

  /// Connect to instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    final existing = _connectionOperations[instance.id];
    if (existing != null) {
      return existing;
    }
    final operation = _connectInstance(instance);
    _connectionOperations[instance.id] = operation;
    try {
      return await operation;
    } finally {
      if (identical(_connectionOperations[instance.id], operation)) {
        _connectionOperations.remove(instance.id);
      }
    }
  }

  Future<bool> _connectInstance(Aria2Instance instance) async {
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
          e('Built-in instance validation failed: $validationError');
          updateInstanceInList(
            instance.id,
            ConnectionStatus.failed,
            errorMessage: validationError,
          );
          return false;
        }
        i('Starting built-in Aria2 process before connecting');
        final isStarted = await _builtinInstanceService.startInstance();
        if (!isStarted) {
          e('Failed to start built-in Aria2 instance');
          final startFailureMessage =
              _builtinInstanceService.lastStartError ??
              _builtinInstanceService.validateBuiltinFiles() ??
              'Failed to start built-in Aria2 instance';
          updateInstanceInList(
            instance.id,
            ConnectionStatus.failed,
            errorMessage: startFailureMessage,
          );
          return false;
        }
      }

      final canConnect = instance.type == InstanceType.builtin
          ? await _waitForConnection(resolvedInstance)
          : await checkConnection(resolvedInstance);
      if (!canConnect) {
        w(
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
        i(
          'Retrieved aria2 version $version for instance ${resolvedInstance.name}',
        );
      } catch (e, stackTrace) {
        w(
          'Failed to get Aria2 version for instance ${resolvedInstance.name}',
          error: e,
          stackTrace: stackTrace,
        );
      } finally {
        await client.close();
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

      i('Connected to instance ${resolvedInstance.name}');
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

  Future<bool> _waitForConnection(Aria2Instance instance) async {
    final deadline = DateTime.now().add(const Duration(seconds: 10));
    var delay = const Duration(milliseconds: 150);
    while (DateTime.now().isBefore(deadline)) {
      if (await checkConnection(instance)) {
        return true;
      }
      await Future<void>.delayed(delay);
      final nextMilliseconds = (delay.inMilliseconds * 1.6).round();
      delay = Duration(milliseconds: nextMilliseconds.clamp(150, 1000));
    }
    return false;
  }

  /// Disconnect instance
  Future<void> disconnectInstance(Aria2Instance instance) async {
    final connectionOperation = _connectionOperations[instance.id];
    if (connectionOperation != null) {
      await connectionOperation;
    }
    // For built-in instances, stop the Aria2 process
    if (instance.type == InstanceType.builtin) {
      i(
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
      _invalidateConnectedCache();
      // Schedule notifyListeners to run after the current frame is built
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    }
  }

  void updateConnectionHealth(
    String instanceId, {
    required bool isStale,
    required int consecutiveFailures,
    String? errorMessage,
  }) {
    final instance = getInstanceById(instanceId);
    if (instance == null) {
      return;
    }
    if (isStale &&
        consecutiveFailures >= 2 &&
        instance.status == ConnectionStatus.connected) {
      updateInstanceInList(
        instanceId,
        ConnectionStatus.reconnecting,
        version: instance.version,
        errorMessage: errorMessage,
      );
      return;
    }
    if (!isStale && instance.status == ConnectionStatus.reconnecting) {
      updateInstanceInList(
        instanceId,
        ConnectionStatus.connected,
        version: instance.version,
        errorMessage: '',
      );
    }
  }

  /// Get instance by ID
  Aria2Instance? getInstanceById(String instanceId) {
    for (final instance in _instances) {
      if (instance.id == instanceId) return instance;
    }
    return null;
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
    _invalidateConnectedCache();
    notifyListeners();
  }

  @override
  void dispose() {
    _builtinInstanceService.dispose();
    super.dispose();
  }
}
