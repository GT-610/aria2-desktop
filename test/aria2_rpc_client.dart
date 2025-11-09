import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:aria2_desktop/utils/logging.dart';

/// Aria2 RPC通信测试程序
/// 功能：发送getVersion请求到Aria2 RPC服务并显示响应
void main() async {
  final logger = AppLogger('Aria2RpcClientTest');
  // 定义请求对象
  final request = {  
  "jsonrpc": "2.0",  
  "id": "ID",  
  "method": "aria2.addUri",  
  "params": [  
    "token:test114514",  
    ["http://example.com/file.zip"],  
    {  
      "dir": "/path/to/download",  
      "out": "filename.zip",  
      "max-connection-per-server": "16",  
      "split": "16"  
    }  
  ]  
};

  try {
    // 发送请求
    final response = await http.post(
      Uri.parse('http://127.0.0.1:6800/jsonrpc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    // 记录响应
    logger.i('状态码: ${response.statusCode}');
    
    // 解析并记录JSON响应
    final responseData = jsonDecode(response.body);
    logger.i('响应数据:');
    logger.i(jsonEncode(responseData));
    
  } catch (e) {
    // 错误处理
    logger.e('请求失败', error: e);
  }
}