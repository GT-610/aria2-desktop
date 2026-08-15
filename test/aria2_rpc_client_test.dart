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
    test('retries an idempotent HTTP request after a timeout', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        final body = await utf8.decoder.bind(request).join();
        final decoded = jsonDecode(body) as Map<String, dynamic>;
        if (requestCount == 1) {
          await Future<void>.delayed(const Duration(milliseconds: 120));
        }
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': decoded['id'],
            'result': <String, dynamic>{'version': '1.37.0'},
          }),
        );
        await request.response.close();
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'http-retry',
          name: 'HTTP',
          type: InstanceType.remote,
          protocol: 'http',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
        requestTimeout: const Duration(milliseconds: 50),
        retryDelay: const Duration(milliseconds: 5),
      );

      expect(await client.getVersion(), '1.37.0');
      expect(requestCount, 2);

      await client.close();
      await server.close(force: true);
    });

    test(
      'supports a single WebSocket attempt for an idempotent probe',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var connectionCount = 0;
        server.listen((request) async {
          connectionCount++;
          final socket = await WebSocketTransformer.upgrade(request);
          socket.listen((_) async {
            await socket.close();
          });
        });
        final client = Aria2RpcClient(
          Aria2Instance(
            id: 'ws-probe',
            name: 'WebSocket probe',
            type: InstanceType.builtin,
            protocol: 'ws',
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
          ),
          requestTimeout: const Duration(milliseconds: 200),
          retryDelay: const Duration(milliseconds: 5),
          maximumAttempts: 1,
        );

        await expectLater(
          client.getVersion(),
          throwsA(isA<ConnectionFailedException>()),
        );
        expect(connectionCount, 1);

        await client.close();
        await server.close(force: true);
      },
    );

    test('rejects an invalid maximum attempt count', () {
      expect(
        () => Aria2RpcClient(
          Aria2Instance(
            id: 'invalid-attempts',
            name: 'Invalid attempts',
            type: InstanceType.remote,
            protocol: 'http',
            host: 'localhost',
            port: 6800,
          ),
          maximumAttempts: 0,
        ),
        throwsArgumentError,
      );
    });

    test('does not retry a non-idempotent HTTP request after send', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      var requestCount = 0;
      server.listen((request) async {
        requestCount++;
        await utf8.decoder.bind(request).join();
        await Future<void>.delayed(const Duration(milliseconds: 120));
        await request.response.close();
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'http-write',
          name: 'HTTP',
          type: InstanceType.remote,
          protocol: 'http',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
        requestTimeout: const Duration(milliseconds: 50),
        retryDelay: const Duration(milliseconds: 5),
      );

      await expectLater(
        client.addUri(<String>[
          'https://example.com/file',
        ], <String, dynamic>{}),
        throwsA(isA<RpcResultIndeterminateException>()),
      );
      expect(requestCount, 1);

      await client.close();
      await server.close(force: true);
    });

    test('rejects mismatched JSON-RPC response ids', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
        await utf8.decoder.bind(request).join();
        request.response.headers.contentType = ContentType.json;
        request.response.write(
          jsonEncode(<String, dynamic>{
            'jsonrpc': '2.0',
            'id': 'wrong-id',
            'result': <String, dynamic>{'version': '1.37.0'},
          }),
        );
        await request.response.close();
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'http-id',
          name: 'HTTP',
          type: InstanceType.remote,
          protocol: 'http',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
      );

      await expectLater(client.getVersion(), throwsA(isA<RpcException>()));

      await client.close();
      await server.close(force: true);
    });

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

    test(
      'keeps concurrent websocket requests isolated when one times out',
      () async {
        final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
        var connectionCount = 0;
        var messageCount = 0;
        server.listen((request) async {
          connectionCount++;
          final socket = await WebSocketTransformer.upgrade(request);
          socket.listen((message) {
            messageCount++;
            final sequence = messageCount;
            final decoded =
                jsonDecode(message as String) as Map<String, dynamic>;
            final delay = switch (sequence) {
              1 => const Duration(milliseconds: 360),
              2 => const Duration(milliseconds: 90),
              _ => Duration.zero,
            };
            Future<void>.delayed(delay, () {
              if (socket.readyState == WebSocket.open) {
                socket.add(
                  jsonEncode(<String, dynamic>{
                    'jsonrpc': '2.0',
                    'id': decoded['id'],
                    'result': <String, dynamic>{'version': '1.37.$sequence'},
                  }),
                );
              }
            });
          });
        });
        final client = Aria2RpcClient(
          Aria2Instance(
            id: 'ws-concurrent',
            name: 'WS',
            type: InstanceType.remote,
            protocol: 'ws',
            host: InternetAddress.loopbackIPv4.address,
            port: server.port,
          ),
          requestTimeout: const Duration(milliseconds: 210),
          retryDelay: const Duration(milliseconds: 5),
        );

        final delayedRequest = client.getVersion();
        await Future<void>.delayed(const Duration(milliseconds: 5));
        final fastRequest = client.getVersion();

        expect(await fastRequest, '1.37.2');
        expect(await delayedRequest, '1.37.3');
        expect(connectionCount, 1);
        expect(messageCount, 3);

        await client.close();
        await server.close(force: true);
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

    test('emits aria2 websocket notifications without an id', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      server.listen((request) async {
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
          socket.add(
            jsonEncode(<String, dynamic>{
              'jsonrpc': '2.0',
              'method': 'aria2.onDownloadComplete',
              'params': <Object>[
                <String, String>{'gid': 'complete-gid'},
              ],
            }),
          );
        });
      });
      final client = Aria2RpcClient(
        Aria2Instance(
          id: 'ws-events',
          name: 'WS',
          type: InstanceType.remote,
          protocol: 'ws',
          host: InternetAddress.loopbackIPv4.address,
          port: server.port,
        ),
      );
      final notification = client.notifications.first;

      expect(await client.getVersion(), '1.37.0');
      final event = await notification.timeout(const Duration(seconds: 1));
      expect(event.method, 'aria2.onDownloadComplete');
      expect(event.gid, 'complete-gid');

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
