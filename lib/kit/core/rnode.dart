import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

class RNode implements ChangeNotifier {
  final List<VoidCallback> _listeners = [];

  RNode();

  @override
  String toString() => 'RNode($hashCode)';

  @override
  void addListener(VoidCallback listener) {
    _listeners.add(listener);
  }

  @override
  void removeListener(VoidCallback listener) {
    _listeners.remove(listener);
  }

  void _notifySync() {
    for (final listener in List.of(_listeners)) {
      try {
        listener();
      } catch (error, stack) {
        FlutterError.reportError(
          FlutterErrorDetails(exception: error, stack: stack),
        );
      }
    }
  }

  Future<void> notify({bool delay = false}) async {
    if (delay) await Future.delayed(const Duration(milliseconds: 277));
    _notifySync();
  }

  @override
  void dispose() {
    _listeners.clear();
  }

  @override
  bool get hasListeners => _listeners.isNotEmpty;

  @override
  void notifyListeners() {
    _notifySync();
  }
}

extension RNodeX on RNode {
  ListenBuilder listen(Widget Function() builder) {
    return ListenBuilder(listenable: this, builder: builder);
  }
}

class VNode<T> extends RNode implements ValueNotifier<T> {
  T _value;

  VNode(T value) : _value = value;

  @override
  T get value => _value;

  @override
  set value(T newVal) {
    if (_value == newVal) return;
    _value = newVal;
    notify();
  }

  @override
  String toString() => 'VNode($value)';
}

extension ValueListenableX<T> on ValueListenable<T> {
  ValBuilder<T> listenVal(Widget Function(T) builder) {
    return ValBuilder<T>(listenable: this, builder: builder);
  }
}

final class ValBuilder<T> extends ValueListenableBuilder<T> {
  final ValueListenable<T> listenable;

  ValBuilder({
    super.key,
    required this.listenable,
    required Widget Function(T) builder,
  }) : super(valueListenable: listenable, builder: (_, val, _) => builder(val));
}

final class ListenBuilder extends ListenableBuilder {
  ListenBuilder({
    super.key,
    required super.listenable,
    required Widget Function() builder,
  }) : super(builder: (_, _) => builder());
}

final class EmptyListenable<T> implements ValueListenable<T?> {
  @override
  void addListener(VoidCallback listener) {}

  @override
  void removeListener(VoidCallback listener) {}

  @override
  T? get value => null;

  const EmptyListenable();
}

abstract final class RNodes {
  static final app = RNode();
  static final dark = VNode<bool>(false);
}
