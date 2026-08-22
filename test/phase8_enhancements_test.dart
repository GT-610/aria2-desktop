import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:setsuna/generated/l10n/l10n.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/pages/settings_page/components/speed_limit_card.dart';
import 'package:setsuna/services/update_check_service.dart';
import 'package:setsuna/utils/file_category.dart';

import 'support/memory_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group('FileCategoryRule parsing', () {
    test('parses valid rule JSON and normalizes extensions', () {
      final rule = FileCategoryRule.tryParse(
        '{"extensions":[".MP4","mkv "],"subdirectory":"Videos/"}',
      );

      expect(rule, isNotNull);
      expect(rule!.extensions, {'mp4', 'mkv'});
      expect(rule.subdirectory, 'Videos');
    });

    test('rejects malformed or traversal rules', () {
      expect(FileCategoryRule.tryParse('not json'), isNull);
      expect(
        FileCategoryRule.tryParse('{"extensions":[],"subdirectory":"a"}'),
        isNull,
      );
      expect(
        FileCategoryRule.tryParse(
          '{"extensions":["mp4"],"subdirectory":"../x"}',
        ),
        isNull,
      );
    });

    test('parseFileCategoryRules caps at the maximum', () {
      final raw = List.generate(
        maxFileCategoryRules + 5,
        (i) => '{"extensions":["e$i"],"subdirectory":"d$i"}',
      );

      expect(parseFileCategoryRules(raw).length, maxFileCategoryRules);
    });
  });

  group('categorySubdirFor', () {
    final rules = parseFileCategoryRules([
      '{"extensions":["mp4","mkv"],"subdirectory":"Videos"}',
      '{"extensions":["zip"],"subdirectory":"Archives"}',
    ]);

    test('routes matching URIs to their subdirectory', () {
      expect(
        categorySubdirFor('https://example.com/movie.mp4?token=1', rules),
        'Videos',
      );
      expect(
        categorySubdirFor('ftp://example.com/files/big.ZIP', rules),
        'Archives',
      );
    });

    test('returns null for unmatched extensions and non-download URIs', () {
      expect(categorySubdirFor('https://example.com/page.html', rules), isNull);
      expect(categorySubdirFor('magnet:?xt=urn:btih:abc', rules), isNull);
      expect(categorySubdirFor('https://example.com/', rules), isNull);
      expect(
        categorySubdirFor('https://example.com/file.zip', const []),
        isNull,
      );
    });
  });

  group('isNewerVersion', () {
    test('compares dotted versions numerically', () {
      expect(isNewerVersion('1.2.3', '1.2.4'), isTrue);
      expect(isNewerVersion('1.10.0', '1.9.9'), isFalse);
      expect(isNewerVersion('0.0.0+12', 'v1.0.5'), isTrue);
      expect(isNewerVersion('2.5.5', '2.5.5'), isFalse);
      // Short versions are padded with zeros.
      expect(isNewerVersion('1.2', '1.2.0'), isFalse);
      expect(isNewerVersion('1.2', '1.2.1'), isTrue);
    });
  });

  group('SpeedLimitCard', () {
    testWidgets('toggling the master switch persists the setting', (
      tester,
    ) async {
      final settings = Settings(
        repository: MemorySettingsRepository(<String, dynamic>{}),
      );
      await settings.loadSettings();

      await tester.pumpWidget(
        MultiProvider(
          providers: [ChangeNotifierProvider<Settings>.value(value: settings)],
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: SpeedLimitCard(settings: settings)),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(settings.speedLimitEnabled, isTrue);

      await tester.tap(find.byType(Switch).first);
      await tester.pumpAndSettle();

      expect(settings.speedLimitEnabled, isFalse);
    });
  });
}
