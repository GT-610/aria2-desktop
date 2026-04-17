import 'package:flutter_test/flutter_test.dart';

import 'package:aria2_desktop/pages/download_page/utils/add_task_options.dart';

void main() {
  group('buildAria2TaskOptions', () {
    test('builds normalized options from dialog values', () {
      final options = buildAria2TaskOptions(
        const AddTaskOptionsData(
          outputFileName: ' file.zip ',
          split: '8',
          userAgent: ' TestAgent ',
          continueDownloads: true,
          autoFileRenaming: false,
          allowOverwrite: true,
        ),
      );

      expect(options, {
        'out': 'file.zip',
        'split': '8',
        'continue': 'true',
        'auto-file-renaming': 'false',
        'allow-overwrite': 'true',
        'user-agent': 'TestAgent',
      });
    });

    test('omits optional string options when blank', () {
      final options = buildAria2TaskOptions(
        const AddTaskOptionsData(outputFileName: '', split: '', userAgent: ''),
      );

      expect(options.containsKey('out'), isFalse);
      expect(options.containsKey('split'), isFalse);
      expect(options.containsKey('user-agent'), isFalse);
      expect(options['continue'], 'true');
      expect(options['auto-file-renaming'], 'true');
      expect(options['allow-overwrite'], 'false');
    });

    test('rejects non-positive split values', () {
      expect(
        () => buildAria2TaskOptions(const AddTaskOptionsData(split: '0')),
        throwsFormatException,
      );
      expect(
        () => buildAria2TaskOptions(const AddTaskOptionsData(split: 'abc')),
        throwsFormatException,
      );
    });
  });
}
