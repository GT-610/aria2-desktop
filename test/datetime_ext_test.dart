import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/kit/core/ext/datetime.dart';

void main() {
  group('DateTimeX', () {
    group('hourMinute', () {
      test('formats midnight', () {
        final dt = DateTime(2024, 1, 1, 0, 0);
        expect(dt.hourMinute, '00:00');
      });

      test('formats single-digit hour and minute', () {
        final dt = DateTime(2024, 1, 1, 9, 5);
        expect(dt.hourMinute, '09:05');
      });

      test('formats double-digit hour and minute', () {
        final dt = DateTime(2024, 1, 1, 14, 30);
        expect(dt.hourMinute, '14:30');
      });

      test('formats end of day', () {
        final dt = DateTime(2024, 1, 1, 23, 59);
        expect(dt.hourMinute, '23:59');
      });

      test('formats noon', () {
        final dt = DateTime(2024, 1, 1, 12, 0);
        expect(dt.hourMinute, '12:00');
      });
    });
  });
}
