import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';

import '../enums.dart';

class TaskToolbar extends StatelessWidget {
  final VoidCallback onAddTask;
  final VoidCallback onPauseAll;
  final VoidCallback onResumeAll;
  final VoidCallback onDeleteAll;
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

  String _sortLabel(TaskSortOption option) {
    switch (option) {
      case TaskSortOption.name:
        return 'Name';
      case TaskSortOption.progress:
        return 'Progress';
      case TaskSortOption.size:
        return 'Size';
      case TaskSortOption.speed:
        return 'Speed';
      case TaskSortOption.instance:
        return 'Instance';
    }
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

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
          Wrap(
            spacing: 12,
            runSpacing: 12,
            children: [
              Btn.elevated(
                text: 'Add Task',
                icon: const Icon(Icons.add),
                onTap: onAddTask,
              ),
              const SizedBox(width: 12),
              Btn.tile(
                text: 'Pause All',
                icon: const Icon(Icons.pause),
                onTap: onPauseAll,
              ),
              const SizedBox(width: 12),
              Btn.tile(
                text: 'Resume All',
                icon: const Icon(Icons.play_arrow),
                onTap: onResumeAll,
              ),
              const SizedBox(width: 12),
              Btn.tile(
                text: 'Delete All',
                icon: const Icon(Icons.delete),
                onTap: onDeleteAll,
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
                    hintText: 'Search tasks by name, path, or instance',
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
                tooltip: 'Sort tasks',
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
                        Text(_sortLabel(option)),
                      ],
                    ),
                  );
                }).toList(),
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.sort),
                  label: Text(_sortLabel(sortOption)),
                ),
              ),
              const SizedBox(width: 8),
              IconButton.filledTonal(
                tooltip: sortDescending ? 'Descending' : 'Ascending',
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
