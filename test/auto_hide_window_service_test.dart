import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/services/auto_hide_window_service.dart';

void main() {
  group('AutoHideWindowService', () {
    late AutoHideWindowService service;

    setUp(() {
      service = AutoHideWindowService();
    });

    group('isSuppressed', () {
      test('is false by default', () {
        expect(service.isSuppressed, isFalse);
      });
    });

    group('runWithSuppressedAutoHide', () {
      test('suppresses auto-hide during action', () async {
        bool wasSuppressed = false;

        await service.runWithSuppressedAutoHide(() async {
          wasSuppressed = service.isSuppressed;
        });

        expect(wasSuppressed, isTrue);
      });

      test('restores suppression after action completes', () async {
        await service.runWithSuppressedAutoHide(() async {});

        expect(service.isSuppressed, isFalse);
      });

      test('restores suppression even when action throws', () async {
        try {
          await service.runWithSuppressedAutoHide(() async {
            throw Exception('test error');
          });
        } catch (_) {}

        expect(service.isSuppressed, isFalse);
      });

      test('returns the value from the action', () async {
        final result = await service.runWithSuppressedAutoHide(() async {
          return 42;
        });

        expect(result, 42);
      });

      test('nests suppression correctly', () async {
        bool outerSuppressed = false;
        bool innerSuppressed = false;
        bool afterInner = false;

        await service.runWithSuppressedAutoHide(() async {
          outerSuppressed = service.isSuppressed;
          await service.runWithSuppressedAutoHide(() async {
            innerSuppressed = service.isSuppressed;
          });
          afterInner = service.isSuppressed;
        });

        expect(outerSuppressed, isTrue);
        expect(innerSuppressed, isTrue);
        expect(afterInner, isTrue);
        expect(service.isSuppressed, isFalse);
      });
    });
  });
}
