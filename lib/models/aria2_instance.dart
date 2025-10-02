import 'dart:io';

/// 实例类型枚举
enum InstanceType {
  local,
  remote
}

/// Aria2实例数据模型
class Aria2Instance {
  String id;              // 唯一标识符
  String name;            // 实例名称
  InstanceType type;      // 本地或远程
  String protocol;        // HTTP/HTTPS/WS/WSS
  String host;            // 主机地址
  int port;               // 端口
  String secret;          // 密钥
  String? aria2Path;      // 本地实例的 Aria2 可执行文件路径
  String? version;        // Aria2 版本
  bool isActive;          // 是否为当前活动实例
  Process? localProcess;  // 本地进程引用

  Aria2Instance({
    required this.id,
    required this.name,
    required this.type,
    required this.protocol,
    required this.host,
    required this.port,
    this.secret = '',
    this.aria2Path,
    this.version,
    this.isActive = false,
    this.localProcess,
  });

  // 从JSON创建实例
  factory Aria2Instance.fromJson(Map<String, dynamic> json) {
    return Aria2Instance(
      id: json['id'],
      name: json['name'],
      type: InstanceType.values.byName(json['type']),
      protocol: json['protocol'],
      host: json['host'],
      port: json['port'],
      secret: json['secret'] ?? '',
      aria2Path: json['aria2Path'],
      version: json['version'],
      isActive: json['isActive'] ?? false,
    );
  }

  // 转换为JSON
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'protocol': protocol,
      'host': host,
      'port': port,
      'secret': secret,
      'aria2Path': aria2Path,
      'version': version,
      'isActive': isActive,
    };
  }

  // 获取RPC URL
  String get rpcUrl {
    return '$protocol://$host:$port/jsonrpc';
  }

  // 复制方法，用于编辑实例
  Aria2Instance copyWith({
    String? id,
    String? name,
    InstanceType? type,
    String? protocol,
    String? host,
    int? port,
    String? secret,
    String? aria2Path,
    String? version,
    bool? isActive,
    Process? localProcess,
  }) {
    return Aria2Instance(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      secret: secret ?? this.secret,
      aria2Path: aria2Path ?? this.aria2Path,
      version: version ?? this.version,
      isActive: isActive ?? this.isActive,
      localProcess: localProcess ?? this.localProcess,
    );
  }
}