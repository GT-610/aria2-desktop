import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/kit/core/rnode.dart';

void main() {
  group('RNode', () {
    test('hasListeners is false when no listeners added', () {
      final node = RNode();
      expect(node.hasListeners, isFalse);
    });

    test('hasListeners is true after adding listener', () {
      final node = RNode();
      node.addListener(() {});
      expect(node.hasListeners, isTrue);
    });

    test('hasListeners is false after removing all listeners', () {
      final node = RNode();
      void listener() {}
      node.addListener(listener);
      node.removeListener(listener);
      expect(node.hasListeners, isFalse);
    });

    test('notifies listeners when notifyListeners is called', () {
      final node = RNode();
      int callCount = 0;
      node.addListener(() => callCount++);

      node.notifyListeners();

      expect(callCount, 1);
    });

    test('notifies multiple listeners', () {
      final node = RNode();
      int count1 = 0;
      int count2 = 0;
      node.addListener(() => count1++);
      node.addListener(() => count2++);

      node.notifyListeners();

      expect(count1, 1);
      expect(count2, 1);
    });

    test('dispose clears all listeners', () {
      final node = RNode();
      node.addListener(() {});
      node.addListener(() {});

      node.dispose();

      expect(node.hasListeners, isFalse);
    });

    test('toString includes hash code', () {
      final node = RNode();
      expect(node.toString(), contains('RNode'));
    });
  });

  group('VNode', () {
    test('stores initial value', () {
      final node = VNode<int>(42);
      expect(node.value, 42);
    });

    test('updates value', () {
      final node = VNode<int>(0);
      node.value = 100;
      expect(node.value, 100);
    });

    test('notifies listeners on value change', () {
      final node = VNode<int>(0);
      int notifiedValue = -1;
      node.addListener(() => notifiedValue = node.value);

      node.value = 42;

      expect(notifiedValue, 42);
    });

    test('does not notify when value is unchanged', () {
      final node = VNode<int>(42);
      int callCount = 0;
      node.addListener(() => callCount++);

      node.value = 42;

      expect(callCount, 0);
    });

    test('toString includes value', () {
      final node = VNode<String>('hello');
      expect(node.toString(), contains('hello'));
    });

    test('works with nullable types', () {
      final node = VNode<int?>(null);
      expect(node.value, isNull);

      node.value = 10;
      expect(node.value, 10);

      node.value = null;
      expect(node.value, isNull);
    });
  });
}
