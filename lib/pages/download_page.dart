import 'package:flutter/material.dart';

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

  DownloadTask({
    required this.id,
    required this.name,
    required this.status,
    required this.progress,
    required this.speed,
    required this.size,
    required this.completedSize,
    required this.isLocal,
  });
}

class DownloadPage extends StatefulWidget {
  const DownloadPage({super.key});

  @override
  State<DownloadPage> createState() => _DownloadPageState();
}

class _DownloadPageState extends State<DownloadPage> {
  CategoryType _selectedCategory = CategoryType.all;
  DownloadStatus? _selectedStatusFilter;
  bool? _selectedTypeFilter; // true for local, false for remote
  String? _selectedInstanceFilter;

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
    ),
  ];

  @override
  void initState() {
    super.initState();
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

  // Filter tasks based on selected criteria
  List<DownloadTask> _filterTasks() {
    List<DownloadTask> filtered = _downloadTasks;
    
    // 根据当前选择的分类方式进行过滤
    switch (_selectedCategory) {
      case CategoryType.all:
        // 全部任务，不过滤
        break;
      case CategoryType.byStatus:
        if (_selectedStatusFilter != null) {
          filtered = filtered.where((task) => task.status == _selectedStatusFilter).toList();
        }
        break;
      case CategoryType.byType:
        if (_selectedTypeFilter != null) {
          filtered = filtered.where((task) => task.isLocal == _selectedTypeFilter).toList();
        }
        break;
      case CategoryType.byInstance:
        // 按实例过滤（模拟实现，实际应根据真实的实例数据）
        // 这里我们假设每个任务都有实例信息
        break;
    }
    
    return filtered;
  }
  
  // Get display text for category
  String _getCategoryText(CategoryType category) {
    switch (category) {
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
  
  // Build category selector
  Widget _buildCategorySelector(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: CategoryType.values.map((category) {
            final isSelected = _selectedCategory == category;
            return Padding(
              padding: const EdgeInsets.only(right: 8),
              child: FilledButton.tonal(
                onPressed: () {
                  setState(() {
                    _selectedCategory = category;
                    // 重置其他过滤器状态
                    if (category != CategoryType.byStatus) {
                      _selectedStatusFilter = null;
                    }
                    if (category != CategoryType.byType) {
                      _selectedTypeFilter = null;
                    }
                    if (category != CategoryType.byInstance) {
                      _selectedInstanceFilter = null;
                    }
                  });
                },
                style: FilledButton.styleFrom(
                  backgroundColor: isSelected ? colorScheme.primaryContainer : null,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(_getCategoryText(category)),
              ),
            );
          }).toList(),
        ),
      ),
    );
  }
  
  // Build sub-category filter
  Widget _buildSubCategoryFilter(ColorScheme colorScheme) {
    switch (_selectedCategory) {
      case CategoryType.byStatus:
        return _buildStatusFilter(colorScheme);
      case CategoryType.byType:
        return _buildTypeFilter(colorScheme);
      case CategoryType.byInstance:
        return _buildInstanceFilter(colorScheme);
      default:
        return const SizedBox.shrink();
    }
  }
  
  // Build type filter
  Widget _buildTypeFilter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text('全部类型'),
              selected: _selectedTypeFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = null;
                });
              },
              selectedColor: colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('本地'),
              selected: _selectedTypeFilter == true,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = selected ? true : null;
                });
              },
              selectedColor: colorScheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('远程'),
              selected: _selectedTypeFilter == false,
              onSelected: (selected) {
                setState(() {
                  _selectedTypeFilter = selected ? false : null;
                });
              },
              selectedColor: colorScheme.secondary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
  }
  
  // Build instance filter
  Widget _buildInstanceFilter(ColorScheme colorScheme) {
    // Mock instance data
    final instances = ['默认实例', '实例1', '实例2'];
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text('全部实例'),
              selected: _selectedInstanceFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedInstanceFilter = null;
                });
              },
              selectedColor: colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            ...instances.map((instance) {
              return Row(
                children: [
                  const SizedBox(width: 8),
                  FilterChip(
                    label: Text(instance),
                    selected: _selectedInstanceFilter == instance,
                    onSelected: (selected) {
                      setState(() {
                        _selectedInstanceFilter = selected ? instance : null;
                      });
                    },
                    selectedColor: colorScheme.primary.withOpacity(0.1),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                ],
              );
            }).toList(),
          ],
        ),
      ),
    );
  }

  // Build status filter
  Widget _buildStatusFilter(ColorScheme colorScheme) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceVariant)),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            FilterChip(
              label: Text('全部状态'),
              selected: _selectedStatusFilter == null,
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = null;
                });
              },
              selectedColor: colorScheme.primaryContainer,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('活跃'),
              labelStyle: TextStyle(color: colorScheme.primary),
              selected: _selectedStatusFilter == DownloadStatus.active,
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = selected ? DownloadStatus.active : null;
                });
              },
              selectedColor: colorScheme.primary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('等待'),
              labelStyle: TextStyle(color: colorScheme.secondary),
              selected: _selectedStatusFilter == DownloadStatus.waiting,
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = selected ? DownloadStatus.waiting : null;
                });
              },
              selectedColor: colorScheme.secondary.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
            const SizedBox(width: 8),
            FilterChip(
              label: Text('停止'),
              labelStyle: TextStyle(color: colorScheme.errorContainer),
              selected: _selectedStatusFilter == DownloadStatus.stopped,
              onSelected: (selected) {
                setState(() {
                  _selectedStatusFilter = selected ? DownloadStatus.stopped : null;
                });
              },
              selectedColor: colorScheme.errorContainer.withOpacity(0.1),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ],
        ),
      ),
    );
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
          // Category selector
          _buildCategorySelector(colorScheme),
          // Sub-category filter
          _buildSubCategoryFilter(colorScheme),
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