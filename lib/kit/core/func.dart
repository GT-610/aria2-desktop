import 'dart:async';

abstract final class Fns {
  static const _defaultDurationTime = 377;
  static const _defaultThrottleId = 'default';
  static final startTimeMap = <String, int>{_defaultThrottleId: 0};

  static FutureOr<T?> throttle<T>(
    FutureOr<T> Function() func, {
    String id = _defaultThrottleId,
    int duration = _defaultDurationTime,
    Function? continueClick,
  }) async {
    final currentTime = DateTime.now().millisecondsSinceEpoch;
    if (currentTime - (startTimeMap[id] ?? 0) > duration) {
      startTimeMap[id] = DateTime.now().millisecondsSinceEpoch;
      return await func();
    } else {
      continueClick?.call();
      return null;
    }
  }
}
