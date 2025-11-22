// Dart core imports
import 'dart:async';

// Flutter & third-party packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services
import '../../services/instance_manager.dart';
import '../../services/aria2_rpc_client.dart';
import '../../services/download_data_service.dart';

// Models
import '../../models/aria2_instance.dart';
import 'models/download_task.dart';

// Page-specific components
import 'components/add_task_dialog.dart';
import 'components/task_action_dialogs.dart';
import 'components/filter_selector.dart';
import 'components/task_list_view.dart';
import 'components/task_toolbar.dart';
import 'components/task_details_dialog.dart';
import 'services/download_task_service.dart';

// Utilities
import 'enums.dart';
import '../../utils/logging.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> with Loggable {
  FilterOption _selectedFilter = FilterOption.all;
  CategoryType _currentCategoryType = CategoryType.all;

  // Instance name mapping for displaying instance names
  Map<String, String> _instanceNames = {};
  
  // InstanceManager instance
  InstanceManager? instanceManager;
  
  // DownloadDataService instance
  DownloadDataService? downloadDataService;

  @override
  void initState() {
    super.initState();
    // Initialize logger
    initLogger();
    
    // Get service instances
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    downloadDataService = Provider.of<DownloadDataService>(context, listen: false);
    
    // Load instance names
    _loadInstanceNames(instanceManager!);
    
    // Listen for changes in the instance manager
    instanceManager?.addListener(_handleInstanceChanges);
    
    logger.d('DownloadPage initialized');
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    
    // Get service instances again in case dependencies change
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    downloadDataService = Provider.of<DownloadDataService>(context, listen: false);
    
    // Load instance names when dependencies change
    if (instanceManager != null) {
      _loadInstanceNames(instanceManager!);
    }
  }
  
  @override
  void dispose() {
    // Remove listener to avoid memory leaks
    if (instanceManager != null) {
      instanceManager!.removeListener(_handleInstanceChanges);
    }
    
    // Stop the refresh timer when disposing
    downloadDataService?.stopPeriodicRefresh();
    
    super.dispose();
  }
  
  // Method to handle instance status changes
  void _handleInstanceChanges() {
    if (mounted) {
      // Update refresh timer when instance changes
      _updateRefreshTimer();
      
      // Reload instance names
      if (instanceManager != null) {
        _loadInstanceNames(instanceManager!);
      }
      
      // Trigger UI rebuild
      setState(() {});
    }
  }
  
  // Update the refresh timer based on the active instance
  void _updateRefreshTimer() {
    if (instanceManager == null || downloadDataService == null || !mounted) return;
    
    final activeInstance = instanceManager!.activeInstance;
    
    // Record debug information to help locate issues
    logger.d('Updating refresh timer - Active instance: ${activeInstance?.name}, Status: ${activeInstance?.status}');
    
    if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
      // Start or update the refresh timer with the active instance
      logger.d('Starting periodic refresh for instance: ${activeInstance.name}');
      // Store timer reference for status tracking
      _refreshTimer = downloadDataService!.startPeriodicRefresh(activeInstance);
      // Force an immediate refresh only when the timer starts for the first time, avoiding triggering refresh on every UI update
      if (_refreshTimer != null) {
        logger.d('Performing initial refresh');
        downloadDataService!.refreshTasks(activeInstance);
      }
    } else {
      // Stop the refresh timer when there's no connected instance
      logger.d('Stopping periodic refresh - No connected instance');
      downloadDataService!.stopPeriodicRefresh();
      _refreshTimer = null; // Clear timer reference
    }
  }

  // Show task details dialog
  void _showTaskDetails(BuildContext context, DownloadTask task) {
    // Get complete task information from the global service
    logger.d('Show task details dialog for: ${task.name} (ID: ${task.id})');
    
    // Get all tasks from the downloadDataService
    final allTasks = downloadDataService?.tasks ?? [];
    
    // Show the task details dialog
    TaskDetailsDialog.showTaskDetailsDialog(
      context,
      task,
      allTasks,
      DownloadTaskService.getStatusInfo,
    );
  }
  
  // Load instance names
  Future<void> _loadInstanceNames(InstanceManager instanceManager) async {
    try {
      // Get all instances
      final instances = instanceManager.instances;
      
      // Build mapping from instance ID to name
      final Map<String, String> instanceMap = {};
      for (final instance in instances) {
        instanceMap[instance.id] = instance.name;
      }
      
      // Update state
      if (mounted) {
        setState(() {
          _instanceNames = instanceMap;
        });
      }
    } catch (e, stackTrace) {
      logger.e('Failed to load instance names', error: e, stackTrace: stackTrace);
      // Notify user when error occurs
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to load instance names: $e'),
            duration: const Duration(seconds: 3),
          ),
        );
        // Keep _instanceNames empty to avoid displaying incorrect instance information
      }
    }
  }
  
  
  // Get all instance ID list
  List<String> _getAllInstanceIds() {
    if (downloadDataService == null) return [];
    
    // Extract all unique instance IDs from tasks
    return downloadDataService!.tasks.map((task) => task.instanceId).toSet().toList();
  }

  // Refresh tasks and restart timer
  void _refreshTasksAndRestartTimer() {
    if (instanceManager == null || downloadDataService == null) return;
    
    final activeInstance = instanceManager!.activeInstance;
    if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
      // Directly refresh task data
      downloadDataService!.refreshTasks(activeInstance);
    }
  }

  // Store currently selected instance ID
  String? _selectedInstanceId;
  
  // Store timer reference for checking timer status
  Timer? _refreshTimer;
  
  // Filter tasks based on selected criteria
  List<DownloadTask> _filterTasks() {
    if (downloadDataService == null) return [];
    
    List<DownloadTask> tasks = downloadDataService!.tasks;
    
    // If filtering by instance, use _selectedInstanceId
    if (_currentCategoryType == CategoryType.byInstance && _selectedInstanceId != null) {
      tasks = tasks.where((task) => task.instanceId == _selectedInstanceId).toList();
    } else {
      // Other categories use _selectedFilter
      switch (_selectedFilter) {
        case FilterOption.all:
          // All tasks, no filtering
          break;
        case FilterOption.active:
          tasks = tasks.where((task) => task.status == DownloadStatus.active).toList();
          break;
        case FilterOption.waiting:
          tasks = tasks.where((task) => task.status == DownloadStatus.waiting).toList();
          break;
        case FilterOption.stopped:
          tasks = tasks.where((task) => task.status == DownloadStatus.stopped).toList();
          break;
        case FilterOption.local:
          tasks = tasks.where((task) => task.isLocal == true).toList();
          break;
        case FilterOption.remote:
          tasks = tasks.where((task) => task.isLocal == false).toList();
          break;
        case FilterOption.instance:
          // Instance filtering is already handled above
          break;
      }
    }
    
    return tasks;
  }
  

  
  // Handle category changes
  void _handleCategoryChanged(CategoryType newCategory) {
    setState(() {
      _currentCategoryType = newCategory;
    });
  }
  
  // Handle filter option changes
  void _handleFilterChanged(FilterOption newFilter) {
    setState(() {
      _selectedFilter = newFilter;
    });
  }
  
  // Handle instance selection changes
  void _handleInstanceSelected(String? instanceId) {
    setState(() {
      _selectedInstanceId = instanceId;
    });
  }
  
  // Store the last active instance ID and status for detecting real changes
  String? _lastActiveInstanceId;
  ConnectionStatus? _lastActiveInstanceStatus;

  @override
  Widget build(BuildContext context) {
    // Listen for InstanceManager changes to ensure immediate response when instance status changes
    final instanceManager = context.watch<InstanceManager>();
    
    // Get the latest data from DownloadDataService via Provider for responsive updates
    final lastError = context.watch<DownloadDataService>().lastError;
    
    // Get current active instance information
    final currentActiveInstance = instanceManager.activeInstance;
    final currentInstanceId = currentActiveInstance?.id;
    final currentInstanceStatus = currentActiveInstance?.status;
    
    // Only update the timer when the active instance truly changes (ID or status changes)
    if (currentInstanceId != _lastActiveInstanceId || 
        currentInstanceStatus != _lastActiveInstanceStatus) {
      // Update recorded instance information
      _lastActiveInstanceId = currentInstanceId;
      _lastActiveInstanceStatus = currentInstanceStatus;
      
      // Update refresh timer
      _updateRefreshTimer();
    }
    
    // Display error message
    if (lastError != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('获取任务数据失败: $lastError')),
        );
      });
    }
    
    return Scaffold(
      body: Column(
        children: [
          // Task action toolbar
          TaskToolbar(
            onAddTask: () => _showAddTaskDialog(context),
            onPauseAll: () => _showPauseDialog(context),
            onResumeAll: () => _showResumeDialog(context),
            onDeleteAll: () => _showDeleteDialog(context),
            onSearch: () {},
          ),
          
          // Filter selector
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
          
          // Task list - Material You style
          Expanded(
            child: TaskListView(
              tasks: _filterTasks(),
              instanceNames: _instanceNames,
              onTaskTap: (task) => _showTaskDetails(context, task),
              onTaskUpdated: _refreshTasksAndRestartTimer,
            ),
          ),
        ],
      ),
    );
  }

  // Show resume dialog
  void _showResumeDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.resume,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }

  // Show pause dialog
  void _showPauseDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.pause,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }

  // Show delete dialog
  void _showDeleteDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.delete,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }
  
  // Show add task dialog
  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
            onAddTask: (taskType, uri, downloadDir) async {
            try {
              // Get instance manager and active instance
              final instanceManager = Provider.of<InstanceManager>(context, listen: false);
              final activeInstance = instanceManager.activeInstance;
              
              if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                final client = Aria2RpcClient(activeInstance);
                
                // Add task based on task type
                switch (taskType) {
                  case 'uri':
                    if (uri.isNotEmpty) {
                      // Split URI by newlines to support multiple URLs
                      final uris = uri.split('\n').map((u) => u.trim()).where((u) => u.isNotEmpty).toList();
                      
                      // Add each URI as a separate download task
                      for (final singleUri in uris) {
                        await client.addUri(singleUri, downloadDir);
                      }
                    }
                    break;
                  case 'torrent':
                    // TODO: Implement torrent file upload logic
                    logger.d('Adding torrent task, download directory: $downloadDir');
                    break;
                  case 'metalink':
                    // TODO: Implement Metalink file upload logic
                    logger.d('Adding metalink task, download directory: $downloadDir');
                    break;
                }
                
                // Immediately refresh task list and reset timer
                _refreshTasksAndRestartTimer();
                
                client.close();
                
                // Show success message
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('任务添加成功')),
                  );
                }
              } else {
                // Show error message when no active instance
                if (context.mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('当前没有连接的实例')),
                  );
                }
              }
            } catch (e, stackTrace) {
              logger.e('Failed to add task', error: e, stackTrace: stackTrace);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('添加任务失败: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}