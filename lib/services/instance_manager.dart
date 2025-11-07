import 'dart:convert' show jsonDecode, jsonEncode, utf8;
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

/// Instance management service
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
      logger.i('开始初始化实例管理器');
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

  /// Load instance data
  Future<void> _loadInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.d('加载实例数据: 从 $filePath 读取');
      
      if (file.existsSync()) {
        logger.d('实例文件存在，正在读取...');
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        // 加载实例并将所有实例状态设置为未连接
        _instances = jsonList
            .map((e) => Aria2Instance.fromJson(e))
            .map((instance) => instance.copyWith(status: ConnectionStatus.disconnected))
            .toList();
        
        logger.i('成功读取 ${_instances.length} 个实例: ${_instances.map((i) => i.name).join(', ')}');
        
        // 不再设置活动实例，只有用户明确连接时才设置
        _activeInstance = null;
      } else {
        logger.d('实例文件不存在，创建默认实例...');
        // Create default instance if file doesn't exist
        await _createDefaultInstance();
      }
    } catch (e, stackTrace) {
      logger.e('加载实例数据失败', error: e, stackTrace: stackTrace);
      await _createDefaultInstance();
    }
    notifyListeners();
  }

  /// Create default instance if file doesn't exist
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

  /// Save instance data to file 
  Future<void> _saveInstances() async {
    try {
      logger.i('开始保存实例数据');
      final directory = await getApplicationDocumentsDirectory();
      final filePath = '${directory.path}/$_fileName';
      final file = File(filePath);
      
      logger.i('保存实例数据: 写入到 $filePath');
      logger.i('准备保存的实例数量: ${_instances.length}');
      logger.i('实例列表: ${_instances.map((i) => i.name).join(', ')}');
      
      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      logger.i('实例数据已转换为JSON格式');
      final jsonString = jsonEncode(jsonList);
      logger.i('JSON数据已编码完成');
      
      // 确保目录存在
      final dir = Directory(directory.path);
      if (!dir.existsSync()) {
        logger.i('创建目录: ${directory.path}');
        await dir.create(recursive: true);
      }
      
      logger.i('开始写入文件...');
      await file.writeAsString(jsonString);
      logger.i('实例数据保存成功到 $filePath');
      
      // 验证文件是否成功写入
      if (file.existsSync()) {
        final fileSize = await file.length();
        logger.i('验证: 文件已成功写入，大小: $fileSize 字节');
        // 读取文件内容验证
        final content = await file.readAsString();
        logger.i('验证: 文件内容长度为 ${content.length} 字符');
      } else {
        logger.w('验证: 文件写入后检查失败，文件不存在');
      }
    } catch (e, stackTrace) {
      logger.e('保存实例数据失败', error: e, stackTrace: stackTrace);
    }
  }

  /// Add instance
  Future<void> addInstance(Aria2Instance instance) async {
    try {
      logger.i('添加实例开始: ${instance.name}');
      // 确保ID唯一
      if (_instances.any((i) => i.id == instance.id)) {
        instance = instance.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
        logger.i('实例ID重复，生成新ID');
      }
      
      // 确保实例状态为未连接
      final newInstance = instance.copyWith(status: ConnectionStatus.disconnected);
      logger.i('准备添加实例: ${newInstance.name}, ID: ${newInstance.id}');
      
      _instances.add(newInstance);
      logger.i('实例已添加到内存列表');
      
      // 保存到文件
      logger.i('开始保存实例到文件...');
      await _saveInstances();
      logger.i('实例添加成功并保存: ${newInstance.name}');
      
      // 通知监听器
      notifyListeners();
    } catch (e, stackTrace) {
      logger.e('添加实例失败', error: e, stackTrace: stackTrace);
      throw Exception('添加实例失败: $e');
    }
  }

  /// Update instance
  Future<void> updateInstance(Aria2Instance updatedInstance) async {
    final index = _instances.indexWhere((i) => i.id == updatedInstance.id);
    if (index != -1) {
      _instances[index] = updatedInstance;
      
      // Update active instance reference if it's being updated
      if (_activeInstance?.id == updatedInstance.id) {
        _activeInstance = updatedInstance;
      }
      
      await _saveInstances();
      notifyListeners();
    }
  }

  /// Delete instance
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
      print('连接测试失败: $e');
      return false;
    }
  }

  /// Connect to an instance
  Future<bool> connectInstance(Aria2Instance instance) async {
    try {
      logger.i('开始连接实例: ${instance.name}');
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
      notifyListeners();
      logger.i('成功连接到实例: ${instance.name}');
      
      return true;
    } catch (e, stackTrace) {
      logger.e('连接实例失败', error: e, stackTrace: stackTrace);
      // 更新实例状态为失败
      updateInstanceInList(instance.id, ConnectionStatus.failed);
      return false;
    }
  }

  /// Disconnect from current instance
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

  /// Check if instance is online
  Future<bool> checkInstanceOnline(Aria2Instance instance) async {
    return await checkConnection(instance);
  }

  /// Start local aria2 process
  Future<bool> startLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.aria2Path == null) {
      return false;
    }
    
    try {
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
      
      return true;
    } catch (e) {
      print('启动本地进程失败: $e');
      return false;
    }
  }

  /// Stop local aria2 process
  Future<bool> stopLocalProcess(Aria2Instance instance) async {
    if (instance.type != InstanceType.local || instance.localProcess == null) {
      return false;
    }
    
    try {
      // Kill the process
      instance.localProcess?.kill();
      
      // Update instance
      final updatedInstance = instance.copyWith(localProcess: null);
      await updateInstance(updatedInstance);
      
      return true;
    } catch (e) {
      print('停止本地进程失败: $e');
      return false;
    }
  }

  /// Update instance status in list
  void updateInstanceInList(String instanceId, ConnectionStatus status) {
    final index = _instances.indexWhere((i) => i.id == instanceId);
    if (index != -1) {
      _instances[index] = _instances[index].copyWith(status: status);
      notifyListeners();
    }
  }

  /// Get all instances
  List<Aria2Instance> getInstances() {
    return _instances;
  }

  /// Get active instance
  Aria2Instance? getActiveInstance() {
    return _activeInstance;
  }
}