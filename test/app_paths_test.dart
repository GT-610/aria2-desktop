import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:setsuna/utils/app_paths.dart';

void main() {
  test('resolves the macOS bundled core from app resources', () {
    final executableDirectory = Directory(
      p.join('Setsuna.app', 'Contents', 'MacOS'),
    );

    final coreDirectory = AppPaths.bundledCoreDirectoryFor(
      executableDirectory: executableDirectory,
      isMacOS: true,
    );

    expect(
      coreDirectory.path,
      p.normalize(
        p.join('Setsuna.app', 'Contents', 'Resources', 'data', 'core'),
      ),
    );
  });

  test('resolves other bundled cores beside the executable', () {
    final executableDirectory = Directory(p.join('release', 'bundle'));

    final coreDirectory = AppPaths.bundledCoreDirectoryFor(
      executableDirectory: executableDirectory,
      isMacOS: false,
    );

    expect(
      coreDirectory.path,
      p.normalize(p.join('release', 'bundle', 'data', 'core')),
    );
  });
}
