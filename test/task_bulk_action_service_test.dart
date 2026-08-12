import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/models/aria2_instance.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/aria2_rpc_client.dart';
import 'package:setsuna/services/task_bulk_action_service.dart';

void main() {
  test('reports unconfirmed bulk actions separately from failures', () async {
    final instance = Aria2Instance(
      id: 'remote',
      name: 'Remote',
      type: InstanceType.remote,
      protocol: 'http',
      host: '127.0.0.1',
      port: 6800,
      status: ConnectionStatus.connected,
    );
    final task = DownloadTask(
      id: 'task',
      name: 'Task',
      status: DownloadStatus.active,
      progress: 0,
      downloadSpeed: '0 B/s',
      uploadSpeed: '0 B/s',
      size: '0 B',
      completedSize: '0 B',
      isLocal: false,
      instanceId: instance.id,
    );

    final result = await TaskBulkActionService().run(
      instances: <Aria2Instance>[instance],
      tasks: <DownloadTask>[task],
      perform: (_, _) async {
        throw const RpcResultIndeterminateException('aria2.pause');
      },
    );

    expect(result.successCount, 0);
    expect(result.failureCount, 0);
    expect(result.indeterminateCount, 1);
  });
}
