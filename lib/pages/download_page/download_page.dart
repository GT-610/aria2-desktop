import 'dart:async';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../services/instance_manager.dart';
import '../../services/aria2_rpc_client.dart';
import '../../models/aria2_instance.dart';
import 'components/add_task_dialog.dart';
import 'components/task_action_dialogs.dart';
import 'components/task_details_dialog.dart';
import '../../utils/format_utils.dart';
import 'enums.dart';
import 'utils/task_parser.dart';
import 'models/download_task.dart';

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

  // Show task details dialog using main loop data - now displays extended information
  void _showTaskDetails(BuildContext context, DownloadTask task) {
    // 使用模块化的任务详情对话框组件
    TaskDetailsDialog.showTaskDetailsDialog(context, task, _downloadTasks, _getStatusInfo);
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
  
  // Get instance name by ID
  String _getInstanceName(String instanceId) {
    return _instanceNames[instanceId] ?? '未知实例';
  }
  
  // Get all instance IDs list
  List<String> _getAllInstanceIds() {
    // 从任务中提取所有唯一的实例ID
    return _downloadTasks.map((task) => task.instanceId).toSet().toList();
  }

  // Get status text and color
  (String, Color) _getStatusInfo(DownloadTask task, ColorScheme colorScheme) {
    // 检查是否为暂停中任务
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return ('已暂停', colorScheme.tertiary);
    }
    
    // 特殊处理已完成的任务
    if (task.status == DownloadStatus.stopped && task.taskStatus == 'complete') {
      return ('已完成', colorScheme.primaryContainer);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return ('下载中', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('等待中', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('已停止', colorScheme.errorContainer);
    }
  }

  // 打开下载目录
  void _openDownloadDirectory(DownloadTask task) async {
    try {
      // 检查任务是否有下载目录信息
      if (task.dir == null || task.dir!.isEmpty) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('无法获取下载目录信息')),
        );
        return;
      }

      String directoryPath = task.dir!;
      
      // 确保路径存在
      if (!Directory(directoryPath).existsSync()) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('下载目录不存在')),
        );
        return;
      }

      // 不同平台的处理方式
      if (Platform.isWindows) {
        // Windows平台特殊处理：使用explorer命令打开目录
        // 修复Windows路径格式问题
        String windowsPath = directoryPath;
        // 对于Windows路径，我们使用run方法而不是url_launcher
        await Process.run('explorer.exe', [windowsPath]);
        print('Opening Windows directory: $windowsPath');
      } else {
        // 非Windows平台使用file://协议
        Uri uri = Uri.parse('file://$directoryPath');
        
        // 尝试打开目录
        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('无法打开下载目录')),
          );
        }
      }
    } catch (e) {
      print('Error opening directory: $e');
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('打开目录时出错: $e')),
      );
    }
  }

  // Get status icon
  Icon _getStatusIcon(DownloadTask task, Color color) {
    // 检查是否为暂停中任务
    if (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') {
      return Icon(Icons.pause, color: color);
    }
    
    // 特殊处理已完成的任务
    if (task.status == DownloadStatus.stopped && task.taskStatus == 'complete') {
      return Icon(Icons.check_circle, color: color);
    }
    
    switch (task.status) {
      case DownloadStatus.active:
        return Icon(Icons.file_download, color: color);
      case DownloadStatus.waiting:
        return Icon(Icons.schedule, color: color);
      case DownloadStatus.stopped:
        return Icon(Icons.pause_circle, color: color);
    }
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
  
  // Get display text for filter option
  String _getFilterText(FilterOption filter) {
    switch (filter) {
      case FilterOption.all:
        return '全部';
      case FilterOption.active:
        return '下载中';
      case FilterOption.waiting:
        return '等待中';
      case FilterOption.stopped:
        return '已停止 / 已完成';
      case FilterOption.local:
        return '本地';
      case FilterOption.remote:
        return '远程';
      case FilterOption.instance:
        return '实例';
    }
  }
  
  // Get color for filter option
  Color _getFilterColor(FilterOption filter, ColorScheme colorScheme) {
    switch (filter) {
      case FilterOption.all:
        return colorScheme.primaryContainer;
      case FilterOption.active:
        return colorScheme.primary;
      case FilterOption.waiting:
        return colorScheme.secondary;
      case FilterOption.stopped:
        return colorScheme.errorContainer;
      case FilterOption.local:
        return colorScheme.primary;
      case FilterOption.remote:
        return colorScheme.secondary;
      case FilterOption.instance:
        return colorScheme.tertiary;
    }
  }
  
  // Show category selection dialog
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择分类方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // All option
              TaskActionDialogs.buildDialogOption(
                context,
                '全部',
                onTap: () {
                  setState(() {
                    _selectedFilter = FilterOption.all;
                    _currentCategoryType = CategoryType.all;
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By status
              TaskActionDialogs.buildDialogOption(
                context,
                '按状态',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byStatus;
                    _selectedFilter = FilterOption.active; // Select the first option by default
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By type
              TaskActionDialogs.buildDialogOption(
                context,
                '按类型',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byType;
                    _selectedFilter = FilterOption.local; // Select first option by default
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By instance
              TaskActionDialogs.buildDialogOption(
                context,
                '按实例',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byInstance;
                    _selectedInstanceId = null; // Reset selected instance
                  });
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }
  
  // Build dialog option
  // 对话框选项构建功能已移至TaskActionDialogs组件中
  
  // Build filter selector
  Widget _buildFilterSelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: Row(
        children: [
          // Category button - always show this for switching categories
          FilledButton.tonal(
            onPressed: _showCategoryDialog,
            style: FilledButton.styleFrom(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
            child: Row(
              children: [
                Text(_getCurrentCategoryText()),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          // Only show filter chips when not in 'all' category
          if (_currentCategoryType != CategoryType.all) 
            const SizedBox(width: 12),
          // Dynamic filter chips based on selected category - only show when not in 'all' category
          if (_currentCategoryType != CategoryType.all) 
            // Special handling for instance category
            if (_currentCategoryType == CategoryType.byInstance)
              ..._getInstanceFilterOptions().map((instanceId) {
                final isSelected = _selectedInstanceId == instanceId;
                final instanceColor = colorScheme.tertiary;
                
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _getInstanceName(instanceId),
                        style: TextStyle(
                          color: instanceColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        setState(() {
                          _selectedInstanceId = selected ? instanceId : null;
                        });
                      },
                      selectedColor: instanceColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }).toList()
            else
              ..._getFilterOptionsForCurrentCategory().map((option) {
                final isSelected = _selectedFilter == option;
                final filterColor = _getFilterColor(option, colorScheme);
                
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        _getFilterText(option),
                        style: TextStyle(
                          color: filterColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        if (selected) {
                          setState(() {
                            _selectedFilter = option;
                          });
                        }
                      },
                      selectedColor: filterColor.withOpacity(0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }).toList(),
        ],
      ),
    );
  }
  
  // Get current category display text
  String _getCurrentCategoryText() {
    switch (_currentCategoryType) {
      case CategoryType.all:
        return '全部';
      case CategoryType.byStatus:
        return '按状态';
      case CategoryType.byType:
        return '按类型';
      case CategoryType.byInstance:
        return '按实例';
      }
  }
  
  // Get instance ID list as filter options
  List<String> _getInstanceFilterOptions() {
    return _getAllInstanceIds();
  }
  
  // Get filter options based on current category
  List<FilterOption> _getFilterOptionsForCurrentCategory() {
    switch (_currentCategoryType) {
      case CategoryType.byStatus:
        return [FilterOption.active, FilterOption.waiting, FilterOption.stopped];
      case CategoryType.byType:
        return [FilterOption.local, FilterOption.remote];
      case CategoryType.byInstance:
        // For instance category, we will handle it separately in UI
        return [FilterOption.instance];
      default:
        return [];
    }
  }
  
  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    
    return Scaffold(
      body: Column(
        children: [
          // Task action toolbar - Material You style
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: colorScheme.surface,
              border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
            ),
            child: Row(
              children: [
                FilledButton.icon(
                  onPressed: () {
                    _showAddTaskDialog(context);
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('添加任务'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {
                    _showPauseDialog(context);
                  },
                  icon: const Icon(Icons.pause),
                  label: const Text('全部暂停'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () => _showResumeDialog(context),
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('全部继续'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.delete),
                  label: const Text('全部删除'),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const Spacer(),
                IconButton.outlined(
                  onPressed: () {},
                  icon: const Icon(Icons.search),
                  style: IconButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ],
            ),
          ),
          // Filter selector
          _buildFilterSelector(colorScheme),
          // Task list - Material You style
          Expanded(
            child: _buildTaskList(theme, colorScheme),
          ),
        ],
      ),
    );
  }

  // Build task list
  Widget _buildTaskList(ThemeData theme, ColorScheme colorScheme) {
    final tasks = _filterTasks();
    
    // Check if there are any connected instances
    final hasConnectedInstances = instanceManager?.instances.any((instance) => 
      instance.status == ConnectionStatus.connected
    ) ?? false;
    
    // If no connected instances, show special prompt
    if (!hasConnectedInstances) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('没有正在连接的实例，快去连接实例吧', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }
    
    // If there are connected instances but no tasks, show 'no tasks' message
    if (tasks.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.inbox_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('暂无任务', style: theme.textTheme.titleMedium),
          ],
        ),
      );
    }

    return ListView.builder(
      padding: const EdgeInsets.all(12),
      itemCount: tasks.length,
      itemBuilder: (context, index) {
        final task = tasks[index];
        final (statusText, statusColor) = _getStatusInfo(task, colorScheme);
        
        return Card(
          margin: const EdgeInsets.symmetric(horizontal: 0, vertical: 8),
          elevation: 2,
          shadowColor: Colors.black.withOpacity(0.1),
          surfaceTintColor: colorScheme.surface,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(12),
            onTap: () {
              _showTaskDetails(context, task);
            },
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Task name and status icon
                    Row(
                      children: [
                        _getStatusIcon(task, statusColor),
                        const SizedBox(width: 12),
                        // Progress percentage - styled like download speed
                        if (task.progress > 0)
                          Container(
                            margin: EdgeInsets.only(right: 8),
                            padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: statusColor.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Row(
                              children: [
                                Text(
                                  '${(task.progress * 100).toInt()}%',
                                  style: TextStyle(
                                    color: statusColor,
                                    fontSize: 11,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        Expanded(
                          child: Text(
                            task.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        // Download and upload speed display
                        if (task.status == DownloadStatus.active)
                          Row(
                            children: [
                              // Upload speed
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.secondary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.upload, size: 12, color: colorScheme.secondary),
                                    SizedBox(width: 4),
                                    Text(
                                      task.uploadSpeed,
                                      style: TextStyle(
                                        color: colorScheme.secondary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              // Download speed
                              Container(
                                margin: EdgeInsets.only(right: 8),
                                padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                decoration: BoxDecoration(
                                  color: colorScheme.primary.withOpacity(0.1),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    Icon(Icons.download, size: 12, color: colorScheme.primary),
                                    SizedBox(width: 4),
                                    Text(
                                      task.downloadSpeed,
                                      style: TextStyle(
                                        color: colorScheme.primary,
                                        fontSize: 11,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        // Status label
                        Container(
                          padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                          decoration: BoxDecoration(
                            color: statusColor.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            statusText,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 12,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ),
                      ],
                    ),
                    
                    const SizedBox(height: 12),
                    
                    // Progress bar (shown for all statuses with slight style variation for non-active)
                    Stack(
                      children: [
                        LinearProgressIndicator(
                          value: task.progress,
                          borderRadius: BorderRadius.circular(10),
                          minHeight: 6,
                          backgroundColor: colorScheme.surfaceVariant,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            // 暂停中任务使用黄色显示进度条
                            (task.status == DownloadStatus.waiting && task.taskStatus == 'paused') 
                              ? colorScheme.tertiary 
                              : (task.status == DownloadStatus.active ? statusColor : statusColor.withOpacity(0.6)),
                          ),
                        ),
                        // No longer showing progress text on the progress bar
                      ],
                    ),
                    
                    const SizedBox(height: 8),
                    
                    // Task details
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        // File size info and instance name
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Instance name
                            Container(
                              margin: EdgeInsets.only(bottom: 2),
                              padding: EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                              decoration: BoxDecoration(
                                color: colorScheme.tertiary.withOpacity(0.1),
                                borderRadius: BorderRadius.circular(8),
                              ),
                              child: Text(
                                _getInstanceName(task.instanceId),
                                style: TextStyle(
                                  color: colorScheme.tertiary,
                                  fontSize: 11,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ),
                            // Size info with remaining time
                            Text(
                              '${task.completedSize} / ${task.size} (${calculateRemainingTime(task.progress, task.downloadSpeed)})',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        // Action buttons - Dynamic based on task status
                        Row(
                          children: [
                            if (task.status == DownloadStatus.active) ...[
                              // Pause button
                              Tooltip(
                                message: '暂停',
                                child: IconButton(
                                  icon: const Icon(Icons.pause),
                                  onPressed: () async {
                                    print('Pause task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.pauseTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error pausing task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                              SizedBox(width: 8), // Add spacing between buttons
                              // Stop button
                              Tooltip(
                                message: '停止',
                                child: IconButton(
                                  icon: const Icon(Icons.stop),
                                  onPressed: () async {
                                    print('Stop task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.removeTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error stopping task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ] else if (task.status == DownloadStatus.waiting) ...[
                              // Resume button
                              Tooltip(
                                message: '继续',
                                child: IconButton(
                                  icon: const Icon(Icons.play_arrow),
                                  onPressed: () async {
                                    print('Resume task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.unpauseTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error resuming task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                              SizedBox(width: 8), // Add spacing between buttons
                              // Stop button
                              Tooltip(
                                message: '停止',
                                child: IconButton(
                                  icon: const Icon(Icons.stop),
                                  onPressed: () async {
                                    print('Stop task: ${task.id}');
                                    try {
                                      // Get instance manager and active instance
                                      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
                                      final activeInstance = instanceManager.activeInstance;
                                      if (activeInstance != null && activeInstance.status == ConnectionStatus.connected) {
                                        final client = Aria2RpcClient(activeInstance);
                                        await client.removeTask(task.id);
                                        // Immediately refresh tasks after successful request
                                        await _refreshTasks();
                                        // Reset refresh timer
                                        _stopPeriodicRefresh();
                                        _startPeriodicRefresh();
                                      }
                                    } catch (e) {
                                      print('Error stopping task: $e');
                                    }
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ] else if (task.status == DownloadStatus.stopped && task.taskStatus != 'complete') ...[
                              // Retry button - Don't show for completed tasks
                              Tooltip(
                                message: '重试',
                                child: IconButton(
                                  icon: const Icon(Icons.refresh),
                                  onPressed: () {
                                    print('Retry task: ${task.id}');
                                  },
                                  padding: EdgeInsets.zero,
                                  constraints: BoxConstraints(),
                                ),
                              ),
                            ],
                            SizedBox(width: 8), // Add spacing between buttons
                            // Open directory button - Show for all statuses
                            Tooltip(
                              message: '打开下载目录',
                              child: IconButton(
                                icon: const Icon(Icons.folder_open),
                                onPressed: () {
                                  _openDownloadDirectory(task);
                                },
                                padding: EdgeInsets.zero,
                                constraints: BoxConstraints(),
                              ),
                            )
                          ],
                        ),
                      ],
                    )
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // 显示继续对话框
  void _showResumeDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(context, TaskActionType.resume);
  }

  // 显示暂停对话框
  void _showPauseDialog(BuildContext context) {
    TaskActionDialogs.showTaskActionDialog(context, TaskActionType.pause);
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
                
                // 立即刷新任务列表
                await _refreshTasks();
                // 重置刷新计时器
                _stopPeriodicRefresh();
                _startPeriodicRefresh();
                
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