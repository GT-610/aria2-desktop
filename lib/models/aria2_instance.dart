import 'dart:io';

/// Instance type enum
enum InstanceType {
  local,
  remote
}

/// Connection status enum
enum ConnectionStatus {
  disconnected, // Disconnected
  connecting,   // Connecting
  connected,    // Connected
  failed        // Connection failed
}

/// Aria2 instance data model
class Aria2Instance {
  String id;
  String name;
  InstanceType type;
  String protocol;
  String host;
  int port;
  String secret;
  String? aria2Path;
  String? version;
  String? errorMessage;
  ConnectionStatus status;
  Process? localProcess;

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
    this.errorMessage,
    this.status = ConnectionStatus.disconnected,
    this.localProcess,
  });

  // Create instance from JSON
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
      errorMessage: json['errorMessage'],
      status: json.containsKey('status') ? ConnectionStatus.values.byName(json['status']) : ConnectionStatus.disconnected,
    );
  }

  // Convert to JSON
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
      'errorMessage': errorMessage,
      'status': status.name,
    };
  }

  // Get RPC URL
  String get rpcUrl {
    return '$protocol://$host:$port/jsonrpc';
  }

  // Copy method for editing instances
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
    String? errorMessage,
    ConnectionStatus? status,
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
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
      localProcess: localProcess ?? this.localProcess,
    );
  }
}