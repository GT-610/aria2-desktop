import 'dart:convert';
import 'package:http/http.dart' as http;

void main() async {
  void log(String msg) => print('[Aria2RpcClientTest] $msg');

  log('Testing Aria2 RPC communication');

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
      },
    ],
  };

  try {
    final response = await http.post(
      Uri.parse('http://localhost:6800/jsonrpc'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode(request),
    );

    log('Status code: ${response.statusCode}');
    final responseData = jsonDecode(response.body);
    log('Response data:');
    log(jsonEncode(responseData));
  } catch (e) {
    log('Request failed: $e');
  }
}
