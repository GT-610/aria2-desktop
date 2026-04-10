import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

import '../../../generated/l10n/l10n.dart';
import '../models/download_task.dart';

void _logE(String msg) => lprint('[TaskUtils] $msg');

class TaskUtils {
  static String calculateRemainingTime(double progress, String downloadSpeed) {
    // Implementation will be added later
    return '';
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
    } catch (e) {
      _logE('Error opening directory: $e');
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
