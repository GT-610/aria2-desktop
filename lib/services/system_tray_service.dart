import 'dart:io';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:local_notifier/local_notifier.dart';
import 'package:tray_manager/tray_manager.dart';
import 'package:window_manager/window_manager.dart';
import '../utils/logging.dart';

class SystemTrayService extends ChangeNotifier with Loggable, TrayListener {
  static SystemTrayService? _instance;
  bool _isInitialized = false;
  bool _notificationsInitialized = false;
  // ignore: unused_field - intended for future use in minimizeToTray()
  bool _minimizeToTray = true;
  VoidCallback? _onShowWindow;
  VoidCallback? _onQuitApp;
  Future<void> Function()? _onPauseAll;
  Future<void> Function()? _onResumeAll;
  final Set<LocalNotification> _activeNotifications = <LocalNotification>{};

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

  void setOnPauseAll(Future<void> Function()? callback) {
    _onPauseAll = callback;
  }

  void setOnResumeAll(Future<void> Function()? callback) {
    _onResumeAll = callback;
  }

  Future<void> initialize() async {
    if (_isInitialized) return;

    try {
      await _initNotifications();
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

  Future<void> _initNotifications() async {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    try {
      await localNotifier.setup(
        appName: 'Aria2 Desktop',
        shortcutPolicy: ShortcutPolicy.requireCreate,
      );
      _notificationsInitialized = true;
    } catch (e, stackTrace) {
      w(
        'Failed to initialize desktop notifications',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Future<void> _initSystemTray() async {
    String iconPath;

    if (Platform.isWindows) {
      iconPath = 'assets/logo/app.ico';
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
        MenuItem(key: 'resume_all', label: '继续全部'),
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
      case 'resume_all':
        _onResumeAll?.call();
        break;
      case 'pause_all':
        _onPauseAll?.call();
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
    if (!_notificationsInitialized) {
      return;
    }

    final notification = LocalNotification(title: title, body: message);
    _activeNotifications.add(notification);
    notification.onClick = () {
      _onShowWindow?.call();
      notification.close();
    };
    notification.onClose = (_) {
      _activeNotifications.remove(notification);
    };

    try {
      await notification.show();
    } catch (e, stackTrace) {
      _activeNotifications.remove(notification);
      w(
        'Failed to show desktop notification',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  void destroy() {
    if (_isInitialized) {
      for (final notification in _activeNotifications.toList()) {
        notification.close();
      }
      _activeNotifications.clear();
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
      _notificationsInitialized = false;
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
