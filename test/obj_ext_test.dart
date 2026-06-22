import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/kit/core/ext/obj.dart';

void main() {
  group('ObjectX', () {
    group('vn', () {
      test('creates VNode from non-nullable value', () {
        final node = 42.vn;
        expect(node.value, 42);
      });

      test('creates VNode from string', () {
        final node = 'hello'.vn;
        expect(node.value, 'hello');
      });

      test('creates VNode from object', () {
        final node = [1, 2, 3].vn;
        expect(node.value, [1, 2, 3]);
      });
    });
  });

  group('ObjectXNullable', () {
    group('vn', () {
      test('creates VNode from null', () {
        final node = null.vn;
        expect(node.value, isNull);
      });

      test('creates VNode from nullable int', () {
        int? value = 42;
        final node = value.vn;
        expect(node.value, 42);
      });
    });
  });
}
