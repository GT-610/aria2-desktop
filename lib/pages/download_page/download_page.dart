import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../generated/l10n/l10n.dart';
import '../../services/aria2_rpc_client.dart';
import '../../services/download_data_service.dart';
import '../../services/instance_manager.dart';
import '../../utils/logging.dart';
import 'components/add_task_dialog.dart';
import 'components/filter_selector.dart';
import 'components/task_action_dialogs.dart';
import 'components/task_details_dialog.dart';
import 'components/task_list_view.dart';
import 'components/task_toolbar.dart';
import 'enums.dart';
import 'models/download_task.dart';
import 'services/download_task_service.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with Loggable {
  FilterOption _selectedFilter = FilterOption.all;
  CategoryType _currentCategoryType = CategoryType.all;
  TaskSortOption _sortOption = TaskSortOption.name;
  bool _sortDescending = false;
  Map<String, String> _instanceNames = {};

  InstanceManager? instanceManager;
  DownloadDataService? downloadDataService;
  String? _selectedInstanceId;
  String _searchQuery = '';
  final Set<String> _selectedTaskKeys = <String>{};
  Timer? _refreshTimer;
  String? _lastShownRefreshError;
  late final TextEditingController _searchController;

  @override
  void initState() {
    super.initState();
    _searchController = TextEditingController();
    d('DownloadPage initialized');
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    var dependenciesChanged = false;

    final nextInstanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final nextDownloadDataService = Provider.of<DownloadDataService>(
      context,
      listen: false,
    );

    if (instanceManager != nextInstanceManager) {
      instanceManager?.removeListener(_handleInstanceChanges);
      instanceManager = nextInstanceManager;
      instanceManager?.addListener(_handleInstanceChanges);
      dependenciesChanged = true;
    }

    if (downloadDataService != nextDownloadDataService) {
      downloadDataService?.removeListener(_handleDownloadDataChanges);
      downloadDataService = nextDownloadDataService;
      downloadDataService?.addListener(_handleDownloadDataChanges);
      dependenciesChanged = true;
    }

    if (dependenciesChanged) {
      _loadInstanceNames(instanceManager!);
      _updateRefreshTimer();
    }
  }

  @override
  void dispose() {
    instanceManager?.removeListener(_handleInstanceChanges);
    downloadDataService?.removeListener(_handleDownloadDataChanges);
    downloadDataService?.stopPeriodicRefresh();
    _refreshTimer?.cancel();
    _searchController.dispose();
    super.dispose();
  }

  void _handleInstanceChanges() {
    if (!mounted) return;

    _updateRefreshTimer();
    if (instanceManager != null) {
      _loadInstanceNames(instanceManager!);
    }
    setState(() {});
  }

  void _handleDownloadDataChanges() {
    if (!mounted || downloadDataService == null) {
      return;
    }

    _pruneSelection();

    final lastError = downloadDataService!.lastError;
    if (lastError == null) {
      _lastShownRefreshError = null;
      return;
    }

    if (lastError == _lastShownRefreshError) {
      return;
    }

    _lastShownRefreshError = lastError;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            AppLocalizations.of(context)!.failedToRefreshTasks(lastError),
          ),
        ),
      );
    });
  }

  void _updateRefreshTimer() {
    if (instanceManager == null || downloadDataService == null || !mounted) {
      return;
    }

    final connectedInstances = instanceManager!.getConnectedInstances();
    d(
      'Updating refresh timer for ${connectedInstances.length} connected instance(s)',
    );

    if (connectedInstances.isEmpty) {
      downloadDataService!.stopPeriodicRefresh();
      _refreshTimer = null;
      return;
    }

    _refreshTimer = downloadDataService!.startPeriodicRefresh(
      () => instanceManager?.getConnectedInstances() ?? const [],
    );
    if (_refreshTimer != null) {
      downloadDataService!.refreshTasks(connectedInstances);
    }
  }

  void _showTaskDetails(BuildContext context, DownloadTask task) {
    d('Show task details dialog for: ${task.name} (ID: ${task.id})');

    TaskDetailsDialog.showTaskDetailsDialog(
      context,
      task,
      () => downloadDataService?.tasks ?? const [],
      _instanceNames,
      (context, task, colorScheme) =>
          DownloadTaskService.getStatusInfo(context, task, colorScheme),
      onTaskUpdated: _refreshTasksAndRestartTimer,
    );
  }

  Future<void> _loadInstanceNames(InstanceManager instanceManager) async {
    try {
      final instanceMap = <String, String>{};
      for (final instance in instanceManager.instances) {
        instanceMap[instance.id] = instance.name;
      }

      if (mounted) {
        setState(() {
          _instanceNames = instanceMap;
        });
      }
    } catch (e, stackTrace) {
      this.e('Failed to load instance names', error: e, stackTrace: stackTrace);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              AppLocalizations.of(context)!.failedToLoadInstanceNames('$e'),
            ),
          ),
        );
      }
    }
  }

  List<String> _getAllInstanceIds() {
    if (downloadDataService == null) return [];

    return downloadDataService!.tasks
        .map((task) => task.instanceId)
        .toSet()
        .toList();
  }

  void _refreshTasksAndRestartTimer() {
    if (instanceManager == null || downloadDataService == null) return;

    final connectedInstances = instanceManager!.getConnectedInstances();
    if (connectedInstances.isNotEmpty) {
      downloadDataService!.refreshTasks(connectedInstances);
    }

    _pruneSelection();
  }

  String _taskKey(DownloadTask task) => '${task.instanceId}::${task.id}';

  bool get _isSelectionMode => _selectedTaskKeys.isNotEmpty;

  List<DownloadTask> _selectedTasksFrom(List<DownloadTask> visibleTasks) {
    return visibleTasks
        .where((task) => _selectedTaskKeys.contains(_taskKey(task)))
        .toList();
  }

  int _countActionableTasks(
    List<DownloadTask> tasks,
    TaskActionType actionType,
  ) {
    return TaskActionDialogs.actionableTasks(tasks, actionType).length;
  }

  void _pruneSelection() {
    if (downloadDataService == null || _selectedTaskKeys.isEmpty) return;

    final validKeys = downloadDataService!.tasks.map(_taskKey).toSet();
    final before = _selectedTaskKeys.length;
    _selectedTaskKeys.removeWhere((key) => !validKeys.contains(key));
    if (before != _selectedTaskKeys.length && mounted) {
      setState(() {});
    }
  }

  List<DownloadTask> _filterTasks() {
    if (downloadDataService == null) return [];

    var tasks = List<DownloadTask>.from(downloadDataService!.tasks);

    if (_currentCategoryType == CategoryType.byInstance &&
        _selectedInstanceId != null) {
      tasks = tasks
          .where((task) => task.instanceId == _selectedInstanceId)
          .toList();
    } else {
      switch (_selectedFilter) {
        case FilterOption.all:
          break;
        case FilterOption.active:
          tasks = tasks
              .where((task) => task.status == DownloadStatus.active)
              .toList();
          break;
        case FilterOption.waiting:
          tasks = tasks
              .where((task) => task.status == DownloadStatus.waiting)
              .toList();
          break;
        case FilterOption.stopped:
          tasks = tasks
              .where((task) => task.status == DownloadStatus.stopped)
              .toList();
          break;
        case FilterOption.local:
          tasks = tasks.where((task) => task.isLocal).toList();
          break;
        case FilterOption.remote:
          tasks = tasks.where((task) => !task.isLocal).toList();
          break;
        case FilterOption.instance:
          break;
      }
    }

    if (_searchQuery.isNotEmpty) {
      final query = _searchQuery.toLowerCase();
      tasks = tasks.where((task) {
        final instanceName = (_instanceNames[task.instanceId] ?? '')
            .toLowerCase();
        final taskDir = (task.dir ?? '').toLowerCase();
        final taskName = task.name.toLowerCase();
        return taskName.contains(query) ||
            taskDir.contains(query) ||
            instanceName.contains(query);
      }).toList();
    }

    tasks.sort((left, right) {
      int result;
      switch (_sortOption) {
        case TaskSortOption.name:
          result = left.name.toLowerCase().compareTo(right.name.toLowerCase());
          break;
        case TaskSortOption.progress:
          result = left.progress.compareTo(right.progress);
          break;
        case TaskSortOption.size:
          result = left.totalLengthBytes.compareTo(right.totalLengthBytes);
          break;
        case TaskSortOption.speed:
          result = left.downloadSpeedBytes.compareTo(right.downloadSpeedBytes);
          break;
        case TaskSortOption.instance:
          final leftName = _instanceNames[left.instanceId] ?? left.instanceId;
          final rightName =
              _instanceNames[right.instanceId] ?? right.instanceId;
          result = leftName.toLowerCase().compareTo(rightName.toLowerCase());
          break;
      }

      if (result == 0) {
        result = left.id.compareTo(right.id);
      }
      return _sortDescending ? -result : result;
    });

    return tasks;
  }

  void _handleSearchChanged(String value) {
    setState(() {
      _searchQuery = value.trim();
    });
  }

  void _handleSortChanged(TaskSortOption option) {
    setState(() {
      _sortOption = option;
    });
  }

  void _handleSortDirectionChanged(bool descending) {
    setState(() {
      _sortDescending = descending;
    });
  }

  void _handleCategoryChanged(CategoryType newCategory) {
    setState(() {
      _currentCategoryType = newCategory;
      if (newCategory != CategoryType.byInstance) {
        _selectedInstanceId = null;
      }
    });
  }

  void _handleFilterChanged(FilterOption newFilter) {
    setState(() {
      _selectedFilter = newFilter;
    });
  }

  void _handleInstanceSelected(String? instanceId) {
    setState(() {
      _selectedInstanceId = instanceId;
    });
  }

  void _toggleTaskSelection(DownloadTask task) {
    final key = _taskKey(task);
    setState(() {
      if (_selectedTaskKeys.contains(key)) {
        _selectedTaskKeys.remove(key);
      } else {
        _selectedTaskKeys.add(key);
      }
    });
  }

  void _startTaskSelection(DownloadTask task) {
    final key = _taskKey(task);
    setState(() {
      _selectedTaskKeys.add(key);
    });
  }

  void _clearSelection() {
    setState(() {
      _selectedTaskKeys.clear();
    });
  }

  void _selectAllVisibleTasks(List<DownloadTask> tasks) {
    setState(() {
      _selectedTaskKeys
        ..clear()
        ..addAll(tasks.map(_taskKey));
    });
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    context.watch<InstanceManager>();
    context.watch<DownloadDataService>();
    final filteredTasks = _filterTasks();
    final selectedTasks = _selectedTasksFrom(filteredTasks);
    final pauseableVisibleCount = _countActionableTasks(
      filteredTasks,
      TaskActionType.pause,
    );
    final resumableVisibleCount = _countActionableTasks(
      filteredTasks,
      TaskActionType.resume,
    );
    final deletableVisibleCount = _countActionableTasks(
      filteredTasks,
      TaskActionType.delete,
    );
    final pauseableSelectedCount = _countActionableTasks(
      selectedTasks,
      TaskActionType.pause,
    );
    final resumableSelectedCount = _countActionableTasks(
      selectedTasks,
      TaskActionType.resume,
    );
    final deletableSelectedCount = _countActionableTasks(
      selectedTasks,
      TaskActionType.delete,
    );

    return Scaffold(
      body: Column(
        children: [
          TaskToolbar(
            onAddTask: () => _showAddTaskDialog(context),
            onPauseAll: pauseableVisibleCount > 0
                ? () => _showPauseDialog(context, tasks: filteredTasks)
                : null,
            onResumeAll: resumableVisibleCount > 0
                ? () => _showResumeDialog(context, tasks: filteredTasks)
                : null,
            onDeleteAll: deletableVisibleCount > 0
                ? () => _showDeleteDialog(context, tasks: filteredTasks)
                : null,
            searchController: _searchController,
            onSearchChanged: _handleSearchChanged,
            sortOption: _sortOption,
            sortDescending: _sortDescending,
            onSortChanged: _handleSortChanged,
            onSortDirectionChanged: _handleSortDirectionChanged,
          ),
          if (_isSelectionMode)
            _SelectionToolbar(
              selectedCount: selectedTasks.length,
              visibleCount: filteredTasks.length,
              pauseableSelectedCount: pauseableSelectedCount,
              resumableSelectedCount: resumableSelectedCount,
              deletableSelectedCount: deletableSelectedCount,
              l10n: l10n,
              onClearSelection: _clearSelection,
              onSelectAll: () => _selectAllVisibleTasks(filteredTasks),
              onPauseSelected: () =>
                  _showPauseDialog(context, tasks: selectedTasks),
              onResumeSelected: () =>
                  _showResumeDialog(context, tasks: selectedTasks),
              onDeleteSelected: () =>
                  _showDeleteDialog(context, tasks: selectedTasks),
            ),
          FilterSelector(
            currentCategoryType: _currentCategoryType,
            selectedFilter: _selectedFilter,
            selectedInstanceId: _selectedInstanceId,
            instanceNames: _instanceNames,
            instanceIds: _getAllInstanceIds(),
            onCategoryChanged: _handleCategoryChanged,
            onFilterChanged: _handleFilterChanged,
            onInstanceSelected: _handleInstanceSelected,
          ),
          Expanded(
            child: TaskListView(
              tasks: filteredTasks,
              instanceNames: _instanceNames,
              onTaskTap: (task) => _showTaskDetails(context, task),
              onTaskLongPress: _startTaskSelection,
              onTaskSelectionToggle: _toggleTaskSelection,
              selectedTaskKeys: _selectedTaskKeys,
              onTaskUpdated: _refreshTasksAndRestartTimer,
            ),
          ),
        ],
      ),
    );
  }

  void _showResumeDialog(BuildContext context, {List<DownloadTask>? tasks}) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.resume,
      tasks: tasks,
      onActionCompleted: () {
        _clearSelection();
        _refreshTasksAndRestartTimer();
      },
    );
  }

  void _showPauseDialog(BuildContext context, {List<DownloadTask>? tasks}) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.pause,
      tasks: tasks,
      onActionCompleted: () {
        _clearSelection();
        _refreshTasksAndRestartTimer();
      },
    );
  }

  void _showDeleteDialog(BuildContext context, {List<DownloadTask>? tasks}) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.delete,
      tasks: tasks,
      onActionCompleted: () {
        _clearSelection();
        _refreshTasksAndRestartTimer();
      },
    );
  }

  void _showAddTaskDialog(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final targetInstances = instanceManager.getConnectedInstances();
    final defaultTarget = instanceManager.getPreferredTargetInstance();

    if (targetInstances.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.connectBeforeAddingTasks)));
      return;
    }

    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
          targetInstances: targetInstances,
          defaultTargetInstanceId: defaultTarget?.id,
          onAddTask:
              (
                taskType,
                uri,
                downloadDir,
                fileContent,
                targetInstanceId,
              ) async {
                final dialogInstanceManager = Provider.of<InstanceManager>(
                  context,
                  listen: false,
                );
                Aria2RpcClient? client;
                try {
                  final targetInstance = dialogInstanceManager.getInstanceById(
                    targetInstanceId,
                  );

                  if (targetInstance == null) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(content: Text(l10n.noConnectedInstance)),
                      );
                    }
                    return false;
                  }

                  client = Aria2RpcClient(targetInstance);
                  final options = <String, dynamic>{};
                  if (downloadDir.trim().isNotEmpty) {
                    options['dir'] = downloadDir.trim();
                  }

                  switch (taskType) {
                    case 'uri':
                      final uris = uri
                          .split('\n')
                          .map((u) => u.trim())
                          .where((u) => u.isNotEmpty)
                          .toList();
                      if (uris.isEmpty) {
                        return false;
                      }
                      await client.addUri(uris, options);
                      break;
                    case 'torrent':
                      if (fileContent == null) {
                        return false;
                      }
                      await client.addTorrent(fileContent, options);
                      break;
                    case 'metalink':
                      if (fileContent == null) {
                        return false;
                      }
                      await client.addMetalink(fileContent, options);
                      break;
                  }

                  _refreshTasksAndRestartTimer();

                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text(
                          l10n.taskAddedToInstanceSuccess(targetInstance.name),
                        ),
                      ),
                    );
                  }
                  return true;
                } catch (e, stackTrace) {
                  this.e(
                    'Failed to add task',
                    error: e,
                    stackTrace: stackTrace,
                  );
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text(l10n.addTaskFailed('$e'))),
                    );
                  }
                  return false;
                } finally {
                  client?.close();
                }
              },
        );
      },
    );
  }
}

class _SelectionToolbar extends StatelessWidget {
  final int selectedCount;
  final int visibleCount;
  final int pauseableSelectedCount;
  final int resumableSelectedCount;
  final int deletableSelectedCount;
  final AppLocalizations l10n;
  final VoidCallback onClearSelection;
  final VoidCallback onSelectAll;
  final VoidCallback onPauseSelected;
  final VoidCallback onResumeSelected;
  final VoidCallback onDeleteSelected;

  const _SelectionToolbar({
    required this.selectedCount,
    required this.visibleCount,
    required this.pauseableSelectedCount,
    required this.resumableSelectedCount,
    required this.deletableSelectedCount,
    required this.l10n,
    required this.onClearSelection,
    required this.onSelectAll,
    required this.onPauseSelected,
    required this.onResumeSelected,
    required this.onDeleteSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      color: colorScheme.primaryContainer.withValues(alpha: 0.45),
      child: Wrap(
        spacing: 8,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          Text(
            l10n.selectedCount(selectedCount.toString()),
            style: Theme.of(context).textTheme.titleSmall,
          ),
          OutlinedButton(
            onPressed: onSelectAll,
            child: Text(
              selectedCount == visibleCount
                  ? l10n.allVisibleSelected
                  : l10n.selectAllVisible,
            ),
          ),
          FilledButton.tonal(
            onPressed: pauseableSelectedCount > 0 ? onPauseSelected : null,
            child: Text(l10n.pause),
          ),
          FilledButton.tonal(
            onPressed: resumableSelectedCount > 0 ? onResumeSelected : null,
            child: Text(l10n.resume),
          ),
          FilledButton.tonal(
            onPressed: deletableSelectedCount > 0 ? onDeleteSelected : null,
            child: Text(l10n.delete),
          ),
          TextButton(onPressed: onClearSelection, child: Text(l10n.clear)),
        ],
      ),
    );
  }
}
