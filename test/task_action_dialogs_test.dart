import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/pages/download_page/components/task_action_dialogs.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';

DownloadTask _task({required DownloadStatus status, String? taskStatus}) {
  return DownloadTask(
    id: '${status.name}-${taskStatus ?? 'none'}',
    name: 'task',
    status: status,
    taskStatus: taskStatus,
    progress: 0,
    downloadSpeed: '0 B/s',
    uploadSpeed: '0 B/s',
    size: '0 B',
    completedSize: '0 B',
    isLocal: true,
    instanceId: 'local',
  );
}

void main() {
  group('TaskActionDialogs actionability', () {
    test('pause only applies to active or non-paused waiting tasks', () {
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.active),
          TaskActionType.pause,
        ),
        isTrue,
      );
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.waiting, taskStatus: 'paused'),
          TaskActionType.pause,
        ),
        isFalse,
      );
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.stopped),
          TaskActionType.pause,
        ),
        isFalse,
      );
    });

    test('resume only applies to paused waiting tasks', () {
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.waiting, taskStatus: 'paused'),
          TaskActionType.resume,
        ),
        isTrue,
      );
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.waiting),
          TaskActionType.resume,
        ),
        isFalse,
      );
      expect(
        TaskActionDialogs.canPerformAction(
          _task(status: DownloadStatus.active),
          TaskActionType.resume,
        ),
        isFalse,
      );
    });

    test('delete applies to every task', () {
      final tasks = [
        _task(status: DownloadStatus.active),
        _task(status: DownloadStatus.waiting, taskStatus: 'paused'),
        _task(status: DownloadStatus.stopped, taskStatus: 'error'),
      ];

      expect(
        TaskActionDialogs.actionableTasks(tasks, TaskActionType.delete).length,
        tasks.length,
      );
    });
  });
}
