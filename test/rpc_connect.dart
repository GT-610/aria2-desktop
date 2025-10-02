import 'dart:convert';  
import 'dart:io';  
  
Future<void> connectToAria2() async {  
  final client = HttpClient();  
    
  try {  
    // Aria2 RPC endpoint (default port 6800)  
    final request = await client.postUrl(Uri.parse('http://localhost:6800/jsonrpc'));  
    request.headers.contentType = ContentType.json;  
      
    // JSON-RPC 2.0 request to test connection using aria2.getVersion  
    final jsonRpcRequest = {  
      'jsonrpc': '2.0',  
      'id': 'dart_client_test',  
      'method': 'aria2.getVersion',  
      'params': []  
    };  
      
    request.add(utf8.encode(json.encode(jsonRpcRequest)));  
      
    final response = await request.close();  
    final responseBody = await response.transform(utf8.decoder).join();  
      
    if (response.statusCode == 200) {  
      final responseData = json.decode(responseBody);  
        
      if (responseData['error'] == null) {  
        final version = responseData['result']['version'];  
        final enabledFeatures = responseData['result']['enabledFeatures'];  
          
        print('✅ Successfully connected to Aria2!');  
        print('   Version: $version');  
        print('   Enabled features: ${enabledFeatures.join(', ')}');  
      } else {  
        print('❌ Connection failed: ${responseData['error']['message']}');  
      }  
    } else {  
      print('❌ HTTP Error: ${response.statusCode}');  
      print('   Response: $responseBody');  
    }  
      
  } catch (e) {  
    print('❌ Failed to connect to Aria2 client: $e');  
    print('   Make sure Aria2 is running with RPC enabled:');  
    print('   aria2c --enable-rpc --rpc-listen-all');  
  } finally {  
    client.close();  
  }  
}  
  
void main() async {  
  await connectToAria2();  
}