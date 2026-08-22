import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../../generated/l10n/l10n.dart';
import '../../../models/aria2_instance.dart';
import '../../../services/clipboard_monitor_service.dart';
import '../../../services/download_data_service.dart';
import '../../../services/instance_manager.dart';
import '../../../utils/format_utils.dart';
import '../enums.dart';
import '../models/download_task.dart';
import '../services/download_task_service.dart';
import 'task_details_bt_helpers.dart';
import 'task_details_options_tab.dart';
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
        var isLoadingPeers = false;
        DateTime? lastPeersFetchTime;
        String? peersError;
        List<Map<String, dynamic>> peers = <Map<String, dynamic>>[];
        String lastRefreshSignature = '';

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
            final optionsTab = Tab(text: l10n.taskOptions);
            final tabs = <Tab>[
              overviewTab,
              piecesTab,
              filesTab,
              optionsTab,
              if (isBtTask) Tab(text: l10n.trackers),
              if (isBtTask) Tab(text: l10n.peers),
            ];
            String buildRefreshSignature(DownloadTask task) {
              return [
                task.status.name,
                task.taskStatus,
                task.completedLengthBytes,
                task.totalLengthBytes,
                task.downloadSpeedBytes,
                task.uploadSpeedBytes,
                task.uploadLengthBytes,
                task.connections,
                task.numSeeders,
                task.isSeeder,
                task.errorMessage,
                task.files?.length,
                peers.length,
                isLoadingPeers,
                peersError,
              ].join('\u001f');
            }

            refreshTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
              unawaited(requestPeersIfNeeded?.call() ?? Future.value());
              if (!context.mounted) {
                return;
              }
              // Rebuild only when something the dialog renders changed;
              // idle tasks would otherwise rebuild every second.
              final signature = buildRefreshSignature(getLatestTaskData());
              if (signature != lastRefreshSignature) {
                lastRefreshSignature = signature;
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
            final taskDisplayName = currentTask.name.trim().isEmpty
                ? currentTask.id
                : currentTask.name;
            final isSeeding = DownloadTaskService.isSeedingTask(currentTask);
            final isBtTaskDetail =
                currentTask.bittorrentInfo != null &&
                currentTask.bittorrentInfo!.isNotEmpty;
            final saveLocation =
                currentTask.dir == null || currentTask.dir!.trim().isEmpty
                ? l10n.unknownPath
                : currentTask.dir!;
            final torrentMetadata = TaskDetailsBtHelpers.parseTorrentMetadata(
              currentTask.bittorrentInfo,
            );
            final showTorrentSection =
                currentTask.bittorrentInfo != null &&
                TaskDetailsBtHelpers.hasTorrentOverviewData(
                  currentTask,
                  torrentMetadata,
                );

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
                      List<Map<String, dynamic>>? peersResult;
                      String? peersErrorLocal;
                      try {
                        if (!outerContext.mounted) return;
                        final instanceManager = outerContext
                            .read<InstanceManager>();
                        final instance = instanceManager.getInstanceById(
                          currentTask.instanceId,
                        );
                        if (instance == null) {
                          peersErrorLocal = l10n.targetInstanceNotConnected;
                        } else {
                          final downloadDataService = outerContext
                              .read<DownloadDataService>();
                          peersResult = await downloadDataService
                              .clientFor(instance)
                              .getPeers(currentTask.id);
                        }
                      } catch (error) {
                        peersErrorLocal = '$error';
                      } finally {
                        if (context.mounted) {
                          setState(() {
                            peersError = peersErrorLocal;
                            isLoadingPeers = false;
                            if (peersResult != null) {
                              peers = peersResult;
                            }
                          });
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
                          setState(() {
                            currentTabIndex = tabController.index;
                          });
                          unawaited(
                            requestPeersIfNeeded?.call(force: true) ??
                                Future.value(),
                          );
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
                                          l10n.saveLocationWithValue(
                                            saveLocation,
                                          ),
                                        ),
                                        if (currentTask.status ==
                                            DownloadStatus.active) ...[
                                          const SizedBox(height: 12),
                                          if (!isSeeding) ...[
                                            Text(
                                              l10n.downloadSpeedWithValue(
                                                currentTask.downloadSpeedBytes
                                                    .toString(),
                                                currentTask.downloadSpeed,
                                              ),
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          Text(
                                            l10n.uploadSpeedWithValue(
                                              currentTask.uploadSpeedBytes
                                                  .toString(),
                                              currentTask.uploadSpeed,
                                            ),
                                          ),
                                          if (isBtTaskDetail) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              '${l10n.torrentConnections}: ${currentTask.connections ?? 0}',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${l10n.torrentSeeders}: ${currentTask.numSeeders ?? 0}',
                                            ),
                                            const SizedBox(height: 8),
                                            if (peers.isNotEmpty)
                                              ...() {
                                                final health =
                                                    TaskDetailsBtHelpers.estimateHealthPercent(
                                                      currentTask,
                                                      peers,
                                                    );
                                                return <Widget>[
                                                  if (health != null)
                                                    Text(
                                                      l10n.healthPercentage(
                                                        '${health.toStringAsFixed(0)}%',
                                                      ),
                                                    ),
                                                  const SizedBox(height: 8),
                                                ];
                                              }(),
                                            Text(
                                              '${l10n.torrentUploaded}: ${formatBytes(currentTask.uploadLengthBytes)}',
                                            ),
                                            const SizedBox(height: 8),
                                            Text(
                                              '${l10n.torrentRatio}: ${TaskDetailsBtHelpers.formatShareRatio(currentTask)}',
                                            ),
                                          ],
                                          if (!isSeeding &&
                                              currentTask.downloadSpeedBytes >
                                                  0) ...[
                                            const SizedBox(height: 8),
                                            Text(
                                              l10n.remainingTimeWithValue(
                                                TaskUtils.calculateRemainingTime(
                                                  currentTask,
                                                ),
                                              ),
                                            ),
                                          ],
                                        ],
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
                                        if (showTorrentSection) ...[
                                          const SizedBox(height: 20),
                                          TaskDetailsBtHelpers.buildSectionDivider(
                                            context,
                                            l10n.torrentInfo,
                                          ),
                                          const SizedBox(height: 16),
                                          if (currentTask.infoHash != null &&
                                              currentTask.infoHash!
                                                  .trim()
                                                  .isNotEmpty) ...[
                                            Text(
                                              '${l10n.torrentHash}: ${currentTask.infoHash!}',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (currentTask.pieceLength != null &&
                                              currentTask.pieceLength! > 0) ...[
                                            Text(
                                              '${l10n.torrentPieceSize}: ${formatBytes(currentTask.pieceLength!)}',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (currentTask.numPieces != null &&
                                              currentTask.numPieces! > 0) ...[
                                            Text(
                                              '${l10n.torrentPieceCount}: ${currentTask.numPieces}',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (torrentMetadata.creationDate !=
                                              null) ...[
                                            Text(
                                              '${l10n.torrentCreationDate}: ${torrentMetadata.creationDate!.toLocal()}',
                                            ),
                                            const SizedBox(height: 8),
                                          ],
                                          if (torrentMetadata.comment != null &&
                                              torrentMetadata.comment!
                                                  .trim()
                                                  .isNotEmpty)
                                            Text(
                                              '${l10n.torrentComment}: ${torrentMetadata.comment!}',
                                            ),
                                        ],
                                      ],
                                    ),
                                  ),
                                  SingleChildScrollView(
                                    padding: const EdgeInsets.all(16),
                                    child:
                                        TaskDetailsBtHelpers.buildBitfieldVisualization(
                                          context,
                                          currentTask,
                                        ),
                                  ),
                                  TaskDetailsOptionsTab(
                                    key: ValueKey(
                                      '${currentTask.instanceId}:${currentTask.id}',
                                    ),
                                    task: currentTask,
                                    onSaved: onTaskUpdated,
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

                                                        try {
                                                          final downloadDataService =
                                                              outerContext
                                                                  .read<
                                                                    DownloadDataService
                                                                  >();
                                                          await downloadDataService
                                                              .clientFor(
                                                                instance,
                                                              )
                                                              .changeOption(
                                                                currentTask.id,
                                                                {
                                                                  'select-file':
                                                                      selectedIndexes
                                                                          .join(
                                                                            ',',
                                                                          ),
                                                                },
                                                              );

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
                                      child:
                                          TaskDetailsBtHelpers.buildPeersView(
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
                        if (currentTask.infoHash?.trim().isNotEmpty ?? false)
                          TextButton.icon(
                            onPressed: () async {
                              final buffer = StringBuffer(
                                'magnet:?xt=urn:btih:${currentTask.infoHash!.trim()}',
                              );
                              final name = currentTask.name.trim();
                              if (name.isNotEmpty) {
                                buffer.write(
                                  '&dn=${Uri.encodeComponent(name)}',
                                );
                              }
                              for (final tracker
                                  in currentTask.trackers ?? const <String>[]) {
                                final trimmed = tracker.trim();
                                if (trimmed.isEmpty) {
                                  continue;
                                }
                                buffer.write(
                                  '&tr=${Uri.encodeComponent(trimmed)}',
                                );
                              }
                              await Clipboard.setData(
                                ClipboardData(text: buffer.toString()),
                              );
                              ClipboardMonitorService.markSelfCopied(
                                buffer.toString(),
                              );
                              if (!context.mounted) {
                                return;
                              }
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(content: Text(l10n.magnetLinkCopied)),
                              );
                            },
                            icon: const Icon(Icons.link, size: 18),
                            label: Text(l10n.copyMagnetLink),
                          ),
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
}
