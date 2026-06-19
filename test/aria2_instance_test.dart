import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/aria2_instance.dart';

void main() {
  group('Aria2Instance', () {
    group('fromJson / toJson round-trip', () {
      test('round-trips all fields', () {
        final original = Aria2Instance(
          id: 'abc-123',
          name: 'My Instance',
          type: InstanceType.remote,
          protocol: 'http',
          host: '192.168.1.100',
          port: 6800,
          secret: 's3cret',
          downloadDir: '/downloads',
          rpcPath: 'jsonrpc',
          rpcRequestHeaders: 'Authorization: Bearer token',
          version: '1.37.0',
          errorMessage: null,
          status: ConnectionStatus.connected,
        );

        final json = original.toJson();
        final restored = Aria2Instance.fromJson(json);

        expect(restored.id, original.id);
        expect(restored.name, original.name);
        expect(restored.type, original.type);
        expect(restored.protocol, original.protocol);
        expect(restored.host, original.host);
        expect(restored.port, original.port);
        expect(restored.secret, original.secret);
        expect(restored.downloadDir, original.downloadDir);
        expect(restored.rpcPath, original.rpcPath);
        expect(restored.rpcRequestHeaders, original.rpcRequestHeaders);
        expect(restored.version, original.version);
        expect(restored.errorMessage, original.errorMessage);
        expect(restored.status, original.status);
      });

      test('handles missing optional fields with defaults', () {
        final json = {
          'id': 'id-1',
          'name': 'Test',
          'type': 'builtin',
          'protocol': 'ws',
          'host': 'localhost',
          'port': 16800,
        };

        final instance = Aria2Instance.fromJson(json);

        expect(instance.secret, '');
        expect(instance.downloadDir, '');
        expect(instance.rpcPath, 'jsonrpc');
        expect(instance.rpcRequestHeaders, '');
        expect(instance.version, isNull);
        expect(instance.errorMessage, isNull);
        expect(instance.status, ConnectionStatus.disconnected);
      });

      test('handles missing status field', () {
        final json = {
          'id': 'id-2',
          'name': 'Test',
          'type': 'remote',
          'protocol': 'http',
          'host': 'localhost',
          'port': 6800,
        };

        final instance = Aria2Instance.fromJson(json);
        expect(instance.status, ConnectionStatus.disconnected);
      });
    });

    group('rpcUrl', () {
      test('builds HTTP URL', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: '192.168.1.1',
          port: 6800,
        );
        expect(instance.rpcUrl, 'http://192.168.1.1:6800/jsonrpc');
      });

      test('builds WebSocket URL', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'ws',
          host: 'localhost',
          port: 16800,
        );
        expect(instance.rpcUrl, 'ws://localhost:16800/jsonrpc');
      });

      test('uses custom rpcPath', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'example.com',
          port: 8080,
          rpcPath: 'custom/rpc',
        );
        expect(instance.rpcUrl, 'http://example.com:8080/custom/rpc');
      });
    });

    group('normalizedRpcPath', () {
      test('returns jsonrpc for empty path', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcPath: '',
        );
        expect(instance.normalizedRpcPath, 'jsonrpc');
      });

      test('returns jsonrpc for whitespace-only path', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcPath: '   ',
        );
        expect(instance.normalizedRpcPath, 'jsonrpc');
      });

      test('strips leading and trailing slashes', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcPath: '/custom/rpc/',
        );
        expect(instance.normalizedRpcPath, 'custom/rpc');
      });

      test('collapses multiple slashes', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcPath: '///a///b///',
        );
        expect(instance.normalizedRpcPath, 'a/b');
      });
    });

    group('copyWith', () {
      test('copies with no changes', () {
        final original = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          secret: 'abc',
        );

        final copy = original.copyWith();

        expect(copy.id, original.id);
        expect(copy.name, original.name);
        expect(copy.secret, original.secret);
      });

      test('copies with overridden fields', () {
        final original = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
        );

        final copy = original.copyWith(
          name: 'Updated',
          port: 8080,
          secret: 'new-secret',
        );

        expect(copy.id, '1');
        expect(copy.name, 'Updated');
        expect(copy.port, 8080);
        expect(copy.secret, 'new-secret');
        expect(copy.protocol, 'http');
      });
    });

    group('toJson field types', () {
      test('serializes enum as name string', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.builtin,
          protocol: 'ws',
          host: 'localhost',
          port: 16800,
          status: ConnectionStatus.connected,
        );

        final json = instance.toJson();
        expect(json['type'], 'builtin');
        expect(json['status'], 'connected');
      });

      test('serializes null fields as null', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
        );

        final json = instance.toJson();
        expect(json['version'], isNull);
        expect(json['errorMessage'], isNull);
      });
    });
  });
}
