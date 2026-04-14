import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../constants/app_branding.dart';
import '../models/settings.dart';
import '../utils/logging.dart';

class ProtocolIntegrationService with Loggable {
  static final ProtocolIntegrationService _instance =
      ProtocolIntegrationService._internal();
  static const MethodChannel _channel = MethodChannel(kProtocolChannelName);

  String? _pendingLaunchUri;

  factory ProtocolIntegrationService() {
    return _instance;
  }

  ProtocolIntegrationService._internal();

  bool get isSupported => !kIsWeb && Platform.isWindows;
  bool get hasPendingLaunchUri => _pendingLaunchUri != null;

  void captureInitialArguments(List<String> args) {
    if (_pendingLaunchUri != null) {
      return;
    }

    for (final argument in args) {
      final normalizedUri = normalizeIncomingUri(argument);
      if (normalizedUri != null) {
        _pendingLaunchUri = normalizedUri;
        i('Captured external launch URI: $normalizedUri');
        return;
      }
    }
  }

  String? takePendingLaunchUri() {
    final launchUri = _pendingLaunchUri;
    _pendingLaunchUri = null;
    return launchUri;
  }

  Future<List<String>> reconcileProtocolPreferences(Settings settings) async {
    final failedSchemes = <String>[];
    final preferences = <String, bool>{
      'magnet': settings.protocolMagnetEnabled,
      'thunder': settings.protocolThunderEnabled,
    };

    for (final entry in preferences.entries) {
      try {
        await setProtocolEnabled(entry.key, entry.value);
      } catch (e, stackTrace) {
        failedSchemes.add(entry.key);
        this.w(
          'Failed to reconcile ${entry.key} protocol preference',
          error: e,
          stackTrace: stackTrace,
        );
      }
    }

    return failedSchemes;
  }

  Future<void> setProtocolEnabled(String scheme, bool enabled) async {
    if (!isSupported) {
      w('Protocol integration is not supported on this platform');
      return;
    }

    await _channel.invokeMethod<void>('setProtocolEnabled', {
      'scheme': scheme,
      'enabled': enabled,
    });
    i('Protocol ${scheme.toLowerCase()} enabled=$enabled applied');
  }

  String? normalizeIncomingUri(String rawValue) {
    final candidate = rawValue.trim();
    if (candidate.isEmpty) {
      return null;
    }

    final parsed = Uri.tryParse(candidate);
    if (parsed == null || !parsed.hasScheme) {
      return null;
    }

    switch (parsed.scheme.toLowerCase()) {
      case 'magnet':
      case 'http':
      case 'https':
      case 'ftp':
      case 'sftp':
        return candidate;
      case 'thunder':
        return _decodeThunderLink(candidate);
      default:
        return null;
    }
  }

  String? _decodeThunderLink(String link) {
    const thunderPrefix = 'thunder://';
    if (!link.toLowerCase().startsWith(thunderPrefix)) {
      return null;
    }

    try {
      final payload = link.substring(thunderPrefix.length);
      final decodedPayload = Uri.decodeComponent(payload);
      final normalizedBase64 = decodedPayload
          .replaceAll('-', '+')
          .replaceAll('_', '/');
      final paddedBase64 = _padBase64(normalizedBase64);
      final decoded = utf8.decode(base64Decode(paddedBase64)).trim();
      var normalized = decoded;
      if (normalized.startsWith('AA')) {
        normalized = normalized.substring(2);
      }
      if (normalized.endsWith('ZZ')) {
        normalized = normalized.substring(0, normalized.length - 2);
      }

      final parsed = Uri.tryParse(normalized);
      if (parsed == null || !parsed.hasScheme) {
        return null;
      }
      return normalized;
    } catch (e, stackTrace) {
      this.w('Failed to decode thunder link', error: e, stackTrace: stackTrace);
      return null;
    }
  }

  String _padBase64(String value) {
    final remainder = value.length % 4;
    if (remainder == 0) {
      return value;
    }
    return value.padRight(value.length + (4 - remainder), '=');
  }
}
