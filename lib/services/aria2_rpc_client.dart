import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;

import '../models/aria2_instance.dart';
import '../utils/logging.dart';

// Custom exception classes
class ConnectionFailedException implements Exception {
  const ConnectionFailedException([
    this.message = 'Failed to connect to instance',
  ]);

  final String message;

  @override
  String toString() => message;
}

class UnauthorizedException implements Exception {
  @override
  String toString() => 'Authentication failed';
}

class RpcException implements Exception {
  const RpcException(this.message, {this.code});

  final String message;
  final Object? code;

  @override
  String toString() => code == null ? message : '$message (code: $code)';
}

class RpcResultIndeterminateException extends RpcException {
  const RpcResultIndeterminateException(String method)
    : super('The result of $method is unknown because the connection closed');
}

class Aria2RpcNotification {
  const Aria2RpcNotification({required this.method, required this.params});

  final String method;
  final List<dynamic> params;

  String? get gid {
    if (params.isEmpty || params.first is! Map) {
      return null;
    }
    return (params.first as Map)['gid']?.toString();
  }
}

class _PendingRpcRequest {
  _PendingRpcRequest({required this.completer, required this.generation});

  final Completer<Map<String, dynamic>> completer;
  final int generation;
}

/// Aria2 RPC client service
class Aria2RpcClient with Loggable {
  static const Duration _defaultRequestTimeout = Duration(seconds: 10);
  static const Duration _defaultRetryDelay = Duration(milliseconds: 150);
  static const int _maximumAttempts = 3;
  static int _requestSequence = 0;

  final Aria2Instance instance;
  final Duration _requestTimeout;
  final Duration _retryDelay;
  http.Client? _httpClient;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Future<void>? _webSocketInitFuture;
  final Map<String, _PendingRpcRequest> _pendingRequests = {};
  final StreamController<Aria2RpcNotification>? _notificationController;
  final bool _isWebSocket;
  bool _isClosed = false;
  int _connectionGeneration = 0;

  Stream<Aria2RpcNotification> get notifications =>
      _notificationController?.stream ??
      const Stream<Aria2RpcNotification>.empty();

  /// Factory method to create appropriate client based on protocol
  factory Aria2RpcClient(
    Aria2Instance instance, {
    Duration requestTimeout = _defaultRequestTimeout,
    Duration retryDelay = _defaultRetryDelay,
  }) {
    return Aria2RpcClient._(
      instance,
      isWebSocket: instance.protocol.startsWith('ws'),
      requestTimeout: requestTimeout,
      retryDelay: retryDelay,
    );
  }

  Aria2RpcClient._(
    this.instance, {
    required bool isWebSocket,
    required Duration requestTimeout,
    required Duration retryDelay,
  }) : _isWebSocket = isWebSocket,
       _requestTimeout = requestTimeout,
       _retryDelay = retryDelay,
       _notificationController = isWebSocket
           ? StreamController<Aria2RpcNotification>.broadcast()
           : null,
       _httpClient = isWebSocket ? null : http.Client();

  /// Send RPC request
  Future<Map<String, dynamic>> callRpc(
    String method,
    List<dynamic> params, {
    bool idempotent = false,
  }) async {
    if (_isClosed) {
      throw ConnectionFailedException();
    }
    if (_isWebSocket) {
      return _callWebSocketRpc(method, params, idempotent: idempotent);
    } else {
      return _callHttpRpc(method, params, idempotent: idempotent);
    }
  }

  /// HTTP RPC implementation
  Future<Map<String, dynamic>> _callHttpRpc(
    String method,
    List<dynamic> params, {
    required bool idempotent,
  }) async {
    for (var attempt = 0; attempt < _maximumAttempts; attempt++) {
      final requestId = _nextRequestId();
      final requestBody = buildRequestBody(method, params, requestId);
      try {
        final client = _httpClient;
        if (client == null || _isClosed) {
          throw const ConnectionFailedException();
        }

        final response = await client
            .post(
              Uri.parse(_buildRpcUrl()),
              headers: buildHttpHeaders(),
              body: jsonEncode(requestBody),
            )
            .timeout(_requestTimeout);
        return _parseHttpResponse(response, requestId);
      } catch (error, stackTrace) {
        if (!_isTransportFailure(error)) {
          rethrow;
        }
        if (!idempotent) {
          throw RpcResultIndeterminateException(method);
        }
        if (_isClosed || attempt == _maximumAttempts - 1) {
          throw const ConnectionFailedException();
        }
        w(
          'HTTP RPC attempt ${attempt + 1} failed for ${instance.name}, '
          'retrying',
          error: error,
          stackTrace: stackTrace,
        );
        await _waitBeforeRetry(attempt);
      }
    }
    throw const ConnectionFailedException();
  }

  Map<String, dynamic> _parseHttpResponse(
    http.Response response,
    String requestId,
  ) {
    Object? decoded;
    try {
      decoded = jsonDecode(response.body);
    } on FormatException catch (error) {
      if (response.body.toLowerCase().contains('unauthorized')) {
        throw UnauthorizedException();
      }
      throw RpcException('aria2 returned invalid JSON: ${error.message}');
    }

    if (decoded is! Map) {
      throw const RpcException('aria2 returned an invalid JSON-RPC response');
    }
    final data = Map<String, dynamic>.from(decoded);
    if (_isUnauthorizedResponse(data) ||
        response.statusCode == HttpStatus.unauthorized ||
        response.statusCode == HttpStatus.forbidden) {
      throw UnauthorizedException();
    }
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw RpcException('aria2 returned HTTP ${response.statusCode}');
    }
    return _validateRpcResponse(data, requestId);
  }

  /// WebSocket RPC implementation
  Future<Map<String, dynamic>> _callWebSocketRpc(
    String method,
    List<dynamic> params, {
    required bool idempotent,
  }) async {
    for (var attempt = 0; attempt < _maximumAttempts; attempt++) {
      String? requestId;
      WebSocket? requestSocket;
      var requestGeneration = -1;
      var requestWasSent = false;
      try {
        await _initWebSocket();
        requestSocket = _webSocket;
        requestGeneration = _connectionGeneration;
        if (requestSocket == null ||
            requestSocket.readyState != WebSocket.open) {
          throw const ConnectionFailedException();
        }
        requestId = _nextRequestId();
        final requestBody = buildRequestBody(method, params, requestId);

        final completer = Completer<Map<String, dynamic>>();
        _pendingRequests[requestId] = _PendingRpcRequest(
          completer: completer,
          generation: requestGeneration,
        );

        try {
          requestSocket.add(jsonEncode(requestBody));
        } on StateError catch (error) {
          throw ConnectionFailedException(
            'Failed to send WebSocket RPC request: $error',
          );
        }
        requestWasSent = true;

        final response = await completer.future.timeout(_requestTimeout);
        return _validateRpcResponse(response, requestId);
      } catch (error, stackTrace) {
        if (requestId != null) {
          _pendingRequests.remove(requestId);
        }
        if (requestWasSent && !idempotent && _isTransportFailure(error)) {
          throw RpcResultIndeterminateException(method);
        }
        if (!_isTransportFailure(error)) {
          rethrow;
        }
        if (_isClosed || attempt == _maximumAttempts - 1) {
          throw const ConnectionFailedException();
        }
        w(
          'WebSocket RPC attempt ${attempt + 1} failed for ${instance.name}, retrying',
          error: error,
          stackTrace: stackTrace,
        );
        if (requestSocket != null && error is! TimeoutException) {
          await _invalidateWebSocket(
            requestSocket,
            requestGeneration,
            const ConnectionFailedException(),
          );
        }
        await _waitBeforeRetry(attempt);
      }
    }
    throw const ConnectionFailedException();
  }

  /// Initialize WebSocket connection
  Future<void> _initWebSocket() async {
    if (_isClosed) {
      throw const ConnectionFailedException();
    }
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      return;
    }

    final inFlightInitialization = _webSocketInitFuture;
    if (inFlightInitialization != null) {
      await inFlightInitialization;
      if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
        return;
      }
    }

    final initialization = _connectWebSocket();
    _webSocketInitFuture = initialization;
    try {
      await initialization;
    } finally {
      if (identical(_webSocketInitFuture, initialization)) {
        _webSocketInitFuture = null;
      }
    }
  }

  Future<void> _connectWebSocket() async {
    if (_isClosed) {
      throw ConnectionFailedException();
    }
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      return;
    }

    _webSocketSubscription?.cancel();
    _webSocketSubscription = null;
    await _closeWebSocket(_webSocket);
    _webSocket = null;

    final generation = ++_connectionGeneration;
    try {
      final socket = await WebSocket.connect(
        _buildRpcUrl(),
        headers: buildHttpHeaders(),
      ).timeout(_requestTimeout);
      if (_isClosed || generation != _connectionGeneration) {
        await _closeWebSocket(socket);
        throw const ConnectionFailedException();
      }
      _webSocket = socket;
      _webSocketSubscription?.cancel();
      _webSocketSubscription = socket.listen(
        (message) => _handleWebSocketMessage(socket, generation, message),
        onError: (Object error) =>
            _handleWebSocketError(socket, generation, error),
        onDone: () => _handleWebSocketDone(socket, generation),
      );
    } catch (error) {
      if (generation == _connectionGeneration) {
        _webSocket = null;
      }
      if (error is TimeoutException ||
          error is SocketException ||
          error is WebSocketException ||
          error is ConnectionFailedException) {
        throw const ConnectionFailedException();
      }
      throw ConnectionFailedException('Failed to open WebSocket: $error');
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(
    WebSocket socket,
    int generation,
    dynamic message,
  ) {
    if (!_isCurrentWebSocket(socket, generation)) {
      return;
    }
    try {
      final data = jsonDecode(message);
      if (data is! Map) return;
      final response = Map<String, dynamic>.from(data);
      final requestId = response['id']?.toString();
      if (requestId == null) {
        final method = response['method'];
        final params = response['params'];
        if (method is String && params is List) {
          _notificationController?.add(
            Aria2RpcNotification(
              method: method,
              params: List<dynamic>.from(params),
            ),
          );
        }
        return;
      }
      final pending = _pendingRequests[requestId];
      if (pending == null || pending.generation != generation) {
        return;
      }
      _pendingRequests.remove(requestId);
      if (!pending.completer.isCompleted) {
        pending.completer.complete(response);
      }
    } catch (err, stackTrace) {
      e(
        'Failed to parse WebSocket message for ${instance.name}',
        error: err,
        stackTrace: stackTrace,
      );
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(WebSocket socket, int generation, Object error) {
    unawaited(
      _invalidateWebSocket(
        socket,
        generation,
        error is ConnectionFailedException
            ? error
            : const ConnectionFailedException(),
      ),
    );
  }

  /// Handle WebSocket connection closed
  void _handleWebSocketDone(WebSocket socket, int generation) {
    unawaited(
      _invalidateWebSocket(
        socket,
        generation,
        const ConnectionFailedException(),
      ),
    );
  }

  Future<void> _invalidateWebSocket(
    WebSocket socket,
    int generation,
    Object error,
  ) async {
    if (!_isCurrentWebSocket(socket, generation)) {
      return;
    }
    _connectionGeneration++;
    _webSocket = null;
    final subscription = _webSocketSubscription;
    _webSocketSubscription = null;
    await subscription?.cancel();
    await _closeWebSocket(socket);
    _completePendingGeneration(generation, error);
  }

  Future<void> _closeWebSocket(WebSocket? socket) async {
    if (socket == null) {
      return;
    }
    try {
      await socket.close().timeout(const Duration(seconds: 1));
    } on TimeoutException {
      w('Timed out while closing WebSocket for ${instance.name}');
    } catch (error, stackTrace) {
      w(
        'Failed to close WebSocket for ${instance.name}',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  bool _isCurrentWebSocket(WebSocket socket, int generation) {
    return identical(_webSocket, socket) && generation == _connectionGeneration;
  }

  void _completePendingGeneration(int generation, Object error) {
    final requestIds = _pendingRequests.entries
        .where((entry) => entry.value.generation == generation)
        .map((entry) => entry.key)
        .toList(growable: false);
    for (final requestId in requestIds) {
      final pending = _pendingRequests.remove(requestId);
      if (pending != null && !pending.completer.isCompleted) {
        pending.completer.completeError(error);
      }
    }
  }

  bool _isTransportFailure(Object error) {
    return error is ConnectionFailedException ||
        error is TimeoutException ||
        error is SocketException ||
        error is WebSocketException ||
        error is http.ClientException;
  }

  Future<void> _waitBeforeRetry(int attempt) {
    final multiplier = 1 << attempt;
    return Future<void>.delayed(_retryDelay * multiplier);
  }

  bool _isUnauthorizedResponse(Map<String, dynamic> response) {
    final error = response['error'];
    return error is Map &&
        error['message']?.toString().toLowerCase() == 'unauthorized';
  }

  Map<String, dynamic> _validateRpcResponse(
    Map<String, dynamic> response,
    String requestId,
  ) {
    if (response['id']?.toString() != requestId) {
      throw const RpcException('aria2 returned a mismatched response id');
    }
    if (_isUnauthorizedResponse(response)) {
      throw UnauthorizedException();
    }
    final error = response['error'];
    if (error != null) {
      if (error is Map) {
        throw RpcException(
          error['message']?.toString() ?? 'Unknown aria2 RPC error',
          code: error['code'],
        );
      }
      throw RpcException(error.toString());
    }
    if (!response.containsKey('result')) {
      throw const RpcException('aria2 returned no result');
    }
    return response;
  }

  /// Get version string
  Future<String> getVersion() async {
    final info = await getVersionInfo();
    return info['version'] as String;
  }

  /// Get detailed version information, including enabled features.
  Future<Map<String, dynamic>> getVersionInfo() async {
    final response = await callRpc('aria2.getVersion', [], idempotent: true);
    return Map<String, dynamic>.from(response['result'] as Map);
  }

  /// Execute multiple RPC calls in one request
  Future<List<Map<String, dynamic>>> multicall(
    List<Map<String, dynamic>> calls, {
    bool idempotent = false,
  }) async {
    try {
      // Format: [{"methodName": "aria2.getActive", "params": [...]}, ...]
      final response = await callRpc('system.multicall', [
        calls,
      ], idempotent: idempotent);

      // Use original response for type checking directly
      if (response.containsKey('result') &&
          response['result'] is List<dynamic>) {
        final results = response['result'] as List<dynamic>;
        return results.map((item) {
          try {
            // Directly judge the content of the item without additional nesting levels
            final isSuccess = item is List<dynamic>;
            return {'success': isSuccess, 'data': item};
          } catch (e, stackTrace) {
            this.e(
              'Error processing multicall item for ${instance.name}',
              error: e,
              stackTrace: stackTrace,
            );
            return {'success': false, 'error': 'Error processing item: $e'};
          }
        }).toList();
      }
      e(
        'Received invalid multicall response format from ${instance.name}: $response',
      );
      return [];
    } catch (e, stackTrace) {
      this.e(
        'Multicall failed for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get download status information
  Future<List<Map<String, dynamic>>> getDownloadStatus() async {
    const pageSize = 100;
    const maximumTasksPerState = 10000;
    // Create multicall with three status requests using correct format
    final calls = [
      {
        "methodName": "aria2.tellActive",
        "params": instance.secret.isNotEmpty
            ? ["token:${instance.secret}"]
            : [],
      },
      {
        "methodName": "aria2.tellWaiting",
        "params": instance.secret.isNotEmpty
            ? ["token:${instance.secret}", 0, pageSize]
            : [0, pageSize],
      },
      {
        "methodName": "aria2.tellStopped",
        "params": instance.secret.isNotEmpty
            ? ["token:${instance.secret}", 0, pageSize]
            : [0, pageSize],
      },
    ];

    final firstPage = await multicall(calls, idempotent: true);
    if (firstPage.length < 3) {
      return firstPage;
    }

    final normalized = <Map<String, dynamic>>[
      _normalizeTaskMulticallResult(firstPage[0]),
      _normalizeTaskMulticallResult(firstPage[1]),
      _normalizeTaskMulticallResult(firstPage[2]),
    ];
    await _appendTaskPages(
      normalized[1],
      method: 'aria2.tellWaiting',
      pageSize: pageSize,
      maximumTasks: maximumTasksPerState,
    );
    await _appendTaskPages(
      normalized[2],
      method: 'aria2.tellStopped',
      pageSize: pageSize,
      maximumTasks: maximumTasksPerState,
    );
    return normalized;
  }

  Map<String, dynamic> _normalizeTaskMulticallResult(
    Map<String, dynamic> result,
  ) {
    if (result['success'] != true) {
      return result;
    }
    final data = result['data'];
    final tasks = data is List && data.length == 1 && data.first is List
        ? List<dynamic>.from(data.first as List)
        : data is List
        ? List<dynamic>.from(data)
        : <dynamic>[];
    return <String, dynamic>{'success': true, 'data': tasks};
  }

  Future<void> _appendTaskPages(
    Map<String, dynamic> result, {
    required String method,
    required int pageSize,
    required int maximumTasks,
  }) async {
    if (result['success'] != true || result['data'] is! List) {
      return;
    }
    final tasks = result['data'] as List<dynamic>;
    var offset = tasks.length;
    while (offset > 0 && offset % pageSize == 0 && offset < maximumTasks) {
      final response = await callRpc(method, <dynamic>[
        offset,
        pageSize,
      ], idempotent: true);
      final rawPage = response['result'];
      if (rawPage is! List || rawPage.isEmpty) {
        break;
      }
      tasks.addAll(rawPage);
      offset = tasks.length;
      if (rawPage.length < pageSize) {
        break;
      }
    }
    if (tasks.length >= maximumTasks) {
      w(
        '$method reached the safety limit of $maximumTasks tasks for ${instance.name}',
      );
    }
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      await getVersion();
      return true;
    } on ConnectionFailedException catch (e) {
      w('Connection test failed: $e');
      return false;
    } on UnauthorizedException {
      rethrow;
    } catch (err, stackTrace) {
      e(
        'Unexpected error during connection test',
        error: err,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Pause a download task
  Future<String> pauseTask(String gid) async {
    final response = await callRpc('aria2.pause', [gid]);
    return response['result'] as String; // Returns the GID of the paused task
  }

  /// Force pause a download task, mainly used for BT tasks.
  Future<String> forcePauseTask(String gid) async {
    final response = await callRpc('aria2.forcePause', [gid]);
    return response['result'] as String;
  }

  /// Resume a paused download task
  Future<String> unpauseTask(String gid) async {
    final response = await callRpc('aria2.unpause', [gid]);
    return response['result'] as String; // Returns the GID of the resumed task
  }

  /// Remove a download task
  Future<String> removeTask(String gid) async {
    final response = await callRpc('aria2.remove', [gid]);
    return response['result'] as String; // Returns the GID of the removed task
  }

  /// Remove a download result from stopped list
  /// Only works for stopped/completed tasks, not active ones
  Future<String> removeDownloadResult(String gid) async {
    final response = await callRpc('aria2.removeDownloadResult', [gid]);
    return response['result'] as String;
  }

  /// Change task options.
  Future<String> changeOption(String gid, Map<String, dynamic> options) async {
    final response = await callRpc('aria2.changeOption', [
      gid,
      options,
    ], idempotent: true);
    return response['result'] as String;
  }

  /// Get task options.
  Future<Map<String, dynamic>> getOption(String gid) async {
    final response = await callRpc('aria2.getOption', [gid], idempotent: true);
    return Map<String, dynamic>.from(response['result'] as Map);
  }

  /// Get peer information for a BT task.
  Future<List<Map<String, dynamic>>> getPeers(String gid) async {
    try {
      final response = await callRpc('aria2.getPeers', [gid], idempotent: true);
      final result = response['result'];
      if (result is! List) {
        return const [];
      }
      return result
          .whereType<Map>()
          .map((item) => Map<String, dynamic>.from(item))
          .toList();
    } on Exception catch (error) {
      if (_isNoPeerDataError(error)) {
        return const [];
      }
      rethrow;
    }
  }

  bool _isNoPeerDataError(Exception error) {
    final message = error.toString().toLowerCase();
    return message.contains('no peer data is available');
  }

  /// Add a download task with URI(s)
  Future<String> addUri(List<String> uris, Map<String, dynamic> options) async {
    // Build request parameters - [URL list, options]
    final params = [
      uris, // URL list
      options, // Download options
    ];

    // Call RPC method to send request
    final response = await callRpc('aria2.addUri', params);

    // Return task GID
    return response['result'] as String; // Returns the GID of the added task
  }

  /// Add a download task with torrent file
  Future<String> addTorrent(
    String torrentContent,
    Map<String, dynamic> options,
  ) async {
    // Build request parameters - [torrent content, uris, options]
    final params = [
      torrentContent, // Base64 encoded torrent content
      [], // List of webseed URIs (optional)
      options, // Download options
    ];

    // Call RPC method to send request
    final response = await callRpc('aria2.addTorrent', params);

    // Return task GID
    return response['result'] as String; // Returns the GID of the added task
  }

  /// Add a download task with metalink file
  Future<String> addMetalink(
    String metalinkContent,
    Map<String, dynamic> options,
  ) async {
    // Build request parameters - [metalink content, options]
    final params = [
      metalinkContent, // Base64 encoded metalink content
      options, // Download options
    ];

    // Call RPC method to send request
    final response = await callRpc('aria2.addMetalink', params);

    // Return task GID
    return response['result'] as String; // Returns the GID of the added task
  }

  /// Set global options (Aria2 global configuration)
  Future<bool> setGlobalOption(Map<String, dynamic> options) async {
    try {
      final response = await callRpc('aria2.changeGlobalOption', [
        options,
      ], idempotent: true);
      return response['result'] == 'OK';
    } catch (e, stackTrace) {
      this.e(
        'Failed to set global options for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get global options (Aria2 global configuration)
  Future<Map<String, dynamic>> getGlobalOption() async {
    try {
      final response = await callRpc(
        'aria2.getGlobalOption',
        [],
        idempotent: true,
      );
      return response['result'] as Map<String, dynamic>;
    } catch (e, stackTrace) {
      this.e(
        'Failed to get global options for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Get global status information.
  Future<Map<String, dynamic>> getGlobalStat() async {
    try {
      final response = await callRpc(
        'aria2.getGlobalStat',
        [],
        idempotent: true,
      );
      return Map<String, dynamic>.from(response['result'] as Map);
    } catch (e, stackTrace) {
      this.e(
        'Failed to get global stat for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Save the current aria2 session.
  Future<bool> saveSession() async {
    try {
      final response = await callRpc('aria2.saveSession', [], idempotent: true);
      return response['result'] == 'OK';
    } catch (e, stackTrace) {
      this.e(
        'Failed to save session for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Shut down aria2 through RPC so it can flush its session state.
  Future<bool> shutdown({bool force = false}) async {
    try {
      final response = await callRpc(
        force ? 'aria2.forceShutdown' : 'aria2.shutdown',
        [],
      );
      return response['result'] == 'OK';
    } catch (e, stackTrace) {
      this.e(
        'Failed to shut down ${instance.name} through RPC',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Purge all stopped download results from aria2.
  Future<bool> purgeDownloadResult() async {
    try {
      final response = await callRpc(
        'aria2.purgeDownloadResult',
        [],
        idempotent: true,
      );
      return response['result'] == 'OK';
    } catch (e, stackTrace) {
      this.e(
        'Failed to purge download results for ${instance.name}',
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Close connection
  Future<void> close() async {
    if (_isClosed) {
      return;
    }
    _isClosed = true;
    _connectionGeneration++;
    if (_isWebSocket) {
      _webSocketInitFuture = null;
      await _webSocketSubscription?.cancel();
      _webSocketSubscription = null;
      await _closeWebSocket(_webSocket);
      _webSocket = null;
      for (final pending in _pendingRequests.values) {
        if (!pending.completer.isCompleted) {
          pending.completer.completeError(const ConnectionFailedException());
        }
      }
      _pendingRequests.clear();
    } else {
      _httpClient?.close();
      _httpClient = null;
    }
    await _notificationController?.close();
  }

  @visibleForTesting
  Map<String, dynamic> buildRequestBody(
    String method,
    List<dynamic> params,
    String requestId,
  ) {
    Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
    };

    List<dynamic> requestParams = [];

    // Special handling for the system.multicall method
    // Because in multicall, the token is already included in the params of each sub-call
    if (method == 'system.multicall') {
      requestParams = List.from(params);
    } else {
      // For other methods, handle token normally
      if (instance.secret.isNotEmpty) {
        requestParams.add('token:${instance.secret}');
        requestParams.addAll(params);
      } else {
        requestParams = List.from(params);
      }
    }

    requestBody['params'] = requestParams;
    return requestBody;
  }

  /// Build RPC URL
  String _buildRpcUrl() {
    return instance.rpcUrl;
  }

  @visibleForTesting
  Map<String, String> buildHttpHeaders() {
    final headers = <String, String>{'Content-Type': 'application/json'};

    final rawHeaders = instance.rpcRequestHeaders.trim();
    if (rawHeaders.isEmpty) {
      return headers;
    }

    for (final line in rawHeaders.split(RegExp(r'\r?\n'))) {
      final trimmed = line.trim();
      if (trimmed.isEmpty) {
        continue;
      }

      final separatorIndex = trimmed.indexOf(':');
      if (separatorIndex <= 0) {
        continue;
      }

      final name = trimmed.substring(0, separatorIndex).trim();
      final value = trimmed.substring(separatorIndex + 1).trim();
      if (name.isEmpty || value.isEmpty) {
        continue;
      }

      headers[name] = value;
    }

    return headers;
  }

  String _nextRequestId() {
    _requestSequence++;
    return '${DateTime.now().microsecondsSinceEpoch}-${_requestSequence.toRadixString(16)}';
  }
}
