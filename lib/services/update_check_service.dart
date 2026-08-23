import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:url_launcher/url_launcher.dart';

import '../constants/github_id.dart';
import '../generated/l10n/l10n.dart';
import '../models/settings.dart';
import '../utils/logging.dart';

final _logger = taggedLogger('UpdateCheckService');

/// GitHub repository slug releases are fetched from.
const String kUpdateCheckRepo = '${GithubIds.author}/aria2-desktop';

/// Result of comparing the local app version with a release tag.
enum UpdateCheckStatus { upToDate, updateAvailable, failed, selfBuild }

class UpdateCheckResult {
  const UpdateCheckResult({
    required this.status,
    this.latestVersion,
    this.releaseUrl,
    this.releaseNotes,
  });

  final UpdateCheckStatus status;
  final String? latestVersion;
  final String? releaseUrl;
  final String? releaseNotes;

  bool get isUpdateAvailable => status == UpdateCheckStatus.updateAvailable;

  bool get isFailed => status == UpdateCheckStatus.failed;

  /// Version 0.0.0 marks a self-built binary; update checks stay disabled.
  bool get isSelfBuild => status == UpdateCheckStatus.selfBuild;
}

/// Compares dotted numeric versions; returns true when [remote] is newer.
bool isNewerVersion(String local, String remote) {
  List<int> parse(String value) => value
      .trim()
      .replaceFirst(RegExp(r'^[vV]'), '')
      .split(RegExp(r'[.+-]'))
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);

  final localParts = parse(local);
  final remoteParts = parse(remote);
  final length = localParts.length > remoteParts.length
      ? localParts.length
      : remoteParts.length;
  for (var i = 0; i < length; i++) {
    final l = i < localParts.length ? localParts[i] : 0;
    final r = i < remoteParts.length ? remoteParts[i] : 0;
    if (r != l) {
      return r > l;
    }
  }
  return false;
}

/// Checks GitHub Releases for a newer version of Setsuna.
class UpdateCheckService with Loggable {
  static const Duration _requestTimeout = Duration(seconds: 10);
  static const Duration _autoCheckInterval = Duration(days: 1);
  static Future<UpdateCheckResult>? _inFlightCheck;

  Future<UpdateCheckResult> checkForUpdate() async {
    final existing = _inFlightCheck;
    if (existing != null) {
      return existing;
    }
    final check = _performCheck();
    _inFlightCheck = check;
    try {
      return await check;
    } finally {
      if (identical(_inFlightCheck, check)) {
        _inFlightCheck = null;
      }
    }
  }

  Future<UpdateCheckResult> _performCheck() async {
    try {
      final info = await PackageInfo.fromPlatform();
      // Self-built binaries (version 0.0.0) have no comparable version;
      // update checks are disabled for them.
      if (info.version == '0.0.0') {
        return const UpdateCheckResult(status: UpdateCheckStatus.selfBuild);
      }
      final response = await http
          .get(
            Uri.parse(
              'https://api.github.com/repos/$kUpdateCheckRepo/releases/latest',
            ),
            headers: const {'Accept': 'application/vnd.github+json'},
          )
          .timeout(_requestTimeout);
      if (response.statusCode != 200) {
        return const UpdateCheckResult(status: UpdateCheckStatus.failed);
      }
      final decoded = jsonDecode(response.body);
      if (decoded is! Map<String, dynamic>) {
        return const UpdateCheckResult(status: UpdateCheckStatus.failed);
      }
      final tag = '${decoded['tag_name'] ?? ''}';
      final body = '${decoded['body'] ?? ''}';
      final htmlUrl = '${decoded['html_url'] ?? ''}';
      final available = tag.isNotEmpty && isNewerVersion(info.version, tag);

      return UpdateCheckResult(
        status: available
            ? UpdateCheckStatus.updateAvailable
            : UpdateCheckStatus.upToDate,
        latestVersion: tag.isEmpty ? null : tag.replaceFirst(RegExp(r'^v'), ''),
        releaseUrl: htmlUrl.isEmpty ? null : htmlUrl,
        releaseNotes: body.isEmpty ? null : body,
      );
    } catch (error, stackTrace) {
      _logger.w('Update check failed', error: error, stackTrace: stackTrace);
      return const UpdateCheckResult(status: UpdateCheckStatus.failed);
    }
  }

  /// Runs the daily background check; shows a dialog when an update exists.
  Future<void> autoCheckIfNeeded(
    Settings settings,
    BuildContext context,
  ) async {
    final now = DateTime.now().millisecondsSinceEpoch;
    final last = settings.lastUpdateCheckTimestamp;
    final due = last == 0 || now - last >= _autoCheckInterval.inMilliseconds;
    if (!due) {
      return;
    }
    final result = await checkForUpdate();
    if (result.isSelfBuild || result.isFailed) {
      // Never persist a timestamp for self-builds so the check stays
      // dormant, or for failures so the check can retry on next launch.
      return;
    }
    await settings.setLastUpdateCheckTimestamp(now);
    if (!context.mounted || !result.isUpdateAvailable) {
      return;
    }
    await showUpdateDialog(context, result);
  }

  Future<void> showUpdateDialog(
    BuildContext context,
    UpdateCheckResult result,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: Text(l10n.updateAvailableTitle),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(l10n.updateAvailableMessage('${result.latestVersion}')),
            if (result.releaseNotes?.isNotEmpty ?? false) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: SingleChildScrollView(child: Text(result.releaseNotes!)),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: Text(l10n.cancel),
          ),
          FilledButton(
            onPressed: () {
              final url = result.releaseUrl;
              if (url != null) {
                unawaited(
                  launchUrl(
                    Uri.parse(url),
                    mode: LaunchMode.externalApplication,
                  ),
                );
              }
              Navigator.of(dialogContext).pop();
            },
            child: Text(l10n.updateOpenReleasePage),
          ),
        ],
      ),
    );
  }
}
