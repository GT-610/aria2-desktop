import 'package:flutter/material.dart';
import '../enums.dart';
import 'task_action_dialogs.dart';

/// 筛选器选择器组件，负责显示和管理下载任务的筛选选项
class FilterSelector extends StatelessWidget {
  final CategoryType currentCategoryType;
  final FilterOption selectedFilter;
  final String? selectedInstanceId;
  final Map<String, String> instanceNames;
  final List<String> instanceIds;
  final ValueChanged<CategoryType> onCategoryChanged;
  final ValueChanged<FilterOption> onFilterChanged;
  final ValueChanged<String?> onInstanceSelected;

  const FilterSelector({
    super.key,
    required this.currentCategoryType,
    required this.selectedFilter,
    required this.selectedInstanceId,
    required this.instanceNames,
    required this.instanceIds,
    required this.onCategoryChanged,
    required this.onFilterChanged,
    required this.onInstanceSelected,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(bottom: BorderSide(color: colorScheme.surfaceContainerHighest)),
      ),
      child: Row(
        children: [
          // 分类按钮 - 始终显示，用于切换分类方式
          FilledButton.tonal(
            onPressed: () => _showCategoryDialog(context),
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
          // 只有在非'all'分类时才显示筛选标签
          if (currentCategoryType != CategoryType.all) 
            const SizedBox(width: 12),
          // 根据当前分类动态显示筛选标签
          if (currentCategoryType != CategoryType.all) 
            // 特殊处理实例分类
            if (currentCategoryType == CategoryType.byInstance)
              ..._getInstanceFilterOptions().map((instanceId) {
                final isSelected = selectedInstanceId == instanceId;
                final instanceColor = colorScheme.tertiary;
                final instanceName = instanceNames[instanceId] ?? '未知实例';
                
                return Row(
                  children: [
                    FilterChip(
                      label: Text(
                        instanceName,
                        style: TextStyle(
                          color: instanceColor,
                        ),
                      ),
                      selected: isSelected,
                      onSelected: (selected) {
                        onInstanceSelected(selected ? instanceId : null);
                      },
                      selectedColor: instanceColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              })
            else
              ..._getFilterOptionsForCurrentCategory().map((option) {
                final isSelected = selectedFilter == option;
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
                          onFilterChanged(option);
                        }
                      },
                      selectedColor: filterColor.withValues(alpha: 0.1),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                      ),
                    ),
                    const SizedBox(width: 8),
                  ],
                );
              }),
        ],
      ),
    );
  }

  // 显示分类选择对话框
  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('选择分类方式'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // 全部选项
              TaskActionDialogs.buildDialogOption(
                context,
                '全部',
                onTap: () {
                  onCategoryChanged(CategoryType.all);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // 按状态
              TaskActionDialogs.buildDialogOption(
                context,
                '按状态',
                onTap: () {
                  onCategoryChanged(CategoryType.byStatus);
                  onFilterChanged(FilterOption.active); // 默认选择第一个选项
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // 按类型
              TaskActionDialogs.buildDialogOption(
                context,
                '按类型',
                onTap: () {
                  onCategoryChanged(CategoryType.byType);
                  onFilterChanged(FilterOption.local); // 默认选择第一个选项
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // 按实例
              TaskActionDialogs.buildDialogOption(
                context,
                '按实例',
                onTap: () {
                  onCategoryChanged(CategoryType.byInstance);
                  onInstanceSelected(null); // 重置选中的实例
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // 获取当前分类显示文本
  String _getCurrentCategoryText() {
    switch (currentCategoryType) {
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

  // 获取实例ID列表作为筛选选项
  List<String> _getInstanceFilterOptions() {
    return instanceIds;
  }

  // 根据当前分类获取筛选选项
  List<FilterOption> _getFilterOptionsForCurrentCategory() {
    switch (currentCategoryType) {
      case CategoryType.byStatus:
        return [FilterOption.active, FilterOption.waiting, FilterOption.stopped];
      case CategoryType.byType:
        return [FilterOption.local, FilterOption.remote];
      case CategoryType.byInstance:
        return [FilterOption.instance];
      default:
        return [];
    }
  }

  // 获取筛选选项显示文本
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

  // 获取筛选选项颜色
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
}