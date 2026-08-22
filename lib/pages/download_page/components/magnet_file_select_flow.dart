import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/download_data_service.dart';
import '../../../utils/format_utils.dart';
import '../../../utils/logging.dart';

final _logger = taggedLogger('MagnetFileSelectFlow');

/// Watches a magnet download added with `pause-metadata=true` and, once
/// aria2 pauses it after fetching the torrent metadata, opens a
/// file-selection dialog.
///
/// Confirming commits `select-file` and resumes the task; dismissing removes
/// the metadata task entirely so nothing is downloaded.
class MagnetFileSelectionFlow {
  static const Duration _pollInterval = Duration(seconds: 1);
  static const int _maximumPolls = 180;

  static Future<void> watchAndPrompt(
    BuildContext context,
    Aria2Instance instance,
    String gid,
  ) async {
    final downloadDataService = context.read<DownloadDataService>();
    final client = downloadDataService.clientFor(instance);

    Map<String, dynamic>? status;
    for (var poll = 0; poll < _maximumPolls; poll++) {
      await Future<void>.delayed(_pollInterval);
      if (!context.mounted) {
        return;
      }
      try {
        final candidate = await client.getTaskStatus(gid);
        final taskStatus = '${candidate['status'] ?? ''}';
        if (taskStatus == 'error' || taskStatus == 'removed') {
          return;
        }
        if (_hasMetadata(candidate) &&
            (taskStatus == 'paused' || taskStatus == 'waiting')) {
          status = candidate;
          break;
        }
      } catch (error, stackTrace) {
        _logger.w(
          'Failed to poll magnet metadata for $gid',
          error: error,
          stackTrace: stackTrace,
        );
        return;
      }
    }

    if (!context.mounted) {
      return;
    }
    if (status == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(AppLocalizations.of(context)!.metadataTimeout)),
      );
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final files = List<Map<String, dynamic>>.from(status['files'] as List);

    // Single-file torrents have nothing worth selecting; resume directly.
    if (files.where((file) => _fileIndex(file) != null).length <= 1) {
      try {
        await client.unpauseTask(gid);
      } catch (error, stackTrace) {
        _logger.w(
          'Failed to resume magnet task $gid',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    final selectedIndexes = await showDialog<List<int>>(
      context: context,
      builder: (dialogContext) =>
          MagnetFileSelectDialog(gid: gid, files: files),
    );

    if (!context.mounted) {
      return;
    }
    if (selectedIndexes == null) {
      try {
        await client.removeTask(gid);
      } catch (error, stackTrace) {
        _logger.w(
          'Failed to discard magnet task $gid',
          error: error,
          stackTrace: stackTrace,
        );
      }
      return;
    }

    try {
      await client.changeOption(gid, {
        'select-file': selectedIndexes.join(','),
      });
      await client.unpauseTask(gid);
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to apply magnet file selection for $gid',
        error: error,
        stackTrace: stackTrace,
      );
      if (!context.mounted) {
        return;
      }
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(l10n.operationFailed('$error'))));
    }
  }

  static bool _hasMetadata(Map<String, dynamic> status) {
    final bittorrent = status['bittorrent'];
    final files = status['files'];
    return bittorrent != null &&
        bittorrent.toString().isNotEmpty &&
        files is List &&
        files.isNotEmpty;
  }

  static int? _fileIndex(Map<String, dynamic> file) =>
      int.tryParse(file['index']?.toString() ?? '');
}

/// File picker shown once magnet metadata became available. Pops with the
/// selected file indexes, or null when the user cancels the download.
class MagnetFileSelectDialog extends StatefulWidget {
  const MagnetFileSelectDialog({
    super.key,
    required this.gid,
    required this.files,
  });

  final String gid;
  final List<Map<String, dynamic>> files;

  @override
  State<MagnetFileSelectDialog> createState() => _MagnetFileSelectDialogState();
}

class _MagnetFileSelectDialogState extends State<MagnetFileSelectDialog> {
  late final Map<int, bool> _selection;

  @override
  void initState() {
    super.initState();
    _selection = {
      for (final file in widget.files)
        if (MagnetFileSelectionFlow._fileIndex(file) != null)
          MagnetFileSelectionFlow._fileIndex(file)!: true,
    };
  }

  bool get _allSelected =>
      _selection.isNotEmpty && _selection.values.every((selected) => selected);

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return AlertDialog(
      title: Text(l10n.metadataReadyHint),
      content: SizedBox(
        width: 520,
        height: 380,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton(
                onPressed: () {
                  setState(() {
                    final nextValue = !_allSelected;
                    for (final key in _selection.keys.toList()) {
                      _selection[key] = nextValue;
                    }
                  });
                },
                child: Text(
                  _allSelected
                      ? l10n.allVisibleSelected
                      : l10n.selectAllVisible,
                ),
              ),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: ListView.builder(
                itemCount: widget.files.length,
                itemBuilder: (context, index) {
                  final file = widget.files[index];
                  final fileIndex =
                      MagnetFileSelectionFlow._fileIndex(file) ?? index + 1;
                  final path = '${file['path'] ?? ''}';
                  final fileName = path.split('/').last.split('\\').last;
                  final size = formatBytes(
                    int.tryParse('${file['length'] ?? '0'}') ?? 0,
                  );
                  return CheckboxListTile(
                    value: _selection[fileIndex] ?? true,
                    onChanged: (value) {
                      setState(() => _selection[fileIndex] = value ?? false);
                    },
                    controlAffinity: ListTileControlAffinity.leading,
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    title: Text(fileName, overflow: TextOverflow.ellipsis),
                    subtitle: Text(size),
                  );
                },
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context, null),
          child: Text(l10n.cancel),
        ),
        FilledButton(
          onPressed: !_selection.values.any((selected) => selected)
              ? null
              : () {
                  final selectedIndexes =
                      _selection.entries
                          .where((entry) => entry.value)
                          .map((entry) => entry.key)
                          .toList()
                        ..sort();
                  Navigator.pop(context, selectedIndexes);
                },
          child: Text(l10n.save),
        ),
      ],
    );
  }
}
