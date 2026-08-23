/// Instance type enum
enum InstanceType { remote, builtin }

/// Connection status enum
enum ConnectionStatus {
  disconnected, // Disconnected
  connecting, // Connecting
  connected, // Connected
  reconnecting, // Temporarily unavailable and retrying
  failed, // Connection failed
}

const _supportedRpcProtocols = <String>{'http', 'https', 'ws', 'wss'};

class Aria2RpcEndpoint {
  const Aria2RpcEndpoint({
    required this.protocol,
    required this.host,
    required this.port,
    required this.rpcPath,
  });

  final String protocol;
  final String host;
  final int port;
  final String rpcPath;

  factory Aria2RpcEndpoint.parse({
    required String hostInput,
    required String fallbackProtocol,
    required int fallbackPort,
    required String fallbackRpcPath,
  }) {
    final input = hostInput.trim();
    if (input.isEmpty) {
      throw const FormatException('RPC host cannot be empty');
    }

    final normalizedFallbackProtocol = fallbackProtocol.trim().toLowerCase();
    _validateProtocol(normalizedFallbackProtocol);
    _validatePort(fallbackPort);

    if (input.contains('://')) {
      return _parseAbsoluteUri(
        input,
        fallbackPort: fallbackPort,
        fallbackRpcPath: fallbackRpcPath,
      );
    }

    final authority = _parseAuthority(input);
    return Aria2RpcEndpoint(
      protocol: normalizedFallbackProtocol,
      host: authority.host,
      port: authority.port ?? fallbackPort,
      rpcPath: _normalizeRpcPath(fallbackRpcPath),
    );
  }

  static Aria2RpcEndpoint _parseAbsoluteUri(
    String input, {
    required int fallbackPort,
    required String fallbackRpcPath,
  }) {
    final uri = Uri.tryParse(input);
    if (uri == null || !uri.hasScheme || uri.host.isEmpty) {
      throw const FormatException('Invalid RPC URL');
    }

    final protocol = uri.scheme.toLowerCase();
    _validateProtocol(protocol);
    if (uri.userInfo.isNotEmpty || uri.hasQuery || uri.hasFragment) {
      throw const FormatException(
        'RPC URL must not contain credentials, a query, or a fragment',
      );
    }

    final rpcPath = uri.pathSegments.isEmpty
        ? _normalizeRpcPath(fallbackRpcPath)
        : _normalizeRpcPath(uri.path);
    final resolvedPort = uri.hasPort ? uri.port : fallbackPort;
    _validatePort(resolvedPort);
    return Aria2RpcEndpoint(
      protocol: protocol,
      host: uri.host,
      port: resolvedPort,
      rpcPath: rpcPath,
    );
  }

  static ({String host, int? port}) _parseAuthority(String input) {
    if (input.contains('/') || input.contains('?') || input.contains('#')) {
      throw const FormatException('Invalid RPC host');
    }

    if (input.startsWith('[')) {
      final closingBracket = input.indexOf(']');
      if (closingBracket <= 1) {
        throw const FormatException('Invalid IPv6 RPC host');
      }
      final host = input.substring(1, closingBracket);
      final remainder = input.substring(closingBracket + 1);
      if (remainder.isEmpty) {
        return (host: host, port: null);
      }
      if (!remainder.startsWith(':')) {
        throw const FormatException('Invalid IPv6 RPC host');
      }
      return (host: host, port: _parsePort(remainder.substring(1)));
    }

    final colonCount = ':'.allMatches(input).length;
    if (colonCount == 1) {
      final separator = input.lastIndexOf(':');
      final host = input.substring(0, separator).trim();
      if (host.isEmpty) {
        throw const FormatException('RPC host cannot be empty');
      }
      return (host: host, port: _parsePort(input.substring(separator + 1)));
    }

    // An unbracketed value containing multiple colons is an IPv6 literal.
    return (host: input, port: null);
  }

  static int _parsePort(String value) {
    final port = int.tryParse(value.trim());
    if (port == null) {
      throw const FormatException('Invalid RPC port');
    }
    _validatePort(port);
    return port;
  }

  static void _validateProtocol(String protocol) {
    if (!_supportedRpcProtocols.contains(protocol)) {
      throw FormatException('Unsupported RPC protocol: $protocol');
    }
  }

  static void _validatePort(int port) {
    if (port < 1 || port > 65535) {
      throw const FormatException('RPC port must be between 1 and 65535');
    }
  }

  static String _normalizeRpcPath(String value) {
    final segments = value
        .trim()
        .split('/')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty)
        .toList();
    return segments.isEmpty ? 'jsonrpc' : segments.join('/');
  }

  String get url => Uri(
    scheme: protocol,
    host: host,
    port: port,
    pathSegments: rpcPath.split('/'),
  ).toString();
}

/// Aria2 instance data model
class Aria2Instance {
  final String id;
  final String name;
  final InstanceType type;
  final String protocol;
  final String host;
  final int port;
  final String secret;
  final String downloadDir;
  final String rpcPath;
  final String rpcRequestHeaders;
  final String? version;
  final String? errorMessage;
  final ConnectionStatus status;

  late final Aria2RpcEndpoint _rpcEndpoint = Aria2RpcEndpoint.parse(
    hostInput: host,
    fallbackProtocol: protocol,
    fallbackPort: port,
    fallbackRpcPath: rpcPath,
  );

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
    final instance = Aria2Instance(
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
    // Validate persisted connection fields at the repository boundary so a
    // malformed record can be skipped without breaking runtime polling.
    instance.rpcEndpoint;
    return instance;
  }

  Map<String, dynamic> toPersistenceJson() {
    return {
      'id': id,
      'name': name,
      'type': type.name,
      'protocol': protocol,
      'host': host,
      'port': port,
      'downloadDir': downloadDir,
      'rpcPath': rpcPath,
    };
  }

  String get connectionFingerprint => <Object>[
    id,
    rpcEndpoint.protocol,
    rpcEndpoint.host,
    rpcEndpoint.port,
    rpcEndpoint.rpcPath,
    secret,
    rpcRequestHeaders,
  ].join('\u001f');

  Aria2RpcEndpoint get rpcEndpoint => _rpcEndpoint;

  String get normalizedRpcPath {
    return rpcEndpoint.rpcPath;
  }

  // Get RPC URL
  String get rpcUrl {
    return rpcEndpoint.url;
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
