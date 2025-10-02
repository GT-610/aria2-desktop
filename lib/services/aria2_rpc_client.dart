import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:http/http.dart';
import '../models/aria2_instance.dart';

// 自定义异常类
class ConnectionFailedException implements Exception {
  @override
  String toString() => '连接实例失败';
}

class UnauthorizedException implements Exception {
  @override
  String toString() => '认证未通过';
}

/// Aria2 RPC客户端服务
class Aria2RpcClient {
  final Aria2Instance instance;
  final http.Client _client = http.Client();

  Aria2RpcClient(this.instance);

  /// 发送RPC请求
  Future<Map<String, dynamic>> callRpc(
    String method,
    List<dynamic> params,
  ) async {
    try {
      final requestId = DateTime.now().millisecondsSinceEpoch;
      
      // 构建请求体
      final requestBody = {
        'jsonrpc': '2.0',
        'id': requestId,
        'method': method,
      };

      // 如果有密钥，需要放在params的第一位
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

      // 无论状态码是什么，都尝试解析响应体以检查是否包含Unauthorized错误
      try {
        final data = jsonDecode(response.body);
        
        // 检查是否有Unauthorized错误，无论是在error字段中还是在其他地方
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
        // 如果JSON解析失败，再次检查响应体是否包含Unauthorized
        if (e is FormatException && response.body.contains('Unauthorized')) {
          throw UnauthorizedException();
        }
        // 重新抛出其他异常
        rethrow;
      }
    } catch (e) {
      // 超时错误表示未收到响应
      if (e is TimeoutException) {
        throw ConnectionFailedException();
      }
      // SocketException通常表示网络连接问题
      if (e is SocketException || e is ClientException) {
        throw ConnectionFailedException();
      }
      // 重新抛出其他异常，包括UnauthorizedException
      rethrow;
    }
  }

  /// 获取版本信息
  Future<String> getVersion() async {
    final response = await callRpc('aria2.getVersion', []);
    return response['result']['version'];
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      await getVersion();
      return true;
    } catch (e) {
      // 重新抛出异常，这样调用者可以获取具体的错误类型
      rethrow;
    }
  }

  /// 关闭连接
  void close() {
    _client.close();
  }

  /// 构建RPC URL（兼容WS/WSS协议）
  String _buildRpcUrl() {
    if (instance.protocol.startsWith('ws')) {
      return '${instance.protocol}://${instance.host}:${instance.port}/jsonrpc';
    }
    return '${instance.protocol}://${instance.host}:${instance.port}/jsonrpc';
  }
}