import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import '../models/aria2_instance.dart';
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
    // Get the executable path
    String executablePath = Platform.resolvedExecutable;
    Directory executableDir = Directory(executablePath).parent;

    // Data directory: data/config relative to executable
    String dataDirPath = '${executableDir.path}/data';
    Directory dataDir = Directory(dataDirPath);
    if (!dataDir.existsSync()) {
      this.d('Creating data directory: $dataDirPath');
      dataDir.createSync(recursive: true);
    }

    return dataDir;
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
        this.i('Added missing built-in instance');
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
        this.i('Migrated builtin instance protocol from http to ws');
      }

      await refreshBuiltinInstanceConfig();

      // Automatically connect to built-in instance on startup
      final builtinInstance = _instances.firstWhere(
        (instance) => instance.id == 'builtin',
      );
      await connectInstance(builtinInstance);

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
        this.d('Creating config directory: ${configDir.path}');
        configDir.createSync(recursive: true);
      }
      final filePath = '${configDir.path}/$_fileName';
      final file = File(filePath);

      this.d('Loading instance data: reading from $filePath');

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

        this.i('Successfully read ${_instances.length} instances');
      } else {
        this.d('Instance file does not exist, creating default instance');
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
    this.i('Built-in instance created');
  }

  /// Save instance data to file
  Future<void> _saveInstances() async {
    try {
      final dataDir = _getDataDirectory();
      final configDir = Directory('${dataDir.path}/config');
      if (!configDir.existsSync()) {
        this.d('Creating config directory: ${configDir.path}');
        await configDir.create(recursive: true);
      }
      final filePath = '${configDir.path}/$_fileName';
      final file = File(filePath);

      this.d('Saving instance data: writing to $filePath');

      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      final jsonString = jsonEncode(jsonList);

      await file.writeAsString(jsonString);
      this.d('Instance data saved successfully');

      // Verify file was successfully written
      if (!file.existsSync()) {
        this.w('Warning: File write verification failed, file does not exist');
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
        this.d('Instance ID duplicate, generating new ID');
      }

      // Ensure instance status is disconnected
      final newInstance = instance.copyWith(
        status: ConnectionStatus.disconnected,
      );

      _instances.add(newInstance);
      await _saveInstances();
      this.i('Instance added successfully: ${newInstance.name}');

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
        this.i('Instance updated successfully: ${updatedInstance.name}');
        notifyListeners();
      } else {
        this.w('Cannot find instance to update: ${updatedInstance.id}');
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
    } catch (e) {
      this.w('Connection test failed: $e');
      return false;
    }
  }

  /// Connect to instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      var resolvedInstance = instance;

      // If it's a built-in instance, start the process first
      if (instance.type == InstanceType.builtin) {
        await refreshBuiltinInstanceConfig(
          preserveStatus: instance.status,
          preserveVersion: instance.version,
        );
        resolvedInstance = getBuiltinInstance() ?? instance;
        this.i('Connecting to built-in instance, starting Aria2 process...');
        final isStarted = await _builtinInstanceService.startInstance();
        if (!isStarted) {
          this.e('Failed to start built-in Aria2 instance');
          updateInstanceInList(instance.id, ConnectionStatus.failed);
          return false;
        }

        // Give some time for the process to start
        await Future.delayed(const Duration(seconds: 1));
      }

      // Test connection
      final canConnect = await checkConnection(resolvedInstance);
      if (!canConnect) {
        this.w(
          'Connection test failed, cannot connect to instance: ${resolvedInstance.name}',
        );

        // If it's a built-in instance, stop the process if it was started
        if (instance.type == InstanceType.builtin) {
          await _builtinInstanceService.stopInstance();
        }

        updateInstanceInList(instance.id, ConnectionStatus.failed);
        return false;
      }

      // Create RPC client to get version information
      final client = Aria2RpcClient(resolvedInstance);
      String? version;
      try {
        version = await client.getVersion();
        this.i('Aria2 version: $version');
      } catch (e) {
        this.w('Failed to get Aria2 version: $e');
      } finally {
        client.close();
      }

      // Update status in instance list
      updateInstanceInList(
        instance.id,
        ConnectionStatus.connected,
        version: version,
      );

      if (instance.type == InstanceType.builtin) {
        _builtinInstanceService.onConnected();
      }

      this.d(
        'Instance connection status set - Instance: ${resolvedInstance.name}, Status: ${ConnectionStatus.connected}',
      );

      await _saveInstances();
      this.i('Successfully connected to instance: ${resolvedInstance.name}');
      notifyListeners();

      return true;
    } catch (e, stackTrace) {
      this.e('Failed to connect to instance', error: e, stackTrace: stackTrace);

      // If it's a built-in instance, stop the process if it was started
      if (instance.type == InstanceType.builtin) {
        await _builtinInstanceService.stopInstance();
      }

      // Update instance status to failed
      updateInstanceInList(instance.id, ConnectionStatus.failed);
      return false;
    }
  }

  /// Disconnect instance
  Future<void> disconnectInstance(Aria2Instance instance) async {
    // For built-in instances, stop the Aria2 process
    if (instance.type == InstanceType.builtin) {
      this.i('Disconnecting built-in instance, stopping Aria2 process...');
      await _builtinInstanceService.stopInstance();
    }

    // Update instance status to disconnected
    updateInstanceInList(instance.id, ConnectionStatus.disconnected);

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
  }) {
    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(
        status: status,
        version: version,
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
      this.d('Cannot find instance with ID $instanceId');
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
}
