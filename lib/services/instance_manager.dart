import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

/// Unified instance management service class, combining the functionality of InstanceManager and NotifiableInstanceManager
class InstanceManager extends ChangeNotifier with Loggable {
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;
  final String _fileName = 'aria2_instances.json';
  
  InstanceManager() {
    initLogger();
  }

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  /// Initialize instance manager
  Future<void> initialize() async {
    try {
      await _loadInstances();
      // Ensure active instance doesn't trigger auto-connection during initialization
      // Explicitly set active instance status to disconnected
      if (_activeInstance != null) {
        updateInstanceInList(_activeInstance!.id, ConnectionStatus.disconnected);
      }
      logger.i('Instance manager initialization completed, loaded ${_instances.length} instances');
    } catch (e, stackTrace) {
      logger.e('Failed to initialize instance manager', error: e, stackTrace: stackTrace);
    }
    notifyListeners();
  }

  /// Load instance data
  Future<void> _loadInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.d('Loading instance data: reading from $filePath');
      
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        // Load instances and set all instance statuses to disconnected
        _instances = jsonList
            .map((e) => Aria2Instance.fromJson(e))
            .map((instance) => instance.copyWith(status: ConnectionStatus.disconnected))
            .toList();
        
        logger.i('Successfully read ${_instances.length} instances');
        
        // No longer set active instance, only set when user explicitly connects
        _activeInstance = null;
      } else {
        logger.d('Instance file does not exist, creating default instance');
        await _createDefaultInstance();
      }
    } catch (e, stackTrace) {
      logger.e('Failed to load instance data', error: e, stackTrace: stackTrace);
      await _createDefaultInstance();
    }
  }

  /// Create default instance
  Future<void> _createDefaultInstance() async {
    _instances = [
      Aria2Instance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '默认实例',
        type: InstanceType.local,
        protocol: 'http',
        host: 'localhost',
        port: 6800,
        secret: '',
        status: ConnectionStatus.disconnected, // Ensure default instance is in disconnected state
      ),
    ];
    _activeInstance = null; // Don't set default active instance
    await _saveInstances();
    logger.i('Default instance created');
  }

  /// Save instance data to file 
  Future<void> _saveInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.d('Saving instance data: writing to $filePath');
      
      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // Ensure directory exists
      final dir = Directory(directory.path);
      if (!dir.existsSync()) {
        logger.d('Creating directory: ${directory.path}');
        await dir.create(recursive: true);
      }
      
      await file.writeAsString(jsonString);
      logger.d('Instance data saved successfully');
      
      // Verify file was successfully written
      if (!file.existsSync()) {
        logger.w('Warning: File write verification failed, file does not exist');
      }
    } catch (e, stackTrace) {
      logger.e('Failed to save instance data', error: e, stackTrace: stackTrace);
    }
  }

  /// Add instance
  Future<void> addInstance(Aria2Instance instance) async {
    try {
      // Ensure ID is unique
      if (_instances.any((i) => i.id == instance.id)) {
        instance = instance.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
        logger.d('Instance ID duplicate, generating new ID');
      }
      
      // Ensure instance status is disconnected
      final newInstance = instance.copyWith(status: ConnectionStatus.disconnected);
      
      _instances.add(newInstance);
      await _saveInstances();
      logger.i('Instance added successfully: ${newInstance.name}');
      
      // Notify listeners
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('Failed to add instance', error: e, stackTrace: stackTrace);
      throw Exception('Failed to add instance: $e');
    }
  }

  /// Update instance
  Future<void> updateInstance(Aria2Instance updatedInstance) async {
    try {
      final index = _instances.indexWhere((i) => i.id == updatedInstance.id);
      if (index != -1) {
        _instances[index] = updatedInstance;
        
        // Update active instance reference if it's being updated
        if (_activeInstance?.id == updatedInstance.id) {
          _activeInstance = updatedInstance;
        }
        
        await _saveInstances();
        logger.i('Instance updated successfully: ${updatedInstance.name}');
        notifyListeners();
      } else {
        logger.w('Cannot find instance to update: ${updatedInstance.id}');
        throw Exception('Cannot find instance to update');
      }
    } catch (e, stackTrace) {
      logger.e('Failed to update instance', error: e, stackTrace: stackTrace);
      rethrow;
    }
  }

  /// Delete instance
  Future<void> deleteInstance(String instanceId) async {
    // Can't delete the last instance
    if (_instances.length <= 1) {
      throw Exception('Cannot delete the only instance');
    }
    
    // If the active instance is being deleted, switch to another instance
    if (_activeInstance?.id == instanceId) {
      final newActive = _instances.firstWhere((i) => i.id != instanceId);
      await setActiveInstance(newActive.id);
    }
    
    _instances.removeWhere((i) => i.id == instanceId);
    await _saveInstances();
    notifyListeners();
  }

  /// Set active instance
  Future<void> setActiveInstance(String instanceId) async {
    // Stop local process of current active instance if it's local
    if (_activeInstance?.type == InstanceType.local && 
        _activeInstance?.localProcess != null) {
      _activeInstance?.localProcess?.kill();
    }
    
    _activeInstance = _instances.firstWhere((i) => i.id == instanceId);
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
      logger.w('Connection test failed: $e');
      return false;
    }
  }

  /// Connect to instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      // First disconnect current active instance if any
      if (_activeInstance != null) {
        await disconnectInstance();
      }
      
      // Test connection
      final canConnect = await checkConnection(instance);
      if (!canConnect) {
        logger.w('Connection test failed, cannot connect to instance: ${instance.name}');
        updateInstanceInList(instance.id, ConnectionStatus.failed);
        return false;
      }
      
      // Update instance status to connected and set as active instance
      final connectedInstance = instance.copyWith(status: ConnectionStatus.connected);
      _activeInstance = connectedInstance;
      
      // Update status in instance list
      updateInstanceInList(instance.id, ConnectionStatus.connected);
      
      logger.d('Instance connection status set - Active instance: ${_activeInstance?.name}, Status: ${_activeInstance?.status}');
      
      await _saveInstances();
      logger.i('Successfully connected to instance: ${instance.name}');
      notifyListeners();
      
      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to connect to instance', error: e, stackTrace: stackTrace);
      // Update instance status to failed
      updateInstanceInList(instance.id, ConnectionStatus.failed);
      return false;
    }
  }

  /// Disconnect current instance
  Future<void> disconnectInstance() async {
    // First get current active instance ID for status update
    final activeInstanceId = _activeInstance?.id;
    
    // For local instances, stop the process
    if (_activeInstance?.type == InstanceType.local && 
        _activeInstance?.localProcess != null) {
      _activeInstance?.localProcess?.kill();
      _activeInstance?.localProcess = null;
    }
    
    // Update active instance status to disconnected
    if (activeInstanceId != null) {
      updateInstanceInList(activeInstanceId, ConnectionStatus.disconnected);
    }
    
    // Clear active instance
    _activeInstance = null;
    notifyListeners();
  }

  /// Check if instance is online
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    return await checkConnection(instance);
  }

  /// Start local aria2 process
  Future<bool> startLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.aria2Path == null) {
      logger.w('Attempting to start local process for non-local instance or instance with no path set');
      return false;
    }
    
    try {
      logger.d('Starting local process for instance: ${instance.name}');
      
      // Build the command with comprehensive arguments
      final List<String> args = [
        '--enable-rpc',
        '--rpc-listen-all=true',
        '--rpc-allow-origin-all',
        '--rpc-listen-port=${instance.port}',
        '--rpc-save-upload-metadata=true',
        '--rpc-max-request-size=10M',
        '--continue=true',
        '--max-concurrent-downloads=5',
        '--max-connection-per-server=16',
        '--min-split-size=10M',
        '--split=10',
        '--max-overall-download-limit=0',
        '--max-overall-upload-limit=0',
        '--max-download-limit=0',
        '--max-upload-limit=0',
        '--file-allocation=prealloc',
        '--disk-cache=64M',
        '--allow-overwrite=true',
        '--allow-piece-length-change=true',
        '--auto-file-renaming=true',
        '--check-integrity=true',
        '--remote-time=true',
        '--follow-torrent=mem',
        '--seed-time=0',
        '--bt-enable-lpd=true',
        '--bt-max-peers=100',
        '--bt-require-crypto=true',
        '--bt-save-metadata=true',
        '--bt-seed-unverified=true',
        '--listen-port=6881-6999',
        '--dht-listen-port=6881-6999',
      ];
      
      if (instance.secret.isNotEmpty) {
        args.add('--rpc-secret=${instance.secret}');
      }
      
      // Add log file argument
      final logDirectory = await getApplicationDocumentsDirectory();
      final logFilePath = '${logDirectory.path}/aria2_${instance.id}_${DateTime.now().millisecondsSinceEpoch}.log';
      args.add('--log-level=info');
      args.add('--log=$logFilePath');
      
      // Start the process
      final process = await Process.start(
        instance.aria2Path!,
        args,
        runInShell: true,
        mode: ProcessStartMode.detachedWithStdio,
      );
      
      // Monitor process exit
      process.exitCode.then((exitCode) {
        logger.w('Local Aria2 process exited with code: $exitCode, instance: ${instance.name}');
        // If the process exited unexpectedly, update instance status
        if (exitCode != 0) {
          final currentInstance = getInstanceById(instance.id);
          if (currentInstance != null && currentInstance.status == ConnectionStatus.connected) {
            updateInstanceInList(instance.id, ConnectionStatus.failed);
          }
        }
      });
      
      // Monitor stdout and stderr
      _monitorProcessOutput(process, instance.name);
      
      // Update instance with process reference
      final updatedInstance = instance.copyWith(localProcess: process);
      await updateInstance(updatedInstance);
      
      logger.i('Local process started successfully: ${instance.name}, PID: ${process.pid}');
      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to start local process', error: e, stackTrace: stackTrace);
      return false;
    }
  }
  
  /// Monitor process output
  void _monitorProcessOutput(Process process, String instanceName) {
    // Monitor stdout
    process.stdout.transform(utf8.decoder).listen((data) {
      logger.d('Aria2 [$instanceName] stdout: $data');
    });
    
    // Monitor stderr
    process.stderr.transform(utf8.decoder).listen((data) {
      logger.e('Aria2 [$instanceName] stderr: $data');
    });
  }

  /// Stop local aria2 process
  Future<bool> stopLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.localProcess == null) {
      logger.w('Attempting to stop non-local instance or instance with no process');
      return false;
    }
    
    try {
      // Kill the process
      instance.localProcess?.kill();
      
      // Update instance
      final updatedInstance = instance.copyWith(localProcess: null);
      await updateInstance(updatedInstance);
      
      logger.i('Local process stopped successfully: ${instance.name}');
      return true;
    } catch (e, stackTrace) {
      logger.e('Failed to stop local process', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// Update instance status in instance list
  void updateInstanceInList(String instanceId, ConnectionStatus status) {
    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(status: status);
      notifyListeners();
    }
  }

  /// Get instance by ID
  Aria2Instance? getInstanceById(String instanceId) {
    try {
      return _instances.firstWhere((instance) => instance.id == instanceId);
    } catch (e) {
      logger.d('Cannot find instance with ID $instanceId');
      return null;
    }
  }

  /// Get all instances (compatibility method)
  List<Aria2Instance> getInstances() {
    return _instances;
  }

  /// Get active instance (compatibility method)
  Aria2Instance? getActiveInstance() {
    return _activeInstance;
  }
}