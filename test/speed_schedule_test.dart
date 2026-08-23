import 'package:flutter_test/flutter_test.dart';

import 'package:setsuna/utils/speed_schedule.dart';

void main() {
  group('parseHmToMinutes / formatMinutesAsHm', () {
    test('parses valid HH:mm values', () {
      expect(parseHmToMinutes('00:00'), 0);
      expect(parseHmToMinutes('09:30'), 570);
      expect(parseHmToMinutes('24:00'), minutesPerDay);
    });

    test('rejects malformed values', () {
      expect(parseHmToMinutes('25:00'), -1);
      expect(parseHmToMinutes('9:60'), -1);
      expect(parseHmToMinutes('abc'), -1);
      expect(parseHmToMinutes(''), -1);
    });

    test('formats minutes back to HH:mm', () {
      expect(formatMinutesAsHm(0), '00:00');
      expect(formatMinutesAsHm(570), '09:30');
      expect(formatMinutesAsHm(minutesPerDay), '24:00');
    });
  });

  group('weekdayIndex', () {
    test('maps Monday to 0 and Sunday to 6', () {
      // 2024-01-01 was a Monday.
      expect(weekdayIndex(DateTime(2024, 1, 1)), 0);
      expect(weekdayIndex(DateTime(2024, 1, 7)), 6);
      expect(weekdayIndex(DateTime(2024, 1, 8)), 0);
    });
  });

  group('isWithinSpeedScheduleWindow', () {
    DateTime at(int weekday, int hour, int minute) {
      // 2024-01-01 was a Monday (weekday index 0).
      return DateTime(2024, 1, 1 + weekday, hour, minute);
    }

    bool within(
      DateTime now, {
      int startMinutes = 600,
      int endMinutes = 720,
      int daysBitmask = allDaysBitmask,
    }) {
      return isWithinSpeedScheduleWindow(
        scheduleEnabled: true,
        daysBitmask: daysBitmask,
        startMinutes: startMinutes,
        endMinutes: endMinutes,
        now: now,
      );
    }

    test('honors a simple same-day window', () {
      expect(within(at(0, 10, 0)), isTrue);
      expect(within(at(0, 11, 59)), isTrue);
      expect(within(at(0, 12, 0)), isFalse);
      expect(within(at(0, 9, 59)), isFalse);
    });

    test('honors overnight windows across midnight', () {
      expect(
        within(
          at(0, 23, 0),
          startMinutes: 22 * 60, // 22:00
          endMinutes: 6 * 60, // 06:00 next day
        ),
        isTrue,
      );
      expect(
        within(at(1, 2, 0), startMinutes: 22 * 60, endMinutes: 6 * 60),
        isTrue,
      );
      expect(
        within(at(1, 6, 0), startMinutes: 22 * 60, endMinutes: 6 * 60),
        isFalse,
      );
      // Monday 03:00 belongs to Sunday's window; Sunday is selected too.
      expect(
        within(at(0, 3, 0), startMinutes: 22 * 60, endMinutes: 6 * 60),
        isTrue,
      );
    });

    test('uses the starting day for a Monday-only overnight window', () {
      const mondayOnly = 0x01;
      expect(
        within(
          at(0, 23, 0),
          startMinutes: 22 * 60,
          endMinutes: 6 * 60,
          daysBitmask: mondayOnly,
        ),
        isTrue,
      );
      expect(
        within(
          at(1, 2, 0),
          startMinutes: 22 * 60,
          endMinutes: 6 * 60,
          daysBitmask: mondayOnly,
        ),
        isTrue,
      );
      expect(
        within(
          at(0, 2, 0),
          startMinutes: 22 * 60,
          endMinutes: 6 * 60,
          daysBitmask: mondayOnly,
        ),
        isFalse,
      );
      expect(
        within(
          at(1, 23, 0),
          startMinutes: 22 * 60,
          endMinutes: 6 * 60,
          daysBitmask: mondayOnly,
        ),
        isFalse,
      );
    });

    test('respects the selected weekdays only', () {
      // Only Monday (bit 0) with an all-day window.
      expect(
        within(
          at(0, 12, 0),
          startMinutes: 0,
          endMinutes: minutesPerDay,
          daysBitmask: 0x01,
        ),
        isTrue,
      );
      expect(
        within(
          at(1, 12, 0),
          startMinutes: 0,
          endMinutes: minutesPerDay,
          daysBitmask: 0x01,
        ),
        isFalse,
      );
    });

    test('treats an empty day selection as every day', () {
      expect(
        isWithinSpeedScheduleWindow(
          scheduleEnabled: true,
          daysBitmask: 0,
          startMinutes: 0,
          endMinutes: minutesPerDay,
          now: at(5, 12, 0),
        ),
        isTrue,
      );
    });
  });

  group('effectiveSpeedLimit', () {
    test('returns configured value only when enabled and in window', () {
      expect(
        effectiveSpeedLimit(
          limitsEnabled: true,
          windowActive: true,
          configuredValue: 512,
        ),
        512,
      );
      expect(
        effectiveSpeedLimit(
          limitsEnabled: false,
          windowActive: true,
          configuredValue: 512,
        ),
        0,
      );
      expect(
        effectiveSpeedLimit(
          limitsEnabled: true,
          windowActive: false,
          configuredValue: 512,
        ),
        0,
      );
      expect(
        effectiveSpeedLimit(
          limitsEnabled: true,
          windowActive: true,
          configuredValue: -3,
        ),
        0,
      );
    });
  });
}
