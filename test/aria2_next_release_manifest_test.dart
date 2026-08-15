import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  final manifestFile = File('tool/aria2_next_release.json');

  test('pins Aria2 Next artifacts for every desktop release target', () {
    final manifest = jsonDecode(manifestFile.readAsStringSync());
    expect(manifest, isA<Map<String, dynamic>>());
    final values = manifest as Map<String, dynamic>;
    final version = values['version'] as String;
    final assets = values['assets'] as Map<String, dynamic>;

    expect(version, matches(RegExp(r'^\d+\.\d+\.\d+$')));

    const requiredTargets = <String>{
      'windows-x64',
      'windows-arm64',
      'macos-x64',
      'macos-arm64',
      'linux-x64',
      'linux-arm64',
    };
    expect(assets.keys.toSet(), containsAll(requiredTargets));

    for (final target in requiredTargets) {
      final asset = assets[target];
      expect(asset, isA<Map<String, dynamic>>(), reason: target);
      final assetMap = asset as Map<String, dynamic>;
      expect(assetMap['file'], contains(version), reason: target);
      expect(
        assetMap['sha256'],
        matches(RegExp(r'^[0-9a-f]{64}$')),
        reason: target,
      );
    }
  });

  test('pins the engine license and matching source notice', () {
    final manifest =
        jsonDecode(manifestFile.readAsStringSync()) as Map<String, dynamic>;
    final version = manifest['version'] as String;
    final license = manifest['license'] as Map<String, dynamic>;
    final notice = File('assets/core/ARIA2_NEXT_NOTICE.txt').readAsStringSync();

    expect(license['url'], contains('/v$version/COPYING'));
    expect(license['sha256'], matches(RegExp(r'^[0-9a-f]{64}$')));
    expect(notice, contains('Aria2 Next $version'));
    expect(notice, contains('/tree/v$version'));
  });
}
