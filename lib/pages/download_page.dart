import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../services/instance_manager.dart';
import '../services/aria2_rpc_client.dart';
import '../models/aria2_instance.dart';
import '../models/global_stat.dart';

// Define download task status enum
enum DownloadStatus {
  active,   // Active
  waiting,  // Waiting
  stopped   // Stopped
}

// Define category type enum
enum CategoryType {
  all,      // All
  byStatus, // By status
  byType,   // By type
  byInstance // By instance
}

// Define filter option enum
enum FilterOption {
  all,      // All items
  active,   // Active status
  waiting,  // Waiting status
  stopped,  // Stopped status
  local,    // Local type
  remote,   // Remote type
  instance, // Instance filter (dynamic)
}

// Download task model
class DownloadTask {
  final String id;
  final String name;
  final DownloadStatus status;
  final double progress;
  final String speed;
  final String size;
  final String completedSize;
  final bool isLocal;
  final String instanceId; // 添加实例ID字段

  DownloadTask({
    required this.id,
    required this.name,
    required this.status,
    required this.progress,
    required this.speed,
    required this.size,
    required this.completedSize,
    required this.isLocal,
    required this.instanceId,
  });
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  FilterOption _selectedFilter = FilterOption.all;
  CategoryType _currentCategoryType = CategoryType.all; // 默认设置为'全部'

  // 实例名称映射表，用于展示实例名称
  Map<String, String> _instanceNames = {};
  
  // 定时器，用于周期性获取任务状态
  Timer? _refreshTimer;
  
  // 下载任务列表
  List<DownloadTask> _downloadTasks = [];
  
  // InstanceManager实例
  InstanceManager? instanceManager;

  @override
  void initState() {
    super.initState();
    // 加载实例名称和初始化
    _initialize();
    
    // 通过Provider获取InstanceManager实例
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    // 监听实例管理器的变化，当实例状态改变时刷新页面
    instanceManager?.addListener(_handleInstanceChanges);
    
    // 启动定时刷新（1秒一次）
    _startPeriodicRefresh();
  }
  
  // 初始化
  Future<void> _initialize() async {
    // 从Provider获取实例管理器
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    await _loadInstanceNames(instanceManager!);
    await _refreshTasks();
  }
  
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // 监听实例管理器的变化
    instanceManager = Provider.of<InstanceManager>(context, listen: false);
    instanceManager?.addListener(_handleInstanceChanges);
  }
  
  // 启动周期性刷新
  void _startPeriodicRefresh() {
    _refreshTimer = Timer.periodic(const Duration(seconds: 1), (_) async {
      await _refreshTasks();
    });
  }
  
  // 停止周期性刷新
  void _stopPeriodicRefresh() {
    _refreshTimer?.cancel();
    _refreshTimer = null;
  }
  
  @override
  void dispose() {
    _stopPeriodicRefresh();
    // 移除监听器以避免内存泄漏
    if (instanceManager != null) {
      instanceManager!.removeListener(_handleInstanceChanges);
    }
    super.dispose();
  }
  
  // 处理实例状态变化的方法
  void _handleInstanceChanges() {
    if (mounted && instanceManager != null) {
      setState(() {
        // 状态变化时，我们不需要做什么特殊处理，setState会触发UI重建
        // UI重建时会根据最新的实例状态重新渲染
      });
      // 当实例状态变化时，重新加载任务列表
      _refreshTasks();
    }
  }
  
  // 刷新所有任务
  Future<void> _refreshTasks() async {
    try {
      List<DownloadTask> allTasks = [];
      
      // 从Provider获取实例管理器
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      
      // 只对活动实例发送请求，不再循环尝试所有实例
      final activeInstance = instanceManager.activeInstance;
      if (activeInstance != null) {
        // 检查实例状态，如果不是连接状态则不尝试连接
        if (activeInstance.status == ConnectionStatus.connected) {
          try {
            // 创建RPC客户端
            final client = Aria2RpcClient(activeInstance);
            
            // 发送multicall请求获取所有任务
            final response = await client.getTasksMulticall();
            
            // 解析响应
            if (response.containsKey('result') && response['result'] is List) {
              final result = response['result'] as List;
              
              // 打印调试信息：result的结构和内容
              print('result结构: $result');
              print('result长度: ${result.length}');
              
              // 解析活跃任务 - 处理三层嵌套数组结构 [[[]], [[]], [[...]]]
              if (result.length > 0 && result[0] is List && (result[0] as List).isNotEmpty && (result[0] as List)[0] is List) {
                final activeTasks = (result[0] as List)[0] as List;
                print('活跃任务数量: ${activeTasks.length}');
                allTasks.addAll(_parseTasks(activeTasks, DownloadStatus.active, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // 解析等待任务
              if (result.length > 1 && result[1] is List && (result[1] as List).isNotEmpty && (result[1] as List)[0] is List) {
                final waitingTasks = (result[1] as List)[0] as List;
                print('等待任务数量: ${waitingTasks.length}');
                allTasks.addAll(_parseTasks(waitingTasks, DownloadStatus.waiting, activeInstance.id, activeInstance.type == InstanceType.local));
              }
              
              // 解析已停止任务
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
            
            // 关闭客户端
            client.close();
          } catch (e) {
            print('获取实例 ${activeInstance.name} 的任务失败: $e');
          }
        } else if (activeInstance.status == ConnectionStatus.connecting) {
          // 如果正在连接中，不重复尝试
          print('实例 ${activeInstance.name} 正在连接中，跳过当前刷新');
        } else {
          // 如果实例未连接且不是正在连接中，不尝试连接
          // 避免自动连接行为
        }
      }
      
      // 更新任务列表
      if (mounted) {
        setState(() {
          _downloadTasks = allTasks;
        });
      }
    } catch (e) {
      print('刷新任务失败: $e');
    }
  }
  
  // 解析任务列表
  List<DownloadTask> _parseTasks(List tasks, DownloadStatus status, String instanceId, bool isLocal) {
    List<DownloadTask> parsedTasks = [];
    
    for (var taskData in tasks) {
      if (taskData is Map) {
        try {
          String name = '';
          double progress = 0.0;
          String speed = '0 B/s';
          String size = '0 B';
          String completedSize = '0 B';
          String id = taskData['gid'] as String? ?? '';
          
          // 获取文件名
          if (taskData.containsKey('files') && taskData['files'] is List && (taskData['files'] as List).isNotEmpty) {
            final firstFile = (taskData['files'] as List)[0];
            if (firstFile is Map && firstFile.containsKey('path')) {
              final path = firstFile['path'] as String;
              name = path.split('/').last.split('\\').last;
            }
          }
          
          // 获取进度信息
          if (status == DownloadStatus.active) {
            // 活跃任务有特定的进度字段
            final completedLength = int.tryParse(taskData['completedLength'] as String? ?? '0') ?? 0;
            final totalLength = int.tryParse(taskData['totalLength'] as String? ?? '0') ?? 1;
            progress = totalLength > 0 ? completedLength / totalLength : 0.0;
            speed = _formatBytes(int.tryParse(taskData['downloadSpeed'] as String? ?? '0') ?? 0) + '/s';
            size = _formatBytes(totalLength);
            completedSize = _formatBytes(completedLength);
          } else if (status == DownloadStatus.waiting) {
            // 等待任务通常没有进度
            final totalLength = int.tryParse(taskData['totalLength'] as String? ?? '0') ?? 0;
            size = _formatBytes(totalLength);
          } else if (status == DownloadStatus.stopped) {
            // 停止任务有已完成的长度
            final completedLength = int.tryParse(taskData['completedLength'] as String? ?? '0') ?? 0;
            final totalLength = int.tryParse(taskData['totalLength'] as String? ?? '0') ?? 1;
            progress = totalLength > 0 ? completedLength / totalLength : 0.0;
            size = _formatBytes(totalLength);
            completedSize = _formatBytes(completedLength);
          }
          
          // 如果没有文件名，使用gid作为名称
          if (name.isEmpty) {
            name = id.substring(0, 8);
          }
          
          parsedTasks.add(DownloadTask(
            id: id,
            name: name,
            status: status,
            progress: progress,
            speed: speed,
            size: size,
            completedSize: completedSize,
            isLocal: isLocal,
            instanceId: instanceId,
          ));
        } catch (e) {
          print('解析任务失败: $e');
          continue;
        }
      }
    }
    
    return parsedTasks;
  }
  
  // 格式化字节大小
  String _formatBytes(int bytes, {int decimals = 2}) {
    if (bytes <= 0) return '0 B';
    
    const suffixes = ['B', 'KB', 'MB', 'GB', 'TB'];
    int i = (bytes == 0 ? 0 : (log(bytes) / log(1024))).floor();
    i = i.clamp(0, suffixes.length - 1);
    
    return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
  }
  
  // 加载实例名称
  Future<void> _loadInstanceNames(InstanceManager instanceManager) async {
    try {
      // 获取所有实例
      final instances = instanceManager.instances;
      
      // 构建实例ID到名称的映射
      final Map<String, String> instanceMap = {};
      for (final instance in instances) {
        instanceMap[instance.id] = instance.name;
      }
      
      // 更新状态
      if (mounted) {
        setState(() {
          _instanceNames = instanceMap;
        });
      }
    } catch (e) {
      print('加载实例名称失败: $e');
      // 发生错误时使用备用数据
      if (mounted) {
        setState(() {
          _instanceNames = {
            'local1': '本地实例',
            'local2': '本地测试',
            'remote1': '远程服务器',
          };
        });
      }
    }
  }
  
  // 当实例列表发生变化时调用
  void _onInstancesChanged() {
    if (mounted) {
      final instanceManager = Provider.of<InstanceManager>(context, listen: false);
      _loadInstanceNames(instanceManager);
      _refreshTasks();
    }
  }
  
  // 根据实例ID获取实例名称
  String _getInstanceName(String instanceId) {
    return _instanceNames[instanceId] ?? '未知实例';
  }
  
  // 获取所有实例ID列表
  List<String> _getAllInstanceIds() {
    // 从任务中提取所有唯一的实例ID
    return _downloadTasks.map((task) => task.instanceId).toSet().toList();
  }

  // Get status text and color
  (String, Color) _getStatusInfo(DownloadStatus status, ColorScheme colorScheme) {
    switch (status) {
      case DownloadStatus.active:
        return ('下载中', colorScheme.primary);
      case DownloadStatus.waiting:
        return ('等待中', colorScheme.secondary);
      case DownloadStatus.stopped:
        return ('已停止', colorScheme.errorContainer);
    }
  }

  // Get status icon
  Icon _getStatusIcon(DownloadStatus status, Color color) {
    switch (status) {
      case DownloadStatus.active:
        return Icon(Icons.file_download, color: color);
      case DownloadStatus.waiting:
        return Icon(Icons.schedule, color: color);
      case DownloadStatus.stopped:
        return Icon(Icons.pause_circle, color: color);
    }
  }

  // 存储当前选择的实例ID
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
        return '已停止';
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
        return colorScheme.tertiary; // 实例筛选器使用第三颜色
    }
  }
  
  // Show category selection dialog
  void _showCategoryDialog() {
    showDialog(
      context: context,
      builder: (context) {
        final colorScheme = Theme.of(context).colorScheme;
        
        return AlertDialog(
          title: const Text('选择分类方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // All option
              _buildDialogOption(
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
              _buildDialogOption(
                context,
                '按状态',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byStatus;
                    _selectedFilter = FilterOption.active; // 默认选择第一个选项
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By type
              _buildDialogOption(
                context,
                '按类型',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byType;
                    _selectedFilter = FilterOption.local; // 默认选择第一个选项
                  });
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By instance
              _buildDialogOption(
                context,
                '按实例',
                onTap: () {
                  setState(() {
                    _currentCategoryType = CategoryType.byInstance;
                    _selectedInstanceId = null; // 重置选择的实例
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
  Widget _buildDialogOption(BuildContext context, String text, {required VoidCallback onTap}) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(8),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Text(
          text,
          style: Theme.of(context).textTheme.bodyLarge,
        ),
      ),
    );
  }
  
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
      default:
        return '分类';
    }
  }
  
  // 获取实例ID列表作为筛选选项
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
        // 对于实例分类，我们将在UI中单独处理
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
                  onPressed: () {},
                  icon: const Icon(Icons.add),
                  label: const Text('添加下载'),
                  style: FilledButton.styleFrom(
                    padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                OutlinedButton.icon(
                  onPressed: () {},
                  icon: const Icon(Icons.pause),
                  label: const Text('暂停'),
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
                  icon: const Icon(Icons.play_arrow),
                  label: const Text('继续'),
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
                  label: const Text('删除'),
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
    
    // 检查是否有已连接的实例
    final hasConnectedInstances = instanceManager?.instances.any((instance) => 
      instance.status == ConnectionStatus.connected
    ) ?? false;
    
    // 如果没有已连接的实例，显示特殊提示
    if (!hasConnectedInstances) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.cloud_off_outlined, size: 64, color: colorScheme.onSurfaceVariant),
            SizedBox(height: 16),
            Text('没有正在连接的实例，快去连接实例吧', style: theme.textTheme.titleMedium),
            SizedBox(height: 24),
            ElevatedButton(
              onPressed: () {
                // 跳转到实例管理页面
                Navigator.pushNamed(context, '/instance');
              },
              child: const Text('去连接实例'),
              style: ElevatedButton.styleFrom(
                padding: EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ],
        ),
      );
    }
    
    // 如果有已连接的实例但没有任务，显示暂无任务
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
        final (statusText, statusColor) = _getStatusInfo(task.status, colorScheme);
        
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
            onTap: () {},
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                    // Task name and status icon
                    Row(
                      children: [
                        _getStatusIcon(task.status, statusColor),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            task.name,
                            style: theme.textTheme.titleMedium,
                            overflow: TextOverflow.ellipsis,
                          ),
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
                        const SizedBox(width: 8),
                        IconButton(
                          icon: const Icon(Icons.more_vert),
                          onPressed: () {},
                          padding: EdgeInsets.zero,
                          constraints: BoxConstraints(),
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
                            task.status == DownloadStatus.active ? statusColor : statusColor.withOpacity(0.6),
                          ),
                        ),
                        // Only show progress text for non-active status
                        if (task.status != DownloadStatus.active && task.progress > 0)
                          Positioned.fill(
                            child: Align(
                              alignment: Alignment.center,
                              child: Text(
                                '${(task.progress * 100).toInt()}%',
                                style: TextStyle(
                                  color: colorScheme.onSurfaceVariant,
                                  fontSize: 10,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ),
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
                            // Size info
                            Text(
                              '${task.completedSize} / ${task.size}',
                              style: TextStyle(
                                color: colorScheme.onSurfaceVariant,
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                        // Download speed (only shown for active status)
                        if (task.status == DownloadStatus.active)
                          Text(
                            task.speed,
                            style: TextStyle(
                              color: statusColor,
                              fontSize: 13,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        // Empty space for alignment in non-active status
                        if (task.status != DownloadStatus.active)
                          SizedBox(width: 60),
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
}