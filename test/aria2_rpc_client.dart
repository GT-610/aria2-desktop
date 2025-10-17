import 'dart:convert';
import 'package:http/http.dart' as http;

/// Aria2 RPC通信测试程序
/// 功能：发送getVersion请求到Aria2 RPC服务并显示响应
void main() async {
  // 定义请求对象
  final request = {  
  "jsonrpc": "2.0",  
  "id": "qwer",  
  "method": "aria2.tellActive",  
  "params": ["token:test114514"]  
};

  try {
    // 发送请求
    final response = await http.post(
      Uri.parse('http://172.21.160.1:6800/jsonrpc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    // 打印响应
    print('状态码: ${response.statusCode}');
    print('\n');
    
    // 解析并打印JSON响应
    final responseData = jsonDecode(response.body);
    print('响应数据:');
    print(jsonEncode(responseData));
    
  } catch (e) {
    // 错误处理
    print('请求失败: $e');
  }
}