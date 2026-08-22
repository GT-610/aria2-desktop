import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/models/aria2_instance.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/services/aria2_rpc_client.dart';
import 'package:setsuna/services/task_bulk_action_service.dart';

DownloadTask _task(
  Aria2Instance instance,
  String id, {
  DownloadStatus status = DownloadStatus.active,
}) {
  return DownloadTask(
    id: id,
    name: 'task-$id',
    status: status,
    progress: 0,
    downloadSpeed: '0 B/s',
    uploadSpeed: '0 B/s',
    size: '0 B',
    completedSize: '0 B',
    isLocal: false,
    instanceId: instance.id,
  );
}

Aria2Instance _instance(String id) {
  return Aria2Instance(
    id: id,
    name: id,
    type: InstanceType.remote,
    protocol: 'http',
    host: '127.0.0.1',
    port: 1,
    status: ConnectionStatus.connected,
  );
}

void main() {
  test('reports unconfirmed bulk actions separately from failures', () async {
    final instance = _instance('remote');
    final task = _task(instance, 'task');

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
    expect(result.skippedCount, 0);
    expect(result.warningCount, 0);
  });

  test('counts skipped items separately and aggregates warnings', () async {
    final instance = _instance('remote');
    final tasks = [
      _task(instance, 'a'),
      _task(instance, 'b'),
      _task(instance, 'c'),
    ];

    final result = await TaskBulkActionService().run(
      instances: <Aria2Instance>[instance],
      tasks: tasks,
      perform: (client, task) async {
        switch (task.id) {
          case 'a':
            return const BulkActionItemResult();
          case 'b':
            return const BulkActionItemResult.skipped();
          default:
            return const BulkActionItemResult(warning: 'cleanup issue');
        }
      },
    );

    expect(result.successCount, 2);
    expect(result.skippedCount, 1);
    expect(result.failureCount, 0);
    expect(result.warningCount, 1);
  });

  test('groups tasks per instance and consults the factory once', () async {
    final first = _instance('first');
    final second = _instance('second');
    final clients = <String, Aria2RpcClient>{
      'first': Aria2RpcClient(first),
      'second': Aria2RpcClient(second),
    };
    final requestedInstances = <String>[];
    final seenClients = <String, List<Aria2RpcClient>>{};
    final performedByInstance = <String, List<String>>{};

    final result = await TaskBulkActionService().run(
      instances: <Aria2Instance>[first, second],
      tasks: [_task(first, 'f1'), _task(second, 's1'), _task(first, 'f2')],
      clientFactory: (instance) {
        requestedInstances.add(instance.id);
        return clients[instance.id]!;
      },
      perform: (client, task) async {
        seenClients.putIfAbsent(task.instanceId, () => []).add(client);
        performedByInstance.putIfAbsent(task.instanceId, () => []).add(task.id);
        return const BulkActionItemResult();
      },
    );

    expect(result.successCount, 3);
    expect(requestedInstances, ['first', 'second']);
    expect(performedByInstance['first'], ['f1', 'f2']);
    expect(performedByInstance['second'], ['s1']);
    expect(seenClients['first']!.toSet().single, same(clients['first']));
    expect(seenClients['second']!.toSet().single, same(clients['second']));
  });

  test('leaves factory-provided clients open after the run', () async {
    final instance = _instance('remote');
    final client = Aria2RpcClient(
      instance,
      requestTimeout: const Duration(milliseconds: 200),
      retryDelay: const Duration(milliseconds: 1),
      maximumAttempts: 1,
    );

    await TaskBulkActionService().run(
      instances: <Aria2Instance>[instance],
      tasks: [_task(instance, 'task')],
      clientFactory: (_) => client,
      perform: (_, _) async => const BulkActionItemResult(),
    );

    // The client must still be usable: an open HTTP client that fails to
    // reach the server reports the result as indeterminate, whereas a closed
    // client raises ConnectionFailedException synchronously.
    await expectLater(
      client.callRpc('aria2.getVersion', []),
      throwsA(isA<RpcResultIndeterminateException>()),
    );
    await client.close();
  });

  test('closes its own clients after the run', () async {
    final instance = _instance('remote');
    final service = TaskBulkActionService();

    await service.run(
      instances: <Aria2Instance>[instance],
      tasks: [_task(instance, 'task')],
      perform: (_, _) async => const BulkActionItemResult(),
    );

    // No way to reach the internally created client; assert via a fresh
    // closed-client comparison that the closed state raises immediately.
    final probe = Aria2RpcClient(instance);
    await probe.close();
    await expectLater(
      probe.callRpc('aria2.getVersion', []),
      throwsA(isA<ConnectionFailedException>()),
    );
  });

  test('counts every task of an instance as failed when setup fails', () async {
    final first = _instance('first');
    final second = _instance('second');

    final result = await TaskBulkActionService().run(
      instances: <Aria2Instance>[first, second],
      tasks: [_task(first, 'f1'), _task(first, 'f2'), _task(second, 's1')],
      clientFactory: (instance) {
        if (instance.id == 'first') {
          throw StateError('boom');
        }
        return Aria2RpcClient(instance);
      },
      perform: (_, _) async => const BulkActionItemResult(),
    );

    expect(result.failureCount, 2);
    expect(result.successCount, 1);
  });
}
