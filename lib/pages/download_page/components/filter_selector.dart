import 'package:flutter/material.dart';

import '../enums.dart';
import 'task_action_dialogs.dart';

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
        border: Border(
          bottom: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      child: Wrap(
        spacing: 12,
        runSpacing: 8,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
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
          if (currentCategoryType != CategoryType.all)
            if (currentCategoryType == CategoryType.byInstance) ...[
              FilterChip(
                label: const Text('All instances'),
                selected: selectedInstanceId == null,
                onSelected: (_) => onInstanceSelected(null),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                ),
              ),
              ..._getInstanceFilterOptions().map((instanceId) {
                final isSelected = selectedInstanceId == instanceId;
                final instanceColor = colorScheme.tertiary;
                final instanceName =
                    instanceNames[instanceId] ?? 'Unknown instance';

                return FilterChip(
                  label: Text(
                    instanceName,
                    style: TextStyle(color: instanceColor),
                  ),
                  selected: isSelected,
                  onSelected: (selected) {
                    onInstanceSelected(selected ? instanceId : null);
                  },
                  selectedColor: instanceColor.withValues(alpha: 0.1),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(20),
                  ),
                );
              }),
            ] else
              ..._getFilterOptionsForCurrentCategory().map((option) {
                final isSelected = selectedFilter == option;
                final filterColor = _getFilterColor(option, colorScheme);

                return FilterChip(
                  label: Text(
                    _getFilterText(option),
                    style: TextStyle(color: filterColor),
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
                );
              }),
        ],
      ),
    );
  }

  void _showCategoryDialog(BuildContext context) {
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Choose a category'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskActionDialogs.buildDialogOption(
                context,
                'All tasks',
                onTap: () {
                  onCategoryChanged(CategoryType.all);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                'By status',
                onTap: () {
                  onCategoryChanged(CategoryType.byStatus);
                  onFilterChanged(FilterOption.active);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                'By type',
                onTap: () {
                  onCategoryChanged(CategoryType.byType);
                  onFilterChanged(FilterOption.local);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                'By instance',
                onTap: () {
                  onCategoryChanged(CategoryType.byInstance);
                  onInstanceSelected(null);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCurrentCategoryText() {
    switch (currentCategoryType) {
      case CategoryType.all:
        return 'All tasks';
      case CategoryType.byStatus:
        return 'By status';
      case CategoryType.byType:
        return 'By type';
      case CategoryType.byInstance:
        return 'By instance';
    }
  }

  List<String> _getInstanceFilterOptions() {
    return instanceIds;
  }

  List<FilterOption> _getFilterOptionsForCurrentCategory() {
    switch (currentCategoryType) {
      case CategoryType.byStatus:
        return [
          FilterOption.active,
          FilterOption.waiting,
          FilterOption.stopped,
        ];
      case CategoryType.byType:
        return [FilterOption.local, FilterOption.remote];
      case CategoryType.byInstance:
        return [FilterOption.instance];
      case CategoryType.all:
        return [];
    }
  }

  String _getFilterText(FilterOption filter) {
    switch (filter) {
      case FilterOption.all:
        return 'All';
      case FilterOption.active:
        return 'Downloading';
      case FilterOption.waiting:
        return 'Waiting';
      case FilterOption.stopped:
        return 'Stopped / Completed';
      case FilterOption.local:
        return 'Built-in';
      case FilterOption.remote:
        return 'Remote';
      case FilterOption.instance:
        return 'Instance';
    }
  }

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
