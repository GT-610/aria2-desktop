import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import '../models/aria2_instance.dart';
import '../utils/logging.dart';

// Custom exception classes
class ConnectionFailedException implements Exception {
  @override
  String toString() => 'Failed to connect to instance';
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

/// Aria2 RPC client service
class Aria2RpcClient with Loggable {
  static int _requestSequence = 0;
  final Aria2Instance instance;
  http.Client? _httpClient;
  WebSocket? _webSocket;
  StreamSubscription? _webSocketSubscription;
  Future<void>? _webSocketInitFuture;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  bool _isWebSocket = false;
  bool _isClosed = false;
  int _connectionGeneration = 0;

  /// Factory method to create appropriate client based on protocol
  factory Aria2RpcClient(Aria2Instance instance) {
    if (instance.protocol.startsWith('ws')) {
      return Aria2RpcClient._(instance, isWebSocket: true);
    } else {
      return Aria2RpcClient._(instance, isWebSocket: false);
    }
  }

  Aria2RpcClient._(this.instance, {required bool isWebSocket})
    : _isWebSocket = isWebSocket,
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
    try {
      final requestId = _nextRequestId();
      final requestBody = buildRequestBody(method, params, requestId);

      final client = _httpClient;
      if (client == null) throw ConnectionFailedException();
      final response = await client
          .post(
            Uri.parse(_buildRpcUrl()),
            headers: buildHttpHeaders(),
            body: jsonEncode(requestBody),
          )
          .timeout(const Duration(seconds: 10));

      // Regardless of status code, try to parse response body to check for Unauthorized error
      try {
        final data = jsonDecode(response.body);

        // Check for Unauthorized error in structured response
        if (data.containsKey('error') &&
            data['error'] is Map &&
            data['error']['message'] == 'Unauthorized') {
          throw UnauthorizedException();
        }

        if (response.statusCode == 200) {
          if (data.containsKey('error')) {
            final errorMsg = data['error'] is Map
                ? data['error']['message']
                : data['error'];
            throw Exception('RPC Error: $errorMsg');
          }
          return data;
        } else {
          throw Exception('HTTP Error: ${response.statusCode}');
        }
      } catch (e) {
        // If JSON parsing fails, check again if response body contains Unauthorized
        if (e is FormatException && response.body.contains('Unauthorized')) {
          throw UnauthorizedException();
        }
        // Re-throw other exceptions
        rethrow;
      }
    } catch (e) {
      // Timeout error indicates no response was received
      if (e is TimeoutException) {
        if (!idempotent) {
          throw RpcResultIndeterminateException(method);
        }
        throw ConnectionFailedException();
      }
      // http package wraps SocketException as ClientException
      if (e is SocketException || e is http.ClientException) {
        if (!idempotent) {
          throw RpcResultIndeterminateException(method);
        }
        throw ConnectionFailedException();
      }
      rethrow;
    }
  }

  /// WebSocket RPC implementation
  Future<Map<String, dynamic>> _callWebSocketRpc(
    String method,
    List<dynamic> params, {
    required bool idempotent,
  }) async {
    const maxRetries = 2;
    String? requestId;
    var requestWasSent = false;

    for (int attempt = 0; attempt <= maxRetries; attempt++) {
      try {
        await _initWebSocket();
        requestId = _nextRequestId();
        final requestBody = buildRequestBody(method, params, requestId);

        final completer = Completer<Map<String, dynamic>>();
        _pendingRequests[requestId] = completer;

        _webSocket!.add(jsonEncode(requestBody));
        requestWasSent = true;

        return await completer.future.timeout(const Duration(seconds: 10));
      } catch (e, stackTrace) {
        // Clean up current request from pending before rethrowing
        if (requestId != null) {
          _pendingRequests.remove(requestId);
        }
        if (requestWasSent &&
            !idempotent &&
            (e is ConnectionFailedException ||
                e is TimeoutException ||
                e is SocketException)) {
          throw RpcResultIndeterminateException(method);
        }
        if (attempt == maxRetries || _isClosed) {
          if (e is TimeoutException || e is SocketException) {
            throw ConnectionFailedException();
          }
          rethrow;
        }
        w(
          'WebSocket RPC attempt ${attempt + 1} failed for ${instance.name}, retrying',
          error: e,
          stackTrace: stackTrace,
        );
        await _webSocket?.close();
        _webSocket = null;
        // Complete pending requests with error before clearing
        for (final completer in _pendingRequests.values) {
          if (!completer.isCompleted) {
            completer.completeError(ConnectionFailedException());
          }
        }
        _pendingRequests.clear();
        requestWasSent = false;
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }
    throw ConnectionFailedException();
  }

  /// Initialize WebSocket connection
  Future<void> _initWebSocket() async {
    if (_isClosed) {
      throw ConnectionFailedException();
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
    await _webSocket?.close();
    _webSocket = null;

    final generation = _connectionGeneration;
    try {
      final socket = await WebSocket.connect(
        _buildRpcUrl(),
        headers: buildHttpHeaders(),
      ).timeout(const Duration(seconds: 10));
      if (_isClosed || generation != _connectionGeneration) {
        await socket.close();
        throw ConnectionFailedException();
      }
      _webSocket = socket;
      _webSocketSubscription?.cancel();
      _webSocketSubscription = _webSocket!.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );
    } catch (e) {
      _webSocket = null;
      throw ConnectionFailedException();
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      if (data is! Map<String, dynamic>) return;
      final requestId = data['id']?.toString();

      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        final completer = _pendingRequests[requestId]!;
        _pendingRequests.remove(requestId);

        if (data.containsKey('error')) {
          if (data['error'] is Map &&
              data['error']['message'] == 'Unauthorized') {
            completer.completeError(UnauthorizedException());
          } else {
            final errorMsg = data['error'] is Map
                ? data['error']['message']
                : data['error'];
            completer.completeError(Exception('RPC Error: $errorMsg'));
          }
        } else {
          completer.complete(data);
        }
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
  void _handleWebSocketError(dynamic error) {
    // Complete all pending requests with error
    final errorToThrow = error is ConnectionFailedException
        ? error
        : ConnectionFailedException();

    for (final Completer<Map<String, dynamic>> completer
        in _pendingRequests.values) {
      if (!completer.isCompleted) {
        completer.completeError(errorToThrow);
      }
    }
    _pendingRequests.clear();
  }

  /// Handle WebSocket connection closed
  void _handleWebSocketDone() {
    _handleWebSocketError(ConnectionFailedException());
    _webSocket = null;
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
    final response = await callRpc('aria2.changeOption', [gid, options]);
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
      final response = await callRpc('aria2.changeGlobalOption', [options]);
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
      final response = await callRpc('aria2.saveSession', []);
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
      final response = await callRpc('aria2.purgeDownloadResult', []);
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
      await _webSocket?.close();
      _webSocket = null;
      for (final completer in _pendingRequests.values) {
        if (!completer.isCompleted) {
          completer.completeError(ConnectionFailedException());
        }
      }
      _pendingRequests.clear();
    } else {
      _httpClient?.close();
      _httpClient = null;
    }
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
