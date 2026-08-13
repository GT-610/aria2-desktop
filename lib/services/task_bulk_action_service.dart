import '../models/aria2_instance.dart';
import '../pages/download_page/models/download_task.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';

class TaskBulkActionResult {
  const TaskBulkActionResult({
    required this.successCount,
    required this.failureCount,
    this.indeterminateCount = 0,
  });

  final int successCount;
  final int failureCount;
  final int indeterminateCount;
}

class TaskBulkActionService with Loggable {
  Future<TaskBulkActionResult> run({
    required List<Aria2Instance> instances,
    required List<DownloadTask> tasks,
    required Future<String> Function(Aria2RpcClient client, String taskId)
    perform,
  }) async {
    final tasksByInstance = <String, List<DownloadTask>>{};
    for (final task in tasks) {
      tasksByInstance.putIfAbsent(task.instanceId, () => []).add(task);
    }

    var successCount = 0;
    var failureCount = 0;
    var indeterminateCount = 0;
    for (final instance in instances) {
      final instanceTasks = tasksByInstance[instance.id];
      if (instanceTasks == null || instanceTasks.isEmpty) {
        continue;
      }
      final client = Aria2RpcClient(instance);
      try {
        for (final task in instanceTasks) {
          try {
            await perform(client, task.id);
            successCount++;
          } on RpcResultIndeterminateException catch (error, stackTrace) {
            indeterminateCount++;
            w(
              'Bulk action result is unknown for task ${task.id} on ${instance.name}',
              error: error,
              stackTrace: stackTrace,
            );
          } catch (error, stackTrace) {
            failureCount++;
            e(
              'Bulk action failed for task ${task.id} on ${instance.name}',
              error: error,
              stackTrace: stackTrace,
            );
          }
        }
      } finally {
        await client.close();
      }
    }

    return TaskBulkActionResult(
      successCount: successCount,
      failureCount: failureCount,
      indeterminateCount: indeterminateCount,
    );
  }
}
