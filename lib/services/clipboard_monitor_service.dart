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
  ClipboardMonitorService();

  static final ClipboardMonitorService instance = ClipboardMonitorService();

  static const int schemeHttp = 1 << 0;
  static const int schemeFtp = 1 << 1;
  static const int schemeMagnet = 1 << 2;
  static const int schemeThunder = 1 << 3;
  static const int allSchemes = 0xF;

  /// Notified whenever a new eligible URI was detected; consumers call
  /// [takePendingUri] to consume it.
  final ValueNotifier<int> version = ValueNotifier<int>(0);

  Timer? _timer;
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
    if (!enabled) {
      stop();
      return;
    }
    if (_timer != null) {
      return;
    }
    _timer = Timer.periodic(const Duration(seconds: 1), (_) {
      unawaited(_tick(schemes));
    });
    unawaited(_tick(schemes));
  }

  void stop() {
    _timer?.cancel();
    _timer = null;
  }

  String? takePendingUri() {
    final uri = _pendingUri;
    _pendingUri = null;
    return uri;
  }

  Future<void> _tick(int schemes) async {
    String? content;
    try {
      final data = await Clipboard.getData(Clipboard.kTextPlain);
      content = data?.text;
    } catch (error, stackTrace) {
      w('Failed to read clipboard', error: error, stackTrace: stackTrace);
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

    final uri = extractEligibleUri(content, schemes);
    if (uri == null) {
      return;
    }

    _logger.i('Detected downloadable URI from clipboard');
    _pendingUri = uri;
    version.value++;
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
