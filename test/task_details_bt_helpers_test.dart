import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/models/aria2_peer.dart';
import 'package:setsuna/pages/download_page/components/task_details_bt_helpers.dart';
import 'package:setsuna/pages/download_page/enums.dart';
import 'package:setsuna/pages/download_page/models/download_task.dart';

DownloadTask _task(String? bitfield) {
  return DownloadTask(
    id: 'task',
    name: 'task',
    status: DownloadStatus.active,
    progress: 0,
    downloadSpeed: '0 B/s',
    uploadSpeed: '0 B/s',
    size: '0 B',
    completedSize: '0 B',
    isLocal: true,
    instanceId: 'local',
    bitfield: bitfield,
  );
}

Aria2Peer _peer(String bitfield) {
  return Aria2Peer.fromRpc(<Object?, Object?>{'bitfield': bitfield});
}

void main() {
  test('file selection signature changes with index or selected state', () {
    final original = TaskDetailsBtHelpers.buildFileSelectionSignature(const [
      <String, Object?>{'index': '1', 'selected': 'true'},
      <String, Object?>{'index': '2', 'selected': 'false'},
    ]);

    expect(
      TaskDetailsBtHelpers.buildFileSelectionSignature(const [
        <String, Object?>{'index': '1', 'selected': 'false'},
        <String, Object?>{'index': '2', 'selected': 'false'},
      ]),
      isNot(original),
    );
    expect(
      TaskDetailsBtHelpers.buildFileSelectionSignature(const [
        <String, Object?>{'index': '3', 'selected': 'true'},
        <String, Object?>{'index': '2', 'selected': 'false'},
      ]),
      isNot(original),
    );
  });

  test('normalizes boolean file selection values', () {
    expect(
      TaskDetailsBtHelpers.buildFileSelectionSignature(const [
        <String, Object?>{'index': 1, 'selected': true},
        <String, Object?>{'index': 2, 'selected': false},
      ]),
      '1:true|2:false',
    );
  });

  group('estimateHealthPercent', () {
    test('returns null without a local bitfield', () {
      expect(
        TaskDetailsBtHelpers.estimateHealthPercent(_task(null), const []),
        isNull,
      );
      expect(
        TaskDetailsBtHelpers.estimateHealthPercent(_task(''), const []),
        isNull,
      );
    });

    test('counts pieces available locally or at any peer', () {
      // Local: piece 0 complete, piece 1 missing, piece 2 partial.
      final task = _task('f05');
      final peers = <Aria2Peer>[_peer('010'), _peer('00f')];

      final health = TaskDetailsBtHelpers.estimateHealthPercent(task, peers);

      expect(health, closeTo((3 / 3) * 100, 0.01));
    });

    test('reports only locally complete pieces without peers', () {
      // f = complete, 5 = partial (not counted alone), 0 = missing.
      final task = _task('f50');

      final health = TaskDetailsBtHelpers.estimateHealthPercent(task, const []);

      expect(health, closeTo((1 / 3) * 100, 0.01));
    });

    test('peers without bitfields do not increase health', () {
      final task = _task('00');
      final missingBitfields = <Aria2Peer>[
        const Aria2Peer(ip: '1.2.3.4'),
        _peer(''),
      ];

      expect(
        TaskDetailsBtHelpers.estimateHealthPercent(task, missingBitfields),
        closeTo(0, 0.01),
      );
      expect(
        TaskDetailsBtHelpers.estimateHealthPercent(task, [_peer('f0')]),
        closeTo(50, 0.01),
      );
    });

    test('unions peer availability while respecting local piece bounds', () {
      final task = _task('000');

      expect(
        TaskDetailsBtHelpers.estimateHealthPercent(task, [
          _peer('f'),
          _peer('0f'),
          _peer('00ff'),
        ]),
        closeTo(100, 0.01),
      );
    });
  });
}
