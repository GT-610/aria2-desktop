import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/settings.dart';
import 'package:setsuna/services/settings_service.dart';

import 'support/memory_settings_repository.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('builds only live aria2 options from loaded settings', () async {
    final settings = Settings(
      repository: MemorySettingsRepository(<String, dynamic>{
        'maxConcurrentDownloads': 8,
        'maxConnectionPerServer': 12,
        'split': 6,
        'continueDownloads': false,
        'downloadDir': ' C:\\Downloads\\Setsuna ',
        'maxOverallDownloadLimit': 1024,
        'maxOverallUploadLimit': 512,
        'btSaveMetadata': false,
        'btForceEncryption': true,
        'btLoadSavedMetadata': false,
        'keepSeeding': true,
        'btTracker': 'udp://tracker',
        'proxyEnabled': false,
        'allProxy': 'http://127.0.0.1:7890',
        'noProxy': 'localhost',
        'autoFileRenaming': false,
        'allowOverwrite': true,
        'userAgent': 'Setsuna Test',
      }),
    );
    await settings.loadSettings();
    final service = SettingsService()..initialize(settings);

    final options = service.convertSettingsToRuntimeAria2Options();

    expect(options['max-concurrent-downloads'], '8');
    expect(options['dir'], r'C:\Downloads\Setsuna');
    expect(options['max-overall-download-limit'], '1024K');
    expect(options['bt-save-metadata'], 'false');
    expect(options['bt-require-crypto'], 'true');
    expect(options['seed-time'], '525600');
    expect(options['seed-ratio'], '0.0');
    expect(options['all-proxy'], '');
    expect(options['no-proxy'], '');
    expect(options['auto-file-renaming'], 'false');
    expect(options['allow-overwrite'], 'true');
    expect(options, isNot(contains('bt-load-saved-metadata')));
    expect(options, isNot(contains('bt-seed-unverified')));
  });
}
