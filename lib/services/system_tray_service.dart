import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/logging.dart';

class SystemTrayService extends ChangeNotifier with Loggable, TrayListener {
  static SystemTrayService? _instance;
  bool _isInitialized = false;
  // ignore: unused_field - intended for future use in minimizeToTray()
  bool _minimizeToTray = true;
  VoidCallback? _onShowWindow;
  VoidCallback? _onQuitApp;

  factory SystemTrayService() {
    _instance ??= SystemTrayService._internal();
    return _instance!;
  }

  SystemTrayService._internal();

  void setMinimizeToTray(bool value) {
    _minimizeToTray = value;
  }

  void setOnShowWindow(VoidCallback callback) {
    _onShowWindow = callback;
  }

  void setOnQuitApp(VoidCallback callback) {
    _onQuitApp = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initSystemTray();
      _isInitialized = true;
      i('System tray initialized successfully');
    } catch (err, stackTrace) {
      this.e(
        'Failed to initialize system tray',
        error: err,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initSystemTray() async {
    String iconPath;

    if (Platform.isWindows) {
      iconPath = '.trae/references/Motrix/static/mo-tray-colorful-normal.ico';
    } else if (Platform.isMacOS) {
      iconPath = '.trae/references/Motrix/static/mo-tray-colorful-normal.png';
    } else {
      iconPath = '.trae/references/Motrix/static/mo-tray-colorful-normal.png';
    }

    await trayManager.setIcon(iconPath);
    await trayManager.setToolTip('Aria2 Desktop - Aria2 下载管理器');

    final menu = Menu(
      items: [
        MenuItem(key: 'show_window', label: '显示主窗口'),
        MenuItem.separator(),
        MenuItem(key: 'start_download', label: '开始下载'),
        MenuItem(key: 'pause_all', label: '暂停全部'),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: '退出'),
      ],
    );

    await trayManager.setContextMenu(menu);

    trayManager.addListener(this);
  }

  @override
  void onTrayIconMouseDown() {
    if (Platform.isWindows) {
      _onShowWindow?.call();
    }
  }

  @override
  void onTrayIconRightMouseDown() {
    trayManager.popUpContextMenu();
  }

  @override
  void onTrayMenuItemClick(MenuItem menuItem) {
    switch (menuItem.key) {
      case 'show_window':
        _onShowWindow?.call();
        break;
      case 'start_download':
        d('Tray menu: Start downloads');
        break;
      case 'pause_all':
        d('Tray menu: Pause all');
        break;
      case 'quit':
        _onQuitApp?.call();
        break;
    }
  }

  Future<void> updateTooltip(String tooltip) async {
    if (!_isInitialized) return;
    try {
      await trayManager.setToolTip(tooltip);
    } catch (e) {
      w('Failed to update tray tooltip', error: e);
    }
  }

  Future<void> showNotification(String title, String message) async {
    if (!_isInitialized) return;
    d('Tray notification: $title - $message');
  }

  void destroy() {
    if (_isInitialized) {
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
      i('System tray destroyed');
    }
  }

  @override
  void dispose() {
    destroy();
    super.dispose();
  }
}

class WindowManagerService with Loggable {
  static WindowManagerService? _instance;

  factory WindowManagerService() {
    _instance ??= WindowManagerService._internal();
    return _instance!;
  }

  WindowManagerService._internal() {}

  Future<void> initialize() async {
    await windowManager.ensureInitialized();

    const windowOptions = WindowOptions(
      size: Size(1200, 800),
      minimumSize: Size(800, 600),
      center: true,
      backgroundColor: Color(0x00000000),
      skipTaskbar: false,
      titleBarStyle: TitleBarStyle.normal,
      title: 'Aria2 Desktop',
    );

    await windowManager.waitUntilReadyToShow(windowOptions, () async {
      await windowManager.show();
      await windowManager.focus();
    });

    i('Window manager initialized');
  }

  Future<void> showWindow() async {
    await windowManager.show();
    await windowManager.focus();
  }

  Future<void> hideWindow() async {
    await windowManager.hide();
  }

  Future<void> minimizeToTray() async {
    await windowManager.hide();
  }

  Future<void> close() async {
    await windowManager.close();
  }

  Future<bool> isVisible() async {
    return await windowManager.isVisible();
  }

  Future<void> setPreventClose(bool prevent) async {
    await windowManager.setPreventClose(prevent);
  }
}
