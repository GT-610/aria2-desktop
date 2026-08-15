import 'dart:async';
import 'dart:convert';
import 'dart:io';

Future<void> main(List<String> arguments) async {
  final executable = _readArgument(arguments, '--executable');
  final expectedVersion = _readArgument(arguments, '--expected-version');
  final configuration = _readArgument(arguments, '--config');
  final executableFile = File(executable);
  if (!await executableFile.exists()) {
    throw StateError('Aria2 Next executable does not exist: $executable');
  }
  final configurationFile = File(configuration);
  if (!await configurationFile.exists()) {
    throw StateError('Aria2 Next configuration does not exist: $configuration');
  }

  final temporaryDirectory = await Directory.systemTemp.createTemp(
    'setsuna-aria2-next-smoke-',
  );
  final sessionFile = File(
    '${temporaryDirectory.path}${Platform.pathSeparator}aria2.session',
  );
  await sessionFile.create();
  final logFile = File(
    '${temporaryDirectory.path}${Platform.pathSeparator}aria2.log',
  );
  final port = await _reservePort();
  final secret = 'setsuna-release-smoke-test';
  final output = StringBuffer();
  final errors = StringBuffer();
  Process? process;
  StreamSubscription<String>? outputSubscription;
  StreamSubscription<String>? errorSubscription;

  try {
    process = await Process.start(
      executableFile.absolute.path,
      <String>[
        '--conf-path=${configurationFile.absolute.path}',
        '--enable-rpc=true',
        '--rpc-listen-all=false',
        '--rpc-listen-port=$port',
        '--rpc-secret=$secret',
        '--enable-dht=false',
        '--enable-dht6=false',
        '--bt-enable-lpd=false',
        '--dir=${temporaryDirectory.path}',
        '--input-file=${sessionFile.path}',
        '--save-session=${sessionFile.path}',
        '--log=${logFile.path}',
        '--log-level=warn',
        '--console-log-level=warn',
      ],
      workingDirectory: temporaryDirectory.path,
      runInShell: false,
    );
    outputSubscription = process.stdout
        .transform(utf8.decoder)
        .listen(output.write);
    errorSubscription = process.stderr
        .transform(utf8.decoder)
        .listen(errors.write);

    final client = HttpClient();
    try {
      final versionResult = await _waitForRpc(
        client: client,
        port: port,
        secret: secret,
        process: process,
      );
      final version = versionResult['version']?.toString();
      if (version != expectedVersion) {
        throw StateError(
          'Expected Aria2 Next $expectedVersion, received $version.',
        );
      }

      final statResult = await _callRpc(
        client: client,
        port: port,
        secret: secret,
        method: 'aria2.getGlobalStat',
      );
      for (final key in <String>['numActive', 'numWaiting', 'numStopped']) {
        if (!statResult.containsKey(key)) {
          throw StateError('Aria2 Next RPC response is missing $key.');
        }
      }

      await _callRpc(
        client: client,
        port: port,
        secret: secret,
        method: 'aria2.forceShutdown',
      );
    } finally {
      client.close(force: true);
    }

    final exitCode = await process.exitCode.timeout(
      const Duration(seconds: 10),
    );
    if (exitCode != 0) {
      throw StateError('Aria2 Next exited with code $exitCode.');
    }
    stdout.writeln(
      'Aria2 Next $expectedVersion passed the process and JSON-RPC smoke test.',
    );
  } catch (error) {
    stderr.writeln('Aria2 Next smoke test failed: $error');
    if (output.isNotEmpty) {
      stderr.writeln('stdout:\n$output');
    }
    if (errors.isNotEmpty) {
      stderr.writeln('stderr:\n$errors');
    }
    rethrow;
  } finally {
    final runningProcess = process;
    if (runningProcess != null) {
      runningProcess.kill();
      try {
        await runningProcess.exitCode.timeout(const Duration(seconds: 5));
      } on TimeoutException {
        stderr.writeln('Timed out while cleaning up the Aria2 Next process.');
      }
    }
    await outputSubscription?.cancel();
    await errorSubscription?.cancel();
    try {
      await temporaryDirectory.delete(recursive: true);
    } catch (error) {
      stderr.writeln(
        'Failed to remove the Aria2 Next smoke-test directory: $error',
      );
    }
  }
}

String _readArgument(List<String> arguments, String name) {
  final index = arguments.indexOf(name);
  if (index == -1 || index + 1 >= arguments.length) {
    throw ArgumentError('Missing required argument: $name');
  }
  return arguments[index + 1];
}

Future<int> _reservePort() async {
  final socket = await ServerSocket.bind(InternetAddress.loopbackIPv4, 0);
  try {
    return socket.port;
  } finally {
    await socket.close();
  }
}

Future<Map<String, Object?>> _waitForRpc({
  required HttpClient client,
  required int port,
  required String secret,
  required Process process,
}) async {
  Object? lastError;
  for (var attempt = 0; attempt < 50; attempt++) {
    try {
      return await _callRpc(
        client: client,
        port: port,
        secret: secret,
        method: 'aria2.getVersion',
      );
    } catch (error) {
      lastError = error;
      final exited = await process.exitCode
          .then((_) => true)
          .timeout(const Duration(milliseconds: 1), onTimeout: () => false);
      if (exited) {
        throw StateError('Aria2 Next exited before RPC became ready.');
      }
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
  }
  throw StateError('Aria2 Next RPC did not become ready: $lastError');
}

Future<Map<String, Object?>> _callRpc({
  required HttpClient client,
  required int port,
  required String secret,
  required String method,
}) async {
  final request = await client
      .postUrl(Uri.parse('http://127.0.0.1:$port/jsonrpc'))
      .timeout(const Duration(seconds: 2));
  request.headers.contentType = ContentType.json;
  final payload = utf8.encode(
    jsonEncode(<String, Object>{
      'jsonrpc': '2.0',
      'id': method,
      'method': method,
      'params': <String>['token:$secret'],
    }),
  );
  request.contentLength = payload.length;
  request.add(payload);
  final response = await request.close().timeout(const Duration(seconds: 2));
  final body = await utf8.decoder
      .bind(response)
      .join()
      .timeout(const Duration(seconds: 2));
  if (response.statusCode != HttpStatus.ok) {
    throw HttpException('RPC returned HTTP ${response.statusCode}: $body');
  }
  final decoded = jsonDecode(body);
  if (decoded is! Map<String, Object?>) {
    throw FormatException('RPC returned a non-object response: $body');
  }
  final rpcError = decoded['error'];
  if (rpcError != null) {
    throw StateError('RPC $method failed: $rpcError');
  }
  final result = decoded['result'];
  if (result is Map<String, Object?>) {
    return result;
  }
  if (method == 'aria2.forceShutdown' && result == 'OK') {
    return <String, Object?>{'status': result};
  }
  throw FormatException('RPC $method returned an unexpected result: $result');
}
