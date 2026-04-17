import 'dart:async';

import 'package:port_forwarder/port_forwarder.dart';

import '../utils/logging.dart';

class _PortMappingRule {
  final int port;
  final PortType protocol;
  final String description;

  const _PortMappingRule({
    required this.port,
    required this.protocol,
    required this.description,
  });

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) {
      return true;
    }
    return other is _PortMappingRule &&
        other.port == port &&
        other.protocol == protocol;
  }

  @override
  int get hashCode => Object.hash(port, protocol);
}

class BuiltinUpnpService with Loggable {
  static const Duration _discoverTimeout = Duration(seconds: 5);
  static const Duration _mappingTimeout = Duration(seconds: 3);
  static const int _maxExpandedPorts = 256;

  Gateway? _gateway;
  Set<_PortMappingRule> _mappedRules = <_PortMappingRule>{};
  Future<void> _pendingOperation = Future<void>.value();

  Future<void> syncMappings({
    required bool enabled,
    required String btListenPort,
    required int dhtListenPort,
  }) {
    _pendingOperation = _pendingOperation.catchError((Object _) {}).then((_) {
      return _syncMappings(
        enabled: enabled,
        btListenPort: btListenPort,
        dhtListenPort: dhtListenPort,
      );
    });
    return _pendingOperation;
  }

  Future<void> shutdown() {
    _pendingOperation = _pendingOperation.catchError((Object _) {}).then((_) {
      return _shutdown();
    });
    return _pendingOperation;
  }

  Future<void> _syncMappings({
    required bool enabled,
    required String btListenPort,
    required int dhtListenPort,
  }) async {
    if (!enabled) {
      await _shutdown();
      return;
    }

    final desiredRules = _buildDesiredRules(
      btListenPort: btListenPort,
      dhtListenPort: dhtListenPort,
    );

    if (desiredRules.isEmpty) {
      w('UPnP is enabled but no valid ports were resolved for mapping');
      await _shutdown();
      return;
    }

    final gateway = await _ensureGateway();
    if (gateway == null) {
      w('No compatible gateway found for UPnP/NAT-PMP port mapping');
      return;
    }

    final removedRules = _mappedRules.difference(desiredRules).toList();
    final addedRules = desiredRules.difference(_mappedRules).toList();

    if (removedRules.isNotEmpty) {
      await _unmapRules(gateway, removedRules);
    }

    if (addedRules.isNotEmpty) {
      await _mapRules(gateway, addedRules);
    }

    _mappedRules = desiredRules;
  }

  Future<void> _shutdown() async {
    if (_gateway != null && _mappedRules.isNotEmpty) {
      await _unmapRules(_gateway!, _mappedRules.toList());
    }

    _mappedRules = <_PortMappingRule>{};
    _gateway = null;
  }

  Future<Gateway?> _ensureGateway() async {
    if (_gateway != null) {
      return _gateway;
    }

    try {
      _gateway = await Gateway.discover().timeout(
        _discoverTimeout,
        onTimeout: () => null,
      );
    } catch (e, stackTrace) {
      this.w(
        'Failed to discover UPnP/NAT-PMP gateway',
        error: e,
        stackTrace: stackTrace,
      );
      _gateway = null;
    }

    return _gateway;
  }

  Set<_PortMappingRule> _buildDesiredRules({
    required String btListenPort,
    required int dhtListenPort,
  }) {
    final rules = <_PortMappingRule>{};

    for (final port in _expandPorts(btListenPort)) {
      rules.add(
        _PortMappingRule(
          port: port,
          protocol: PortType.tcp,
          description: 'Setsuna aria2 BT',
        ),
      );
    }

    if (_isValidPort(dhtListenPort)) {
      rules.add(
        _PortMappingRule(
          port: dhtListenPort,
          protocol: PortType.udp,
          description: 'Setsuna aria2 DHT',
        ),
      );
    }

    return rules;
  }

  List<int> _expandPorts(String rawPorts) {
    final ports = <int>{};
    final segments = rawPorts
        .split(',')
        .map((segment) => segment.trim())
        .where((segment) => segment.isNotEmpty);

    for (final segment in segments) {
      if (segment.contains('-')) {
        final bounds = segment.split('-').map((item) => item.trim()).toList();
        if (bounds.length != 2) {
          w('Ignoring invalid UPnP port range: $segment');
          continue;
        }

        final start = int.tryParse(bounds[0]);
        final end = int.tryParse(bounds[1]);
        if (start == null || end == null || !_isValidPort(start)) {
          w('Ignoring invalid UPnP port range: $segment');
          continue;
        }

        final normalizedStart = start <= end ? start : end;
        final normalizedEnd = start <= end ? end : start;
        if (!_isValidPort(normalizedEnd)) {
          w('Ignoring invalid UPnP port range: $segment');
          continue;
        }

        for (var port = normalizedStart; port <= normalizedEnd; port++) {
          ports.add(port);
          if (ports.length >= _maxExpandedPorts) {
            w(
              'UPnP port expansion reached the safety cap of '
              '$_maxExpandedPorts ports, truncating the rest',
            );
            return ports.toList()..sort();
          }
        }
        continue;
      }

      final port = int.tryParse(segment);
      if (port == null || !_isValidPort(port)) {
        w('Ignoring invalid UPnP port value: $segment');
        continue;
      }
      ports.add(port);
    }

    final sortedPorts = ports.toList()..sort();
    return sortedPorts;
  }

  bool _isValidPort(int port) {
    return port >= 1 && port <= 65535;
  }

  Future<void> _mapRules(Gateway gateway, List<_PortMappingRule> rules) async {
    await Future.wait(
      rules.map((rule) async {
        try {
          await gateway
              .openPort(
                protocol: rule.protocol,
                externalPort: rule.port,
                portDescription: rule.description,
              )
              .timeout(_mappingTimeout);
          i(
            'Mapped ${rule.protocol.name.toUpperCase()} port ${rule.port} via '
            'UPnP/NAT-PMP',
          );
        } catch (e, stackTrace) {
          w(
            'Failed to map ${rule.protocol.name.toUpperCase()} port '
            '${rule.port}',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }),
    );
  }

  Future<void> _unmapRules(
    Gateway gateway,
    List<_PortMappingRule> rules,
  ) async {
    await Future.wait(
      rules.map((rule) async {
        try {
          await gateway
              .closePort(protocol: rule.protocol, externalPort: rule.port)
              .timeout(_mappingTimeout);
          i(
            'Unmapped ${rule.protocol.name.toUpperCase()} port ${rule.port} '
            'from UPnP/NAT-PMP',
          );
        } catch (e, stackTrace) {
          w(
            'Failed to unmap ${rule.protocol.name.toUpperCase()} port '
            '${rule.port}',
            error: e,
            stackTrace: stackTrace,
          );
        }
      }),
    );
  }
}
