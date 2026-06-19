import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/settings.dart';

void main() {
  group('Settings', () {
    group('normalizeBtTracker', () {
      late Settings settings;

      setUp(() {
        settings = Settings();
      });

      test('returns empty string for empty input', () {
        expect(settings.normalizeBtTracker(''), '');
      });

      test('returns single tracker unchanged', () {
        const tracker = 'udp://tracker.example.com:6969/announce';
        expect(settings.normalizeBtTracker(tracker), tracker);
      });

      test('preserves comma-separated trackers', () {
        const input =
            'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce';
        expect(settings.normalizeBtTracker(input), input);
      });

      test('normalizes newline-separated trackers to comma-separated', () {
        const input =
            'udp://t1.example.com:6969/announce\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('normalizes CRLF-separated trackers', () {
        const input =
            'udp://t1.example.com:6969/announce\r\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('strips empty entries from consecutive delimiters', () {
        const input =
            'udp://t1.example.com:6969/announce\n\n\nudp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('trims whitespace from each tracker', () {
        const input =
            '  udp://t1.example.com:6969/announce  ,  udp://t2.example.com:6969/announce  ';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('filters out empty entries after trimming', () {
        const input =
            'udp://t1.example.com:6969/announce, , udp://t2.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce',
        );
      });

      test('handles mixed comma and newline separators', () {
        const input =
            'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce\nudp://t3.example.com:6969/announce';
        expect(
          settings.normalizeBtTracker(input),
          'udp://t1.example.com:6969/announce,udp://t2.example.com:6969/announce,udp://t3.example.com:6969/announce',
        );
      });
    });
  });
}
