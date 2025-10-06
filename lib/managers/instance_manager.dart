import 'dart:io';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/aria2_instance.dart';

class InstanceManager {
  static final InstanceManager _instance = InstanceManager._internal();
  factory InstanceManager() => _instance;

  final List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;
  SharedPreferences? _prefs;

  InstanceManager._internal();

  // Initialize
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadInstances();
  }

  // Load instance configurations
  Future<void> loadInstances() async {
    if (_prefs == null) return;
    
    final instanceIds = _prefs!.getStringList('instanceIds') ?? [];
    _instances.clear();
    
    for (final id in instanceIds) {
      final instanceJson = _prefs!.getString('instance_$id');
      if (instanceJson != null) {
        try {
          final map = Map<String, dynamic>.from(
              _prefs!.getKeys().where((key) => key.startsWith('instance_$id/'))
                  .fold<Map<String, dynamic>>({}, (map, key) {
                final subKey = key.substring(('instance_$id/').length);
                map[subKey] = _prefs!.get(key);
                return map;
              }));
          
          // Add basic fields
          map['id'] = id;
          
          final instance = Aria2Instance.fromJson(map);
          _instances.add(instance);
          
          if (instance.isActive) {
            _activeInstance = instance;
          }
        } catch (e) {
          print('加载实例失败: $e');
        }
      }
    }
  }

  // Save instance configuration
  Future<void> _saveInstance(Aria2Instance instance) async {
    if (_prefs == null) return;
    
    final instanceMap = instance.toJson();
    
    // Save each field of the instance
    for (final entry in instanceMap.entries) {
      if (entry.key != 'id') {
        final key = 'instance_${instance.id}/${entry.key}';
        if (entry.value is String) {
          await _prefs!.setString(key, entry.value);
        } else if (entry.value is int) {
          await _prefs!.setInt(key, entry.value);
        } else if (entry.value is bool) {
          await _prefs!.setBool(key, entry.value);
        }
      }
    }
    
    // Update instance ID list
    final instanceIds = _prefs!.getStringList('instanceIds') ?? [];
    if (!instanceIds.contains(instance.id)) {
      instanceIds.add(instance.id);
      await _prefs!.setStringList('instanceIds', instanceIds);
    }
  }

  // Add instance
  Future<Aria2Instance> addInstance(Aria2Instance instance) async {
    _instances.add(instance);
    await _saveInstance(instance);
    return instance;
  }

  // Update instance
  Future<Aria2Instance> updateInstance(Aria2Instance instance) async {
    final index = _instances.indexWhere((i) => i.id == instance.id);
    if (index != -1) {
      _instances[index] = instance;
      await _saveInstance(instance);
    }
    
    // If updating the current active instance, sync update
    if (_activeInstance?.id == instance.id) {
      _activeInstance = instance;
    }
    
    return instance;
  }

  // Delete instance
  Future<void> deleteInstance(String id) async {
    if (_prefs == null) return;
    
    // If deleting the current active instance, disconnect first
    if (_activeInstance?.id == id) {
      await disconnectInstance();
    }
    
    _instances.removeWhere((instance) => instance.id == id);
    
    // Remove from storage
    final instanceIds = _prefs!.getStringList('instanceIds') ?? [];
    instanceIds.remove(id);
    await _prefs!.setStringList('instanceIds', instanceIds);
    
    // Delete all related fields
    final keysToRemove = _prefs!.getKeys().where((key) => key.startsWith('instance_$id')).toList();
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
  }

  // Get all instances
  List<Aria2Instance> getInstances() {
    return [..._instances];
  }

  // Get active instance
  Aria2Instance? getActiveInstance() {
    return _activeInstance;
  }

  // Connect instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      // If there is an active instance, disconnect first
      if (_activeInstance != null && _activeInstance!.id != instance.id) {
        await disconnectInstance();
      }
      
      // For local instance, start Aria2 process
      if (instance.type == InstanceType.local) {
        await startLocalAria2(instance);
      }
      
      // Mark as active instance
      instance.isActive = true;
      await updateInstance(instance);
      _activeInstance = instance;
      
      return true;
    } catch (e) {
      print('连接实例失败: $e');
      return false;
    }
  }

  // Disconnect instance
  Future<void> disconnectInstance() async {
    if (_activeInstance == null) return;
    
    try {
      // Stop local Aria2 process
      if (_activeInstance!.type == InstanceType.local && _activeInstance!.localProcess != null) {
        await stopLocalAria2(_activeInstance!);
      }
      
      // Cancel active status
      _activeInstance!.isActive = false;
      await updateInstance(_activeInstance!);
      _activeInstance = null;
    } catch (e) {
      print('断开实例连接失败: $e');
    }
  }

  // Start local Aria2 process
  Future<void> startLocalAria2(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.aria2Path == null) {
      throw Exception('无效的本地实例配置');
    }
    
    try {
      // Build start command
      final process = await Process.start(
        instance.aria2Path!,
        [
          '--enable-rpc',
          '--rpc-listen-all=true',
          '--rpc-allow-origin-all',
          '--rpc-listen-port=${instance.port}',
          if (instance.secret.isNotEmpty) '--rpc-secret=${instance.secret}',
        ],
        mode: ProcessStartMode.detachedWithStdio,
      );
      
      instance.localProcess = process;
      await updateInstance(instance);
      
      // Wait for process to start
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      throw Exception('启动本地Aria2失败: $e');
    }
  }

  // Stop local Aria2 process
  Future<void> stopLocalAria2(Aria2Instance instance) async {
    if (instance.localProcess != null) {
      try {
        instance.localProcess!.kill();
        await instance.localProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // Force terminate
              if (Platform.isWindows) {
                Process.run('taskkill', ['/F', '/PID', instance.localProcess!.pid.toString()]);
              } else {
                Process.killPid(instance.localProcess!.pid);
              }
              return 0;
          },
        );
      } catch (e) {
        print('停止Aria2进程失败: $e');
      } finally {
        instance.localProcess = null;
        await updateInstance(instance);
      }
    }
  }

  // Check if instance is online
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    try {
      // Simple connection check
      final socket = await Socket.connect(instance.host, instance.port, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}