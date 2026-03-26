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
  DownloadDataService() {
    initLogger();
    logger.i('Service initialization completed');
  }

  Timer? _refreshTimer;
  
  List<DownloadTask> _tasks = [];
  bool _isRefreshing = false;
  String? _lastError;
  
  int _refreshInterval = 1000;

  final Map<String, Aria2RpcClient> _clientCache = {};

  List<DownloadTask> get tasks => _tasks;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;

  Aria2RpcClient _getClient(Aria2Instance instance) {
    final key = '${instance.id}_${instance.host}_${instance.port}';
    return _clientCache.putIfAbsent(key, () => Aria2RpcClient(instance));
  }

  void _clearClientCache() {
    for (final client in _clientCache.values) {
      client.close();
    }
    _clientCache.clear();
  }

  void setRefreshInterval(int milliseconds) {
    _refreshInterval = milliseconds;
    _restartTimer();
  }

  Timer? startPeriodicRefresh(Aria2Instance? instance) {
    _restartTimer(instance);
    return _refreshTimer;
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    logger.d('Timer stopped');
  }

  Future<void> refreshTasks(Aria2Instance? instance) async {
    if (_isRefreshing || instance == null) return;
    
    try {
      _isRefreshing = true;
      _lastError = null;
      
      final newTasks = await _fetchTasks(instance);
      
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

  Future<List<DownloadTask>?> _fetchTasks(Aria2Instance instance) async {
    if (instance.status != ConnectionStatus.connected) {
      logger.w('Instance not connected, skipping task fetch: ${instance.name}');
      return null;
    }

    final instanceId = instance.id;
    final isLocal = instance.type == InstanceType.builtin;

    try {
      List<DownloadTask> allTasks = [];

      final client = _getClient(instance);
      final results = await client.getDownloadStatus();

      if (results.isEmpty) {
        logger.d('Task data is empty');
        return allTasks;
      }

      if (results[0]['success'] && results[0]['data'] is List) {
        final activeTasks = results[0]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          activeTasks,
          DownloadStatus.active,
          instanceId,
          isLocal,
        ));
      }

      if (results.length > 1 && results[1]['success'] && results[1]['data'] is List) {
        final waitingTasks = results[1]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          waitingTasks,
          DownloadStatus.waiting,
          instanceId,
          isLocal,
        ));
      }

      if (results.length > 2 && results[2]['success'] && results[2]['data'] is List) {
        final stoppedTasks = results[2]['data'] as List;
        allTasks.addAll(TaskParser.parseTasks(
          stoppedTasks,
          DownloadStatus.stopped,
          instanceId,
          isLocal,
        ));
      }

      logger.d('Task fetch completed: ${allTasks.length} total');

      return allTasks;
    } catch (e, stackTrace) {
      logger.e('Failed to fetch tasks: ${instance.name}', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  void _restartTimer([Aria2Instance? instance]) {
    stopPeriodicRefresh();
    
    if (instance != null && instance.status == ConnectionStatus.connected) {
      logger.i('Preparing to start timer: ${instance.name}, fixed interval ${_refreshInterval}ms');
      _refreshTimer = Timer.periodic(
        Duration(milliseconds: _refreshInterval),
        (timer) {
          if (timer.isActive && !_isRefreshing) {
            logger.d('Timer triggered task refresh');
            refreshTasks(instance);
          }
        }
      );
      logger.i('Timer started successfully: ${instance.name}, interval ${_refreshInterval}ms');
    }
  }

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
    _clearClientCache();
    super.dispose();
  }
}