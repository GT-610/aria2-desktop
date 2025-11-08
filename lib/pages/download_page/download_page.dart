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
    
    // Update the timer based on the active instance
    _updateRefreshTimer();
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
    if (instanceManager == null || downloadDataService == null) return;
    
    final activeInstance = instanceManager!.activeInstance;
    
    if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
      // Start or update the refresh timer with the active instance
      downloadDataService!.startPeriodicRefresh(activeInstance);
      // Force an immediate refresh
      downloadDataService!.refreshTasks(activeInstance);
    } else {
      // Stop the refresh timer when there's no connected instance
      downloadDataService!.stopPeriodicRefresh();
    }
  }

  // Show task details dialog
  void _showTaskDetails(BuildContext context, DownloadTask task) {
    // 从全局服务获取完整的任务信息
    logger.d('Show task details dialog for: ${task.name} (ID: ${task.id})');
    
    // 这里可以实现任务详情对话框的显示逻辑
    // 由于我们使用全局的DownloadDataService，对话框可以直接订阅服务获取最新数据
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
  
  
  // 获取所有实例ID列表
  List<String> _getAllInstanceIds() {
    if (downloadDataService == null) return [];
    
    // 从任务中提取所有唯一的实例ID
    return downloadDataService!.tasks.map((task) => task.instanceId).toSet().toList();
  }

  // Refresh tasks and restart timer
  void _refreshTasksAndRestartTimer() {
    if (instanceManager == null || downloadDataService == null) return;
    
    final activeInstance = instanceManager!.activeInstance;
    if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
      // 直接刷新任务数据
      downloadDataService!.refreshTasks(activeInstance);
    }
  }

  // Store currently selected instance ID
  String? _selectedInstanceId;
  
  // Filter tasks based on selected criteria
  List<DownloadTask> _filterTasks() {
    if (downloadDataService == null) return [];
    
    List<DownloadTask> tasks = downloadDataService!.tasks;
    
    // 如果是按实例筛选，使用_selectedInstanceId
    if (_currentCategoryType == CategoryType.byInstance && _selectedInstanceId != null) {
      tasks = tasks.where((task) => task.instanceId == _selectedInstanceId).toList();
    } else {
      // 其他分类使用_selectedFilter
      switch (_selectedFilter) {
        case FilterOption.all:
          // 全部任务，不过滤
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
          // 实例筛选已经在上面处理
          break;
      }
    }
    
    return tasks;
  }
  

  
  // 处理分类变更
  void _handleCategoryChanged(CategoryType newCategory) {
    setState(() {
      _currentCategoryType = newCategory;
    });
  }
  
  // 处理筛选选项变更
  void _handleFilterChanged(FilterOption newFilter) {
    setState(() {
      _selectedFilter = newFilter;
    });
  }
  
  // 处理实例选择变更
  void _handleInstanceSelected(String? instanceId) {
    setState(() {
      _selectedInstanceId = instanceId;
    });
  }
  
  @override
  Widget build(BuildContext context) {
    // 通过Provider获取DownloadDataService的最新数据，实现响应式更新
    final lastError = context.watch<DownloadDataService>().lastError;
    
    // 显示错误信息
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

  // 显示继续对话框
  void _showResumeDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.resume,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }

  // 显示暂停对话框
  void _showPauseDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.pause,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }

  // 显示删除对话框
  void _showDeleteDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(
      context,
      TaskActionType.delete,
      onActionCompleted: _refreshTasksAndRestartTimer,
    );
  }
  
  // 显示添加任务对话框
  void _showAddTaskDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AddTaskDialog(
            onAddTask: (taskType, uri, downloadDir) async {
            try {
              // 获取实例管理器和活动实例
              final instanceManager = Provider.of<InstanceManager>(context, listen: false);
              final activeInstance = instanceManager.activeInstance;
              
              if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                final client = Aria2RpcClient(activeInstance);
                
                // 根据任务类型添加任务
                switch (taskType) {
                  case 'uri':
                    if (uri.isNotEmpty) {
                      await client.addUri(uri, downloadDir);
                    }
                    break;
                  case 'torrent':
                    // TODO: 实现种子文件上传逻辑
                    logger.d('Adding torrent task, download directory: $downloadDir');
                    break;
                  case 'metalink':
                    // TODO: 实现Metalink文件上传逻辑
                    logger.d('Adding metalink task, download directory: $downloadDir');
                    break;
                }
                
                // 立即刷新任务列表并重置计时器
                _refreshTasksAndRestartTimer();
                
                client.close();
              }
            } catch (e, stackTrace) {
              logger.e('Failed to add task', error: e, stackTrace: stackTrace);
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(content: Text('Failed to add task: $e')),
                );
              }
            }
          },
        );
      },
    );
  }
}