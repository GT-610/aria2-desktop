import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'pages/download_page.dart';
import 'pages/instance_list_page.dart';
import 'pages/settings_page.dart';
import 'models/global_stat.dart';
import 'services/instance_manager.dart';

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
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
      themeMode: ThemeMode.system,
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
    // 初始化实例管理器
    final instanceManager = Provider.of<InstanceManager>(context, listen: false);
    
    return FutureBuilder(
      future: instanceManager.initialize(),
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
      appBar: AppBar(
        title: const Text('Aria2 Desktop'),
        elevation: 0,
        scrolledUnderElevation: 4,
        centerTitle: false,
      ),
      body: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                // 侧边导航栏 - Material You 风格
                NavigationRail(
                  selectedIndex: _selectedIndex,
                  onDestinationSelected: _onItemTapped,
                  labelType: NavigationRailLabelType.selected,
                  backgroundColor: colorScheme.surfaceContainer,
                  indicatorColor: colorScheme.surfaceVariant,
                  elevation: null,
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
                // 主内容区域
                Expanded(
                  child: _pages[_selectedIndex],
                ),
              ],
            ),
          ),
          // 底部状态栏 - Material You 风格
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