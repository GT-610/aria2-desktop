import 'dart:convert' show jsonDecode, jsonEncode;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

/// 统一的实例管理服务类，合并了InstanceManager和NotifiableInstanceManager的功能
class InstanceManager extends ChangeNotifier with Loggable {
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;
  final String _fileName = 'aria2_instances.json';
  
  InstanceManager() {
    initLogger();
  }

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  /// 初始化实例管理器
  Future<void> initialize() async {
    try {
      await _loadInstances();
      // 确保活动实例在初始化时不会触发自动连接
      // 明确设置活动实例状态为未连接
      if (_activeInstance != null) {
        updateInstanceInList(_activeInstance!.id, ConnectionStatus.disconnected);
      }
      logger.i('实例管理器初始化完成，共加载 ${_instances.length} 个实例');
    } catch (e, stackTrace) {
      logger.e('初始化实例管理器失败', error: e, stackTrace: stackTrace);
    }
    notifyListeners();
  }

  /// 加载实例数据
  Future<void> _loadInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.d('加载实例数据: 从 $filePath 读取');
      
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        // 加载实例并将所有实例状态设置为未连接
        _instances = jsonList
            .map((e) => Aria2Instance.fromJson(e))
            .map((instance) => instance.copyWith(status: ConnectionStatus.disconnected))
            .toList();
        
        logger.i('成功读取 ${_instances.length} 个实例');
        
        // 不再设置活动实例，只有用户明确连接时才设置
        _activeInstance = null;
      } else {
        logger.d('实例文件不存在，创建默认实例');
        await _createDefaultInstance();
      }
    } catch (e, stackTrace) {
      logger.e('加载实例数据失败', error: e, stackTrace: stackTrace);
      await _createDefaultInstance();
    }
  }

  /// 创建默认实例
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
        status: ConnectionStatus.disconnected, // 确保默认实例处于未连接状态
      ),
    ];
    _activeInstance = null; // 不设置默认活动实例
    await _saveInstances();
    logger.i('已创建默认实例');
  }

  /// 保存实例数据到文件 
  Future<void> _saveInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.d('保存实例数据: 写入到 $filePath');
      
      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      // 确保目录存在
      final dir = Directory(directory.path);
      if (!dir.existsSync()) {
        logger.d('创建目录: ${directory.path}');
        await dir.create(recursive: true);
      }
      
      await file.writeAsString(jsonString);
      logger.d('实例数据保存成功');
      
      // 验证文件是否成功写入
      if (!file.existsSync()) {
        logger.w('警告: 文件写入后检查失败，文件不存在');
      }
    } catch (e, stackTrace) {
      logger.e('保存实例数据失败', error: e, stackTrace: stackTrace);
    }
  }

  /// 添加实例
  Future<void> addInstance(Aria2Instance instance) async {
    try {
      // 确保ID唯一
      if (_instances.any((i) => i.id == instance.id)) {
        instance = instance.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
        logger.d('实例ID重复，生成新ID');
      }
      
      // 确保实例状态为未连接
      final newInstance = instance.copyWith(status: ConnectionStatus.disconnected);
      
      _instances.add(newInstance);
      await _saveInstances();
      logger.i('实例添加成功: ${newInstance.name}');
      
      // 通知监听器
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('添加实例失败', error: e, stackTrace: stackTrace);
      throw Exception('添加实例失败: $e');
    }
  }

  /// 更新实例
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
        logger.i('实例更新成功: ${updatedInstance.name}');
        notifyListeners();
      } else {
        logger.w('找不到要更新的实例: ${updatedInstance.id}');
        throw Exception('找不到要更新的实例');
      }
    } catch (e, stackTrace) {
      logger.e('更新实例失败', error: e, stackTrace: stackTrace);
      throw e;
    }
  }

  /// 删除实例
  Future<void> deleteInstance(String instanceId) async {
    // Can't delete the last instance
    if (_instances.length <= 1) {
      throw Exception('不能删除唯一的实例');
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

  /// 设置活动实例
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

  /// 检查实例连接状态
  Future<bool> checkConnection(Aria2Instance instance) async {
    try {
      final client = Aria2RpcClient(instance);
      final isConnected = await client.testConnection();
      client.close();
      return isConnected;
    } catch (e) {
      logger.w('连接测试失败: $e');
      return false;
    }
  }

  /// 连接到实例
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      // 先断开当前活动实例（如果有）
      if (_activeInstance != null) {
        await disconnectInstance();
      }
      
      // 测试连接
      final canConnect = await checkConnection(instance);
      if (!canConnect) {
        logger.w('连接测试失败，无法连接到实例: ${instance.name}');
        updateInstanceInList(instance.id, ConnectionStatus.failed);
        return false;
      }
      
      // 直接设置活动实例，不再更新isActive属性
      _activeInstance = instance;
      
      // 更新实例状态为已连接
      updateInstanceInList(instance.id, ConnectionStatus.connected);
      
      await _saveInstances();
      logger.i('成功连接到实例: ${instance.name}');
      notifyListeners();
      
      return true;
    } catch (e, stackTrace) {
      logger.e('连接实例失败', error: e, stackTrace: stackTrace);
      // 更新实例状态为失败
      updateInstanceInList(instance.id, ConnectionStatus.failed);
      return false;
    }
  }

  /// 断开当前实例连接
  Future<void> disconnectInstance() async {
    // 先获取当前活动实例ID，用于更新状态
    final activeInstanceId = _activeInstance?.id;
    
    // For local instances, stop the process
    if (_activeInstance?.type == InstanceType.local && 
        _activeInstance?.localProcess != null) {
      _activeInstance?.localProcess?.kill();
      _activeInstance?.localProcess = null;
    }
    
    // 更新活动实例的状态为未连接
    if (activeInstanceId != null) {
      updateInstanceInList(activeInstanceId, ConnectionStatus.disconnected);
    }
    
    // Clear active instance
    _activeInstance = null;
    notifyListeners();
  }

  /// 检查实例是否在线
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    return await checkConnection(instance);
  }

  /// 启动本地aria2进程
  Future<bool> startLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.aria2Path == null) {
      logger.w('尝试为非本地实例或路径未设置的实例启动本地进程');
      return false;
    }
    
    try {
      logger.d('为实例启动本地进程: ${instance.name}');
      // Build the command
      final List<String> args = [
        '--enable-rpc',
        '--rpc-listen-all=true',
        '--rpc-allow-origin-all',
        '--rpc-listen-port=${instance.port}',
      ];
      
      if (instance.secret.isNotEmpty) {
        args.add('--rpc-secret=${instance.secret}');
      }
      
      // Start the process
      final process = await Process.start(
        instance.aria2Path!,
        args,
        runInShell: true,
      );
      
      // Update instance with process reference
      final updatedInstance = instance.copyWith(localProcess: process);
      await updateInstance(updatedInstance);
      
      logger.i('本地进程启动成功: ${instance.name}');
      return true;
    } catch (e, stackTrace) {
      logger.e('启动本地进程失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 停止本地aria2进程
  Future<bool> stopLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.localProcess == null) {
      logger.w('尝试停止非本地实例或没有进程的实例');
      return false;
    }
    
    try {
      // Kill the process
      instance.localProcess?.kill();
      
      // Update instance
      final updatedInstance = instance.copyWith(localProcess: null);
      await updateInstance(updatedInstance);
      
      logger.i('本地进程停止成功: ${instance.name}');
      return true;
    } catch (e, stackTrace) {
      logger.e('停止本地进程失败', error: e, stackTrace: stackTrace);
      return false;
    }
  }

  /// 更新实例列表中的实例状态
  void updateInstanceInList(String instanceId, ConnectionStatus status) {
    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(status: status);
      notifyListeners();
    }
  }

  /// 根据ID获取实例
  Aria2Instance? getInstanceById(String instanceId) {
    try {
      return _instances.firstWhere((instance) => instance.id == instanceId);
    } catch (e) {
      logger.d('找不到ID为 $instanceId 的实例');
      return null;
    }
  }

  /// 获取所有实例（兼容方法）
  List<Aria2Instance> getInstances() {
    return _instances;
  }

  /// 获取活动实例（兼容方法）
  Aria2Instance? getActiveInstance() {
    return _activeInstance;
  }
}