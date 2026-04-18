import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
import '../enums.dart';

class TaskToolbar extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback? onPauseAll;
  final VoidCallback? onResumeAll;
  final VoidCallback? onDeleteAll;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final TaskSortOption sortOption;
  final bool sortDescending;
  final ValueChanged<TaskSortOption> onSortChanged;
  final ValueChanged<bool> onSortDirectionChanged;

  const TaskToolbar({
    super.key,
    required this.onAddTask,
    required this.onPauseAll,
    required this.onResumeAll,
    required this.onDeleteAll,
    required this.searchController,
    required this.onSearchChanged,
    required this.sortOption,
    required this.sortDescending,
    required this.onSortChanged,
    required this.onSortDirectionChanged,
  });

  String _sortLabel(AppLocalizations l10n, TaskSortOption option) {
    switch (option) {
      case TaskSortOption.name:
        return l10n.name;
      case TaskSortOption.progress:
        return l10n.progress;
      case TaskSortOption.size:
        return l10n.size;
      case TaskSortOption.speed:
        return l10n.speed;
      case TaskSortOption.instance:
        return l10n.instance;
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final textTheme = theme.textTheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        border: Border(
          bottom: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: _ToolbarActionButton(
                  label: l10n.addTask,
                  icon: Icons.add,
                  onPressed: onAddTask,
                  variant: _ToolbarActionButtonVariant.filled,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToolbarActionButton(
                  label: l10n.pauseAll,
                  icon: Icons.pause,
                  onPressed: onPauseAll,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToolbarActionButton(
                  label: l10n.resumeAll,
                  icon: Icons.play_arrow,
                  onPressed: onResumeAll,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _ToolbarActionButton(
                  label: l10n.deleteAll,
                  icon: Icons.delete_outline,
                  onPressed: onDeleteAll,
                  variant: _ToolbarActionButtonVariant.error,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: searchController,
                  onChanged: onSearchChanged,
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.search),
                    hintText: l10n.searchTasksHint,
                    filled: true,
                    fillColor: colorScheme.surfaceContainerLowest,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(12),
                      borderSide: BorderSide.none,
                    ),
                    suffixIcon: searchController.text.isEmpty
                        ? null
                        : IconButton(
                            onPressed: () {
                              searchController.clear();
                              onSearchChanged('');
                            },
                            icon: const Icon(Icons.close),
                          ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              PopupMenuButton<TaskSortOption>(
                tooltip: l10n.sortTasks,
                style: ButtonStyle(
                  shape: WidgetStatePropertyAll(
                    RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
                onSelected: onSortChanged,
                itemBuilder: (context) => TaskSortOption.values.map((option) {
                  return PopupMenuItem<TaskSortOption>(
                    value: option,
                    child: Row(
                      children: [
                        if (option == sortOption)
                          const Icon(Icons.check, size: 18)
                        else
                          const SizedBox(width: 18),
                        const SizedBox(width: 8),
                        Text(_sortLabel(l10n, option)),
                      ],
                    ),
                  );
                }).toList(),
                child: Material(
                  color: Colors.transparent,
                  child: Ink(
                    decoration: ShapeDecoration(
                      shape: RoundedRectangleBorder(
                        side: BorderSide(
                          color: colorScheme.outline.withValues(alpha: 0.5),
                        ),
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 10,
                      ),
                      child: IconTheme.merge(
                        data: IconThemeData(color: colorScheme.onSurface),
                        child: DefaultTextStyle.merge(
                          style:
                              textTheme.labelLarge?.copyWith(
                                color: colorScheme.onSurface,
                              ) ??
                              TextStyle(color: colorScheme.onSurface),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(Icons.sort),
                              const SizedBox(width: 8),
                              Text(_sortLabel(l10n, sortOption)),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: sortDescending ? l10n.descending : l10n.ascending,
                onPressed: () => onSortDirectionChanged(!sortDescending),
                icon: Icon(
                  sortDescending
                      ? Icons.arrow_downward_rounded
                      : Icons.arrow_upward_rounded,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

enum _ToolbarActionButtonVariant { filled, tonal, error }

class _ToolbarActionButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback? onPressed;
  final _ToolbarActionButtonVariant variant;

  const _ToolbarActionButton({
    required this.label,
    required this.icon,
    required this.onPressed,
    this.variant = _ToolbarActionButtonVariant.tonal,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final buttonStyle = FilledButton.styleFrom(
      minimumSize: const Size.fromHeight(44),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
    );

    switch (variant) {
      case _ToolbarActionButtonVariant.filled:
        return FilledButton.icon(
          onPressed: onPressed,
          style: buttonStyle,
          icon: Icon(icon),
          label: Text(label),
        );
      case _ToolbarActionButtonVariant.error:
        return FilledButton.icon(
          onPressed: onPressed,
          style: buttonStyle.copyWith(
            backgroundColor: WidgetStatePropertyAll(colorScheme.errorContainer),
            foregroundColor: WidgetStatePropertyAll(
              colorScheme.onErrorContainer,
            ),
          ),
          icon: Icon(icon),
          label: Text(label),
        );
      case _ToolbarActionButtonVariant.tonal:
        return FilledButton.tonalIcon(
          onPressed: onPressed,
          style: buttonStyle,
          icon: Icon(icon),
          label: Text(label),
        );
    }
  }
}
