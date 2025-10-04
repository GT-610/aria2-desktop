import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/download_page.dart';
import 'pages/instance_list_page.dart';
import 'pages/settings_page.dart';
import 'models/global_stat.dart';
import 'services/instance_manager.dart';
import 'models/settings.dart';
import 'services/aria2_rpc_client.dart';
import 'models/aria2_instance.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (context) => Settings()),
      ],
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
      theme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.light,
            ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      darkTheme: ThemeData(
            useMaterial3: true,
            colorScheme: ColorScheme.fromSeed(
              seedColor: Colors.blue,
              brightness: Brightness.dark,
            ),
        buttonTheme: ButtonThemeData(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
        ),
      ),
      themeMode: settings.themeMode,
      home: MultiProvider(
        providers: [
          ChangeNotifierProvider(create: (context) => InstanceManager()),
        ],
        child: const _HomeWrapper(),
      ),
    );
  }
}

class _HomeWrapper extends StatelessWidget {
  const _HomeWrapper();

  @override
  Widget build(BuildContext context) {
    // Initialize instance manager
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    final settings = Provider.of<Settings>(context, listen: false);
    
    // Ensure settings are loaded
    final initializationFuture = Future(() async {
      // Wait for instance manager initialization
      await instanceManager.initialize();
      
      // Try to connect to active instance if auto-connect is enabled
      if (settings.autoConnectLastInstance && instanceManager.activeInstance != null) {
        try {
          // Attempt to connect to active instance
          final activeInstance = instanceManager.activeInstance!;
          final client = Aria2RpcClient(activeInstance);
          
          // Validate connection by getting version info
          final version = await client.getVersion();
          
          // Update instance connection status and version
          final updatedInstance = activeInstance.copyWith(
            version: version,
            status: ConnectionStatus.connected,
          );
          
          // Update instance information
          await instanceManager.updateInstance(updatedInstance);
        } catch (e) {
          print('Auto-connection failed: $e');
        }
      }
    });
    
    return FutureBuilder(
      future: initializationFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        return const MainWindow();
      },
    );
  }
}

class MainWindow extends StatefulWidget {
  const MainWindow({super.key});

  @override
  State<MainWindow> createState() => _MainWindowState();
}

class _MainWindowState extends State<MainWindow> {
  int _selectedIndex = 0;
  final GlobalStat _globalStat = GlobalStat();

  @override
  Widget build(BuildContext context) {
    final instanceManager = Provider.of<InstanceManager>(context);
    
    List<Widget> _pages = [
      const DownloadPage(),
      InstanceListPage(instanceManager: instanceManager),
      const SettingsPage(),
    ];

    void _onItemTapped(int index) {
      setState(() {
        _selectedIndex = index;
      });
    }

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
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.selected,
                  backgroundColor: colorScheme.surfaceContainer,
                  indicatorColor: colorScheme.surfaceVariant,
                  elevation: null,
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
                      child: Icon(Icons.download_done, size: 28, color: colorScheme.primary),
                    ),
                  ),
                  destinations: const [
                    NavigationRailDestination(
                      icon: Icon(Icons.download_outlined),
                      selectedIcon: Icon(Icons.download),
                      label: Text('下载'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_remote_outlined),
                      selectedIcon: Icon(Icons.settings_remote),
                      label: Text('实例'),
                    ),
                    NavigationRailDestination(
                      icon: Icon(Icons.settings_outlined),
                      selectedIcon: Icon(Icons.settings),
                      label: Text('设置'),
                    ),
                  ],
                ),
                // Main content area
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
          // Bottom status bar - Material You style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: colorScheme.surfaceContainer,
              border: Border(top: BorderSide(color: colorScheme.surfaceVariant)),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  offset: const Offset(0, -1),
                  blurRadius: 2,
                ),
              ],
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Chip(
                  label: Text('总速度: ${_formatSpeed(_globalStat.downloadSpeed)}'),
                  avatar: const Icon(Icons.speed, size: 16),
                  backgroundColor: colorScheme.surfaceVariant,
                  padding: const EdgeInsets.all(4),
                ),
                Chip(
                  label: Text('活跃任务: ${_globalStat.activeTasks}'),
                  avatar: const Icon(Icons.task_alt, size: 16),
                  backgroundColor: colorScheme.surfaceVariant,
                  padding: const EdgeInsets.all(4),
                ),
                Chip(
                  label: Text('等待任务: ${_globalStat.waitingTasks}'),
                  avatar: const Icon(Icons.pending, size: 16),
                  backgroundColor: colorScheme.surfaceVariant,
                  padding: const EdgeInsets.all(4),
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
      return '${bytesPerSecond} B/s';
    } else if (bytesPerSecond < 1024 * 1024) {
      return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
    } else {
      return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
    }
  }
}