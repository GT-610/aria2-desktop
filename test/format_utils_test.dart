import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/utils/format_utils.dart';

void main() {
  group('formatRemainingTime', () {
    test('returns placeholder when total size is unknown', () {
      expect(
        formatRemainingTime(
          totalBytes: 0,
          completedBytes: 0,
          downloadSpeedBytes: 100,
        ),
        '--',
      );
    });

    test('calculates remaining time from bytes and speed', () {
      expect(
        formatRemainingTime(
          totalBytes: 1000,
          completedBytes: 400,
          downloadSpeedBytes: 100,
        ),
        '6s',
      );
    });

    test('returns zero seconds when completed', () {
      expect(
        formatRemainingTime(
          totalBytes: 1000,
          completedBytes: 1000,
          downloadSpeedBytes: 100,
        ),
        '0s',
      );
    });
  });
}
