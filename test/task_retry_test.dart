import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/models/aria2_instance.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';
import 'package:setsuna/pages/download_page/services/download_task_service.dart';
import 'package:setsuna/pages/download_page/utils/task_retry.dart';
import 'package:setsuna/services/aria2_rpc_client.dart';

void main() {
  late Aria2RpcClient client;

  setUp(() {
    client = Aria2RpcClient(
      Aria2Instance(
        id: 'test',
        name: 'Test',
        type: InstanceType.remote,
        protocol: 'http',
        host: '127.0.0.1',
        port: 6800,
      ),
    );
  });

  tearDown(() => client.close());

  DownloadTask task({
    String? infoHash,
    List<String>? trackers,
    List<String>? uris,
    List<Map<String, dynamic>>? files,
    String dir = '/downloads',
  }) {
    return DownloadTask(
      id: 'old-gid',
      name: 'archive.zip',
      status: DownloadStatus.stopped,
      taskStatus: 'error',
      progress: 0.5,
      downloadSpeed: '0 B/s',
      uploadSpeed: '0 B/s',
      size: '1 KiB',
      completedSize: '512 B',
      isLocal: false,
      instanceId: 'test',
      dir: dir,
      infoHash: infoHash,
      trackers: trackers,
      uris: uris,
      files: files,
    );
  }

  group('buildTaskRetrySources', () {
    test('builds a magnet link with trackers from a BT task', () {
      final sources = buildTaskRetrySources(
        task(
          infoHash: '0123456789ABCDEF0123456789ABCDEF01234567',
          trackers: const <String>[
            'udp://tracker.example.com:6969/announce',
            'https://tracker.example.com/announce',
          ],
        ),
      );

      expect(sources, hasLength(1));
      final magnet = Uri.parse(sources.single.uris.single);
      expect(magnet.scheme, 'magnet');
      expect(magnet.queryParametersAll['xt'], <String>[
        'urn:btih:0123456789ABCDEF0123456789ABCDEF01234567',
      ]);
      expect(magnet.queryParametersAll['dn'], <String>['archive.zip']);
      expect(magnet.queryParametersAll['tr'], hasLength(2));
    });

    test('falls back when magnet topics and info hashes are invalid', () {
      final sources = buildTaskRetrySources(
        task(
          infoHash: 'not-a-hash',
          uris: const <String>[
            'magnet:?xt=urn:btih:not-a-hash',
            'https://example/archive.zip',
          ],
        ),
      );

      expect(sources.single.uris, <String>['https://example/archive.zip']);
    });

    test('preserves paths relative to the task directory', () {
      final sources = buildTaskRetrySources(
        task(
          files: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '/downloads/releases/one.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://example/one.iso'},
              ],
            },
          ],
        ),
      );

      expect(sources.single.outputName, 'releases/one.iso');
    });

    test('does not preserve paths that escape the task directory', () {
      final sources = buildTaskRetrySources(
        task(
          files: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '../outside/one.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://example/one.iso'},
              ],
            },
          ],
        ),
      );

      expect(sources.single.outputName, 'one.iso');
    });

    test('does not preserve Windows paths that escape the task directory', () {
      final sources = buildTaskRetrySources(
        task(
          dir: r'C:\downloads',
          files: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': r'..\outside\one.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://example/one.iso'},
              ],
            },
          ],
        ),
      );

      expect(sources.single.outputName, 'one.iso');
    });

    test('keeps mirror URIs grouped by HTTP file', () {
      final sources = buildTaskRetrySources(
        task(
          files: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '/downloads/one.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://one.example/one.iso'},
                <String, String>{'uri': 'https://two.example/one.iso'},
              ],
            },
            <String, dynamic>{
              'path': '/downloads/two.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://one.example/two.iso'},
              ],
            },
          ],
        ),
      );

      expect(sources, hasLength(2));
      expect(sources.first.uris, hasLength(2));
      expect(sources.first.outputName, 'one.iso');
      expect(sources.last.uris.single, 'https://one.example/two.iso');
      expect(sources.last.outputName, 'two.iso');
    });
  });

  group('retryTaskWithClient', () {
    test('removes the old result only after every source succeeds', () async {
      final added = <List<String>>[];
      final outputs = <String?>[];
      var removedOld = false;
      final result = await DownloadTaskService.retryTaskWithClient(
        client,
        task(
          files: <Map<String, dynamic>>[
            <String, dynamic>{
              'path': '/downloads/one.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://example/one.iso'},
              ],
            },
            <String, dynamic>{
              'path': '/downloads/two.iso',
              'uris': <Map<String, String>>[
                <String, String>{'uri': 'https://example/two.iso'},
              ],
            },
          ],
        ),
        getOptionsOverride: () async => <String, dynamic>{
          'header': <String>['Authorization: hidden'],
          'out': 'old-name.iso',
        },
        addUriOverride: (uris, options) async {
          added.add(uris);
          outputs.add(options['out'] as String?);
          return 'new-${added.length}';
        },
        removeDownloadResultOverride: (gid) async {
          removedOld = true;
          return 'OK';
        },
        saveSessionOverride: () async => true,
      );

      expect(result, <String>['new-1', 'new-2']);
      expect(added, hasLength(2));
      expect(outputs, <String?>['one.iso', 'two.iso']);
      expect(removedOld, isTrue);
    });

    test(
      'applies a nested retry destination under the task directory',
      () async {
        Map<String, dynamic>? submittedOptions;

        await DownloadTaskService.retryTaskWithClient(
          client,
          task(
            infoHash: 'invalid',
            files: <Map<String, dynamic>>[
              <String, dynamic>{
                'path': '/downloads/releases/one.iso',
                'uris': <Map<String, String>>[
                  <String, String>{'uri': 'https://example/one.iso'},
                ],
              },
            ],
          ),
          getOptionsOverride: () async => <String, dynamic>{},
          addUriOverride: (uris, options) async {
            submittedOptions = Map<String, dynamic>.from(options);
            return 'new-1';
          },
          removeDownloadResultOverride: (gid) async => 'OK',
          saveSessionOverride: () async => true,
        );

        expect(submittedOptions?['dir'], '/downloads');
        expect(submittedOptions?['out'], 'releases/one.iso');
      },
    );

    test('rolls back new tasks after a partial submission failure', () async {
      final rolledBack = <String>[];
      var addCount = 0;
      var removedOld = false;

      await expectLater(
        DownloadTaskService.retryTaskWithClient(
          client,
          task(
            files: <Map<String, dynamic>>[
              <String, dynamic>{
                'path': '/downloads/one.iso',
                'uris': <Map<String, String>>[
                  <String, String>{'uri': 'https://example/one.iso'},
                ],
              },
              <String, dynamic>{
                'path': '/downloads/two.iso',
                'uris': <Map<String, String>>[
                  <String, String>{'uri': 'https://example/two.iso'},
                ],
              },
            ],
          ),
          getOptionsOverride: () async => <String, dynamic>{},
          addUriOverride: (uris, options) async {
            addCount++;
            if (addCount == 2) {
              throw const RpcException('submission failed');
            }
            return 'new-1';
          },
          getTaskStatusOverride: (gid) async => 'active',
          removeTaskOverride: (gid) async {
            rolledBack.add(gid);
            return gid;
          },
          removeDownloadResultOverride: (gid) async {
            removedOld = true;
            return 'OK';
          },
          saveSessionOverride: () async => true,
        ),
        throwsA(isA<RpcException>()),
      );

      expect(rolledBack, <String>['new-1']);
      expect(removedOld, isFalse);
    });

    test('removes a completed retry result during rollback', () async {
      final removedTasks = <String>[];
      final removedResults = <String>[];
      var addCount = 0;

      await expectLater(
        DownloadTaskService.retryTaskWithClient(
          client,
          task(
            files: <Map<String, dynamic>>[
              <String, dynamic>{
                'path': '/downloads/one.iso',
                'uris': <Map<String, String>>[
                  <String, String>{'uri': 'https://example/one.iso'},
                ],
              },
              <String, dynamic>{
                'path': '/downloads/two.iso',
                'uris': <Map<String, String>>[
                  <String, String>{'uri': 'https://example/two.iso'},
                ],
              },
            ],
          ),
          getOptionsOverride: () async => <String, dynamic>{},
          addUriOverride: (uris, options) async {
            addCount++;
            if (addCount == 2) {
              throw const RpcException('submission failed');
            }
            return 'new-1';
          },
          getTaskStatusOverride: (gid) async => 'complete',
          removeTaskOverride: (gid) async {
            removedTasks.add(gid);
            return gid;
          },
          removeDownloadResultOverride: (gid) async {
            removedResults.add(gid);
            return 'OK';
          },
          saveSessionOverride: () async => true,
        ),
        throwsA(isA<RpcException>()),
      );

      expect(removedTasks, isEmpty);
      expect(removedResults, <String>['new-1']);
    });

    test(
      'preserves confirmed tasks when a later result is indeterminate',
      () async {
        final rolledBack = <String>[];
        var addCount = 0;

        await expectLater(
          DownloadTaskService.retryTaskWithClient(
            client,
            task(
              files: <Map<String, dynamic>>[
                <String, dynamic>{
                  'path': '/downloads/one.iso',
                  'uris': <Map<String, String>>[
                    <String, String>{'uri': 'https://example/one.iso'},
                  ],
                },
                <String, dynamic>{
                  'path': '/downloads/two.iso',
                  'uris': <Map<String, String>>[
                    <String, String>{'uri': 'https://example/two.iso'},
                  ],
                },
              ],
            ),
            getOptionsOverride: () async => <String, dynamic>{},
            addUriOverride: (uris, options) async {
              addCount++;
              if (addCount == 2) {
                throw const RpcResultIndeterminateException('aria2.addUri');
              }
              return 'new-1';
            },
            removeTaskOverride: (gid) async {
              rolledBack.add(gid);
              return gid;
            },
            removeDownloadResultOverride: (gid) async => 'OK',
            saveSessionOverride: () async => true,
          ),
          throwsA(isA<RpcResultIndeterminateException>()),
        );

        expect(rolledBack, isEmpty);
      },
    );
  });
}
