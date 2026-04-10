import 'dart:async';

import 'package:flutter/material.dart';

import '../../../utils/format_utils.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';

class TaskDetailsDialog {
  static Future<void> showTaskDetailsDialog(
    BuildContext context,
    DownloadTask initialTask,
    List<DownloadTask> allTasks,
    Map<String, String> instanceNames,
    (String, Color) Function(DownloadTask, ColorScheme) getStatusInfo,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        Timer? refreshTimer;

        return StatefulBuilder(
          builder: (context, setState) {
            DownloadTask getLatestTaskData() {
              return allTasks.firstWhere(
                (task) =>
                    task.id == initialTask.id &&
                    task.instanceId == initialTask.instanceId,
                orElse: () => initialTask,
              );
            }

            refreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              if (context.mounted) {
                setState(() {});
              }
            });

            void disposeResources() {
              refreshTimer?.cancel();
              refreshTimer = null;
            }

            final currentTask = getLatestTaskData();
            final statusInfo = getStatusInfo(
              currentTask,
              Theme.of(context).colorScheme,
            );
            final progressPercent = (currentTask.progress * 100)
                .toStringAsFixed(2);

            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (_, _) => disposeResources(),
              child: DefaultTabController(
                length: 3,
                child: AlertDialog(
                  title: const Text('Task details'),
                  content: SizedBox(
                    width: 600,
                    height: 450,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          currentTask.name,
                          style: Theme.of(context).textTheme.titleMedium,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Instance: ${instanceNames[currentTask.instanceId] ?? currentTask.instanceId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        const TabBar(
                          tabs: [
                            Tab(text: 'Overview'),
                            Tab(text: 'Pieces'),
                            Tab(text: 'Files'),
                          ],
                          indicatorSize: TabBarIndicatorSize.tab,
                        ),
                        Expanded(
                          child: TabBarView(
                            children: [
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('Task ID: ${currentTask.id}'),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        const Text('Status: '),
                                        Text(
                                          statusInfo.$1,
                                          style: TextStyle(
                                            color: statusInfo.$2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Size: ${currentTask.size} (${currentTask.totalLengthBytes} bytes)',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Downloaded: ${currentTask.completedSize} (${currentTask.completedLengthBytes} bytes)',
                                    ),
                                    const SizedBox(height: 8),
                                    Text('Progress: $progressPercent%'),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Download speed: ${currentTask.downloadSpeed} (${currentTask.downloadSpeedBytes} bytes/s)',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Upload speed: ${currentTask.uploadSpeed} (${currentTask.uploadSpeedBytes} bytes/s)',
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      'Connections: ${currentTask.connections ?? '--'}',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Save location: ${currentTask.dir ?? '--'}',
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      'Task type: ${currentTask.isLocal ? 'Built-in' : 'Remote'}',
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentTask.errorMessage != null &&
                                        currentTask.errorMessage!.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'Error: ${currentTask.errorMessage}',
                                            style: const TextStyle(
                                              color: Colors.red,
                                            ),
                                          ),
                                          const SizedBox(height: 8),
                                        ],
                                      ),
                                    if (currentTask.status ==
                                            DownloadStatus.active &&
                                        currentTask.downloadSpeedBytes > 0)
                                      Text(
                                        'Remaining time: ${TaskUtils.calculateRemainingTime(currentTask.progress, currentTask.downloadSpeed)}',
                                      ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _buildBitfieldVisualization(currentTask),
                              ),
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text(
                                      'Files',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentTask.files != null &&
                                        currentTask.files!.isNotEmpty)
                                      ListView.builder(
                                        shrinkWrap: true,
                                        physics:
                                            const NeverScrollableScrollPhysics(),
                                        itemCount: currentTask.files!.length,
                                        itemBuilder: (context, index) {
                                          final file =
                                              currentTask.files![index];
                                          final filePath =
                                              file['path'] as String? ??
                                              'Unknown path';
                                          final fileName = filePath
                                              .split('/')
                                              .last
                                              .split('\\')
                                              .last;
                                          final fileSize = formatBytes(
                                            int.tryParse(
                                                  file['length'] as String? ??
                                                      '0',
                                                ) ??
                                                0,
                                          );
                                          final completedSize = formatBytes(
                                            int.tryParse(
                                                  file['completedLength']
                                                          as String? ??
                                                      '0',
                                                ) ??
                                                0,
                                          );
                                          final selected =
                                              (file['selected'] as String? ??
                                                  'true') ==
                                              'true';

                                          return Container(
                                            padding: const EdgeInsets.symmetric(
                                              vertical: 4,
                                            ),
                                            decoration: BoxDecoration(
                                              border: Border(
                                                bottom: BorderSide(
                                                  color: Colors.grey.shade200,
                                                ),
                                              ),
                                            ),
                                            child: Column(
                                              crossAxisAlignment:
                                                  CrossAxisAlignment.start,
                                              children: [
                                                Text(
                                                  fileName,
                                                  style: TextStyle(
                                                    fontWeight: selected
                                                        ? FontWeight.normal
                                                        : FontWeight.w300,
                                                  ),
                                                ),
                                                Row(
                                                  children: [
                                                    Text(
                                                      '$completedSize / $fileSize',
                                                    ),
                                                    if (!selected)
                                                      const Text(
                                                        ' (not selected)',
                                                        style: TextStyle(
                                                          color: Colors.grey,
                                                        ),
                                                      ),
                                                  ],
                                                ),
                                              ],
                                            ),
                                          );
                                        },
                                      )
                                    else
                                      const Text('No file information'),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        disposeResources();
                        Navigator.of(context).pop();
                      },
                      child: const Text('Close'),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  static Widget _buildBitfieldVisualization(DownloadTask task) {
    final bitfield = task.bitfield;

    if (bitfield == null || bitfield.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              'No piece information available for this task.',
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'The task may not have started yet, or Aria2 did not expose piece data.',
              style: TextStyle(fontSize: 14, color: Colors.grey[600]),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      );
    }

    final pieces = _parseHexBitfield(bitfield);
    final totalPieces = pieces.length;
    final completedPieces = pieces.where((piece) => piece == 15).length;
    final partialPieces = pieces
        .where((piece) => piece > 0 && piece < 15)
        .length;
    final missingPieces = pieces.where((piece) => piece == 0).length;
    final completionPercentage = totalPieces > 0
        ? ((completedPieces + partialPieces * 0.5) / totalPieces) * 100
        : 0.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Card(
          elevation: 2,
          margin: const EdgeInsets.only(bottom: 16),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Piece statistics',
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildStatRow('Total pieces', '$totalPieces'),
                _buildStatRow('Completed', '$completedPieces', Colors.green),
                _buildStatRow('Partial', '$partialPieces', Colors.yellow),
                _buildStatRow('Missing', '$missingPieces', Colors.grey),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 4),
                Text('Completion: ${completionPercentage.toStringAsFixed(2)}%'),
              ],
            ),
          ),
        ),
        const Text(
          'Piece map',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
        ),
        const SizedBox(height: 12),
        _buildPiecesGrid(pieces),
        const SizedBox(height: 16),
        Card(
          elevation: 1,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Legend',
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.green, 'Completed (f)'),
                _buildLegendRow(Colors.lightGreen, 'High progress (8-b)'),
                _buildLegendRow(Colors.yellow, 'Medium progress (4-7)'),
                _buildLegendRow(Colors.orange, 'Low progress (1-3)'),
                _buildLegendRow(Colors.grey, 'Missing (0)'),
              ],
            ),
          ),
        ),
      ],
    );
  }

  static Widget _buildStatRow(String label, String value, [Color? color]) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Row(
          children: [
            if (color != null) ...[
              Container(
                width: 12,
                height: 12,
                margin: const EdgeInsets.only(right: 8),
                color: color,
              ),
            ],
            Text(label),
          ],
        ),
        Text(value),
      ],
    );
  }

  static Widget _buildLegendRow(Color color, String text) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          margin: const EdgeInsets.only(right: 8),
          color: color,
        ),
        Text(text),
      ],
    );
  }

  static List<int> _parseHexBitfield(String bitfield) {
    final pieces = <int>[];
    for (var i = 0; i < bitfield.length; i++) {
      try {
        pieces.add(int.parse(bitfield[i], radix: 16));
      } catch (_) {
        pieces.add(0);
      }
    }
    return pieces;
  }

  static Widget _buildPiecesGrid(List<int> pieces) {
    final pieceSize = pieces.length > 1000
        ? 4.0
        : (pieces.length > 500 ? 6.0 : 8.0);

    return Wrap(
      spacing: 1,
      runSpacing: 1,
      children: List.generate(pieces.length, (index) {
        return Container(
          width: pieceSize,
          height: pieceSize,
          decoration: BoxDecoration(
            color: _getPieceColor(pieces[index]),
            border: Border.all(
              width: 0.5,
              color: Colors.black.withValues(alpha: 0.1),
            ),
          ),
        );
      }),
    );
  }

  static Color _getPieceColor(int pieceValue) {
    switch (pieceValue) {
      case 0:
        return Colors.grey;
      case 1:
      case 2:
      case 3:
        return Colors.orange;
      case 4:
      case 5:
      case 6:
      case 7:
        return Colors.yellow;
      case 8:
      case 9:
      case 10:
      case 11:
        return Colors.lightGreen;
      case 12:
      case 13:
      case 14:
      case 15:
        return Colors.green;
      default:
        return Colors.grey;
    }
  }
}
