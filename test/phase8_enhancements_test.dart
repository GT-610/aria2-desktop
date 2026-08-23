import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

import 'package:setsuna/generated/l10n/l10n.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/pages/components/file_category_editor_dialog.dart';
import 'package:setsuna/pages/components/quick_speed_limit_dialog.dart';
import 'package:setsuna/pages/settings_page/components/speed_limit_card.dart';
import 'package:setsuna/services/instance_manager.dart';
import 'package:setsuna/services/update_check_service.dart';
import 'package:setsuna/utils/file_category.dart';

import 'support/memory_settings_repository.dart';

const _dialogLauncherKey = Key('dialogLauncher');

class _ControlledSettingsRepository extends MemorySettingsRepository {
  _ControlledSettingsRepository() : super(<String, dynamic>{});

  Completer<void>? pendingSave;
  Object? nextSaveError;
  int saveCalls = 0;

  @override
  Future<void> save(
    Map<String, dynamic> values, {
    bool credentialsBlocked = false,
  }) async {
    saveCalls++;
    final error = nextSaveError;
    nextSaveError = null;
    if (error != null) {
      throw error;
    }
    await pendingSave?.future;
    await super.save(values, credentialsBlocked: credentialsBlocked);
  }
}

Widget _testApp(Settings settings, Widget child) {
  return MultiProvider(
    providers: [
      ChangeNotifierProvider<Settings>.value(value: settings),
      ChangeNotifierProvider<InstanceManager>(create: (_) => InstanceManager()),
    ],
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: child),
    ),
  );
}

Widget _dialogLauncher(void Function(BuildContext context) showDialog) {
  return Builder(
    builder: (context) => IconButton(
      key: _dialogLauncherKey,
      onPressed: () => showDialog(context),
      icon: const Icon(Icons.open_in_new),
    ),
  );
}

AppLocalizations _l10n(WidgetTester tester) {
  return AppLocalizations.of(tester.element(find.byType(Scaffold)))!;
}

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
      for (final subdirectory in <String>[
        '.',
        '..',
        '/outside',
        'C:/outside',
        'safe/invalid:name',
      ]) {
        expect(
          FileCategoryRule.tryParse(
            '{"extensions":["mp4"],"subdirectory":"$subdirectory"}',
          ),
          isNull,
          reason: 'accepted unsafe subdirectory $subdirectory',
        );
      }
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

    test('routes the first matching URI in a multiline value', () {
      const uris = '''
        https://example.com/readme.txt

        https://example.com/archive.zip
        https://example.com/movie.mp4
      ''';

      expect(categorySubdirForUris(uris, rules), 'Archives');
    });

    test('returns null when no URI in a multiline value matches', () {
      const uris = '''
        magnet:?xt=urn:btih:abc
        https://example.com/readme.txt
      ''';

      expect(categorySubdirForUris(uris, rules), isNull);
      expect(categorySubdirForUris('\r\n  \n', rules), isNull);
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
    late Settings settings;

    setUp(() async {
      settings = Settings(
        repository: MemorySettingsRepository(<String, dynamic>{}),
      );
      await settings.loadSettings();
    });

    Future<AppLocalizations> pumpCard(WidgetTester tester) async {
      await tester.pumpWidget(
        _testApp(
          settings,
          Consumer<Settings>(
            builder: (context, value, child) => SpeedLimitCard(settings: value),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return _l10n(tester);
    }

    testWidgets('toggling the master switch persists the setting', (
      tester,
    ) async {
      final l10n = await pumpCard(tester);

      expect(settings.speedLimitEnabled, isTrue);
      expect(find.text(l10n.maxOverallUploadSpeed), findsOneWidget);

      final masterTile = find.widgetWithText(
        ListTile,
        l10n.speedLimitEnabledTitle,
      );
      await tester.tap(
        find.descendant(of: masterTile, matching: find.byType(Switch)),
      );
      await tester.pumpAndSettle();

      expect(settings.speedLimitEnabled, isFalse);
      expect(
        tester
            .widget<ListTile>(
              find.widgetWithText(ListTile, l10n.maxOverallUploadSpeed),
            )
            .enabled,
        isFalse,
      );
    });

    testWidgets('uses settings tiles and edits a limit in a dialog', (
      tester,
    ) async {
      final l10n = await pumpCard(tester);

      expect(find.text(l10n.maxOverallUploadSpeed), findsOneWidget);
      expect(find.text(l10n.maxOverallDownloadSpeed), findsOneWidget);
      expect(find.byType(TextField), findsNothing);

      await tester.tap(find.text(l10n.maxOverallUploadSpeed));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.enterText(find.byType(TextField), '512');
      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pumpAndSettle();

      expect(settings.maxOverallUploadLimit, 512);
      expect(
        find.textContaining('${settings.maxOverallUploadLimit}'),
        findsOneWidget,
      );
      expect(find.byType(AlertDialog), findsNothing);
    });
  });

  group('File category editor', () {
    testWidgets('reports invalid rows and keeps the dialog open', (
      tester,
    ) async {
      final settings = Settings(
        repository: MemorySettingsRepository(<String, dynamic>{}),
      );
      await settings.loadSettings();

      await tester.pumpWidget(
        _testApp(
          settings,
          _dialogLauncher(
            (context) => showFileCategoryEditorDialog(context, settings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);

      await tester.tap(find.byKey(_dialogLauncherKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.fileCategoryAddRule),
      );
      await tester.pump();
      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.fileCategoryInvalidRule), findsOneWidget);
      expect(settings.fileCategoryRules, isEmpty);

      await tester.enterText(find.byType(TextField).first, '.MP4');
      await tester.enterText(find.byType(TextField).last, 'Videos/');
      await tester.pump();
      expect(find.text(l10n.fileCategoryInvalidRule), findsNothing);

      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.fileCategoryRules.single.extensions, {'mp4'});
      expect(settings.fileCategoryRules.single.subdirectory, 'Videos');
    });

    testWidgets('reports persistence failures and keeps the dialog open', (
      tester,
    ) async {
      final repository = _ControlledSettingsRepository();
      final settings = Settings(repository: repository);
      await settings.loadSettings();

      await tester.pumpWidget(
        _testApp(
          settings,
          _dialogLauncher(
            (context) => showFileCategoryEditorDialog(context, settings),
          ),
        ),
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);

      await tester.tap(find.byKey(_dialogLauncherKey));
      await tester.pumpAndSettle();
      await tester.tap(
        find.widgetWithText(TextButton, l10n.fileCategoryAddRule),
      );
      await tester.pump();
      await tester.enterText(find.byType(TextField).first, 'mp4');
      await tester.enterText(find.byType(TextField).last, 'Videos');
      repository.nextSaveError = StateError('save failed');

      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.saveSettingsFailed), findsOneWidget);
      expect(settings.fileCategoryRules, isEmpty);

      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(settings.fileCategoryRules.single.subdirectory, 'Videos');
    });
  });

  group('Quick speed-limit dialog', () {
    late _ControlledSettingsRepository repository;
    late Settings settings;

    setUp(() async {
      repository = _ControlledSettingsRepository();
      settings = Settings(repository: repository);
      await settings.loadSettings();
    });

    testWidgets('uses global labels and guards an in-progress save', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(settings, _dialogLauncher(showQuickSpeedLimitDialog)),
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);

      await tester.tap(find.byKey(_dialogLauncherKey));
      await tester.pumpAndSettle();
      expect(find.text(l10n.maxOverallDownloadSpeed), findsOneWidget);
      expect(find.text(l10n.maxOverallUploadSpeed), findsOneWidget);

      await tester.enterText(find.byType(TextField).first, '256');
      await tester.enterText(find.byType(TextField).last, '128');
      repository.pendingSave = Completer<void>();
      final saveFinder = find.widgetWithText(FilledButton, l10n.save);
      final save = tester.widget<FilledButton>(saveFinder).onPressed!;
      save();
      save();
      await tester.pump();

      expect(tester.widget<FilledButton>(saveFinder).onPressed, isNull);
      final callsDuringFirstSave = repository.saveCalls;
      expect(callsDuringFirstSave, greaterThan(0));

      repository.pendingSave!.complete();
      await tester.pumpAndSettle();

      expect(repository.saveCalls, callsDuringFirstSave + 1);
      expect(settings.maxOverallDownloadLimit, 256);
      expect(settings.maxOverallUploadLimit, 128);
      expect(find.byType(AlertDialog), findsNothing);
    });

    testWidgets('reports persistence failures and leaves the dialog open', (
      tester,
    ) async {
      await tester.pumpWidget(
        _testApp(settings, _dialogLauncher(showQuickSpeedLimitDialog)),
      );
      await tester.pumpAndSettle();
      final l10n = _l10n(tester);

      await tester.tap(find.byKey(_dialogLauncherKey));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextField).first, '256');
      repository.nextSaveError = StateError('save failed');
      await tester.tap(find.widgetWithText(FilledButton, l10n.save));
      await tester.pump();

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text(l10n.saveSettingsFailed), findsOneWidget);
      expect(
        tester
            .widget<FilledButton>(find.widgetWithText(FilledButton, l10n.save))
            .onPressed,
        isNotNull,
      );
    });
  });
}
