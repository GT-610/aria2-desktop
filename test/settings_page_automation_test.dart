import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:provider/provider.dart';

import 'package:setsuna/generated/l10n/l10n.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/pages/settings_page/settings_page.dart';
import 'package:setsuna/services/clipboard_monitor_service.dart';
import 'package:setsuna/services/update_check_service.dart';

import 'support/memory_settings_repository.dart';

class _FailedUpdateCheckService extends UpdateCheckService {
  @override
  Future<UpdateCheckResult> checkForUpdate() async {
    return const UpdateCheckResult(status: UpdateCheckStatus.failed);
  }
}

class _PendingUpdateCheckService extends UpdateCheckService {
  final Completer<UpdateCheckResult> completer = Completer<UpdateCheckResult>();
  int calls = 0;

  @override
  Future<UpdateCheckResult> checkForUpdate() {
    calls++;
    return completer.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUp(() {
    PackageInfo.setMockInitialValues(
      appName: 'Setsuna',
      packageName: 'setsuna',
      version: '1.0.0',
      buildNumber: '1',
      buildSignature: '',
    );
  });

  Future<Settings> pumpSettingsPage(
    WidgetTester tester, {
    Map<String, dynamic>? values,
    UpdateCheckService? updateCheckService,
  }) async {
    final settings = Settings(
      repository: MemorySettingsRepository(values ?? <String, dynamic>{}),
    );
    await settings.loadSettings();
    await tester.pumpWidget(
      ChangeNotifierProvider<Settings>.value(
        value: settings,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: SettingsPage(updateCheckService: updateCheckService),
        ),
      ),
    );
    await tester.pumpAndSettle();
    return settings;
  }

  testWidgets('clipboard monitor exposes persisted scheme selectors', (
    tester,
  ) async {
    final settings = await pumpSettingsPage(
      tester,
      values: <String, dynamic>{
        'clipboardMonitorEnabled': true,
        'clipboardMonitorSchemes': ClipboardMonitorService.schemeMagnet,
      },
    );

    expect(find.widgetWithText(FilterChip, 'HTTP(S)'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'FTP'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Magnet'), findsOneWidget);
    expect(find.widgetWithText(FilterChip, 'Thunder'), findsOneWidget);

    final httpChip = find.widgetWithText(FilterChip, 'HTTP(S)');
    await tester.ensureVisible(httpChip);
    await tester.tap(httpChip);
    await tester.pumpAndSettle();

    expect(
      settings.clipboardMonitorSchemes,
      ClipboardMonitorService.schemeHttp | ClipboardMonitorService.schemeMagnet,
    );
  });

  testWidgets('failed update check shows an error instead of up-to-date', (
    tester,
  ) async {
    await pumpSettingsPage(
      tester,
      updateCheckService: _FailedUpdateCheckService(),
    );

    final checkTile = find.text('Check for updates');
    await tester.ensureVisible(checkTile);
    await tester.tap(checkTile);
    await tester.pump();

    expect(find.textContaining('Operation failed'), findsOneWidget);
    expect(find.text('You are running the latest version.'), findsNothing);
  });

  testWidgets('update check ignores a second tap while one is in flight', (
    tester,
  ) async {
    final service = _PendingUpdateCheckService();
    await pumpSettingsPage(tester, updateCheckService: service);

    final checkTile = find.text('Check for updates');
    await tester.ensureVisible(checkTile);
    await tester.tap(checkTile);
    await tester.pump();
    await tester.tap(checkTile);
    await tester.pump();

    expect(service.calls, 1);

    service.completer.complete(
      const UpdateCheckResult(status: UpdateCheckStatus.upToDate),
    );
    await tester.pumpAndSettle();
  });
}
