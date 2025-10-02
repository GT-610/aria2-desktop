import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';

/// 实例管理服务
class InstanceManager extends ChangeNotifier {
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;
  final String _fileName = 'aria2_instances.json';

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  /// 初始化实例数据
  Future<void> initialize() async {
    await _loadInstances();
  }

  /// 加载实例数据
  Future<void> _loadInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _instances = jsonList.map((e) => Aria2Instance.fromJson(e)).toList();
        
        // 设置活动实例
      _activeInstance = _instances.firstWhere(
        (instance) => instance.isActive,
        orElse: () => _instances.first,
      );
      } else {
        // 创建默认实例
        _createDefaultInstance();
      }
    } catch (e) {
      print('加载实例数据失败: $e');
      _createDefaultInstance();
    }
    notifyListeners();
  }

  /// 创建默认实例
  void _createDefaultInstance() {
    _instances = [
      Aria2Instance(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        name: '默认实例',
        type: InstanceType.local,
        protocol: 'http',
        host: 'localhost',
        port: 6800,
        secret: '',
        isActive: true,
      ),
    ];
    _activeInstance = _instances.first;
    _saveInstances();
  }

  /// 保存实例数据
  Future<void> _saveInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      final jsonList = _instances.map((instance) => instance.toJson()).toList();
      final jsonString = jsonEncode(jsonList);
      
      await file.writeAsString(jsonString);
    } catch (e) {
      print('保存实例数据失败: $e');
    }
  }

  /// 添加实例
  Future<void> addInstance(Aria2Instance instance) async {
    // 确保ID唯一
    if (_instances.any((i) => i.id == instance.id)) {
      instance = instance.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
    }
    
    _instances.add(instance);
    
    // 如果是第一个实例，设置为活动实例
    if (_instances.length == 1) {
      await setActiveInstance(instance.id);
    }
    
    await _saveInstances();
    notifyListeners();
  }

  /// 更新实例
  Future<void> updateInstance(Aria2Instance updatedInstance) async {
    final index = _instances.indexWhere((i) => i.id == updatedInstance.id);
    if (index != -1) {
      _instances[index] = updatedInstance;
      
      // 如果更新的是活动实例，更新活动实例引用
      if (_activeInstance?.id == updatedInstance.id) {
        _activeInstance = updatedInstance;
      }
      
      await _saveInstances();
      notifyListeners();
    }
  }

  /// 删除实例
  Future<void> deleteInstance(String instanceId) async {
    // 不能删除唯一的实例
    if (_instances.length <= 1) {
      throw Exception('不能删除唯一的实例');
    }
    
    // 如果删除的是活动实例，切换到另一个实例
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
    // 停止当前活动实例的本地进程（如果需要）
    if (_activeInstance?.type == InstanceType.local && 
        _activeInstance?.localProcess != null) {
      _activeInstance?.localProcess?.kill();
    }
    
    // 更新所有实例的活动状态
    _instances.forEach((instance) {
      instance.isActive = instance.id == instanceId;
    });
    
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
      print('连接测试失败: $e');
      return false;
    }
  }
}