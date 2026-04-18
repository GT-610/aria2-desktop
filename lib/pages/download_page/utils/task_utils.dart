import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../../generated/l10n/l10n.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/logging.dart';
import '../models/download_task.dart';

final _logger = taggedLogger('TaskUtils');

class TaskUtils {
  static String calculateRemainingTime(DownloadTask task) {
    return formatRemainingTime(
      totalBytes: task.totalLengthBytes,
      completedBytes: task.completedLengthBytes,
      downloadSpeedBytes: task.downloadSpeedBytes,
    );
  }

  // Open download directory
  static Future<void> openDownloadDirectory(
    BuildContext context,
    DownloadTask task,
  ) async {
    final l10n = AppLocalizations.of(context)!;
    try {
      // Check if task has download directory information
      if (task.dir == null || task.dir!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.cannotGetDownloadDirectoryInformation)),
          );
        }
        return;
      }

      String directoryPath = task.dir!;

      // Ensure path exists
      if (!Directory(directoryPath).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(l10n.downloadDirectoryDoesNotExist)),
          );
        }
        return;
      }

      // Platform-specific handling
      if (Platform.isWindows) {
        // Windows platform special handling: use explorer command
        await Process.run('explorer.exe', [directoryPath]);
      } else {
        // Non-Windows platforms use file:// protocol
        Uri uri = Uri.parse('file://$directoryPath');

        if (await canLaunchUrl(uri)) {
          await launchUrl(uri, mode: LaunchMode.externalApplication);
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text(l10n.cannotOpenDownloadDirectory)),
            );
          }
        }
      }
    } catch (e, stackTrace) {
      _logger.e(
        'Failed to open download directory for task ${task.id}',
        error: e,
        stackTrace: stackTrace,
      );
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(l10n.errorOpeningDirectory('$e'))),
        );
      }
    }
  }

  // Get instance name display
  static String getInstanceName(
    Map<String, String> instanceNames,
    String instanceId,
  ) {
    return instanceNames[instanceId] ?? 'Unknown instance';
  }
}
