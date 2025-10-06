import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';

/// Instance management service
class InstanceManager extends ChangeNotifier {
  List<Aria2Instance> _instances = [];
  Aria2Instance? _activeInstance;
  final String _fileName = 'aria2_instances.json';

  List<Aria2Instance> get instances => _instances;
  Aria2Instance? get activeInstance => _activeInstance;

  /// Initialize instance data
  Future<void> initialize() async {
    await _loadInstances();
  }

  /// Load instance data
  Future<void> _loadInstances() async {
    try {
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$_fileName');
      
      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final List<dynamic> jsonList = jsonDecode(jsonString);
        _instances = jsonList.map((e) => Aria2Instance.fromJson(e)).toList();
        
        // Set the active instance
      _activeInstance = _instances.firstWhere(
        (instance) => instance.isActive,
        orElse: () => _instances.first,
      );
      } else {
        // Create default instance if file doesn't exist
        _createDefaultInstance();
      }
    } catch (e) {
      print('加载实例数据失败: $e');
      _createDefaultInstance();
    }
    notifyListeners();
  }

  /// Create default instance if file doesn't exist
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

  /// Save instance data to file 
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

  /// Add instance
  Future<void> addInstance(Aria2Instance instance) async {
    // 确保ID唯一
    if (_instances.any((i) => i.id == instance.id)) {
      instance = instance.copyWith(id: DateTime.now().millisecondsSinceEpoch.toString());
    }
    
    _instances.add(instance);
    
    // Set the active instance if it's the first one
    if (_instances.length == 1) {
      await setActiveInstance(instance.id);
    }
    
    await _saveInstances();
    notifyListeners();
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
    
    // Update active status of all instances
    _instances.forEach((instance) {
      instance.isActive = instance.id == instanceId;
    });
    
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
}