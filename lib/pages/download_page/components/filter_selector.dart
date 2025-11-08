import 'package:flutter/material.dart';
import '../enums.dart';
import 'task_action_dialogs.dart';

/// Filter selector component, responsible for displaying and managing download task filter options
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
          // Category button - always displayed, used to switch category methods
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
          // Only display filter tags when not in 'all' category
          if (currentCategoryType != CategoryType.all) 
            const SizedBox(width: 12),
          // Dynamically display filter tags based on current category
          if (currentCategoryType != CategoryType.all) 
            // Special handling for instance category
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

  // Show category selection dialog
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
              // All options
              TaskActionDialogs.buildDialogOption(
                context,
                '全部',
                onTap: () {
                  onCategoryChanged(CategoryType.all);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By status
              TaskActionDialogs.buildDialogOption(
                context,
                '按状态',
                onTap: () {
                  onCategoryChanged(CategoryType.byStatus);
                  onFilterChanged(FilterOption.active);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By type
              TaskActionDialogs.buildDialogOption(
                context,
                '按类型',
                onTap: () {
                  onCategoryChanged(CategoryType.byType);
                  onFilterChanged(FilterOption.local);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              // By instance
              TaskActionDialogs.buildDialogOption(
                context,
                '按实例',
                onTap: () {
                  onCategoryChanged(CategoryType.byInstance);
                  onInstanceSelected(null); // reset selected instance
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  // Get current category display text
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

  // Get instance ID list as filter options
  List<String> _getInstanceFilterOptions() {
    return instanceIds;
  }

  // Get filter options based on current category
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

  // Get filter option display text
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

  // Get filter option color
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