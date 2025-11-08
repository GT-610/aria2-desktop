import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pages/download_page/models/download_task.dart';
import '../pages/download_page/enums.dart';
import '../pages/download_page/utils/task_parser.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

/// 统一的下载任务数据服务
/// 负责定时从Aria2获取任务数据，进行统一数据封装和缓存
class DownloadDataService extends ChangeNotifier with Loggable {
  // 移除单例模式，使用Provider管理实例生命周期
  DownloadDataService() {
    initLogger();
    logger.d('DownloadDataService 初始化');
  }

  // 定时刷新的定时器
  Timer? _refreshTimer;
  
  // 任务数据缓存
  List<DownloadTask> _tasks = [];
  bool _isRefreshing = false;
  String? _lastError;
  
  // 刷新间隔（毫秒）
  int _refreshInterval = 1000;

  // 获取任务列表
  List<DownloadTask> get tasks => _tasks;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;

  /// 设置刷新间隔
  void setRefreshInterval(int milliseconds) {
    _refreshInterval = milliseconds;
    _restartTimer();
  }

  /// 开始定时刷新
  void startPeriodicRefresh(Aria2Instance? instance) {
    _restartTimer(instance);
  }

  /// 停止定时刷新
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    logger.d('下载数据刷新定时器已停止');
  }

  /// 手动刷新任务数据
  Future<void> refreshTasks(Aria2Instance? instance) async {
    if (_isRefreshing || instance == null) return;
    
    try {
      _isRefreshing = true;
      _lastError = null;
      
      final newTasks = await _fetchTasks(instance);
      
      // 更新缓存并通知监听器
      if (newTasks != null) {
        _tasks = newTasks;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _lastError = e.toString();
      logger.e('刷新任务数据失败', error: e, stackTrace: stackTrace);
    } finally {
      _isRefreshing = false;
    }
  }

  /// 根据实例获取任务数据
  Future<List<DownloadTask>?> _fetchTasks(Aria2Instance instance) async {
    // 确保实例状态是已连接
    if (instance.status != ConnectionStatus.connected) {
      logger.w('实例 ${instance.name} 未连接，跳过任务获取');
      return null;
    }
    
    Aria2RpcClient? client;
    try {
      List<DownloadTask> allTasks = [];
      
      // 创建RPC客户端
      client = Aria2RpcClient(instance);
      
      // 使用getDownloadStatus方法获取所有任务
      final results = await client.getDownloadStatus();
      
      if (results.isEmpty) {
        logger.w('获取任务数据返回空结果');
        return allTasks;
      }
      
      // 处理活动任务
      if (results[0]['success'] && results[0]['data'] is List) {
        final activeTasks = results[0]['data'] as List;
        logger.d('获取到 ${activeTasks.length} 个活动任务');
        allTasks.addAll(TaskParser.parseTasks(
          activeTasks, 
          DownloadStatus.active, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      // 处理等待任务
      if (results.length > 1 && results[1]['success'] && results[1]['data'] is List) {
        final waitingTasks = results[1]['data'] as List;
        logger.d('获取到 ${waitingTasks.length} 个等待任务');
        allTasks.addAll(TaskParser.parseTasks(
          waitingTasks, 
          DownloadStatus.waiting, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      // 处理已停止任务
      if (results.length > 2 && results[2]['success'] && results[2]['data'] is List) {
        final stoppedTasks = results[2]['data'] as List;
        logger.d('获取到 ${stoppedTasks.length} 个已停止任务');
        allTasks.addAll(TaskParser.parseTasks(
          stoppedTasks, 
          DownloadStatus.stopped, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      logger.d('总共获取到 ${allTasks.length} 个任务');
      
      return allTasks;
    } catch (e, stackTrace) {
      logger.e('从实例 ${instance.name} 获取任务数据失败', error: e, stackTrace: stackTrace);
      return null;
    } finally {
      // 确保客户端被关闭
      client?.close();
    }
  }

  /// 重启定时器
  void _restartTimer([Aria2Instance? instance]) {
    // 先取消现有的定时器
    stopPeriodicRefresh();
    
    // 如果提供了实例且实例已连接，则启动新的定时器
    if (instance != null && instance.status == ConnectionStatus.connected) {
      _refreshTimer = Timer.periodic(
        Duration(milliseconds: _refreshInterval),
        (_) {
          // 避免在定时器回调中捕获定时器本身的错误
          if (_isRefreshing) {
            logger.d('任务刷新正在进行中，跳过本次定时刷新');
            return;
          }
          
          refreshTasks(instance);
        }
      );
      logger.d('下载数据刷新定时器已启动，实例: ${instance.name}，间隔: ${_refreshInterval}ms');
    }
  }

  /// 过滤任务
  List<DownloadTask> filterTasks({
    DownloadStatus? status,
    String? instanceId,
    bool? isLocal,
  }) {
    return _tasks.where((task) {
      if (status != null && task.status != status) return false;
      if (instanceId != null && task.instanceId != instanceId) return false;
      if (isLocal != null && task.isLocal != isLocal) return false;
      return true;
    }).toList();
  }

  /// 根据ID获取任务
  DownloadTask? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      logger.w('未找到ID为 $taskId 的任务');
      return null;
    }
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }
}