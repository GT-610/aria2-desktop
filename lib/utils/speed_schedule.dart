/// Pure helpers for the global speed-limit schedule.
///
/// The user's configured limits stay untouched; the schedule only decides
/// whether they are currently enforced. This mirrors Motrix-Next's passive
/// scheduler: enforcement state never mutates user intent.
library;

/// Bitmask days: bit 0 = Monday ... bit 6 = Sunday.
const int allDaysBitmask = 0x7F;

const int minutesPerDay = 24 * 60;

int parseHmToMinutes(String value) {
  final match = RegExp(r'^(\d{1,2}):(\d{2})$').firstMatch(value.trim());
  if (match == null) {
    return -1;
  }
  final hours = int.tryParse(match.group(1)!) ?? -1;
  final minutes = int.tryParse(match.group(2)!) ?? -1;
  if (hours < 0 || hours > 24 || minutes < 0 || minutes > 59) {
    return -1;
  }
  final total = hours * 60 + minutes;
  if (total > minutesPerDay) {
    return -1;
  }
  return total;
}

String formatMinutesAsHm(int totalMinutes) {
  final clamped = totalMinutes.clamp(0, minutesPerDay).toInt();
  final hours = clamped ~/ 60;
  final minutes = clamped % 60;
  return '${hours.toString().padLeft(2, '0')}:${minutes.toString().padLeft(2, '0')}';
}

/// Monday-based weekday index for [now]: 0 = Monday ... 6 = Sunday.
int weekdayIndex(DateTime now) {
  return (now.weekday - 1) % 7;
}

bool isDaySelected(int daysBitmask, DateTime now) {
  final masked = daysBitmask & allDaysBitmask;
  if (masked == allDaysBitmask || masked == 0) {
    // Empty selection is treated as "every day" so enabling a schedule
    // without picking days does not silently disable limits forever.
    return true;
  }
  return (masked >> weekdayIndex(now)) & 1 == 1;
}

bool isWithinSpeedScheduleWindow({
  required bool scheduleEnabled,
  required int daysBitmask,
  required int startMinutes,
  required int endMinutes,
  required DateTime now,
}) {
  if (!scheduleEnabled) {
    return true;
  }

  final start = startMinutes.clamp(0, minutesPerDay).toInt();
  final end = endMinutes.clamp(0, minutesPerDay).toInt();
  if (start == end) {
    // Zero-length window means the schedule never restricts anything.
    return true;
  }

  if (!isDaySelected(daysBitmask, now)) {
    return false;
  }

  final current = now.hour * 60 + now.minute;
  if (start < end) {
    return current >= start && current < end;
  }

  // Overnight window (e.g. 22:00 -> 06:00).
  final dayIsSelected = isDaySelected(daysBitmask, now);
  final previousDayIsSelected = isDaySelected(
    daysBitmask,
    now.subtract(const Duration(days: 1)),
  );
  return (current >= start && dayIsSelected) ||
      (current < end && previousDayIsSelected);
}

/// A limit value of 0 means unlimited for aria2.
int effectiveSpeedLimit({
  required bool limitsEnabled,
  required bool windowActive,
  required int configuredValue,
}) {
  if (!limitsEnabled || !windowActive) {
    return 0;
  }
  return configuredValue < 0 ? 0 : configuredValue;
}
