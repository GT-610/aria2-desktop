import 'package:fl_lib/fl_lib.dart' as fl;
import 'package:fl_lib/fl_lib.dart' show ChineseThemeData;
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:window_manager/window_manager.dart';
import 'generated/l10n/l10n.dart';
import 'models/aria2_instance.dart';
import 'models/settings.dart';
import 'pages/download_page/download_page.dart';
import 'pages/download_page/enums.dart';
import 'pages/download_page/models/download_task.dart';
import 'pages/instance_page/instance_page.dart';
import 'pages/settings_page/settings_page.dart';
import 'services/download_data_service.dart';
import 'services/instance_manager.dart';
import 'services/settings_service.dart';
import 'services/system_tray_service.dart';
import 'services/aria2_rpc_client.dart';
import 'utils/logging.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [ChangeNotifierProvider(create: (context) => Settings())],
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
  void initState() {
    super.initState();
    // Load settings
    Provider.of<Settings>(context, listen: false).loadSettings();
  }

  @override
  Widget build(BuildContext context) {
    final settings = Provider.of<Settings>(context);

    return MaterialApp(
      title: 'Aria2 Desktop',
      locale: settings.locale,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.light,
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ).fixWindowsFont,
      darkTheme: ThemeData(
        useMaterial3: true,
        colorScheme: ColorScheme.fromSeed(
          seedColor: settings.primaryColor,
          brightness: Brightness.dark,
        ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
        ),
      ).fixWindowsFont,
      themeMode: settings.themeMode,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => InstanceManager()),
          ChangeNotifierProxyProvider<InstanceManager, DownloadDataService>(
            create: (context) => DownloadDataService(),
            update: (context, instanceManager, downloadDataService) {
              // Ensure DownloadDataService can access InstanceManager
              return downloadDataService!;
            },
          ),
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

class _HomeWrapperState extends State<_HomeWrapper> {
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initialize();
  }

  Future<void> _initialize() async {
    // Initialize instance manager
    final instanceManager = Provider.of<InstanceManager>(
      context,
      listen: false,
    );
    await instanceManager.initialize();

    // Initialize settings service with current instance
    final settings = Provider.of<Settings>(context, listen: false);
    final settingsService = Provider.of<SettingsService>(
      context,
      listen: false,
    );
    settingsService.initialize(settings);

    // Check if built-in instance failed to connect
    final builtinInstance = instanceManager.getInstanceById('builtin');
    if (builtinInstance == null) {
      throw Exception('Built-in instance not found');
    }

    if (builtinInstance.status == ConnectionStatus.failed) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _showBuiltinConnectionFailedDialog(context);
      });
    }

    setState(() {
      _isInitialized = true;
    });
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

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) {
      return Scaffold(body: Center(child: fl.SizedLoading.medium));
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
  int _selectedIndex = 0;
  late final PageController _pageController;
  bool _switchingPage = false;
  DownloadDataService? _downloadDataService;

  @override
  void initState() {
    super.initState();
    _pageController = PageController(initialPage: _selectedIndex);
    windowManager.addListener(this);
    _initSystemTrayCallbacks();
  }

  @override
  void dispose() {
    _downloadDataService?.removeListener(_handleDownloadNotifications);
    _pageController.dispose();
    windowManager.removeListener(this);
    final systemTrayService = SystemTrayService();
    systemTrayService.setOnPauseAll(null);
    systemTrayService.setOnResumeAll(null);
    super.dispose();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final nextDownloadDataService = Provider.of<DownloadDataService>(
      context,
      listen: false,
    );
    if (_downloadDataService != nextDownloadDataService) {
      _downloadDataService?.removeListener(_handleDownloadNotifications);
      _downloadDataService = nextDownloadDataService;
      _downloadDataService?.addListener(_handleDownloadNotifications);
    }
  }

  Future<void> _initSystemTrayCallbacks() async {
    final systemTrayService = SystemTrayService();
    systemTrayService.setOnShowWindow(() async {
      await windowManager.show();
      await windowManager.focus();
    });
    systemTrayService.setOnQuitApp(() async {
      await windowManager.close();
    });
    systemTrayService.setOnPauseAll(_pauseAllTasksFromTray);
    systemTrayService.setOnResumeAll(_resumeAllTasksFromTray);
  }

  void _handleDownloadNotifications() {
    if (!mounted || _downloadDataService == null) {
      return;
    }

    final notifications = _downloadDataService!.takePendingNotifications();
    if (notifications.isEmpty) {
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
      perform: (client, taskId) => client.pauseTask(taskId),
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
      perform: (client, taskId) => client.unpauseTask(taskId),
    );
  }

  Future<void> _runTrayBulkAction({
    required String actionLabel,
    required bool Function(DownloadTask task) shouldProcess,
    required Future<String> Function(Aria2RpcClient client, String taskId)
    perform,
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

    final actionableTasks = downloadDataService.tasks
        .where(shouldProcess)
        .toList();
    if (actionableTasks.isEmpty) {
      _showTrayActionSnackBar(l10n.taskActionNoMatchingTasks(actionLabel));
      return;
    }

    final tasksByInstance = <String, List<DownloadTask>>{};
    for (final task in actionableTasks) {
      tasksByInstance.putIfAbsent(task.instanceId, () => []).add(task);
    }

    var successCount = 0;
    var failCount = 0;
    for (final instance in connectedInstances) {
      final instanceTasks = tasksByInstance[instance.id];
      if (instanceTasks == null || instanceTasks.isEmpty) {
        continue;
      }

      final client = Aria2RpcClient(instance);
      try {
        for (final task in instanceTasks) {
          try {
            await perform(client, task.id);
            successCount++;
          } catch (e, stackTrace) {
            failCount++;
            this.e(
              'Tray action failed for task ${task.id} on instance ${instance.name}',
              error: e,
              stackTrace: stackTrace,
            );
          }
        }
      } finally {
        client.close();
      }
    }

    await downloadDataService.refreshTasks(connectedInstances);

    if (!mounted) {
      return;
    }

    final message = failCount == 0
        ? l10n.taskActionSummarySuccess(actionLabel, successCount)
        : l10n.taskActionSummaryDetailed(
            actionLabel,
            successCount,
            failCount,
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
    if (settings.minimizeToTray) {
      await windowManager.hide();
    } else {
      await windowManager.destroy();
      SystemTrayService().destroy();
    }
  }

  void _onDestinationSelected(int index) {
    if (_selectedIndex == index) return;
    if (index < 0 || index >= 3) return;
    setState(() => _selectedIndex = index);
    _switchingPage = true;
    _pageController
        .animateToPage(
          index,
          duration: const Duration(milliseconds: 677),
          curve: Curves.fastLinearToSlowEaseIn,
        )
        .then((_) {
          if (mounted) {
            _switchingPage = false;
          }
        });
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      const DownloadPage(),
      const InstancePage(),
      const SettingsPage(),
    ];
    final tasks = context.watch<DownloadDataService>().tasks;
    final activeTasks = tasks
        .where((task) => task.status == DownloadStatus.active)
        .toList();
    final waitingTasks = tasks
        .where((task) => task.status == DownloadStatus.waiting)
        .length;
    final totalDownloadSpeed = activeTasks.fold<int>(
      0,
      (sum, task) => sum + task.downloadSpeedBytes,
    );
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
                    child: Container(
                      width: 48,
                      height: 48,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(12),
                        color: colorScheme.primaryContainer,
                      ),
                      alignment: Alignment.center,
                      // Icon placeholder - will be replaced with actual app icon
                      child: Icon(
                        Icons.download_done,
                        size: 28,
                        color: colorScheme.primary,
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
                // Main content area with page transition animation
                Expanded(
                  child: PageView.builder(
                    controller: _pageController,
                    itemCount: 3,
                    physics: const NeverScrollableScrollPhysics(),
                    itemBuilder: (_, index) => pages[index],
                    onPageChanged: (value) {
                      if (!_switchingPage) {
                        setState(() => _selectedIndex = value);
                      }
                    },
                  ),
                ),
              ],
            ),
          ),
          // Bottom status bar - Material You style
          Container(
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
                Chip(
                  label: Text(
                    l10n.totalSpeed(_formatSpeed(totalDownloadSpeed)),
                  ),
                  avatar: const Icon(Icons.speed, size: 16),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                Chip(
                  label: Text(l10n.activeTasks(activeTasks.length.toString())),
                  avatar: const Icon(Icons.task_alt, size: 16),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
                Chip(
                  label: Text(l10n.waitingTasks(waitingTasks.toString())),
                  avatar: const Icon(Icons.pending, size: 16),
                  backgroundColor: colorScheme.surfaceContainerHighest,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatSpeed(int bytesPerSecond) {
    if (bytesPerSecond < 1024) {
      return '$bytesPerSecond B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }
}
