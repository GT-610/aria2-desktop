import 'package:fl_lib/fl_lib.dart';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'dart:io';

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
    try {
      // Check if task has download directory information
      if (task.dir == null || task.dir!.isEmpty) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Cannot get download directory information'),
            ),
          );
        }
        return;
      }

      String directoryPath = task.dir!;

      // Ensure path exists
      if (!Directory(directoryPath).existsSync()) {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Download directory does not exist')),
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
              const SnackBar(content: Text('Cannot open download directory')),
            );
          }
        }
      }
    } catch (e) {
      _logE('Error opening directory: $e');
      if (context.mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text('Error opening directory: $e')));
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
