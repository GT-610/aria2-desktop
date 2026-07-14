import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:setsuna/models/aria2_instance.dart';
import 'package:setsuna/services/aria2_rpc_client.dart';

void main() {
  group('Aria2RpcClient', () {
    group('buildRequestBody', () {
      test('builds standard RPC request with token', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          secret: 'mySecret',
        );
        final client = Aria2RpcClient(instance);

        final body = client.buildRequestBody('aria2.addUri', [
          'http://example.com',
        ], 'req-1');

        expect(body['jsonrpc'], '2.0');
        expect(body['id'], 'req-1');
        expect(body['method'], 'aria2.addUri');
        expect(body['params'], ['token:mySecret', 'http://example.com']);
      });

      test('builds request without token when secret is empty', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          secret: '',
        );
        final client = Aria2RpcClient(instance);

        final body = client.buildRequestBody('aria2.getVersion', [], 'req-2');

        expect(body['params'], []);
      });

      test('builds multicall request without token injection', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          secret: 'mySecret',
        );
        final client = Aria2RpcClient(instance);

        final multicallParams = [
          {
            'methodName': 'aria2.getVersion',
            'params': ['token:mySecret'],
          },
        ];
        final body = client.buildRequestBody(
          'system.multicall',
          multicallParams,
          'req-3',
        );

        expect(body['method'], 'system.multicall');
        // Multicall params should NOT have token prepended
        expect(body['params'], multicallParams);
      });

      test('builds request with multiple params', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          secret: 'tok',
        );
        final client = Aria2RpcClient(instance);

        final body = client.buildRequestBody('aria2.changeOption', [
          'gid-123',
          {'max-download-limit': '100K'},
        ], 'req-4');

        expect(body['params'][0], 'token:tok');
        expect(body['params'][1], 'gid-123');
        expect(body['params'][2], {'max-download-limit': '100K'});
      });
    });

    group('buildHttpHeaders', () {
      test('returns Content-Type by default', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        expect(headers['Content-Type'], 'application/json');
        expect(headers.length, 1);
      });

      test('parses custom headers from newline-separated string', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcRequestHeaders: 'Authorization: Bearer token123\nX-Custom: value',
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        expect(headers['Content-Type'], 'application/json');
        expect(headers['Authorization'], 'Bearer token123');
        expect(headers['X-Custom'], 'value');
      });

      test('skips empty lines in custom headers', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcRequestHeaders: 'Authorization: Bearer token\n\n\nX-Custom: value',
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        expect(headers.length, 3); // Content-Type + 2 custom
      });

      test('skips malformed header lines (no colon)', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcRequestHeaders: 'InvalidLine\nAuthorization: Bearer token',
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        expect(headers.containsKey('InvalidLine'), isFalse);
        expect(headers['Authorization'], 'Bearer token');
      });

      test('skips headers with empty name or value', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcRequestHeaders: ': empty-name\nempty-value: ',
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        // Both should be skipped
        expect(headers.length, 1); // Only Content-Type
      });

      test('handles CRLF line endings', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
          rpcRequestHeaders: 'Authorization: Bearer token\r\nX-Custom: value',
        );
        final client = Aria2RpcClient(instance);

        final headers = client.buildHttpHeaders();

        expect(headers['Authorization'], 'Bearer token');
        expect(headers['X-Custom'], 'value');
      });
    });

    group('factory constructor', () {
      test('creates HTTP client for http protocol', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'http',
          host: 'localhost',
          port: 6800,
        );
        final client = Aria2RpcClient(instance);
        expect(client, isA<Aria2RpcClient>());
      });

      test('creates WebSocket client for ws protocol', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'ws',
          host: 'localhost',
          port: 16800,
        );
        final client = Aria2RpcClient(instance);
        expect(client, isA<Aria2RpcClient>());
      });

      test('creates WebSocket client for wss protocol', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'wss',
          host: 'localhost',
          port: 16800,
        );
        final client = Aria2RpcClient(instance);
        expect(client, isA<Aria2RpcClient>());
      });
    });

    group('close', () {
      test('close does not throw when called on fresh client', () {
        final instance = Aria2Instance(
          id: '1',
          name: 'Test',
          type: InstanceType.remote,
          protocol: 'ws',
          host: 'localhost',
          port: 16800,
        );
        final client = Aria2RpcClient(instance);
        expect(() => client.close(), returnsNormally);
      });
    });
  });

  group('Aria2RpcClient transport lifecycle', () {
    test(
      'does not retry a non-idempotent websocket request after send',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var connectionCount = 0;
        var messageCount = 0;
        server.listen((request) async {
          connectionCount++;
          final socket = await WebSocketTransformer.upgrade(request);
          socket.listen((message) async {
            messageCount++;
            await socket.close();
          });
        });
        final client = Aria2RpcClient(
          Aria2Instance(
            id: 'ws-write',
            name: 'WS',
            type: InstanceType.remote,
            protocol: 'ws',
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
          ),
        );

        await expectLater(
          client.addUri(<String>[
            'https://example.com/file',
          ], <String, dynamic>{}),
          throwsA(isA<RpcResultIndeterminateException>()),
        );
        await client.close();
        await server.close(force: true);

        expect(connectionCount, 1);
        expect(messageCount, 1);
      },
    );

    test('sends configured headers during websocket upgrade', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      String? authorization;
      server.listen((request) async {
        authorization = request.headers.value(HttpHeaders.authorizationHeader);
        final socket = await WebSocketTransformer.upgrade(request);
        socket.listen((message) {
          final decoded = jsonDecode(message as String) as Map<String, dynamic>;
          socket.add(
            jsonEncode(<String, dynamic>{
              'jsonrpc': '2.0',
              'id': decoded['id'],
              'result': <String, dynamic>{'version': '1.37.0'},
            }),
          );
        });
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'ws-headers',
          name: 'WS',
          type: InstanceType.remote,
          protocol: 'ws',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
          rpcRequestHeaders: 'Authorization: Bearer test-token',
        ),
      );

      expect(await client.getVersion(), '1.37.0');
      expect(authorization, 'Bearer test-token');

      await client.close();
      await server.close(force: true);
    });

    test('paginates waiting tasks beyond the first one hundred', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        final method = decoded['method'];
        Object result;
        if (method == 'system.multicall') {
          result = <Object>[
            <Object>[<Object>[]],
            <Object>[
              List<Object>.generate(
                100,
                (index) => <String, String>{'gid': 'waiting-$index'},
              ),
            ],
            <Object>[<Object>[]],
          ];
        } else {
          expect(method, 'aria2.tellWaiting');
          result = List<Object>.generate(
            5,
            (index) => <String, String>{'gid': 'waiting-${100 + index}'},
          );
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': decoded['id'],
            'result': result,
          }),
        );
        await request.response.close();
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'http-pages',
          name: 'HTTP',
          type: InstanceType.remote,
          protocol: 'http',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
      );

      final results = await client.getDownloadStatus();

      expect(results[1]['success'], isTrue);
      expect(results[1]['data'], hasLength(105));
      await client.close();
      await server.close(force: true);
    });
  });
}
