import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';

import 'constants/app_branding.dart';
import 'generated/l10n/l10n.dart';
import 'models/aria2_instance.dart';
import 'models/settings.dart';
import 'pages/download_page/download_page.dart';
import 'pages/download_page/enums.dart';
import 'pages/download_page/models/download_task.dart';
import 'pages/instance_page/instance_page.dart';
import 'pages/components/quick_speed_limit_dialog.dart';
import 'utils/format_utils.dart';
import 'utils/windows_font_theme.dart';
import 'pages/settings_page/settings_page.dart';
import 'services/download_data_service.dart';
import 'services/desktop_progress_service.dart';
import 'services/power_management_service.dart';
import 'services/builtin_instance_service.dart';
import 'services/clipboard_monitor_service.dart';
import 'services/instance_manager.dart';
import 'services/protocol_integration_service.dart';
import 'services/settings_service.dart';
import 'services/auto_hide_window_service.dart';
import 'services/startup_integration_service.dart';
import 'services/system_tray_service.dart';
import 'services/shutdown_service.dart';
import 'services/tracker_sync_service.dart';
import 'services/task_bulk_action_service.dart';
import 'services/update_check_service.dart';
import 'utils/logging.dart';
import 'widgets/sized_loading.dart';
import 'widgets/virtual_window_frame.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.initialSettings});

  final Settings? initialSettings;

  @override
  Widget build(BuildContext context) {
    final settingsProvider = initialSettings == null
        ? ChangeNotifierProvider<Settings>(create: (context) => Settings())
        : ChangeNotifierProvider<Settings>.value(value: initialSettings!);
    return MultiProvider(
      providers: [settingsProvider],
      child: _ThemeProvider(),
    );
  }
}

class _ThemeProvider extends StatefulWidget {
  @override
  State<_ThemeProvider> createState() => _ThemeProviderState();
}

class _ThemeProviderState extends State<_ThemeProvider> {
  @override
  Widget build(BuildContext context) {
    final display = context
        .select<
          Settings,
          ({
            Locale? locale,
            bool hideTitleBar,
            Color primaryColor,
            ThemeMode themeMode,
          })
        >(
          (s) => (
            locale: s.locale,
            hideTitleBar: s.hideTitleBar,
            primaryColor: s.primaryColor,
            themeMode: s.themeMode,
          ),
        );

    return MaterialApp(
      title: kAppName,
      locale: display.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      builder: (context, child) => AppVirtualWindowFrame(
        title: kAppName,
        showCaption: display.hideTitleBar,
        child: ClipRect(child: child ?? const SizedBox.shrink()),
      ),
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: display.primaryColor,
          brightness: Brightness.light,
        ),
      ).withWindowsChineseFontFallback,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: display.primaryColor,
          brightness: Brightness.dark,
        ),
      ).withWindowsChineseFontFallback,
      themeMode: display.themeMode,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => InstanceManager()),
          ChangeNotifierProvider(create: (context) => DownloadDataService()),
          ChangeNotifierProvider(create: (context) => SettingsService()),
        ],
        child: const _HomeWrapper(),
      ),
    );
  }
}

class _HomeWrapper extends StatefulWidget {
  const _HomeWrapper();

  @override
  State<_HomeWrapper> createState() => _HomeWrapperState();
}

class _HomeWrapperState extends State<_HomeWrapper> with Loggable {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    final settings = Provider.of<Settings>(context, listen: false);
    if (!settings.isLoaded) {
      await settings.loadSettings();
    }

    final protocolPreferenceFailures = await ProtocolIntegrationService()
        .reconcileProtocolPreferences(settings);
    bool startupPreferenceFailure = false;
    try {
      await StartupIntegrationService().reconcileStartupPreference(settings);
    } catch (e, stackTrace) {
      startupPreferenceFailure = true;
      w(
        'Failed to reconcile run-at-startup preference',
        error: e,
        stackTrace: stackTrace,
      );
    }

    if (!mounted) return;
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    settingsService.initialize(settings);
    // Initialize instance manager
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    await instanceManager.initialize();

    unawaited(_syncBuiltinTrackersIfNeeded(settings, instanceManager));
    if (mounted) {
      unawaited(UpdateCheckService().autoCheckIfNeeded(settings, context));
    }

    setState(() {
      _isInitialized = true;
    });

    if (protocolPreferenceFailures.isNotEmpty && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              l10n.protocolReconcileFailed(
                protocolPreferenceFailures.join(', '),
              ),
            ),
          ),
        );
      });
    }

    if (startupPreferenceFailure && mounted) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }

        final l10n = AppLocalizations.of(context)!;
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(l10n.runAtStartupRetryWarning)));
      });
    }
  }

  Future<void> _syncBuiltinTrackersIfNeeded(
    Settings settings,
    InstanceManager instanceManager,
  ) async {
    try {
      if (!mounted) {
        return;
      }
      final builtinInstance = instanceManager.getBuiltinInstance();
      if (builtinInstance == null) {
        return;
      }
      final downloadDataService = Provider.of<DownloadDataService>(
        context,
        listen: false,
      );
      await TrackerSyncService().syncBuiltinTrackersIfNeeded(
        settings,
        builtinInstance: builtinInstance,
        rpcClient: downloadDataService.clientFor(builtinInstance),
      );
    } catch (e, stackTrace) {
      w('Automatic tracker sync failed', error: e, stackTrace: stackTrace);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return const Scaffold(body: Center(child: SizedLoading.medium));
    }
    return const MainWindow();
  }
}

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> with WindowListener, Loggable {
  static const Duration _autoHideWindowDelay = Duration(milliseconds: 300);

  int _selectedIndex = 0;
  final GlobalKey<DownloadPageState> _downloadPageKey =
      GlobalKey<DownloadPageState>();
  late final PageController _pageController;
  DownloadDataService? _downloadDataService;
  InstanceManager? _instanceManager;
  Settings? _settings;
  Timer? _pendingAutoHideTimer;
  bool _isWindowBlurred = false;
  bool _isQuitting = false;
  int _shellSettingsGeneration = 0;
  bool _hasShownBuiltinFailureDialog = false;
  bool _hasResumedTasks = false;
  final DesktopProgressService _desktopProgressService =
      DesktopProgressService();
  final PowerManagementService _powerManagementService =
      PowerManagementService();

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    windowManager.addListener(this);
    BuiltinInstanceService.portRecoveryNotice.addListener(
      _handlePortRecoveryNotice,
    );
    ClipboardMonitorService.instance.version.addListener(
      _handleClipboardUriDetected,
    );
    final initialSettings = Provider.of<Settings>(context, listen: false);
    ClipboardMonitorService.instance.synchronize(
      enabled: initialSettings.clipboardMonitorEnabled,
      schemes: initialSettings.clipboardMonitorSchemes,
    );
    unawaited(_showPreparedWindow());
    _initSystemTrayCallbacks();
  }

  void _handlePortRecoveryNotice() {
    final message = BuiltinInstanceService.portRecoveryNotice.value;
    if (message == null) {
      return;
    }
    BuiltinInstanceService.portRecoveryNotice.value = null;
    if (!mounted) {
      return;
    }
    _showTrayActionSnackBar(message);
  }

  bool _isShowingShutdownDialog = false;

  void _handleClipboardUriDetected() {
    final uri = ClipboardMonitorService.instance.takePendingUri();
    if (uri == null || !mounted) {
      return;
    }
    unawaited(_navigateAndOpenAddTask(initialUri: uri));
  }

  Future<void> _showPreparedWindow() async {
    try {
      await WindowManagerService().showPreparedWindow();
    } catch (error, stackTrace) {
      e(
        'Failed to show the prepared application window',
        error: error,
        stackTrace: stackTrace,
      );
    }
  }

  @override
  void dispose() {
    _downloadDataService?.removeListener(_handleDownloadNotifications);
    _instanceManager?.removeListener(_handleInstanceManagerChanged);
    _settings?.removeListener(_handleSettingsChanged);
    BuiltinInstanceService.portRecoveryNotice.removeListener(
      _handlePortRecoveryNotice,
    );
    ClipboardMonitorService.instance.version.removeListener(
      _handleClipboardUriDetected,
    );
    ClipboardMonitorService.instance.stop();
    unawaited(_desktopProgressService.clear());
    unawaited(_powerManagementService.dispose());
    _pendingAutoHideTimer?.cancel();
    _pageController.dispose();
    windowManager.removeListener(this);
    final systemTrayService = SystemTrayService();
    systemTrayService.setOnShowWindow(null);
    systemTrayService.setOnAddTask(null);
    systemTrayService.setOnToggleWindow(null);
    systemTrayService.setOnQuitApp(null);
    systemTrayService.setOnPauseAll(null);
    systemTrayService.setOnResumeAll(null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _downloadDataService = _swapListener(
      Provider.of<DownloadDataService>(context, listen: false),
      _downloadDataService,
      (l) => l?.removeListener(_handleDownloadNotifications),
      (l) => l?.addListener(_handleDownloadNotifications),
    );

    _instanceManager = _swapListener(
      Provider.of<InstanceManager>(context, listen: false),
      _instanceManager,
      (l) => l?.removeListener(_handleInstanceManagerChanged),
      (l) => l?.addListener(_handleInstanceManagerChanged),
    );

    _settings = _swapListener(
      Provider.of<Settings>(context, listen: false),
      _settings,
      (l) => l?.removeListener(_handleSettingsChanged),
      (l) => l?.addListener(_handleSettingsChanged),
    );

    _synchronizeDownloadRefresh();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      unawaited(_applyShellSettings());
    });
  }

  T _swapListener<T>(
    T next,
    T? current,
    void Function(T? l) remove,
    void Function(T l) add,
  ) {
    if (current != next) {
      remove(current);
      add(next);
    }
    return next;
  }

  void _handleSettingsChanged() {
    final settings = _settings;
    if (settings != null) {
      ClipboardMonitorService.instance.synchronize(
        enabled: settings.clipboardMonitorEnabled,
        schemes: settings.clipboardMonitorSchemes,
      );
    }
    unawaited(_synchronizeDesktopProgress());
    unawaited(_synchronizePowerManagement());
    unawaited(_handleTrayStateChanged());
    unawaited(_applyShellSettings());
  }

  void _showBuiltinConnectionFailedDialog(BuildContext ctx) {
    final l10n = AppLocalizations.of(ctx)!;
    showDialog(
      context: ctx,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(l10n.builtinInstanceConnectFailed),
        content: Text(l10n.builtinInstanceConnectFailedTip),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(l10n.ok)),
        ],
      ),
    );
  }

  Future<void> _resumePausedTasksOnLaunch(
    InstanceManager instanceManager,
    DownloadDataService downloadDataService,
  ) async {
    final connectedInstances = instanceManager.getConnectedInstances();
    if (connectedInstances.isEmpty) {
      return;
    }

    await downloadDataService.refreshTasks(connectedInstances);

    final pausedTasks = downloadDataService.tasks
        .where(
          (task) =>
              task.status == DownloadStatus.waiting &&
              task.taskStatus == 'paused',
        )
        .toList();
    if (pausedTasks.isEmpty) {
      return;
    }

    final result = await TaskBulkActionService().run(
      instances: connectedInstances,
      tasks: pausedTasks,
      clientFactory: downloadDataService.clientFor,
      perform: (client, task) async {
        await client.unpauseTask(task.id);
        return const BulkActionItemResult();
      },
    );

    await downloadDataService.refreshTasks(connectedInstances);
    i(
      'Resume-on-launch finished: ${result.successCount} resumed, '
      '${result.failureCount} failed, ${result.indeterminateCount} unknown',
    );
  }

  void _handleInstanceManagerChanged() {
    unawaited(_handleTrayStateChanged());
    _synchronizeDownloadRefresh();

    final instanceManager =
        _instanceManager ??
        Provider.of<InstanceManager>(context, listen: false);

    // Resume paused tasks on launch when builtin first connects
    if (!_hasResumedTasks) {
      final builtinInstance = instanceManager.getInstanceById('builtin');
      if (builtinInstance != null &&
          builtinInstance.status == ConnectionStatus.connected) {
        _hasResumedTasks = true;
        final settings =
            _settings ?? Provider.of<Settings>(context, listen: false);
        if (settings.resumeAllOnLaunch) {
          final downloadDataService =
              _downloadDataService ??
              Provider.of<DownloadDataService>(context, listen: false);
          unawaited(
            _resumePausedTasksOnLaunch(instanceManager, downloadDataService),
          );
        }
      }
    }

    // Show failure dialog once when builtin fails
    if (_hasShownBuiltinFailureDialog) return;
    final builtinInstance = instanceManager.getInstanceById('builtin');
    if (builtinInstance != null &&
        builtinInstance.status == ConnectionStatus.failed) {
      _hasShownBuiltinFailureDialog = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBuiltinConnectionFailedDialog(context);
      });
    }
  }

  void _synchronizeDownloadRefresh() {
    final instanceManager = _instanceManager;
    final downloadDataService = _downloadDataService;
    if (instanceManager == null || downloadDataService == null) {
      return;
    }
    final refreshableInstances = instanceManager.getRefreshableInstances();
    if (refreshableInstances.isEmpty) {
      downloadDataService.stopPeriodicRefresh();
      unawaited(downloadDataService.refreshTasks(const <Aria2Instance>[]));
      return;
    }
    downloadDataService.startPeriodicRefresh(
      instanceManager.getRefreshableInstances,
    );
    unawaited(downloadDataService.refreshTasks(refreshableInstances));
  }

  Future<void> _initSystemTrayCallbacks() async {
    final systemTrayService = SystemTrayService();
    systemTrayService.setOnShowWindow(() async {
      await windowManager.show();
      await windowManager.focus();
    });
    systemTrayService.setOnAddTask(_openAddTaskFromTray);
    systemTrayService.setOnToggleWindow(_toggleWindowFromTray);
    systemTrayService.setOnQuitApp(() async {
      await _quitApplication();
    });
    systemTrayService.setOnPauseAll(_pauseAllTasksFromTray);
    systemTrayService.setOnResumeAll(_resumeAllTasksFromTray);
  }

  Future<void> _quitApplication() async {
    if (_isQuitting) {
      return;
    }

    _isQuitting = true;
    final instanceManager =
        _instanceManager ??
        Provider.of<InstanceManager>(context, listen: false);

    try {
      final builtinInstance = instanceManager.getBuiltinInstance();
      if (builtinInstance != null) {
        await instanceManager.disconnectInstance(builtinInstance);
      }
    } catch (e, stackTrace) {
      this.e(
        'Failed to stop built-in aria2 during application shutdown',
        error: e,
        stackTrace: stackTrace,
      );
    }

    SystemTrayService().destroy();
    await windowManager.destroy();
  }

  Future<void> _applyShellSettings() async {
    if (!mounted) {
      return;
    }

    final generation = ++_shellSettingsGeneration;
    final settings = _settings ?? Provider.of<Settings>(context, listen: false);
    final trayService = SystemTrayService();
    await WindowManagerService().setHideTitleBar(settings.hideTitleBar);
    if (!mounted || generation != _shellSettingsGeneration) {
      return;
    }
    await trayService.initializeNotifications();
    if (!mounted || generation != _shellSettingsGeneration) {
      return;
    }

    if (settings.runMode == AppRunMode.hideTray) {
      trayService.destroy();
      return;
    }

    await trayService.initialize();
    if (!mounted) {
      return;
    }
    if (generation != _shellSettingsGeneration) {
      final latestSettings =
          _settings ?? Provider.of<Settings>(context, listen: false);
      if (latestSettings.runMode == AppRunMode.hideTray) {
        trayService.destroy();
      }
      return;
    }
    unawaited(_handleTrayStateChanged());
  }

  void _handleDownloadNotifications() {
    if (!mounted || _downloadDataService == null) {
      return;
    }

    unawaited(_synchronizeDesktopProgress());
    unawaited(_synchronizePowerManagement());
    unawaited(_handleTrayStateChanged());

    final instanceManager = _instanceManager;
    if (instanceManager != null) {
      for (final entry in _downloadDataService!.instanceStates.entries) {
        instanceManager.updateConnectionHealth(
          entry.key,
          isStale: entry.value.isStale,
          consecutiveFailures: entry.value.consecutiveFailures,
          errorMessage: entry.value.error,
        );
      }
    }

    final notifications = _downloadDataService!.takePendingNotifications();
    ShutdownService.instance.synchronize(
      notifications: notifications,
      tasks: _downloadDataService!.tasks,
      enabled: Provider.of<Settings>(
        context,
        listen: false,
      ).shutdownWhenComplete,
    );
    if (ShutdownService.instance.isCountingDown &&
        mounted &&
        !_isShowingShutdownDialog) {
      _isShowingShutdownDialog = true;
      showDialog<void>(
        context: context,
        builder: (_) => const ShutdownCountdownDialog(),
      ).whenComplete(() => _isShowingShutdownDialog = false);
    }

    if (notifications.isEmpty) {
      return;
    }

    final settings = Provider.of<Settings>(context, listen: false);
    if (!settings.taskNotification) {
      return;
    }

    for (final notification in notifications) {
      final title = notification.type == DownloadTaskNotificationType.completed
          ? AppLocalizations.of(context)!.completed
          : AppLocalizations.of(context)!.error;
      final message =
          notification.type == DownloadTaskNotificationType.completed
          ? notification.taskName
          : notification.errorMessage?.isNotEmpty == true
          ? '${notification.taskName}\n${AppLocalizations.of(context)!.errorWithValue(notification.errorMessage!)}'
          : notification.taskName;

      _showTrayActionSnackBar('$title: ${notification.taskName}');
      SystemTrayService().showNotification(title, message);
    }
  }

  Future<void> _handleTrayStateChanged() async {
    if (!mounted) {
      return;
    }

    final instanceManager =
        _instanceManager ??
        Provider.of<InstanceManager>(context, listen: false);
    final downloadDataService =
        _downloadDataService ??
        Provider.of<DownloadDataService>(context, listen: false);
    final connectedCount = instanceManager.getConnectedInstances().length;
    final summary = downloadDataService.taskSummary;
    final settings = _settings ?? Provider.of<Settings>(context, listen: false);
    if (settings.runMode == AppRunMode.hideTray) {
      return;
    }
    final isWindowVisible = await windowManager.isVisible();
    if (!mounted) {
      return;
    }
    final l10n = AppLocalizations.of(context)!;
    final tooltipLines = <String>[
      kAppName,
      connectedCount == 0
          ? l10n.notConnected
          : '${l10n.connected}: $connectedCount',
      if (settings.showTraySpeed) l10n.totalSpeed(formatSpeed(summary.speed)),
      l10n.activeTasks(summary.active.toString()),
      l10n.waitingTasks(summary.waiting.toString()),
    ];
    final trayService = SystemTrayService();
    unawaited(trayService.updateTooltip(tooltipLines.join('\n')));
    unawaited(
      trayService.updateMenuState(
        statusLabel: connectedCount == 0
            ? l10n.notConnected
            : '${l10n.connected}: $connectedCount',
        addTaskLabel: l10n.addTask,
        toggleWindowLabel: isWindowVisible
            ? l10n.hideMainWindow
            : l10n.showMainWindow,
        resumeAllLabel: '${l10n.resumeTasks} (${summary.resumable})',
        pauseAllLabel: '${l10n.pauseTasks} (${summary.pausable})',
        quitLabel: l10n.quitApp,
        resumeAllDisabled: summary.resumable == 0,
        pauseAllDisabled: summary.pausable == 0,
      ),
    );
  }

  Future<void> _synchronizeDesktopProgress() async {
    if (!mounted || _downloadDataService == null) {
      return;
    }
    final settings = _settings ?? Provider.of<Settings>(context, listen: false);
    await _desktopProgressService.synchronize(
      enabled: settings.showProgressBar,
      tasks: _downloadDataService!.tasks,
    );
  }

  Future<void> _synchronizePowerManagement() async {
    if (!mounted || _downloadDataService == null) {
      return;
    }
    final settings = _settings ?? Provider.of<Settings>(context, listen: false);
    await _powerManagementService.synchronize(
      enabled: settings.keepAwake,
      tasks: _downloadDataService!.tasks,
    );
  }

  Future<void> _toggleWindowFromTray() async {
    if (!mounted) {
      return;
    }

    final isVisible = await windowManager.isVisible();
    if (!mounted) {
      return;
    }

    if (isVisible) {
      await windowManager.hide();
    } else {
      await windowManager.show();
      await windowManager.focus();
    }

    await _handleTrayStateChanged();
  }

  Future<void> _openAddTaskFromTray() async {
    await _navigateAndOpenAddTask();
    await _handleTrayStateChanged();
  }

  Future<void> _navigateAndOpenAddTask({String? initialUri}) async {
    if (!mounted) {
      return;
    }

    await windowManager.show();
    await windowManager.focus();
    if (!mounted) {
      return;
    }

    if (_selectedIndex != 0) {
      setState(() => _selectedIndex = 0);
      await _pageController.animateToPage(
        0,
        duration: const Duration(milliseconds: 677),
        curve: Curves.fastLinearToSlowEaseIn,
      );
    }

    if (!mounted) {
      return;
    }

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _downloadPageKey.currentState?.showAddTaskDialogFromExternalTrigger(
        initialUri: initialUri,
      );
    });
  }

  Future<void> _pauseAllTasksFromTray() async {
    if (!mounted) {
      return;
    }

    await _runTrayBulkAction(
      actionLabel: AppLocalizations.of(context)!.pauseTasks,
      shouldProcess: (task) =>
          (task.status == DownloadStatus.active ||
              task.status == DownloadStatus.waiting) &&
          task.taskStatus != 'paused',
      perform: (client, task) async {
        await client.pauseTask(task.id);
        return const BulkActionItemResult();
      },
    );
  }

  Future<void> _resumeAllTasksFromTray() async {
    if (!mounted) {
      return;
    }

    await _runTrayBulkAction(
      actionLabel: AppLocalizations.of(context)!.resumeTasks,
      shouldProcess: (task) =>
          task.status == DownloadStatus.waiting && task.taskStatus == 'paused',
      perform: (client, task) async {
        await client.unpauseTask(task.id);
        return const BulkActionItemResult();
      },
    );
  }

  Future<void> _runTrayBulkAction({
    required String actionLabel,
    required bool Function(DownloadTask task) shouldProcess,
    required TaskBulkItemAction perform,
  }) async {
    if (!mounted) {
      return;
    }

    final l10n = AppLocalizations.of(context)!;
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    final downloadDataService = Provider.of<DownloadDataService>(
      context,
      listen: false,
    );
    final connectedInstances = instanceManager.getConnectedInstances();

    if (connectedInstances.isEmpty) {
      _showTrayActionSnackBar(l10n.noConnectedInstancesForAction);
      return;
    }

    await downloadDataService.refreshTasks(connectedInstances);
    if (!mounted) {
      return;
    }

    final actionableTasks = downloadDataService.tasks
        .where(shouldProcess)
        .toList();
    if (actionableTasks.isEmpty) {
      _showTrayActionSnackBar(l10n.taskActionNoMatchingTasks(actionLabel));
      return;
    }

    final result = await TaskBulkActionService().run(
      instances: connectedInstances,
      tasks: actionableTasks,
      clientFactory: downloadDataService.clientFor,
      perform: perform,
    );

    await downloadDataService.refreshTasks(connectedInstances);

    if (!mounted) {
      return;
    }

    final message = result.indeterminateCount > 0
        ? l10n.taskActionSummaryIndeterminate(
            actionLabel,
            result.successCount,
            result.failureCount,
            result.indeterminateCount,
            0,
          )
        : result.failureCount == 0
        ? l10n.taskActionSummarySuccess(actionLabel, result.successCount)
        : l10n.taskActionSummaryDetailed(
            actionLabel,
            result.successCount,
            result.failureCount,
            0,
          );
    _showTrayActionSnackBar(message);
  }

  void _showTrayActionSnackBar(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), behavior: SnackBarBehavior.floating),
    );
  }

  @override
  void onWindowClose() async {
    final settings = Provider.of<Settings>(context, listen: false);
    if (!_isQuitting && settings.runMode == AppRunMode.tray) {
      await windowManager.hide();
    } else {
      await _quitApplication();
    }
  }

  @override
  void onWindowBlur() async {
    final settings = Provider.of<Settings>(context, listen: false);
    if (!settings.autoHideWindow || settings.runMode == AppRunMode.hideTray) {
      return;
    }

    _isWindowBlurred = true;
    _pendingAutoHideTimer?.cancel();
    _pendingAutoHideTimer = Timer(_autoHideWindowDelay, () async {
      if (!_isWindowBlurred) {
        return;
      }

      if (!mounted) {
        return;
      }

      if (AutoHideWindowService().isSuppressed) {
        return;
      }

      final isVisible = await windowManager.isVisible();
      if (!_isWindowBlurred) {
        return;
      }

      if (isVisible) {
        await windowManager.hide();
      }
    });
  }

  @override
  void onWindowFocus() {
    _isWindowBlurred = false;
    _pendingAutoHideTimer?.cancel();
    unawaited(_handleTrayStateChanged());
  }

  @override
  void onWindowEvent(String eventName) {
    if (eventName == 'hide' || eventName == 'show') {
      unawaited(_handleTrayStateChanged());
    }
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    if (index < 0 || index >= 3) return;

    setState(() => _selectedIndex = index);
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 677),
      curve: Curves.fastLinearToSlowEaseIn,
    );
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      DownloadPage(key: _downloadPageKey),
      const InstancePage(),
      const SettingsPage(),
    ];
    final l10n = AppLocalizations.of(context)!;
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // Side navigation rail
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onDestinationSelected,
                  labelType: NavigationRailLabelType.selected,
                  backgroundColor: colorScheme.surfaceContainer,
                  indicatorColor: colorScheme.surfaceContainerHighest,
                  leading: Container(
                    padding: const EdgeInsets.only(top: 16, bottom: 8),
                    alignment: Alignment.center,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: Image.asset(
                        kAppLogoAssetPath,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                  ),
                  destinations: [
                    NavigationRailDestination(
                      icon: const Icon(Icons.download_outlined),
                      selectedIcon: const Icon(Icons.download),
                      label: Text(l10n.download),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_remote_outlined),
                      selectedIcon: const Icon(Icons.settings_remote),
                      label: Text(l10n.instance),
                    ),
                    NavigationRailDestination(
                      icon: const Icon(Icons.settings_outlined),
                      selectedIcon: const Icon(Icons.settings),
                      label: Text(l10n.settings),
                    ),
                  ],
                ),
                // Main content area
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: pages.length,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, index) => pages[index],
                    onPageChanged: (value) {
                      FocusScope.of(context).unfocus();
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bottom status bar - Material You style
          const _StatusBar(),
        ],
      ),
    );
  }
}

class _StatusBar extends StatelessWidget {
  const _StatusBar();

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colorScheme = Theme.of(context).colorScheme;
    final summary = context.select<DownloadDataService, TaskSummary>(
      (service) => service.taskSummary,
    );
    final uploadSpeed = context.select<DownloadDataService, int>(
      (service) => service.totalUploadSpeed,
    );

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: colorScheme.surfaceContainer,
        border: Border(
          top: BorderSide(color: colorScheme.surfaceContainerHighest),
        ),
        boxShadow: [
          BoxShadow(
            color: colorScheme.shadow,
            offset: const Offset(0, -1),
            blurRadius: 3,
            spreadRadius: 0,
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Speed capsule: click to edit limits.
          Tooltip(
            message: l10n.speedCapsuleTooltip,
            child: InkWell(
              borderRadius: BorderRadius.circular(20),
              onTap: () => showQuickSpeedLimitDialog(context),
              child: Chip(
                avatar: const Icon(Icons.speed, size: 16),
                label: Text(
                  '${l10n.downloadShort} ${formatSpeed(summary.speed)}  '
                  '${l10n.uploadShort} ${formatSpeed(uploadSpeed)}',
                ),
                backgroundColor: colorScheme.surfaceContainerHighest,
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              ),
            ),
          ),
          Chip(
            label: Text(l10n.activeTasks(summary.active.toString())),
            avatar: const Icon(Icons.task_alt, size: 16),
            backgroundColor: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
          Chip(
            label: Text(l10n.waitingTasks(summary.waiting.toString())),
            avatar: const Icon(Icons.pending, size: 16),
            backgroundColor: colorScheme.surfaceContainerHighest,
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
          ),
        ],
      ),
    );
  }
}
