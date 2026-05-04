import 'dart:async';
import 'package:flutter/foundation.dart';
import '../pages/download_page/models/download_task.dart';
import '../pages/download_page/enums.dart';
import '../pages/download_page/utils/task_parser.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

enum DownloadTaskNotificationType { completed, failed }

class DownloadTaskNotification {
  const DownloadTaskNotification({
    required this.taskId,
    required this.taskName,
    required this.instanceId,
    required this.type,
    this.errorMessage,
  });

  final String taskId;
  final String taskName;
  final String instanceId;
  final DownloadTaskNotificationType type;
  final String? errorMessage;
}

/// Unified download task data service
/// Responsible for periodically fetching task data from Aria2, performing unified data encapsulation and caching
class DownloadDataService extends ChangeNotifier with Loggable {
  DownloadDataService();

  Timer? _refreshTimer;

  List<DownloadTask> _tasks = [];
  bool _isRefreshing = false;
  String? _lastError;
  final List<DownloadTaskNotification> _pendingNotifications = [];

  final int _refreshInterval = 1000;

  final Map<String, Aria2RpcClient> _clientCache = {};
  List<Aria2Instance> Function()? _connectedInstancesProvider;

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

  Timer? startPeriodicRefresh(
    List<Aria2Instance> Function() connectedInstancesProvider,
  ) {
    _connectedInstancesProvider = connectedInstancesProvider;
    _restartTimer();
    return _refreshTimer;
  }

  void stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }

  Future<void> refreshTasks(List<Aria2Instance> instances) async {
    if (_isRefreshing) return;

    final connectedInstances = instances
        .where((instance) => instance.status == ConnectionStatus.connected)
        .toList();

    if (connectedInstances.isEmpty) {
      final hadTasks = _tasks.isNotEmpty;
      final hadError = _lastError != null;
      _tasks = [];
      _lastError = null;
      if (hadTasks || hadError) {
        notifyListeners();
      }
      return;
    }

    try {
      _isRefreshing = true;
      _lastError = null;
      final previousTasks = _tasks;

      final taskGroups = await Future.wait(
        connectedInstances.map(_fetchTasksForInstance),
      );
      final newTasks = taskGroups.expand((tasks) => tasks).toList()
        ..sort(_compareTasks);

      final terminalTransitionInstanceIds = _collectTaskNotifications(
        previousTasks,
        newTasks,
      );
      _tasks = newTasks;
      _saveSessionsForTerminalTransitions(
        connectedInstances,
        terminalTransitionInstanceIds,
      );
      notifyListeners();
    } catch (e, stackTrace) {
      _lastError = e.toString();
      this.e(
        'Failed to refresh tasks across connected instances',
        error: e,
        stackTrace: stackTrace,
      );
      notifyListeners();
    } finally {
      _isRefreshing = false;
    }
  }

  List<DownloadTaskNotification> takePendingNotifications() {
    final notifications = List<DownloadTaskNotification>.from(
      _pendingNotifications,
    );
    _pendingNotifications.clear();
    return notifications;
  }

  Future<List<DownloadTask>> _fetchTasksForInstance(
    Aria2Instance instance,
  ) async {
    if (instance.status != ConnectionStatus.connected) {
      this.w(
        'Skipping task fetch because instance ${instance.name} is not marked connected',
      );
      return [];
    }

    final instanceId = instance.id;
    final isLocal = instance.type == InstanceType.builtin;

    try {
      final allTasks = <DownloadTask>[];

      final client = _getClient(instance);
      final results = await client.getDownloadStatus();

      if (results.isEmpty) {
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

      return allTasks;
    } catch (e, stackTrace) {
      this.e(
        'Failed to fetch tasks for instance ${instance.name}',
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

  void _restartTimer() {
    stopPeriodicRefresh();

    final connectedInstances = _connectedInstancesProvider?.call() ?? const [];

    if (connectedInstances.isNotEmpty) {
      _refreshTimer = Timer.periodic(Duration(milliseconds: _refreshInterval), (
        timer,
      ) {
        if (timer.isActive && !_isRefreshing) {
          final latestConnectedInstances =
              _connectedInstancesProvider?.call() ?? const [];
          refreshTasks(latestConnectedInstances);
        }
      });
    }
  }

  Set<String> _collectTaskNotifications(
    List<DownloadTask> previousTasks,
    List<DownloadTask> newTasks,
  ) {
    final terminalTransitionInstanceIds = <String>{};
    if (previousTasks.isEmpty || newTasks.isEmpty) {
      return terminalTransitionInstanceIds;
    }

    final previousByKey = {
      for (final task in previousTasks) '${task.instanceId}::${task.id}': task,
    };

    for (final task in newTasks) {
      final previousTask = previousByKey['${task.instanceId}::${task.id}'];
      if (previousTask == null) {
        continue;
      }

      final wasInProgress =
          previousTask.status == DownloadStatus.active ||
          previousTask.status == DownloadStatus.waiting;
      if (!wasInProgress) {
        continue;
      }

      if (task.taskStatus == 'complete') {
        terminalTransitionInstanceIds.add(task.instanceId);
        _pendingNotifications.add(
          DownloadTaskNotification(
            taskId: task.id,
            taskName: task.name,
            instanceId: task.instanceId,
            type: DownloadTaskNotificationType.completed,
          ),
        );
      } else if (task.taskStatus == 'error') {
        terminalTransitionInstanceIds.add(task.instanceId);
        _pendingNotifications.add(
          DownloadTaskNotification(
            taskId: task.id,
            taskName: task.name,
            instanceId: task.instanceId,
            type: DownloadTaskNotificationType.failed,
            errorMessage: task.errorMessage,
          ),
        );
      }
    }

    return terminalTransitionInstanceIds;
  }

  void _saveSessionsForTerminalTransitions(
    List<Aria2Instance> instances,
    Set<String> instanceIds,
  ) {
    if (instanceIds.isEmpty) {
      return;
    }

    for (final instance in instances) {
      if (!instanceIds.contains(instance.id)) {
        continue;
      }

      final client = _getClient(instance);
      unawaited(
        client.saveSession().catchError((Object error, StackTrace stackTrace) {
          this.w(
            'Failed to save session after terminal task transition for ${instance.name}',
            error: error,
            stackTrace: stackTrace,
          );
          return false;
        }),
      );
    }
  }

  @override
  void dispose() {
    stopPeriodicRefresh();
    _clearClientCache();
    super.dispose();
  }
}
