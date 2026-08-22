import '../models/aria2_instance.dart';
import '../pages/download_page/models/download_task.dart';
import '../utils/logging.dart';
import 'aria2_rpc_client.dart';

enum BulkActionItemStatus { performed, skipped }

/// Result of a single task action inside a bulk run.
class BulkActionItemResult {
  const BulkActionItemResult({
    this.status = BulkActionItemStatus.performed,
    this.warning,
  });

  const BulkActionItemResult.skipped()
    : status = BulkActionItemStatus.skipped,
      warning = null;

  final BulkActionItemStatus status;

  /// Optional non-fatal warning (e.g. file cleanup issues) attached to a
  /// successfully performed item.
  final String? warning;
}

class TaskBulkActionResult {
  const TaskBulkActionResult({
    required this.successCount,
    required this.failureCount,
    this.indeterminateCount = 0,
    this.skippedCount = 0,
    this.warningCount = 0,
  });

  final int successCount;
  final int failureCount;
  final int indeterminateCount;
  final int skippedCount;
  final int warningCount;
}

typedef TaskBulkItemAction =
    Future<BulkActionItemResult> Function(
      Aria2RpcClient client,
      DownloadTask task,
    );

/// Executes one action per task, grouping tasks by instance so a single RPC
/// client serves every task on the same instance.
///
/// When [clientFactory] is provided its clients are reused as-is and never
/// closed; otherwise a fresh client is created per instance and closed after
/// the instance's tasks are processed.
class TaskBulkActionService with Loggable {
  Future<TaskBulkActionResult> run({
    required List<Aria2Instance> instances,
    required List<DownloadTask> tasks,
    required TaskBulkItemAction perform,
    Aria2RpcClient? Function(Aria2Instance instance)? clientFactory,
  }) async {
    final tasksByInstance = <String, List<DownloadTask>>{};
    for (final task in tasks) {
      tasksByInstance.putIfAbsent(task.instanceId, () => []).add(task);
    }

    var successCount = 0;
    var failureCount = 0;
    var indeterminateCount = 0;
    var skippedCount = 0;
    var warningCount = 0;

    for (final instance in instances) {
      final instanceTasks = tasksByInstance[instance.id];
      if (instanceTasks == null || instanceTasks.isEmpty) {
        continue;
      }

      final Aria2RpcClient client;
      try {
        client = clientFactory?.call(instance) ?? Aria2RpcClient(instance);
      } catch (error, stackTrace) {
        failureCount += instanceTasks.length;
        e(
          'Failed to prepare RPC client for bulk action on ${instance.name}',
          error: error,
          stackTrace: stackTrace,
        );
        continue;
      }
      final ownsClient = clientFactory == null;

      try {
        for (final task in instanceTasks) {
          try {
            final result = await perform(client, task);
            if (result.status == BulkActionItemStatus.skipped) {
              skippedCount++;
            } else {
              successCount++;
              if (result.warning != null) {
                warningCount++;
                w(
                  'Bulk action completed with a warning for task ${task.id} '
                  'on ${instance.name}: ${result.warning}',
                );
              }
            }
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
        if (ownsClient) {
          await client.close();
        }
      }
    }

    return TaskBulkActionResult(
      successCount: successCount,
      failureCount: failureCount,
      indeterminateCount: indeterminateCount,
      skippedCount: skippedCount,
      warningCount: warningCount,
    );
  }
}
