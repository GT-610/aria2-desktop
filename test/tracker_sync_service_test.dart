import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/services/tracker_sync_service.dart';

void main() {
  group('TrackerSyncService', () {
    late TrackerSyncService service;

    setUp(() {
      service = TrackerSyncService();
    });

    group('reduceTrackerString', () {
      test('returns input when under max length', () {
        const short =
            'udp://tracker1.example.com:6969,udp://tracker2.example.com:6969';
        expect(service.reduceTrackerString(short), short);
      });

      test('returns empty string for empty input', () {
        expect(service.reduceTrackerString(''), '');
      });

      test('truncates at last comma when over max length', () {
        // Build a string that exceeds 6144 chars
        final tracker = 'udp://tracker.example.com:6969/announce';
        final repeats = List.filled(200, tracker);
        final longString = repeats.join(',');

        final result = service.reduceTrackerString(longString);

        expect(result.length, lessThanOrEqualTo(6144));
        expect(result.isNotEmpty, isTrue);
        // Result should not end with a comma (truncated at last comma)
        expect(result.endsWith(','), isFalse);
        // Result should be a prefix of the original
        expect(longString.startsWith(result), isTrue);
      });

      test('truncates at exact max length when no comma found', () {
        // Build a string with no commas that exceeds 6144 chars
        final longString = 'a' * 7000;

        final result = service.reduceTrackerString(longString);

        expect(result.length, 6144);
        expect(result, 'a' * 6144);
      });

      test('preserves tracker URLs separated by commas', () {
        final trackers = List.generate(
          10,
          (i) => 'udp://tracker$i.example.com:6969/announce',
        );
        final input = trackers.join(',');

        final result = service.reduceTrackerString(input);

        // All trackers should be preserved since it's under the limit
        expect(result, input);
      });

      test('handles single tracker under max length', () {
        const single = 'udp://tracker.example.com:6969/announce';
        expect(service.reduceTrackerString(single), single);
      });
    });

    group('sourceOptions', () {
      test('has 6 sources', () {
        expect(TrackerSyncService.sourceOptions.length, 6);
      });

      test('all sources have non-empty labels and URLs', () {
        for (final option in TrackerSyncService.sourceOptions) {
          expect(option.label.isNotEmpty, isTrue);
          expect(option.url.isNotEmpty, isTrue);
          expect(option.url.startsWith('https://'), isTrue);
        }
      });
    });
  });
}
