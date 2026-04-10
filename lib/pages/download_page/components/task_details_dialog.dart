import 'dart:async';

import 'package:flutter/material.dart';

import '../../../generated/l10n/l10n.dart';
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
    (String, Color) Function(BuildContext, DownloadTask, ColorScheme)
    getStatusInfo,
  ) async {
    showDialog(
      context: context,
      builder: (context) {
        Timer? refreshTimer;

        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context)!;
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
              context,
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
                  title: Text(l10n.taskDetails),
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
                          '${l10n.instance}: ${instanceNames[currentTask.instanceId] ?? currentTask.instanceId}',
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                        const SizedBox(height: 12),
                        TabBar(
                          tabs: [
                            Tab(text: l10n.overview),
                            Tab(text: l10n.pieces),
                            Tab(text: l10n.filesTitle),
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
                                    Text(l10n.taskId(currentTask.id)),
                                    const SizedBox(height: 8),
                                    Row(
                                      children: [
                                        Text(
                                          l10n.statusWithValue(statusInfo.$1),
                                          style: TextStyle(
                                            color: statusInfo.$2,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.sizeWithValue(
                                        currentTask.totalLengthBytes.toString(),
                                        currentTask.size,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.downloadedWithValue(
                                        currentTask.completedLengthBytes
                                            .toString(),
                                        currentTask.completedSize,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.progressWithValue(progressPercent),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.downloadSpeedWithValue(
                                        currentTask.downloadSpeedBytes
                                            .toString(),
                                        currentTask.downloadSpeed,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.uploadSpeedWithValue(
                                        currentTask.uploadSpeedBytes.toString(),
                                        currentTask.uploadSpeed,
                                      ),
                                    ),
                                    const SizedBox(height: 12),
                                    Text(
                                      l10n.connectionsWithValue(
                                        '${currentTask.connections ?? '--'}',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.saveLocationWithValue(
                                        currentTask.dir ?? '--',
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    Text(
                                      l10n.taskTypeWithValue(
                                        currentTask.isLocal
                                            ? l10n.builtin
                                            : l10n.remote,
                                      ),
                                    ),
                                    const SizedBox(height: 8),
                                    if (currentTask.errorMessage != null &&
                                        currentTask.errorMessage!.isNotEmpty)
                                      Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            l10n.errorWithValue(
                                              currentTask.errorMessage!,
                                            ),
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
                                        l10n.remainingTimeWithValue(
                                          TaskUtils.calculateRemainingTime(
                                            currentTask.progress,
                                            currentTask.downloadSpeed,
                                          ),
                                        ),
                                      ),
                                  ],
                                ),
                              ),
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(16),
                                child: _buildBitfieldVisualization(
                                  context,
                                  currentTask,
                                ),
                              ),
                              SingleChildScrollView(
                                padding: const EdgeInsets.all(8),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      l10n.filesTitle,
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
                                              l10n.unknownPath;
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
                                                      Text(
                                                        ' ${l10n.notSelected}',
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
                                      Text(l10n.noFileInformation),
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
                      child: Text(l10n.close),
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

  static Widget _buildBitfieldVisualization(
    BuildContext context,
    DownloadTask task,
  ) {
    final l10n = AppLocalizations.of(context)!;
    final bitfield = task.bitfield;

    if (bitfield == null || bitfield.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.info_outline, size: 64, color: Colors.grey[600]),
            const SizedBox(height: 16),
            Text(
              l10n.noPieceInformation,
              style: TextStyle(fontSize: 16, color: Colors.grey[700]),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              l10n.noPieceInformationHint,
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
                Text(
                  l10n.pieceStatistics,
                  style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16),
                ),
                const SizedBox(height: 8),
                _buildStatRow(l10n.totalPieces, '$totalPieces'),
                _buildStatRow(l10n.completed, '$completedPieces', Colors.green),
                _buildStatRow(l10n.partial, '$partialPieces', Colors.yellow),
                _buildStatRow(l10n.missing, '$missingPieces', Colors.grey),
                const SizedBox(height: 8),
                LinearProgressIndicator(
                  value: completionPercentage / 100,
                  backgroundColor: Colors.grey.shade200,
                ),
                const SizedBox(height: 4),
                Text(l10n.completion(completionPercentage.toStringAsFixed(2))),
              ],
            ),
          ),
        ),
        Text(
          l10n.pieceMap,
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
                Text(
                  l10n.legend,
                  style: TextStyle(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 8),
                _buildLegendRow(Colors.green, '${l10n.completed} (f)'),
                _buildLegendRow(Colors.lightGreen, l10n.highProgress),
                _buildLegendRow(Colors.yellow, l10n.mediumProgress),
                _buildLegendRow(Colors.orange, l10n.lowProgress),
                _buildLegendRow(Colors.grey, '${l10n.missing} (0)'),
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
