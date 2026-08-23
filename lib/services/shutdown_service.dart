import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';

import '../generated/l10n/l10n.dart';
import '../pages/download_page/enums.dart';
import '../pages/download_page/models/download_task.dart';
import '../pages/download_page/services/download_task_service.dart';
import '../utils/logging.dart';
import 'download_data_service.dart';

final _logger = taggedLogger('ShutdownService');

enum ShutdownExecutionState { idle, running, failed }

/// Schedules and cancels the shutdown-after-downloads-complete countdown.
///
/// The countdown only starts when a built-in instance download completed and
/// no productive work remains (seeding does not block it). Any new download
/// activity cancels the pending shutdown automatically.
class ShutdownService {
  static final ShutdownService instance = ShutdownService._();

  ShutdownService._();

  static const int countdownSeconds = 60;

  /// Remaining seconds while a countdown is running, null otherwise.
  final ValueNotifier<int?> remainingSeconds = ValueNotifier<int?>(null);
  final ValueNotifier<ShutdownExecutionState> executionState =
      ValueNotifier<ShutdownExecutionState>(ShutdownExecutionState.idle);
  Timer? _timer;

  bool get isCountingDown => _timer != null;

  void _startCountdown() {
    if (_timer != null || executionState.value != ShutdownExecutionState.idle) {
      return;
    }
    remainingSeconds.value = countdownSeconds;
    _logger.i(
      'All downloads finished; shutting down in $countdownSeconds seconds',
    );
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final next = (remainingSeconds.value ?? 0) - 1;
      if (next <= 0) {
        timer.cancel();
        _timer = null;
        remainingSeconds.value = 0;
        unawaited(executeShutdown());
        return;
      }
      remainingSeconds.value = next;
    });
  }

  void cancel({String? reason}) {
    if (_timer == null &&
        remainingSeconds.value == null &&
        executionState.value == ShutdownExecutionState.idle) {
      return;
    }
    _timer?.cancel();
    _timer = null;
    remainingSeconds.value = null;
    executionState.value = ShutdownExecutionState.idle;
    _logger.i(
      'Shutdown countdown cancelled${reason == null ? '' : ': $reason'}',
    );
  }

  /// Called on every task-refresh notification. Starts the countdown when
  /// conditions are met, cancels it when new work appears.
  void synchronize({
    required List<DownloadTaskNotification> notifications,
    required List<DownloadTask> tasks,
    required bool enabled,
  }) {
    if (!enabled) {
      cancel(reason: 'setting disabled');
      return;
    }

    if (isCountingDown && hasActiveWork(tasks)) {
      cancel(reason: 'new download activity');
      return;
    }

    if (!isCountingDown &&
        notifications.any(
          (notification) =>
              notification.type == DownloadTaskNotificationType.completed &&
              notification.instanceId == 'builtin',
        ) &&
        !hasActiveWork(tasks)) {
      _startCountdown();
    }
  }

  @visibleForTesting
  static bool hasActiveWork(List<DownloadTask> tasks) {
    return tasks.any(
      (task) =>
          (task.status == DownloadStatus.active &&
              !DownloadTaskService.isSeedingTask(task)) ||
          (task.status == DownloadStatus.waiting &&
              task.taskStatus != 'paused'),
    );
  }

  static Future<ProcessResult> executeSystemShutdown() async {
    return executeSystemShutdownForPlatform(Platform.operatingSystem);
  }

  @visibleForTesting
  static Future<ProcessResult> executeSystemShutdownForPlatform(
    String operatingSystem, {
    Future<ProcessResult> Function(String executable, List<String> arguments)?
    processRunner,
  }) async {
    final run =
        processRunner ??
        (String executable, List<String> arguments) =>
            Process.run(executable, arguments);
    try {
      if (operatingSystem == 'windows') {
        return await run('shutdown', <String>['/s', '/t', '0']);
      }
      if (operatingSystem == 'macos') {
        return await run('osascript', <String>[
          '-e',
          'tell app "System Events" to shut down',
        ]);
      }
      if (operatingSystem == 'linux') {
        try {
          final result = await run('systemctl', <String>['poweroff']);
          if (result.exitCode == 0) {
            return result;
          }
          _logger.w(
            'systemctl poweroff failed with exit code '
            '${result.exitCode}; trying shutdown -h now',
          );
        } catch (error, stackTrace) {
          _logger.w(
            'systemctl poweroff failed; trying shutdown -h now',
            error: error,
            stackTrace: stackTrace,
          );
        }
        return await run('shutdown', <String>['-h', 'now']);
      }
      throw UnsupportedError(
        'Unsupported platform for shutdown: $operatingSystem',
      );
    } catch (error, stackTrace) {
      _logger.e(
        'Failed to trigger system shutdown',
        error: error,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  @visibleForTesting
  Future<void> executeShutdown({
    Future<ProcessResult> Function()? shutdown,
  }) async {
    if (executionState.value == ShutdownExecutionState.running) {
      return;
    }
    executionState.value = ShutdownExecutionState.running;
    try {
      final result = await (shutdown ?? executeSystemShutdown)();
      if (result.exitCode != 0) {
        throw ProcessException(
          'shutdown',
          const <String>[],
          '${result.stderr}',
          result.exitCode,
        );
      }
    } catch (error, stackTrace) {
      _logger.e(
        'System shutdown command failed',
        error: error,
        stackTrace: stackTrace,
      );
      executionState.value = ShutdownExecutionState.failed;
    }
  }

  Future<void> retryShutdown() async {
    await executeShutdown();
  }

  void dispose() {
    cancel(reason: 'service disposed');
  }
}

/// Cancellable countdown dialog shown while [ShutdownService] waits before
/// powering off the machine.
class ShutdownCountdownDialog extends StatelessWidget {
  const ShutdownCountdownDialog({super.key});

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    return PopScope(
      canPop: false,
      child: AlertDialog(
        title: Text(l10n.shutdownWhenComplete),
        content: ValueListenableBuilder<ShutdownExecutionState>(
          valueListenable: ShutdownService.instance.executionState,
          builder: (context, state, _) {
            if (state == ShutdownExecutionState.failed) {
              return Text(l10n.operationFailed(l10n.shutdownWhenComplete));
            }
            if (state == ShutdownExecutionState.running) {
              return const SizedBox(
                height: 48,
                child: Center(child: CircularProgressIndicator()),
              );
            }
            return ValueListenableBuilder<int?>(
              valueListenable: ShutdownService.instance.remainingSeconds,
              builder: (context, seconds, _) {
                final remaining = seconds ?? 0;
                return Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(l10n.shutdownCountdownMessage(remaining)),
                    const SizedBox(height: 16),
                    SizedBox(
                      width: double.infinity,
                      child: LinearProgressIndicator(
                        value: remaining / ShutdownService.countdownSeconds,
                      ),
                    ),
                  ],
                );
              },
            );
          },
        ),
        actions: [
          ValueListenableBuilder<ShutdownExecutionState>(
            valueListenable: ShutdownService.instance.executionState,
            builder: (context, state, _) {
              if (state == ShutdownExecutionState.running) {
                return const SizedBox.shrink();
              }
              if (state == ShutdownExecutionState.failed) {
                return Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    TextButton(
                      onPressed: () {
                        ShutdownService.instance.cancel(
                          reason: 'shutdown failed',
                        );
                        Navigator.of(context).pop();
                      },
                      child: Text(l10n.close),
                    ),
                    FilledButton(
                      onPressed: ShutdownService.instance.retryShutdown,
                      child: Text(l10n.retry),
                    ),
                  ],
                );
              }
              return FilledButton.tonal(
                onPressed: () {
                  ShutdownService.instance.cancel(reason: 'user cancelled');
                  Navigator.of(context).pop();
                },
                child: Text(l10n.cancel),
              );
            },
          ),
        ],
      ),
    );
  }
}
