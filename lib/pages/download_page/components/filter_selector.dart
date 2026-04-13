import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
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
    final l10n = AppLocalizations.of(context)!;
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
                Text(_getCurrentCategoryText(l10n)),
                const SizedBox(width: 4),
                const Icon(Icons.arrow_drop_down),
              ],
            ),
          ),
          if (currentCategoryType != CategoryType.all)
            if (currentCategoryType == CategoryType.byInstance) ...[
              FilterChip(
                label: Text(l10n.allInstances),
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
                    instanceNames[instanceId] ?? l10n.unknownInstance;

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
                    _getFilterText(l10n, option),
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
    final l10n = AppLocalizations.of(context)!;
    showDialog(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(l10n.chooseCategory),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              TaskActionDialogs.buildDialogOption(
                context,
                l10n.allTasksLabel,
                onTap: () {
                  onCategoryChanged(CategoryType.all);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                l10n.byStatus,
                onTap: () {
                  onCategoryChanged(CategoryType.byStatus);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                l10n.byType,
                onTap: () {
                  onCategoryChanged(CategoryType.byType);
                  Navigator.pop(context);
                },
              ),
              const SizedBox(height: 8),
              TaskActionDialogs.buildDialogOption(
                context,
                l10n.byInstance,
                onTap: () {
                  onCategoryChanged(CategoryType.byInstance);
                  Navigator.pop(context);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  String _getCurrentCategoryText(AppLocalizations l10n) {
    switch (currentCategoryType) {
      case CategoryType.all:
        return l10n.allTasksLabel;
      case CategoryType.byStatus:
        return l10n.byStatus;
      case CategoryType.byType:
        return l10n.byType;
      case CategoryType.byInstance:
        return l10n.byInstance;
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

  String _getFilterText(AppLocalizations l10n, FilterOption filter) {
    switch (filter) {
      case FilterOption.all:
        return l10n.filterAll;
      case FilterOption.active:
        return l10n.downloading;
      case FilterOption.waiting:
        return l10n.waiting;
      case FilterOption.stopped:
        return l10n.stoppedCompleted;
      case FilterOption.local:
        return l10n.builtin;
      case FilterOption.remote:
        return l10n.remote;
      case FilterOption.instance:
        return l10n.instance;
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
