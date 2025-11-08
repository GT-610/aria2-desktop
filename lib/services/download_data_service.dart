import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pages/download_page/models/download_task.dart';
import '../pages/download_page/enums.dart';
import '../pages/download_page/utils/task_parser.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

/// Unified download task data service
/// Responsible for periodically fetching task data from Aria2, performing unified data encapsulation and caching
class DownloadDataService extends ChangeNotifier with Loggable {
  // Use Provider to manage instance lifecycle
  DownloadDataService() {
    initLogger();
    logger.i('Service initialization completed');
  }

  // Timer for periodic refresh
  Timer? _refreshTimer;
  
  // Task data cache
  List<DownloadTask> _tasks = [];
  bool _isRefreshing = false;
  String? _lastError;
  
  // Refresh interval (milliseconds)
  int _refreshInterval = 1000;

  // Get task list
  List<DownloadTask> get tasks => _tasks;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;

  /// Set refresh interval
  void setRefreshInterval(int milliseconds) {
    _refreshInterval = milliseconds;
    _restartTimer();
  }

  /// Start periodic refresh
  Timer? startPeriodicRefresh(Aria2Instance? instance) {
    _restartTimer(instance);
    return _refreshTimer;
  }

  /// Stop periodic refresh
  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    logger.d('Timer stopped');
  }

  /// Manually refresh task data
  Future<void> refreshTasks(Aria2Instance? instance) async {
    if (_isRefreshing || instance == null) return;
    
    try {
      _isRefreshing = true;
      _lastError = null;
      
      final newTasks = await _fetchTasks(instance);
      
      // Update cache and notify listeners
      if (newTasks != null) {
        _tasks = newTasks;
        notifyListeners();
      }
    } catch (e, stackTrace) {
      _lastError = e.toString();
      logger.e('Failed to refresh tasks', error: e, stackTrace: stackTrace);
    } finally {
      _isRefreshing = false;
    }
  }

  /// Get task data by instance
  Future<List<DownloadTask>?> _fetchTasks(Aria2Instance instance) async {
    // Ensure instance status is connected
    if (instance.status != ConnectionStatus.connected) {
      logger.w('Instance not connected, skipping task fetch: ${instance.name}');
      return null;
    }
    
    Aria2RpcClient? client;
    try {
      List<DownloadTask> allTasks = [];
      
      // Create RPC client
      client = Aria2RpcClient(instance);
      
      // Use getDownloadStatus method to get all tasks
      final results = await client.getDownloadStatus();
  
      if (results.isEmpty) {
        logger.d('Task data is empty');
        return allTasks;
      }
      
      // Process active tasks
      if (results[0]['success'] && results[0]['data'] is List) {
        final activeTasks = results[0]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          activeTasks, 
          DownloadStatus.active, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      // Process waiting tasks
      if (results.length > 1 && results[1]['success'] && results[1]['data'] is List) {
        final waitingTasks = results[1]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          waitingTasks, 
          DownloadStatus.waiting, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      // Process stopped tasks
      if (results.length > 2 && results[2]['success'] && results[2]['data'] is List) {
        final stoppedTasks = results[2]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          stoppedTasks, 
          DownloadStatus.stopped, 
          instance.id, 
          instance.type == InstanceType.local
        ));
      }
      
      logger.d('Task fetch completed: ${allTasks.length} total');
      
      return allTasks;
    } catch (e, stackTrace) {
      logger.e('Failed to fetch tasks: ${instance.name}', error: e, stackTrace: stackTrace);
      return null;
    } finally {
      // Ensure client is closed
      client?.close();
    }
  }

  /// Restart timer
  void _restartTimer([Aria2Instance? instance]) {
    // First cancel existing timer
    stopPeriodicRefresh();
    
    // If an instance is provided and it's connected, start a new timer
    if (instance != null && instance.status == ConnectionStatus.connected) {
      logger.i('Preparing to start timer: ${instance.name}, fixed interval ${_refreshInterval}ms');
      _refreshTimer = Timer.periodic(
        Duration(milliseconds: _refreshInterval),
        (timer) {
          // Avoid catching errors from the timer itself in the timer callback
          if (timer.isActive && !_isRefreshing) {
            logger.d('Timer triggered task refresh');
            refreshTasks(instance);
          }
        }
      );
      logger.i('Timer started successfully: ${instance.name}, interval ${_refreshInterval}ms');
    }
  }

  /// Filter tasks
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

  /// Get task by ID
  DownloadTask? getTaskById(String taskId) {
    try {
      return _tasks.firstWhere((task) => task.id == taskId);
    } catch (e) {
      logger.d('Task not found: $taskId');
      return null;
    }
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    super.dispose();
  }
}