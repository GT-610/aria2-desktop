import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/services/protocol_integration_service.dart';

void main() {
  group('ProtocolIntegrationService', () {
    late ProtocolIntegrationService service;

    setUp(() {
      service = ProtocolIntegrationService();
    });

    group('normalizeIncomingUri', () {
      test('returns null for empty string', () {
        expect(service.normalizeIncomingUri(''), isNull);
      });

      test('returns null for whitespace-only string', () {
        expect(service.normalizeIncomingUri('   '), isNull);
      });

      test('returns null for string without scheme', () {
        expect(service.normalizeIncomingUri('not-a-uri'), isNull);
      });

      test('accepts magnet links', () {
        const uri =
            'magnet:?xt=urn:btih:abc123&dn=test&tr=udp://tracker.example.com';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('accepts http links', () {
        const uri = 'http://example.com/file.zip';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('accepts https links', () {
        const uri = 'https://example.com/file.zip';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('accepts ftp links', () {
        const uri = 'ftp://example.com/file.zip';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('accepts sftp links', () {
        const uri = 'sftp://example.com/file.zip';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('rejects unknown schemes', () {
        expect(
          service.normalizeIncomingUri('unknown://example.com'),
          isNull,
        );
      });

      test('handles scheme case-insensitively', () {
        const uri = 'HTTP://example.com/file.zip';
        expect(service.normalizeIncomingUri(uri), uri);
      });

      test('trims whitespace from input', () {
        const uri = '  https://example.com/file.zip  ';
        expect(service.normalizeIncomingUri(uri), 'https://example.com/file.zip');
      });

      test('decodes thunder links', () {
        final thunderUri =
            'thunder://${base64Encode(utf8.encode('AAhttps://example.com/file.zipZZ'))}';
        final result = service.normalizeIncomingUri(thunderUri);
        expect(result, 'https://example.com/file.zip');
      });

      test('returns null for invalid thunder link', () {
        expect(
          service.normalizeIncomingUri('thunder://not-valid-base64!!!'),
          isNull,
        );
      });

      test('returns null for thunder link with non-uri payload', () {
        final thunderUri =
            'thunder://${base64Encode(utf8.encode('not-a-uri'))}';
        expect(service.normalizeIncomingUri(thunderUri), isNull);
      });
    });

    group('captureInitialArguments', () {
      test('captures first valid URI from arguments', () {
        service.captureInitialArguments([
          'not-a-uri',
          'https://example.com/file.zip',
          'https://example.com/other.zip',
        ]);

        expect(service.hasPendingLaunchUri, isTrue);
        expect(
          service.takePendingLaunchUri(),
          'https://example.com/file.zip',
        );
      });

      test('ignores subsequent calls after first capture', () {
        service.captureInitialArguments(['https://first.com/file.zip']);
        service.captureInitialArguments(['https://second.com/file.zip']);

        expect(
          service.takePendingLaunchUri(),
          'https://first.com/file.zip',
        );
      });

      test('returns null for takePendingLaunchUri when nothing captured', () {
        service.captureInitialArguments(['not-a-uri']);
        expect(service.takePendingLaunchUri(), isNull);
      });

      test('takePendingLaunchUri clears the captured URI', () {
        service.captureInitialArguments(['https://example.com/file.zip']);
        service.takePendingLaunchUri();
        expect(service.hasPendingLaunchUri, isFalse);
        expect(service.takePendingLaunchUri(), isNull);
      });
    });
  });
}
