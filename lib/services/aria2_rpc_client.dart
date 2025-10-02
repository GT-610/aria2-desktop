import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../models/aria2_instance.dart';

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

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        if (data.containsKey('error')) {
          throw Exception('RPC Error: ${data['error']['message']}');
        }
        return data;
      } else {
        throw Exception('HTTP Error: ${response.statusCode}');
      }
    } catch (e) {
      rethrow;
    }
  }

  /// 获取版本信息
  Future<String> getVersion() async {
    try {
      final response = await callRpc('aria2.getVersion', []);
      return response['result']['version'];
    } catch (e) {
      throw Exception('获取版本信息失败: $e');
    }
  }

  /// 测试连接
  Future<bool> testConnection() async {
    try {
      await getVersion();
      return true;
    } catch (e) {
      return false;
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