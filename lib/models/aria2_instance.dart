/// Instance type enum
enum InstanceType { remote, builtin }

/// Connection status enum
enum ConnectionStatus {
  disconnected, // Disconnected
  connecting, // Connecting
  connected, // Connected
  failed, // Connection failed
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
  String downloadDir;
  String rpcPath;
  String rpcRequestHeaders;
  String? version;
  String? errorMessage;
  ConnectionStatus status;

  Aria2Instance({
    required this.id,
    required this.name,
    required this.type,
    required this.protocol,
    required this.host,
    required this.port,
    this.secret = '',
    this.downloadDir = '',
    this.rpcPath = 'jsonrpc',
    this.rpcRequestHeaders = '',
    this.version,
    this.errorMessage,
    this.status = ConnectionStatus.disconnected,
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
      downloadDir: json['downloadDir'] ?? '',
      rpcPath: json['rpcPath'] ?? 'jsonrpc',
      rpcRequestHeaders: json['rpcRequestHeaders'] ?? '',
      version: json['version'],
      errorMessage: json['errorMessage'],
      status: json.containsKey('status')
          ? ConnectionStatus.values.byName(json['status'])
          : ConnectionStatus.disconnected,
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
      'downloadDir': downloadDir,
      'rpcPath': rpcPath,
      'rpcRequestHeaders': rpcRequestHeaders,
      'version': version,
      'errorMessage': errorMessage,
      'status': status.name,
    };
  }

  String get normalizedRpcPath {
    final trimmed = rpcPath.trim();
    if (trimmed.isEmpty) {
      return 'jsonrpc';
    }

    final segments = trimmed
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? 'jsonrpc' : segments.join('/');
  }

  // Get RPC URL
  String get rpcUrl {
    return '$protocol://$host:$port/$normalizedRpcPath';
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
    String? downloadDir,
    String? rpcPath,
    String? rpcRequestHeaders,
    String? version,
    String? errorMessage,
    ConnectionStatus? status,
  }) {
    return Aria2Instance(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      protocol: protocol ?? this.protocol,
      host: host ?? this.host,
      port: port ?? this.port,
      secret: secret ?? this.secret,
      downloadDir: downloadDir ?? this.downloadDir,
      rpcPath: rpcPath ?? this.rpcPath,
      rpcRequestHeaders: rpcRequestHeaders ?? this.rpcRequestHeaders,
      version: version ?? this.version,
      errorMessage: errorMessage ?? this.errorMessage,
      status: status ?? this.status,
    );
  }
}
