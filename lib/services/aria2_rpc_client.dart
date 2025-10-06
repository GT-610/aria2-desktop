import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import '../models/aria2_instance.dart';

// Custom exception classes
class ConnectionFailedException implements Exception {
  @override
  String toString() => '连接实例失败';
}

class UnauthorizedException implements Exception {
  @override
  String toString() => '认证未通过';
}

/// Aria2 RPC client service
class Aria2RpcClient {
  final Aria2Instance instance;
  final http.Client? _httpClient;
  WebSocket? _webSocket;
  final Map<String, Completer<Map<String, dynamic>>> _pendingRequests = {};
  bool _isWebSocket = false;

  /// Factory method to create appropriate client based on protocol
  factory Aria2RpcClient(Aria2Instance instance) {
    if (instance.protocol.startsWith('ws')) {
      return Aria2RpcClient._(instance, isWebSocket: true);
    } else {
      return Aria2RpcClient._(instance, isWebSocket: false);
    }
  }

  Aria2RpcClient._(this.instance, {required bool isWebSocket}) : 
    _isWebSocket = isWebSocket,
    _httpClient = isWebSocket ? null : http.Client() {
    if (_isWebSocket) {
      _initWebSocket();
    }
  }

  /// Send RPC request
  Future<Map<String, dynamic>> callRpc(
    String method,
    List<dynamic> params,
  ) async {
    if (_isWebSocket) {
      return _callWebSocketRpc(method, params);
    } else {
      return _callHttpRpc(method, params);
    }
  }

  /// HTTP RPC implementation
  Future<Map<String, dynamic>> _callHttpRpc(String method, List<dynamic> params) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final requestBody = _buildRequestBody(method, params, requestId);

      final response = await _httpClient!.post(
        Uri.parse(buildRpcUrl()),
        headers: {
          'Content-Type': 'application/json',
        },
        body: jsonEncode(requestBody),
      ).timeout(const Duration(seconds: 10));

      // Regardless of status code, try to parse response body to check for Unauthorized error
      try {
        final data = jsonDecode(response.body);
        
        // Check for Unauthorized error, whether in error field or elsewhere
        if ((data.containsKey('error') && data['error']['message'] == 'Unauthorized') ||
            response.body.contains('Unauthorized')) {
          throw UnauthorizedException();
        }
        
        if (response.statusCode == 200) {
          if (data.containsKey('error')) {
            throw Exception('RPC Error: ${data['error']['message']}');
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
        throw ConnectionFailedException();
      }
      // SocketException usually indicates network connection issue
      if (e is SocketException || e is ClientException) {
        throw ConnectionFailedException();
      }
      // Re-throw other exceptions, including UnauthorizedException
      rethrow;
    }
  }

  /// WebSocket RPC implementation
  Future<Map<String, dynamic>> _callWebSocketRpc(String method, List<dynamic> params) async {
    try {
      await _initWebSocket();
      final requestId = DateTime.now().millisecondsSinceEpoch.toString();
      final requestBody = _buildRequestBody(method, params, requestId);

      final completer = Completer<Map<String, dynamic>>();
      _pendingRequests[requestId] = completer;

      _webSocket!.add(jsonEncode(requestBody));

      return await completer.future.timeout(const Duration(seconds: 10));
    } catch (e) {
      if (e is TimeoutException || e is SocketException) {
        throw ConnectionFailedException();
      }
      rethrow;
    }
  }

  /// Initialize WebSocket connection
  Future<void> _initWebSocket() async {
    if (_webSocket != null && _webSocket!.readyState == WebSocket.open) {
      return;
    }

    try {
      _webSocket = await WebSocket.connect(buildRpcUrl())
          .timeout(const Duration(seconds: 10));
      _webSocket!.listen(
        _handleWebSocketMessage,
        onError: _handleWebSocketError,
        onDone: _handleWebSocketDone,
      );
    } catch (e) {
      throw ConnectionFailedException();
    }
  }

  /// Handle WebSocket messages
  void _handleWebSocketMessage(dynamic message) {
    try {
      final data = jsonDecode(message);
      final requestId = data['id']?.toString();

      if (requestId != null && _pendingRequests.containsKey(requestId)) {
        final completer = _pendingRequests[requestId]!;
        _pendingRequests.remove(requestId);

        if (data.containsKey('error')) {
          if (data['error']['message'] == 'Unauthorized') {
            completer.completeError(UnauthorizedException());
          } else {
            completer.completeError(Exception('RPC Error: ${data['error']['message']}'));
          }
        } else {
          completer.complete(data);
        }
      }
    } catch (e) {
      // Handle parsing errors
      print('Failed to parse WebSocket message: $e');
    }
  }

  /// Handle WebSocket errors
  void _handleWebSocketError(error) {
    // Complete all pending requests with error
    final errorToThrow = error is TimeoutException || error is SocketException
        ? ConnectionFailedException()
        : error;

    for (final completer in _pendingRequests.values) {
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

  /// Get version information
  Future<String> getVersion() async {
    final response = await callRpc('aria2.getVersion', []);
    return response['result']['version'];
  }

  /// Execute multiple RPC calls in one request
  Future<List<Map<String, dynamic>>> multicall(List<List<dynamic>> calls) async {
    // Format: [["aria2.getActive", [...]], ["aria2.getWaiting", [...]], ...]
    final response = await callRpc('system.multicall', [calls]);
    
    // Process the results
    final results = response['result'] as List<dynamic>;
    return results.map((item) {
      if (item is List && item.isNotEmpty) {
        // aria2 returns results in format: [{"result": ...}] or [{"error": ...}]
        if (item[0].containsKey('result')) {
          return {'success': true, 'data': item[0]['result']};
        } else if (item[0].containsKey('error')) {
          return {'success': false, 'error': item[0]['error']};
        }
      }
      return {'success': false, 'error': 'Invalid response format'};
    }).toList();
  }

  /// Get download status information
  Future<List<Map<String, dynamic>>> getDownloadStatus() async {
    // Create multicall with three status requests
    final calls = [
      ["aria2.tellActive", []],       // Active downloads
      ["aria2.tellWaiting", [0, 100]], // Waiting downloads (first 100)
      ["aria2.tellStopped", [0, 100]]  // Stopped downloads (first 100)
    ];
    
    return await multicall(calls);
  }

  /// Get all tasks using multicall (legacy method)
  Future<Map<String, dynamic>> getTasksMulticall() async {
    final multicallParams = [
      ['aria2.tellActive'],
      ['aria2.tellWaiting', 0, 1000],
      ['aria2.tellStopped', 0, 1000]
    ];
    
    final response = await callRpc('system.multicall', [multicallParams]);
    return response;
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      await getVersion();
      return true;
    } catch (e) {
      rethrow;
    }
  }

  /// Close connection
  void close() {
    if (_isWebSocket) {
      _webSocket?.close();
      _webSocket = null;
      _pendingRequests.clear();
    } else {
      _httpClient?.close();
    }
  }

  /// Build request body
  Map<String, dynamic> _buildRequestBody(String method, List<dynamic> params, String requestId) {
    Map<String, dynamic> requestBody = {
      'jsonrpc': '2.0',
      'id': requestId,
      'method': method,
    };

    List<dynamic> requestParams = [];
    // If there's a secret, it needs to be placed first in params
    if (instance.secret.isNotEmpty) {
      requestParams.add('token:${instance.secret}');
      requestParams.addAll(params);
    } else {
      requestParams = List.from(params);
    }
    requestBody['params'] = requestParams;

    return requestBody;
  }

  /// Build RPC URL
  String buildRpcUrl() {
    return '${instance.protocol}://${instance.host}:${instance.port}/jsonrpc';
  }
}