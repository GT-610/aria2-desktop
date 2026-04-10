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
    i('Service initialization completed');
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
    final key =
        '${instance.id}_${instance.protocol}_${instance.host}_${instance.port}_${instance.secret}';
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

  Timer? startPeriodicRefresh(List<Aria2Instance> instances) {
    _restartTimer(instances);
    return _refreshTimer;
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
    this.d('Timer stopped');
  }

  Future<void> refreshTasks(List<Aria2Instance> instances) async {
    if (_isRefreshing) return;

    final connectedInstances = instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList();

    if (connectedInstances.isEmpty) {
      final hadTasks = _tasks.isNotEmpty;
      _tasks = [];
      _lastError = null;
      if (hadTasks) {
        notifyListeners();
      }
      return;
    }

    try {
      _isRefreshing = true;
      _lastError = null;

      final taskGroups = await Future.wait(
        connectedInstances.map(_fetchTasksForInstance),
      );
      final newTasks = taskGroups.expand((tasks) => tasks).toList()
        ..sort(_compareTasks);

      _tasks = newTasks;
      notifyListeners();
    } catch (e, stackTrace) {
      _lastError = e.toString();
      this.e('Failed to refresh tasks', error: e, stackTrace: stackTrace);
    } finally {
      _isRefreshing = false;
    }
  }

  Future<List<DownloadTask>> _fetchTasksForInstance(
    Aria2Instance instance,
  ) async {
    if (instance.status != ConnectionStatus.connected) {
      this.w('Instance not connected, skipping task fetch: ${instance.name}');
      return [];
    }

    final instanceId = instance.id;
    final isLocal = instance.type == InstanceType.builtin;

    try {
      final allTasks = <DownloadTask>[];

      final client = _getClient(instance);
      final results = await client.getDownloadStatus();

      if (results.isEmpty) {
        this.d('Task data is empty');
        return allTasks;
      }

      if (results[0]['success'] && results[0]['data'] is List) {
        final activeTasks = results[0]['data'] as List;
        allTasks.addAll(
          TaskParser.parseTasks(
            activeTasks,
            DownloadStatus.active,
            instanceId,
            isLocal,
          ),
        );
      }

      if (results.length > 1 &&
          results[1]['success'] &&
          results[1]['data'] is List) {
        final waitingTasks = results[1]['data'] as List;
        allTasks.addAll(
          TaskParser.parseTasks(
            waitingTasks,
            DownloadStatus.waiting,
            instanceId,
            isLocal,
          ),
        );
      }

      if (results.length > 2 &&
          results[2]['success'] &&
          results[2]['data'] is List) {
        final stoppedTasks = results[2]['data'] as List;
        allTasks.addAll(
          TaskParser.parseTasks(
            stoppedTasks,
            DownloadStatus.stopped,
            instanceId,
            isLocal,
          ),
        );
      }

      this.d('Task fetch completed: ${allTasks.length} total');

      return allTasks;
    } catch (e, stackTrace) {
      this.e(
        'Failed to fetch tasks: ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return [];
    }
  }

  int _compareTasks(DownloadTask left, DownloadTask right) {
    final statusOrder = {
      DownloadStatus.active: 0,
      DownloadStatus.waiting: 1,
      DownloadStatus.stopped: 2,
    };
    final leftOrder = statusOrder[left.status] ?? 99;
    final rightOrder = statusOrder[right.status] ?? 99;
    if (leftOrder != rightOrder) {
      return leftOrder.compareTo(rightOrder);
    }

    if (left.instanceId != right.instanceId) {
      return left.instanceId.compareTo(right.instanceId);
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  void _restartTimer([List<Aria2Instance> instances = const []]) {
    stopPeriodicRefresh();

    final connectedInstances = instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList();

    if (connectedInstances.isNotEmpty) {
      this.i(
        'Preparing to start timer for ${connectedInstances.length} connected instance(s), fixed interval ${_refreshInterval}ms',
      );
      _refreshTimer = Timer.periodic(Duration(milliseconds: _refreshInterval), (
        timer,
      ) {
        if (timer.isActive && !_isRefreshing) {
          this.d('Timer triggered task refresh');
          refreshTasks(connectedInstances);
        }
      });
      this.i(
        'Timer started successfully for ${connectedInstances.length} connected instance(s), interval ${_refreshInterval}ms',
      );
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
      this.d('Task not found: $taskId');
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
