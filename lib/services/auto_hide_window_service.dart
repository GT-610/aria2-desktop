import 'dart:async';

class AutoHideWindowService {
  static final AutoHideWindowService _instance =
      AutoHideWindowService._internal();

  int _suppressionCount = 0;

  factory AutoHideWindowService() => _instance;

  AutoHideWindowService._internal();

  bool get isSuppressed => _suppressionCount > 0;

  Future<T> runWithSuppressedAutoHide<T>(Future<T> Function() action) async {
    _suppressionCount++;
    try {
      return await action();
    } finally {
      _suppressionCount--;
    }
  }
}
