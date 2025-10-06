import 'package:flutter/material.dart';
import '../managers/instance_manager.dart';

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
  
  // Mock download task data
  final List<DownloadTask> _downloadTasks = [
    DownloadTask(
      id: '1',
      name: 'Ubuntu 22.04 LTS ISO 镜像文件',
      status: DownloadStatus.active,
      progress: 0.45,
      speed: '1.2 MB/s',
      size: '4.5 GB',
      completedSize: '2.0 GB',
      isLocal: true,
      instanceId: 'local1',
    ),
    DownloadTask(
      id: '2',
      name: 'Flutter 框架源码包',
      status: DownloadStatus.waiting,
      progress: 0.0,
      speed: '0 B/s',
      size: '150 MB',
      completedSize: '0 MB',
      isLocal: true,
      instanceId: 'local1',
    ),
    DownloadTask(
      id: '3',
      name: '设计资源合集.zip',
      status: DownloadStatus.stopped,
      progress: 0.75,
      speed: '0 B/s',
      size: '2.8 GB',
      completedSize: '2.1 GB',
      isLocal: false,
      instanceId: 'remote1',
    ),
    DownloadTask(
      id: '4',
      name: '项目文档.pdf',
      status: DownloadStatus.active,
      progress: 0.92,
      speed: '500 KB/s',
      size: '15 MB',
      completedSize: '13.8 MB',
      isLocal: false,
      instanceId: 'remote1',
    ),
    DownloadTask(
      id: '5',
      name: '音乐专辑.mp3',
      status: DownloadStatus.waiting,
      progress: 0.0,
      speed: '0 B/s',
      size: '120 MB',
      completedSize: '0 MB',
      isLocal: true,
      instanceId: 'local2',
    ),
  ];

  @override
  void initState() {
    super.initState();
    // 初始化实例名称映射（使用真实实例数据）
    _loadInstanceNames();
  }
  
  // 加载实例名称
  Future<void> _loadInstanceNames() async {
    try {
      // 获取InstanceManager实例
      final instanceManager = InstanceManager();
      
      // 确保实例管理器已初始化
      await instanceManager.initialize();
      
      // 获取所有实例
      final instances = instanceManager.getInstances();
      
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
                        // File size info
                        Text(
                          '${task.completedSize} / ${task.size}',
                          style: TextStyle(
                            color: colorScheme.onSurfaceVariant,
                            fontSize: 13,
                          ),
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
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}