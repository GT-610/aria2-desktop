import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/utils/format_utils.dart';

void main() {
  group('formatBytes', () {
    test('returns 0 B for zero bytes', () {
      expect(formatBytes(0), '0 B');
    });

    test('returns 0 B for negative bytes', () {
      expect(formatBytes(-100), '0 B');
    });

    test('formats bytes correctly', () {
      expect(formatBytes(1), '1.00 B');
      expect(formatBytes(512), '512.00 B');
      expect(formatBytes(1023), '1023.00 B');
    });

    test('formats kilobytes correctly', () {
      expect(formatBytes(1024), '1.00 KB');
      expect(formatBytes(1536), '1.50 KB');
    });

    test('formats megabytes correctly', () {
      expect(formatBytes(1048576), '1.00 MB');
    });

    test('formats gigabytes correctly', () {
      expect(formatBytes(1073741824), '1.00 GB');
    });

    test('formats terabytes correctly', () {
      expect(formatBytes(1099511627776), '1.00 TB');
    });

    test('respects decimals parameter', () {
      expect(formatBytes(1536, decimals: 0), '2 KB');
      expect(formatBytes(1536, decimals: 1), '1.5 KB');
      expect(formatBytes(1536, decimals: 3), '1.500 KB');
    });
  });

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

    test('returns placeholder when speed is zero', () {
      expect(
        formatRemainingTime(
          totalBytes: 1000,
          completedBytes: 500,
          downloadSpeedBytes: 0,
        ),
        '--',
      );
    });

    test('formats minutes and seconds', () {
      expect(
        formatRemainingTime(
          totalBytes: 12000,
          completedBytes: 0,
          downloadSpeedBytes: 100,
        ),
        '2m 0s',
      );
    });

    test('formats hours and minutes', () {
      expect(
        formatRemainingTime(
          totalBytes: 7200000,
          completedBytes: 0,
          downloadSpeedBytes: 1000,
        ),
        '2h 0m',
      );
    });

    test('formats days and hours', () {
      expect(
        formatRemainingTime(
          totalBytes: 172800000,
          completedBytes: 0,
          downloadSpeedBytes: 1000,
        ),
        '2d 0h',
      );
    });
  });

  group('parseHexBitfield', () {
    test('parses hex string', () {
      expect(parseHexBitfield('ff'), [15, 15]);
      expect(parseHexBitfield('0a'), [0, 10]);
      expect(parseHexBitfield('abc'), [10, 11, 12]);
    });

    test('returns empty list for empty string', () {
      expect(parseHexBitfield(''), isEmpty);
    });

    test('handles invalid hex chars gracefully', () {
      final result = parseHexBitfield('z1');
      expect(result.length, 2);
      expect(result[0], 0); // 'z' is invalid, defaults to 0
      expect(result[1], 1);
    });
  });

  group('formatSpeed', () {
    test('returns 0 B/s for zero speed', () {
      expect(formatSpeed(0), '0 B/s');
    });

    test('returns 0 B/s for negative speed', () {
      expect(formatSpeed(-100), '0 B/s');
    });

    test('formats positive speed', () {
      expect(formatSpeed(1024), '1.00 KB/s');
      expect(formatSpeed(1048576), '1.00 MB/s');
    });
  });

  group('formatSpeedLimitOption', () {
    test('returns 0 for zero', () {
      expect(formatSpeedLimitOption(0), '0');
    });

    test('returns 0 for negative', () {
      expect(formatSpeedLimitOption(-100), '0');
    });

    test('appends K suffix for positive values', () {
      expect(formatSpeedLimitOption(100), '100K');
      expect(formatSpeedLimitOption(1024), '1024K');
    });
  });
}
