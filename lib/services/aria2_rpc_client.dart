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
  final http.Client _client = http.Client();

  Aria2RpcClient(this.instance);

  /// Send RPC request
  Future<Map<String, dynamic>> callRpc(
    String method,
    List<dynamic> params,
  ) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch;
      
      // Build request body
      final requestBody = {
        'jsonrpc': '2.0',
        'id': requestId,
        'method': method,
      };

      // If there's a secret, it needs to be placed first in params
      if (instance.secret.isNotEmpty) {
        requestBody['params'] = ['token:${instance.secret}', ...params];
      } else {
        requestBody['params'] = params;
      }

      final response = await _client.post(
        Uri.parse(instance.rpcUrl),
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

  /// Get version information
  Future<String> getVersion() async {
    final response = await callRpc('aria2.getVersion', []);
    return response['result']['version'];
  }

  /// Test connection
  Future<bool> testConnection() async {
    try {
      await getVersion();
      return true;
    } catch (e) {
      // Re-throw exception so caller can get specific error type
      rethrow;
    }
  }

  /// Close connection
  void close() {
    _client.close();
  }

  /// Build RPC URL (compatible with WS/WSS protocols)
  String _buildRpcUrl() {
    if (instance.protocol.startsWith('ws')) {
      return '${instance.protocol}://${instance.host}:${instance.port}/jsonrpc';
    }
    return '${instance.protocol}://${instance.host}:${instance.port}/jsonrpc';
  }
}