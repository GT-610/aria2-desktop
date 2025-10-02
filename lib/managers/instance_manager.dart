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

  // 初始化
  Future<void> initialize() async {
    _prefs = await SharedPreferences.getInstance();
    await loadInstances();
  }

  // 加载实例配置
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
          
          // 添加基本字段
          map['id'] = id;
          
          final instance = Aria2Instance.fromMap(map);
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

  // 保存实例配置
  Future<void> _saveInstance(Aria2Instance instance) async {
    if (_prefs == null) return;
    
    final instanceMap = instance.toMap();
    
    // 保存单个实例的每个字段
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
    
    // 更新实例ID列表
    final instanceIds = _prefs!.getStringList('instanceIds') ?? [];
    if (!instanceIds.contains(instance.id)) {
      instanceIds.add(instance.id);
      await _prefs!.setStringList('instanceIds', instanceIds);
    }
  }

  // 添加实例
  Future<Aria2Instance> addInstance(Aria2Instance instance) async {
    _instances.add(instance);
    await _saveInstance(instance);
    return instance;
  }

  // 更新实例
  Future<Aria2Instance> updateInstance(Aria2Instance instance) async {
    final index = _instances.indexWhere((i) => i.id == instance.id);
    if (index != -1) {
      _instances[index] = instance;
      await _saveInstance(instance);
    }
    
    // 如果更新的是当前活动实例，同步更新
    if (_activeInstance?.id == instance.id) {
      _activeInstance = instance;
    }
    
    return instance;
  }

  // 删除实例
  Future<void> deleteInstance(String id) async {
    if (_prefs == null) return;
    
    // 如果删除的是当前活动实例，断开连接
    if (_activeInstance?.id == id) {
      await disconnectInstance();
    }
    
    _instances.removeWhere((instance) => instance.id == id);
    
    // 从存储中删除
    final instanceIds = _prefs!.getStringList('instanceIds') ?? [];
    instanceIds.remove(id);
    await _prefs!.setStringList('instanceIds', instanceIds);
    
    // 删除所有相关字段
    final keysToRemove = _prefs!.getKeys().where((key) => key.startsWith('instance_$id')).toList();
    for (final key in keysToRemove) {
      await _prefs!.remove(key);
    }
  }

  // 获取所有实例
  List<Aria2Instance> getInstances() {
    return [..._instances];
  }

  // 获取活动实例
  Aria2Instance? getActiveInstance() {
    return _activeInstance;
  }

  // 连接实例
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      // 如果当前有活动实例，先断开
      if (_activeInstance != null && _activeInstance!.id != instance.id) {
        await disconnectInstance();
      }
      
      // 对于本地实例，启动Aria2进程
      if (instance.type == InstanceType.local) {
        await startLocalAria2(instance);
      }
      
      // 标记为活动实例
      instance.isActive = true;
      await updateInstance(instance);
      _activeInstance = instance;
      
      return true;
    } catch (e) {
      print('连接实例失败: $e');
      return false;
    }
  }

  // 断开实例连接
  Future<void> disconnectInstance() async {
    if (_activeInstance == null) return;
    
    try {
      // 停止本地Aria2进程
      if (_activeInstance!.type == InstanceType.local && _activeInstance!.localProcess != null) {
        await stopLocalAria2(_activeInstance!);
      }
      
      // 取消活动状态
      _activeInstance!.isActive = false;
      await updateInstance(_activeInstance!);
      _activeInstance = null;
    } catch (e) {
      print('断开实例连接失败: $e');
    }
  }

  // 启动本地Aria2进程
  Future<void> startLocalAria2(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.aria2Path == null) {
      throw Exception('无效的本地实例配置');
    }
    
    try {
      // 构建启动命令
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
      
      // 等待进程启动
      await Future.delayed(const Duration(seconds: 2));
    } catch (e) {
      throw Exception('启动本地Aria2失败: $e');
    }
  }

  // 停止本地Aria2进程
  Future<void> stopLocalAria2(Aria2Instance instance) async {
    if (instance.localProcess != null) {
      try {
        instance.localProcess!.kill();
        await instance.localProcess!.exitCode.timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            // 强制终止
            if (Platform.isWindows) {
              Process.run('taskkill', ['/F', '/PID', instance.localProcess!.pid.toString()]);
            } else {
              Process.killPid(instance.localProcess!.pid);
            }
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

  // 检查实例是否在线
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    try {
      // 简单的连接检查
      final socket = await Socket.connect(instance.host, instance.port, timeout: const Duration(seconds: 3));
      await socket.close();
      return true;
    } catch (_) {
      return false;
    }
  }
}