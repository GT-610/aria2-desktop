import 'dart:async';
import 'dart:collection';
import 'package:flutter/foundation.dart';
import '../pages/download_page/models/download_task.dart';
import '../pages/download_page/enums.dart';
import '../pages/download_page/utils/task_parser.dart';
import '../models/aria2_instance.dart';
import 'aria2_rpc_client.dart';
import '../utils/logging.dart';

enum DownloadTaskNotificationType { completed, failed }

class InstanceRefreshState {
  const InstanceRefreshState({
    required this.isLoading,
    required this.isStale,
    required this.consecutiveFailures,
    this.error,
    this.lastUpdated,
    this.nextRetryAt,
  });

  final bool isLoading;
  final bool isStale;
  final int consecutiveFailures;
  final String? error;
  final DateTime? lastUpdated;
  final DateTime? nextRetryAt;
}

class _InstanceTaskRefreshResult {
  const _InstanceTaskRefreshResult.success(this.instanceId, this.tasks)
    : error = null,
      attempted = true;

  const _InstanceTaskRefreshResult.failure(
    this.instanceId,
    this.error, {
    this.attempted = true,
  }) : tasks = const <DownloadTask>[];

  final String instanceId;
  final List<DownloadTask> tasks;
  final Object? error;
  final bool attempted;

  bool get isSuccess => error == null;
}

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
  List<DownloadTask> _tasksView = const [];
  bool _isRefreshing = false;
  bool _isDisposed = false;
  String? _lastError;
  final List<DownloadTaskNotification> _pendingNotifications = [];
  int _tasksVersion = 0;
  final Map<String, InstanceRefreshState> _instanceStates = {};

  final int _refreshInterval = 1000;

  final Map<String, Aria2RpcClient> _clientCache = {};
  final Map<String, StreamSubscription<Aria2RpcNotification>>
  _notificationSubscriptions = {};
  List<Aria2Instance> Function()? _connectedInstancesProvider;
  List<Aria2Instance>? _pendingRefreshInstances;
  Future<void>? _refreshLoop;

  List<DownloadTask> get tasks => _tasksView;
  int get tasksVersion => _tasksVersion;
  bool get isRefreshing => _isRefreshing;
  String? get lastError => _lastError;
  Map<String, InstanceRefreshState> get instanceStates =>
      Map.unmodifiable(_instanceStates);

  Aria2RpcClient _getClient(Aria2Instance instance) {
    final key = instance.connectionFingerprint;
    return _clientCache.putIfAbsent(key, () {
      final client = Aria2RpcClient(instance);
      if (instance.protocol.startsWith('ws')) {
        _notificationSubscriptions[key] = client.notifications.listen(
          (notification) => _handleRpcNotification(instance, notification),
          onError: (Object error, StackTrace stackTrace) {
            w(
              'aria2 notification stream failed for ${instance.name}',
              error: error,
              stackTrace: stackTrace,
            );
          },
        );
      }
      return client;
    });
  }

  void _clearClientCache() {
    for (final subscription in _notificationSubscriptions.values) {
      unawaited(subscription.cancel());
    }
    _notificationSubscriptions.clear();
    for (final client in _clientCache.values) {
      unawaited(client.close());
    }
    _clientCache.clear();
  }

  void _synchronizeClientCache(List<Aria2Instance> instances) {
    final activeFingerprints = instances
        .map((instance) => instance.connectionFingerprint)
        .toSet();
    final obsoleteKeys = _clientCache.keys
        .where((key) => !activeFingerprints.contains(key))
        .toList();
    for (final key in obsoleteKeys) {
      final subscription = _notificationSubscriptions.remove(key);
      if (subscription != null) {
        unawaited(subscription.cancel());
      }
      final client = _clientCache.remove(key);
      if (client != null) {
        unawaited(client.close());
      }
    }
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

  Future<void> refreshTasks(List<Aria2Instance> instances) {
    if (_isDisposed) {
      return Future<void>.value();
    }
    _pendingRefreshInstances = List<Aria2Instance>.from(instances);
    final activeLoop = _refreshLoop;
    if (activeLoop != null) {
      return activeLoop;
    }

    final completion = Completer<void>();
    final loop = completion.future;
    _refreshLoop = loop;
    unawaited(_runRefreshLoop(loop, completion));
    return loop;
  }

  Future<void> _runRefreshLoop(
    Future<void> loop,
    Completer<void> completion,
  ) async {
    try {
      while (!_isDisposed && _pendingRefreshInstances != null) {
        final instances = _pendingRefreshInstances!;
        _pendingRefreshInstances = null;
        await _refreshTasksOnce(instances);
      }
      if (identical(_refreshLoop, loop)) {
        _refreshLoop = null;
      }
      completion.complete();
    } catch (error, stackTrace) {
      if (identical(_refreshLoop, loop)) {
        _refreshLoop = null;
      }
      completion.completeError(error, stackTrace);
    }
  }

  Future<void> _refreshTasksOnce(List<Aria2Instance> instances) async {
    final connectedInstances = instances
        .where(
          (instance) =>
              instance.status == ConnectionStatus.connected ||
              instance.status == ConnectionStatus.reconnecting,
        )
        .toList();
    _synchronizeClientCache(connectedInstances);

    if (connectedInstances.isEmpty) {
      final hadTasks = _tasks.isNotEmpty;
      final hadError = _lastError != null;
      final hadInstanceStates = _instanceStates.isNotEmpty;
      _tasks = [];
      _tasksView = UnmodifiableListView(_tasks);
      _instanceStates.clear();
      _tasksVersion++;
      _lastError = null;
      if (hadTasks || hadError || hadInstanceStates) {
        _notifyIfActive();
      }
      return;
    }

    try {
      _isRefreshing = true;
      _lastError = null;
      final previousTasks = _tasks;

      for (final instance in connectedInstances) {
        final previousState = _instanceStates[instance.id];
        _instanceStates[instance.id] = InstanceRefreshState(
          isLoading: true,
          isStale: previousState?.isStale ?? false,
          consecutiveFailures: previousState?.consecutiveFailures ?? 0,
          error: previousState?.error,
          lastUpdated: previousState?.lastUpdated,
          nextRetryAt: previousState?.nextRetryAt,
        );
      }

      final refreshResults = await Future.wait(
        connectedInstances.map(_fetchTasksForInstance),
      );
      if (_isDisposed) {
        return;
      }
      final newTasks = <DownloadTask>[];
      final errors = <String>[];
      for (final result in refreshResults) {
        final previousState = _instanceStates[result.instanceId];
        if (result.isSuccess) {
          newTasks.addAll(result.tasks);
          _instanceStates[result.instanceId] = InstanceRefreshState(
            isLoading: false,
            isStale: false,
            consecutiveFailures: 0,
            lastUpdated: DateTime.now(),
          );
          continue;
        }

        newTasks.addAll(
          previousTasks.where((task) => task.instanceId == result.instanceId),
        );
        final message = result.error.toString();
        errors.add('${result.instanceId}: $message');
        final failures =
            (previousState?.consecutiveFailures ?? 0) +
            (result.attempted ? 1 : 0);
        final backoffExponent = (failures - 1).clamp(0, 4).toInt();
        final retryDelaySeconds = 1 << backoffExponent;
        _instanceStates[result.instanceId] = InstanceRefreshState(
          isLoading: false,
          isStale: true,
          consecutiveFailures: failures,
          error: message,
          lastUpdated: previousState?.lastUpdated,
          nextRetryAt: result.attempted
              ? DateTime.now().add(Duration(seconds: retryDelaySeconds))
              : previousState?.nextRetryAt,
        );
      }
      _instanceStates.removeWhere(
        (instanceId, _) =>
            !connectedInstances.any((instance) => instance.id == instanceId),
      );
      _lastError = errors.isEmpty ? null : errors.join('; ');
      final lowerCaseNames = <String, String>{
        for (final t in newTasks) t.name: t.name.toLowerCase(),
      };
      newTasks.sort((a, b) => _compareTasks(a, b, lowerCaseNames));

      final terminalTransitionInstanceIds = _collectTaskNotifications(
        previousTasks,
        newTasks,
      );
      _tasks = newTasks;
      _tasksView = UnmodifiableListView(_tasks);
      _tasksVersion++;
      _saveSessionsForTerminalTransitions(
        connectedInstances,
        terminalTransitionInstanceIds,
      );
      _notifyIfActive();
    } catch (e, stackTrace) {
      _lastError = e.toString();
      this.e(
        'Failed to refresh tasks across connected instances',
        error: e,
        stackTrace: stackTrace,
      );
      _notifyIfActive();
    } finally {
      _isRefreshing = false;
    }
  }

  void _handleRpcNotification(
    Aria2Instance instance,
    Aria2RpcNotification notification,
  ) {
    if (_isDisposed || !notification.method.startsWith('aria2.on')) {
      return;
    }
    i(
      'Received ${notification.method} for ${instance.name}'
      '${notification.gid == null ? '' : ' (${notification.gid})'}',
    );
    final latestInstances = _connectedInstancesProvider?.call();
    if (latestInstances != null) {
      unawaited(refreshTasks(latestInstances));
    }
  }

  void _notifyIfActive() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  List<DownloadTaskNotification> takePendingNotifications() {
    final notifications = List<DownloadTaskNotification>.from(
      _pendingNotifications,
    );
    _pendingNotifications.clear();
    return notifications;
  }

  Future<_InstanceTaskRefreshResult> _fetchTasksForInstance(
    Aria2Instance instance,
  ) async {
    if (instance.status != ConnectionStatus.connected &&
        instance.status != ConnectionStatus.reconnecting) {
      w(
        'Skipping task fetch because instance ${instance.name} is not marked connected',
      );
      return _InstanceTaskRefreshResult.success(instance.id, const []);
    }

    final instanceId = instance.id;
    final isLocal = instance.type == InstanceType.builtin;
    final previousState = _instanceStates[instanceId];
    final nextRetryAt = previousState?.nextRetryAt;
    if (previousState?.isStale == true &&
        nextRetryAt != null &&
        DateTime.now().isBefore(nextRetryAt)) {
      return _InstanceTaskRefreshResult.failure(
        instanceId,
        previousState?.error ?? 'Waiting to retry',
        attempted: false,
      );
    }

    try {
      final allTasks = <DownloadTask>[];

      final client = _getClient(instance);
      final results = await client.getDownloadStatus();

      if (results.length < 3 ||
          results.take(3).any((result) => result['success'] != true)) {
        throw const RpcException(
          'aria2 returned an incomplete task status response',
        );
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

      return _InstanceTaskRefreshResult.success(instance.id, allTasks);
    } catch (e, stackTrace) {
      this.e(
        'Failed to fetch tasks for instance ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      return _InstanceTaskRefreshResult.failure(instance.id, e);
    }
  }

  static const _statusOrder = {
    DownloadStatus.active: 0,
    DownloadStatus.waiting: 1,
    DownloadStatus.stopped: 2,
  };

  int _compareTasks(
    DownloadTask left,
    DownloadTask right,
    Map<String, String> lowerCaseNames,
  ) {
    final leftOrder = _statusOrder[left.status] ?? 99;
    final rightOrder = _statusOrder[right.status] ?? 99;
    if (leftOrder != rightOrder) {
      return leftOrder.compareTo(rightOrder);
    }

    if (left.instanceId != right.instanceId) {
      return left.instanceId.compareTo(right.instanceId);
    }

    final aLower = lowerCaseNames[left.name] ?? left.name.toLowerCase();
    final bLower = lowerCaseNames[right.name] ?? right.name.toLowerCase();
    return aLower.compareTo(bLower);
  }

  void _restartTimer() {
    stopPeriodicRefresh();

    final connectedInstances = _connectedInstancesProvider?.call() ?? const [];

    if (connectedInstances.isNotEmpty) {
      _refreshTimer = Timer.periodic(Duration(milliseconds: _refreshInterval), (
        timer,
      ) {
        if (timer.isActive) {
          final latestConnectedInstances =
              _connectedInstancesProvider?.call() ?? const [];
          unawaited(refreshTasks(latestConnectedInstances));
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
          w(
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
    _isDisposed = true;
    _pendingRefreshInstances = null;
    stopPeriodicRefresh();
    _clearClientCache();
    super.dispose();
  }
}
