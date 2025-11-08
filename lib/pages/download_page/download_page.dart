// Dart core imports
import 'dart:async';

// Flutter & third-party packages
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// Services
import '../../services/instance_manager.dart';
import '../../services/aria2_rpc_client.dart';

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
import 'utils/task_parser.dart';

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  FilterOption _selectedFilter = FilterOption.all;
  CategoryType _currentCategoryType = CategoryType.all;

  // Instance name mapping for displaying instance names
  Map<String, String> _instanceNames = {};
  
  // Timer for periodically fetching task status
  Timer? _refreshTimer;
  
  // Download task list
  List<DownloadTask> _downloadTasks = [];
  
  // InstanceManager instance
  InstanceManager? instanceManager;

  @override
  void initState() {
    super.initState();
    // Load instance names and initialize
    _initialize();
    
    // Get InstanceManager instance through Provider
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    // Listen for changes in the instance manager and refresh the page when instance status changes
    instanceManager?.addListener(_handleInstanceChanges);
    
    // Start periodic refresh (every 1 second)
    _startPeriodicRefresh();
  }
  
  // Initialize
  Future<void> _initialize() async {
    // Get instance manager from Provider
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    await _loadInstanceNames(instanceManager!);
    await _refreshTasks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Listen for changes in the instance manager
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    instanceManager?.addListener(_handleInstanceChanges);
  }
  
  // Start periodic refresh
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _refreshTasks();
    });
  }
  
  // Stop periodic refresh
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  @override
  void dispose() {
    _stopPeriodicRefresh();
    // Remove listener to avoid memory leaks
    if (instanceManager != null) {
      instanceManager!.removeListener(_handleInstanceChanges);
    }
    super.dispose();
  }
  
  // Method to handle instance status changes
  void _handleInstanceChanges() {
    if (mounted && instanceManager != null) {
      setState(() {
        // When status changes, we don't need any special handling, setState will trigger UI rebuild
        // UI will re-render based on the latest instance status during rebuild
      });
      // When instance status changes, reload the task list
      _refreshTasks();
    }
  }
  
  // Refresh all tasks
  Future<void> _refreshTasks() async {
    try {
      List<DownloadTask> allTasks = [];
      
      // Get instance manager from Provider
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      
      // Only send requests to active instances, no longer loop through all instances
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null) {
        // Check instance status, do not attempt to connect if not in connected state
        if (activeInstance.status == ConnectionStatus.connected) {
          try {
            // Create RPC client
            final client = Aria2RpcClient(activeInstance);
            
            // Send multicall request to get all tasks
            final response = await client.getTasksMulticall();
            
            // Parse response
            if (response.containsKey('result') && response['result'] is List) {
              final result = response['result'] as List;
              
              // Print debug information: structure and content of result
              print('result结构: $result');
              print('result长度: ${result.length}');
              
              // Parse active tasks - handle three-layer nested array structure [[[]], [[]], [[...]]]
              if (result.length > 0 && result[0] is List && (result[0] as List).isNotEmpty && (result[0] as List)[0] is List) {
                final activeTasks = (result[0] as List)[0] as List;
                print('活跃任务数量: ${activeTasks.length}');
                allTasks.addAll(_parseTasks(activeTasks, DownloadStatus.active, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // Parse waiting tasks
              if (result.length > 1 && result[1] is List && (result[1] as List).isNotEmpty && (result[1] as List)[0] is List) {
                final waitingTasks = (result[1] as List)[0] as List;
                print('等待任务数量: ${waitingTasks.length}');
                allTasks.addAll(_parseTasks(waitingTasks, DownloadStatus.waiting, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // Parse stopped tasks
              if (result.length > 2 && result[2] is List && (result[2] as List).isNotEmpty && (result[2] as List)[0] is List) {
                final stoppedTasks = (result[2] as List)[0] as List;
                print('已停止任务数量: ${stoppedTasks.length}');
                if (stoppedTasks.isNotEmpty) {
                  print('第一个已停止任务数据: ${stoppedTasks[0]}');
                }
                final parsedStoppedTasks = _parseTasks(stoppedTasks, DownloadStatus.stopped, activeInstance.id, activeInstance.type == InstanceType.local);
                print('解析后的已停止任务数量: ${parsedStoppedTasks.length}');
                allTasks.addAll(parsedStoppedTasks);
              }
            }
            
            // Close client
            client.close();
          } catch (e) {
            print('Failed to get tasks from instance ${activeInstance.name}: $e');
          }
        } else if (activeInstance.status == ConnectionStatus.connecting) {
          // Do not try to connect if already connecting
        } else {
          // Do not try to connect if not connected
        }
      }
      
      // Update task list
      if (mounted) {
        setState(() {
          _downloadTasks = allTasks;
        });
        
        // 如果有任务详情对话框打开，通知其更新
        // 注意：由于我们使用StatefulBuilder，实际上StatefulBuilder会自动重建
        // 当主循环调用setState时，整个页面会重建，包括打开的对话框
      }
    } catch (e) {
      print('Failed to refresh tasks: $e');
    }
  }
  
  // Parse task list - now stores complete information in the model
  // Use TaskParser to parse tasks
  List<DownloadTask> _parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    // Return the result parsed by TaskParser directly
    return TaskParser.parseTasks(tasks, status, instanceId, isLocal);
  }

  // Show task details dialog - to be implemented
  void _showTaskDetails(BuildContext context, DownloadTask task) {
    // This function is a placeholder and will be implemented in future updates
    print('Show task details dialog for: ${task.name}');
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
    } catch (e) {
      print('Failed to load instance names: $e');
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
    // 从任务中提取所有唯一的实例ID
    return _downloadTasks.map((task) => task.instanceId).toSet().toList();
  }

  // Refresh tasks and restart timer
  void _refreshTasksAndRestartTimer() {
    _refreshTasks();
    _stopPeriodicRefresh();
    _startPeriodicRefresh();
  }

  // Store currently selected instance ID
  String? _selectedInstanceId;
  
  // Filter tasks based on selected criteria
  List<DownloadTask> _filterTasks() {
    List<DownloadTask> filtered = _downloadTasks;
    
    // 如果是按实例筛选，使用_selectedInstanceId
    if (_currentCategoryType == CategoryType.byInstance && _selectedInstanceId != null) {
      filtered = filtered.where((task) => task.instanceId == _selectedInstanceId).toList();
    } else {
      // 其他分类使用_selectedFilter
      switch (_selectedFilter) {
        case FilterOption.all:
          // 全部任务，不过滤
          break;
        case FilterOption.active:
          filtered = filtered.where((task) => task.status == DownloadStatus.active).toList();
          break;
        case FilterOption.waiting:
          filtered = filtered.where((task) => task.status == DownloadStatus.waiting).toList();
          break;
        case FilterOption.stopped:
          filtered = filtered.where((task) => task.status == DownloadStatus.stopped).toList();
          break;
        case FilterOption.local:
          filtered = filtered.where((task) => task.isLocal == true).toList();
          break;
        case FilterOption.remote:
          filtered = filtered.where((task) => task.isLocal == false).toList();
          break;
        case FilterOption.instance:
          // 实例筛选已经在上面处理
          break;
      }
    }
    
    return filtered;
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
                    print('添加种子任务，下载目录: $downloadDir');
                    break;
                  case 'metalink':
                    // TODO: 实现Metalink文件上传逻辑
                    print('添加Metalink任务，下载目录: $downloadDir');
                    break;
                }
                
                // 立即刷新任务列表并重置计时器
                _refreshTasksAndRestartTimer();
                
                client.close();
              }
            } catch (e) {
              print('添加任务失败: $e');
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