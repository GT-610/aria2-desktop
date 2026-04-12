import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/aria2_rpc_client.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/format_utils.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../utils/task_utils.dart';

class TaskDetailsDialog {
  static Future<void> showTaskDetailsDialog(
    BuildContext context,
    DownloadTask initialTask,
    List<DownloadTask> Function() getAllTasks,
    Map<String, String> instanceNames,
    (String, Color) Function(BuildContext, DownloadTask, ColorScheme)
    getStatusInfo, {
    VoidCallback? onTaskUpdated,
  }) async {
    final outerContext = context;

    showDialog(
      context: outerContext,
      builder: (context) {
        Timer? refreshTimer;
        var hasFileSelectionChanges = false;
        var isSavingFileSelection = false;
        String? fileSelectionSourceSignature;
        Map<int, bool> fileSelection = <int, bool>{};
        TabController? activeTabController;
        VoidCallback? activeTabListener;
        Future<void> Function({bool force})? requestPeersIfNeeded;
        var currentTabIndex = 0;
        var peersTaskKey = '';
        String? peersClientKey;
        Aria2RpcClient? peersClient;
        var isLoadingPeers = false;
        DateTime? lastPeersFetchTime;
        String? peersError;
        List<Map<String, dynamic>> peers = <Map<String, dynamic>>[];

        String buildFileSelectionSignature(List<Map<String, dynamic>> files) {
          return files
              .map(
                (file) =>
                    '${file['index'] ?? ''}:${file['selected'] as String? ?? 'true'}',
              )
              .join('|');
        }

        Map<int, bool> buildFileSelectionState(
          List<Map<String, dynamic>> files,
        ) {
          final result = <int, bool>{};
          for (final file in files) {
            final index = int.tryParse(file['index']?.toString() ?? '');
            if (index == null) {
              continue;
            }
            result[index] = (file['selected'] as String? ?? 'true') == 'true';
          }
          return result;
        }

        return StatefulBuilder(
          builder: (context, setState) {
            final l10n = AppLocalizations.of(context)!;
            DownloadTask getLatestTaskData() {
              final allTasks = getAllTasks();
              return allTasks.firstWhere(
                (task) =>
                    task.id == initialTask.id &&
                    task.instanceId == initialTask.instanceId,
                orElse: () => initialTask,
              );
            }

            void disposeResources() {
              refreshTimer?.cancel();
              refreshTimer = null;
              if (activeTabController != null && activeTabListener != null) {
                activeTabController!.removeListener(activeTabListener!);
              }
              activeTabController = null;
              activeTabListener = null;
              requestPeersIfNeeded = null;
              peersClient?.close();
              peersClient = null;
              peersClientKey = null;
            }

            final currentTask = getLatestTaskData();
            final currentFiles = List<Map<String, dynamic>>.from(
              currentTask.files ?? const <Map<String, dynamic>>[],
            );
            final isBtTask =
                (currentTask.trackers?.isNotEmpty ?? false) ||
                currentTask.bittorrentInfo != null;
            final currentSignature = buildFileSelectionSignature(currentFiles);
            if (fileSelectionSourceSignature != currentSignature &&
                !hasFileSelectionChanges) {
              fileSelection = buildFileSelectionState(currentFiles);
              fileSelectionSourceSignature = currentSignature;
            }
            final overviewTab = Tab(text: l10n.overview);
            final piecesTab = Tab(text: l10n.pieces);
            final filesTab = Tab(text: l10n.filesTitle);
            final tabs = <Tab>[
              overviewTab,
              piecesTab,
              filesTab,
              if (isBtTask) Tab(text: l10n.trackers),
              if (isBtTask) Tab(text: l10n.peers),
            ];
            refreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              unawaited(requestPeersIfNeeded?.call() ?? Future.value());
              if (context.mounted) {
                setState(() {});
              }
            });
            final allFilesSelected =
                currentFiles.isNotEmpty &&
                currentFiles.every((file) {
                  final fileIndex = int.tryParse(file['index'].toString());
                  if (fileIndex == null) {
                    return (file['selected'] as String? ?? 'true') == 'true';
                  }
                  return fileSelection[fileIndex] ??
                      ((file['selected'] as String? ?? 'true') == 'true');
                });

            final statusInfo = getStatusInfo(
              context,
              currentTask,
              Theme.of(context).colorScheme,
            );
            final progressPercent = (currentTask.progress * 100)
                .toStringAsFixed(2);
            final taskDisplayName = currentTask.name.trim().isEmpty
                ? currentTask.id
                : currentTask.name;
            final saveLocation =
                currentTask.dir == null || currentTask.dir!.trim().isEmpty
                ? l10n.unknownPath
                : currentTask.dir!;

            return PopScope(
              canPop: true,
              onPopInvokedWithResult: (_, _) => disposeResources(),
              child: DefaultTabController(
                length: tabs.length,
                child: Builder(
                  builder: (tabContext) {
                    final tabController = DefaultTabController.of(tabContext);
                    currentTabIndex = tabController.index;

                    Future<void> fetchPeersIfNeeded({
                      bool force = false,
                    }) async {
                      if (!isBtTask ||
                          currentTabIndex < 0 ||
                          currentTabIndex >= tabs.length ||
                          tabs[currentTabIndex].text != l10n.peers) {
                        return;
                      }

                      final taskKey =
                          '${currentTask.instanceId}:${currentTask.id}';
                      if (isLoadingPeers) {
                        return;
                      }

                      if (peersTaskKey != taskKey) {
                        peers = <Map<String, dynamic>>[];
                        peersError = null;
                        peersTaskKey = taskKey;
                      }

                      final now = DateTime.now();
                      if (!force &&
                          lastPeersFetchTime != null &&
                          now.difference(lastPeersFetchTime!) <
                              const Duration(seconds: 1)) {
                        return;
                      }

                      isLoadingPeers = true;
                      lastPeersFetchTime = now;
                      try {
                        final instanceManager = outerContext
                            .read<InstanceManager>();
                        final instance = instanceManager.getInstanceById(
                          currentTask.instanceId,
                        );
                        if (instance == null) {
                          peersError = l10n.targetInstanceNotConnected;
                          return;
                        }
                        final nextClientKey =
                            '${instance.id}_${instance.protocol}_${instance.host}_${instance.port}_${instance.secret}';
                        if (peersClientKey != nextClientKey ||
                            peersClient == null) {
                          peersClient?.close();
                          peersClient = Aria2RpcClient(instance);
                          peersClientKey = nextClientKey;
                        }
                        peers = await peersClient!.getPeers(currentTask.id);
                        peersError = null;
                      } catch (error) {
                        peersError = '$error';
                      } finally {
                        isLoadingPeers = false;
                        if (context.mounted) {
                          setState(() {});
                        }
                      }
                    }

                    if (activeTabController != tabController) {
                      if (activeTabController != null &&
                          activeTabListener != null) {
                        activeTabController!.removeListener(activeTabListener!);
                      }

                      activeTabController = tabController;
                      activeTabListener = () {
                        if (!tabController.indexIsChanging) {
                          currentTabIndex = tabController.index;
                          unawaited(
                            requestPeersIfNeeded?.call(force: true) ??
                                Future.value(),
                          );
                          if (context.mounted) {
                            setState(() {});
                          }
                        }
                      };
                      activeTabController!.addListener(activeTabListener!);
                    }

                    requestPeersIfNeeded = fetchPeersIfNeeded;

                    return AlertDialog(
                      title: Text(l10n.taskDetails),
                      content: SizedBox(
                        width: 600,
                        height: 450,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              taskDisplayName,
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
                              tabs: tabs,
                              indicatorSize: TabBarIndicatorSize.tab,
                            ),
                            Expanded(
                              child: TabBarView(
                                children: [
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(8),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(l10n.taskId(currentTask.id)),
                                        const SizedBox(height: 8),
                                        Row(
                                          children: [
                                            Text(
                                              l10n.statusWithValue(
                                                statusInfo.$1,
                                              ),
                                              style: TextStyle(
                                                color: statusInfo.$2,
                                              ),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 8),
                                        Text(
                                          l10n.sizeWithValue(
                                            currentTask.totalLengthBytes
                                                .toString(),
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
                                          l10n.progressWithValue(
                                            progressPercent,
                                          ),
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
                                            currentTask.uploadSpeedBytes
                                                .toString(),
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
                                            saveLocation,
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
                                            currentTask
                                                .errorMessage!
                                                .isNotEmpty)
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
                                                currentTask,
                                              ),
                                            ),
                                          ),
                                        if (currentTask.startTime != null) ...[
                                          const SizedBox(height: 8),
                                          Text(
                                            l10n.startedAtWithValue(
                                              currentTask.startTime!
                                                  .toLocal()
                                                  .toString(),
                                            ),
                                          ),
                                        ],
                                        if (currentTask.uris != null &&
                                            currentTask.uris!.isNotEmpty) ...[
                                          const SizedBox(height: 12),
                                          Text(
                                            l10n.sourceLinks,
                                            style: const TextStyle(
                                              fontWeight: FontWeight.bold,
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          SelectableText(
                                            currentTask.uris!.join('\n'),
                                          ),
                                        ],
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
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Text(
                                          l10n.filesTitle,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 8),
                                        if (currentFiles.isNotEmpty) ...[
                                          Wrap(
                                            spacing: 8,
                                            runSpacing: 8,
                                            children: [
                                              FilledButton.tonal(
                                                onPressed: () {
                                                  setState(() {
                                                    fileSelection = {
                                                      for (final file
                                                          in currentFiles)
                                                        if (int.tryParse(
                                                              file['index']
                                                                      ?.toString() ??
                                                                  '',
                                                            ) !=
                                                            null)
                                                          int.parse(
                                                            file['index']
                                                                .toString(),
                                                          ): true,
                                                    };
                                                    hasFileSelectionChanges =
                                                        true;
                                                  });
                                                },
                                                child: Text(
                                                  allFilesSelected
                                                      ? l10n.allVisibleSelected
                                                      : l10n.selectAllVisible,
                                                ),
                                              ),
                                              TextButton(
                                                onPressed:
                                                    hasFileSelectionChanges
                                                    ? () {
                                                        setState(() {
                                                          fileSelection =
                                                              buildFileSelectionState(
                                                                currentFiles,
                                                              );
                                                          fileSelectionSourceSignature =
                                                              currentSignature;
                                                          hasFileSelectionChanges =
                                                              false;
                                                        });
                                                      }
                                                    : null,
                                                child: Text(l10n.discard),
                                              ),
                                              FilledButton(
                                                onPressed:
                                                    hasFileSelectionChanges &&
                                                        !isSavingFileSelection &&
                                                        fileSelection.values
                                                            .any(
                                                              (selected) =>
                                                                  selected,
                                                            )
                                                    ? () async {
                                                        final selectedIndexes =
                                                            fileSelection
                                                                .entries
                                                                .where(
                                                                  (
                                                                    entry,
                                                                  ) => entry
                                                                      .value,
                                                                )
                                                                .map(
                                                                  (entry) =>
                                                                      entry.key,
                                                                )
                                                                .toList()
                                                              ..sort();
                                                        final instanceManager =
                                                            outerContext
                                                                .read<
                                                                  InstanceManager
                                                                >();
                                                        final Aria2Instance?
                                                        instance = instanceManager
                                                            .getInstanceById(
                                                              currentTask
                                                                  .instanceId,
                                                            );
                                                        if (instance == null) {
                                                          if (outerContext
                                                              .mounted) {
                                                            ScaffoldMessenger.of(
                                                              outerContext,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  l10n.targetInstanceNotConnected,
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                          return;
                                                        }

                                                        setState(() {
                                                          isSavingFileSelection =
                                                              true;
                                                        });

                                                        Aria2RpcClient? client;
                                                        try {
                                                          client =
                                                              Aria2RpcClient(
                                                                instance,
                                                              );
                                                          await client.changeOption(
                                                            currentTask.id,
                                                            {
                                                              'select-file':
                                                                  selectedIndexes
                                                                      .join(
                                                                        ',',
                                                                      ),
                                                            },
                                                          );
                                                          client.close();

                                                          onTaskUpdated?.call();

                                                          if (outerContext
                                                              .mounted) {
                                                            ScaffoldMessenger.of(
                                                              outerContext,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  l10n.save,
                                                                ),
                                                              ),
                                                            );
                                                          }

                                                          if (context.mounted) {
                                                            setState(() {
                                                              hasFileSelectionChanges =
                                                                  false;
                                                              fileSelectionSourceSignature =
                                                                  currentSignature;
                                                            });
                                                          }
                                                        } catch (error) {
                                                          if (outerContext
                                                              .mounted) {
                                                            ScaffoldMessenger.of(
                                                              outerContext,
                                                            ).showSnackBar(
                                                              SnackBar(
                                                                content: Text(
                                                                  l10n.operationFailed(
                                                                    '$error',
                                                                  ),
                                                                ),
                                                              ),
                                                            );
                                                          }
                                                        } finally {
                                                          client?.close();
                                                          if (context.mounted) {
                                                            setState(() {
                                                              isSavingFileSelection =
                                                                  false;
                                                            });
                                                          }
                                                        }
                                                      }
                                                    : null,
                                                child: isSavingFileSelection
                                                    ? const SizedBox(
                                                        width: 16,
                                                        height: 16,
                                                        child:
                                                            CircularProgressIndicator(
                                                              strokeWidth: 2,
                                                            ),
                                                      )
                                                    : Text(l10n.save),
                                              ),
                                              Text(
                                                l10n.selectedCount(
                                                  fileSelection.values
                                                      .where(
                                                        (selected) => selected,
                                                      )
                                                      .length
                                                      .toString(),
                                                ),
                                              ),
                                            ],
                                          ),
                                          const SizedBox(height: 12),
                                          ListView.builder(
                                            shrinkWrap: true,
                                            physics:
                                                const NeverScrollableScrollPhysics(),
                                            itemCount: currentFiles.length,
                                            itemBuilder: (context, index) {
                                              final file = currentFiles[index];
                                              final fileIndex = int.tryParse(
                                                file['index']?.toString() ?? '',
                                              );
                                              final rawFilePath =
                                                  file['path'] as String? ?? '';
                                              final filePath =
                                                  rawFilePath.trim().isEmpty
                                                  ? l10n.unknownPath
                                                  : rawFilePath;
                                              final fileName = filePath
                                                  .split('/')
                                                  .last
                                                  .split('\\')
                                                  .last;
                                              final displayName =
                                                  fileName.trim().isEmpty
                                                  ? l10n.unknownPath
                                                  : fileName;
                                              final fileSize = formatBytes(
                                                int.tryParse(
                                                      file['length']
                                                              as String? ??
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
                                              final selected = fileIndex == null
                                                  ? (file['selected']
                                                                as String? ??
                                                            'true') ==
                                                        'true'
                                                  : (fileSelection[fileIndex] ??
                                                        ((file['selected']
                                                                    as String? ??
                                                                'true') ==
                                                            'true'));

                                              return Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                      vertical: 2,
                                                    ),
                                                decoration: BoxDecoration(
                                                  border: Border(
                                                    bottom: BorderSide(
                                                      color:
                                                          Colors.grey.shade200,
                                                    ),
                                                  ),
                                                ),
                                                child: CheckboxListTile(
                                                  value: selected,
                                                  onChanged: fileIndex == null
                                                      ? null
                                                      : (value) {
                                                          setState(() {
                                                            fileSelection = {
                                                              ...fileSelection,
                                                              fileIndex:
                                                                  value ??
                                                                  false,
                                                            };
                                                            hasFileSelectionChanges =
                                                                true;
                                                          });
                                                        },
                                                  controlAffinity:
                                                      ListTileControlAffinity
                                                          .leading,
                                                  contentPadding:
                                                      EdgeInsets.zero,
                                                  title: Text(
                                                    displayName,
                                                    style: TextStyle(
                                                      fontWeight: selected
                                                          ? FontWeight.normal
                                                          : FontWeight.w300,
                                                    ),
                                                  ),
                                                  subtitle: Column(
                                                    crossAxisAlignment:
                                                        CrossAxisAlignment
                                                            .start,
                                                    children: [
                                                      Text(
                                                        '$completedSize / $fileSize',
                                                      ),
                                                      Text(
                                                        filePath,
                                                        style: TextStyle(
                                                          color:
                                                              Colors.grey[600],
                                                          fontSize: 12,
                                                        ),
                                                      ),
                                                      if (!selected)
                                                        Text(
                                                          l10n.notSelected,
                                                          style: TextStyle(
                                                            color: Colors.grey,
                                                          ),
                                                        ),
                                                    ],
                                                  ),
                                                ),
                                              );
                                            },
                                          ),
                                        ] else
                                          Text(l10n.noFileInformation),
                                      ],
                                    ),
                                  ),
                                  if (isBtTask)
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.all(8),
                                      child:
                                          (currentTask.trackers == null ||
                                              currentTask.trackers!.isEmpty)
                                          ? Text(l10n.noTrackerInformation)
                                          : SelectableText(
                                              currentTask.trackers!.join('\n'),
                                            ),
                                    ),
                                  if (isBtTask)
                                    SingleChildScrollView(
                                      padding: const EdgeInsets.all(8),
                                      child: _buildPeersView(
                                        context: context,
                                        peers: peers,
                                        isLoading: isLoadingPeers,
                                        error: peersError,
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
                    );
                  },
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

    final pieces = parseHexBitfield(bitfield);
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

  static Widget _buildPeersView({
    required BuildContext context,
    required List<Map<String, dynamic>> peers,
    required bool isLoading,
    required String? error,
  }) {
    final l10n = AppLocalizations.of(context)!;
    if (isLoading && peers.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (error != null && error.isNotEmpty && peers.isEmpty) {
      return Text(error);
    }

    if (peers.isEmpty) {
      return Text(l10n.noPeerInformation);
    }

    return Column(
      children: peers.map((peer) {
        final ip = peer['ip']?.toString() ?? '--';
        final port = peer['port']?.toString() ?? '--';
        final peerId = peer['peerId']?.toString() ?? '--';
        final progress = _bitfieldToPercent(peer['bitfield']?.toString());
        final uploadSpeed = formatBytes(
          int.tryParse(peer['uploadSpeed']?.toString() ?? '0') ?? 0,
        );
        final downloadSpeed = formatBytes(
          int.tryParse(peer['downloadSpeed']?.toString() ?? '0') ?? 0,
        );

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            title: Text('$ip:$port'),
            subtitle: Text(
              '${l10n.clientLabel}: $peerId\n'
              '${l10n.progress}: ${progress.toStringAsFixed(0)}%\n'
              '${l10n.uploadShort}: $uploadSpeed/s  ${l10n.downloadShort}: $downloadSpeed/s',
            ),
          ),
        );
      }).toList(),
    );
  }

  static double _bitfieldToPercent(String? bitfield) {
    if (bitfield == null || bitfield.isEmpty) {
      return 0;
    }
    final pieces = parseHexBitfield(bitfield);
    if (pieces.isEmpty) {
      return 0;
    }
    final completed = pieces.fold<int>(0, (sum, value) => sum + value);
    return (completed / (pieces.length * 15)) * 100;
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
