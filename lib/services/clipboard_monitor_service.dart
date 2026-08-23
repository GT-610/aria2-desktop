import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import '../utils/logging.dart';
import 'protocol_integration_service.dart';

final _logger = taggedLogger('ClipboardMonitorService');

/// Watches the clipboard for downloadable URIs and exposes them one at a
/// time through [pendingUri].
///
/// Includes the classic guards: self-copy suppression (texts the app itself
/// copied are ignored), oversized-content protection, and per-scheme
/// filtering.
class ClipboardMonitorService with Loggable {
  ClipboardMonitorService({Future<String?> Function()? readText})
    : _readText = readText ?? _readClipboardText;

  static final ClipboardMonitorService instance = ClipboardMonitorService();

  static const int schemeHttp = 1 << 0;
  static const int schemeFtp = 1 << 1;
  static const int schemeMagnet = 1 << 2;
  static const int schemeThunder = 1 << 3;
  static const int allSchemes = 0xF;

  static const Duration _pollInterval = Duration(seconds: 1);

  /// Notified whenever a new eligible URI was detected; consumers call
  /// [takePendingUri] to consume it.
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  final Future<String?> Function() _readText;
  Timer? _timer;
  int _schemes = allSchemes;
  int _generation = 0;
  String? _lastSeenContent;
  String? _pendingUri;
  final Set<String> _selfCopiedTexts = <String>{};

  static void markSelfCopied(String text) {
    instance._selfCopiedTexts.add(text);
    // Keep the suppression set bounded.
    if (instance._selfCopiedTexts.length > 32) {
      instance._selfCopiedTexts.remove(instance._selfCopiedTexts.first);
    }
  }

  void synchronize({required bool enabled, required int schemes}) {
    final nextSchemes = schemes & allSchemes;
    final schemesChanged = nextSchemes != _schemes;
    _schemes = nextSchemes;
    if (schemesChanged) {
      _lastSeenContent = null;
    }
    if (!enabled) {
      stop();
      return;
    }
    if (_timer != null) {
      if (schemesChanged) {
        unawaited(_tick());
      }
      return;
    }
    _timer = Timer.periodic(_pollInterval, (_) {
      unawaited(_tick());
    });
    unawaited(_tick());
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
    _generation++;
    _pendingUri = null;
  }

  String? takePendingUri() {
    final uri = _pendingUri;
    _pendingUri = null;
    return uri;
  }

  @visibleForTesting
  int get synchronizedSchemes => _schemes;

  @visibleForTesting
  Future<void> pollNow() => _tick();

  Future<void> _tick() async {
    final generation = _generation;
    String? content;
    try {
      content = await _readText();
    } catch (error, stackTrace) {
      w('Failed to read clipboard', error: error, stackTrace: stackTrace);
      return;
    }

    if (generation != _generation) {
      return;
    }

    if (content == null || content.isEmpty || content == _lastSeenContent) {
      return;
    }
    _lastSeenContent = content;

    // Do not reprocess content the app copied itself (e.g. copy-magnet).
    if (_selfCopiedTexts.contains(content)) {
      _selfCopiedTexts.remove(content);
      return;
    }

    // Defensive guards against pathological clipboard contents.
    if (content.length > 100000 || content.split('\n').length > 200) {
      _logger.fine('Ignored oversized clipboard content');
      return;
    }

    final uri = extractEligibleUri(content, _schemes);
    if (uri == null) {
      return;
    }

    _logger.i('Detected downloadable URI from clipboard');
    _pendingUri = uri;
    version.value++;
  }

  static Future<String?> _readClipboardText() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    return data?.text;
  }

  /// Extracts a single-line URI matching an enabled scheme. Returns null for
  /// multi-URI pastes so users keep control over bulk additions.
  @visibleForTesting
  String? extractEligibleUri(String content, int schemes) {
    final trimmed = content.trim();
    if (trimmed.isEmpty || trimmed.contains('\n')) {
      return null;
    }

    final lower = trimmed.toLowerCase();
    final isHttp = lower.startsWith('http://') || lower.startsWith('https://');
    final isFtp = lower.startsWith('ftp://') || lower.startsWith('ftps://');
    final isMagnet = lower.startsWith('magnet:?');
    final isThunder = lower.startsWith('thunder://');

    final schemeEnabled =
        (isHttp && schemes & schemeHttp != 0) ||
        (isFtp && schemes & schemeFtp != 0) ||
        (isMagnet && schemes & schemeMagnet != 0) ||
        (isThunder && schemes & schemeThunder != 0);
    if (!schemeEnabled) {
      return null;
    }

    // Validate (and decode thunder links) via the protocol integration.
    return ProtocolIntegrationService().normalizeIncomingUri(trimmed);
  }

  void dispose() {
    stop();
  }
}
