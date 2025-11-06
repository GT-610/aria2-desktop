import 'package:flutter/material.dart';
import '../models/download_task.dart';

// Action buttons component for download task operations
class TaskActionButtons extends StatelessWidget {
  final DownloadTask task;
  final VoidCallback onStart;
  final VoidCallback onPause;
  final VoidCallback onRemove;
  final VoidCallback onOpenFolder;
  final VoidCallback onShowDetails;

  const TaskActionButtons({
    Key? key,
    required this.task,
    required this.onStart,
    required this.onPause,
    required this.onRemove,
    required this.onOpenFolder,
    required this.onShowDetails,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // Implementation will be added later
    return Row();
  }
}