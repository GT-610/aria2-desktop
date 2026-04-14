import 'dart:async';
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
  Future<void>? _initializingTray;
  int _trayLifecycleGeneration = 0;
  // ignore: unused_field - intended for future use in minimizeToTray()
  bool _minimizeToTray = true;
  VoidCallback? _onShowWindow;
  VoidCallback? _onQuitApp;
  Future<void> Function()? _onPauseAll;
  Future<void> Function()? _onResumeAll;
  final Set<LocalNotification> _activeNotifications = <LocalNotification>{};
  String _statusLabel = 'Aria2 Desktop';
  String _showWindowLabel = 'Show Window';
  String _resumeAllLabel = 'Resume All';
  String _pauseAllLabel = 'Pause All';
  String _quitLabel = 'Quit';
  bool _resumeAllDisabled = false;
  bool _pauseAllDisabled = false;

  factory SystemTrayService() {
    _instance ??= SystemTrayService._internal();
    return _instance!;
  }

  SystemTrayService._internal();

  bool get isInitialized => _isInitialized;
  bool get notificationsInitialized => _notificationsInitialized;

  void setMinimizeToTray(bool value) {
    _minimizeToTray = value;
  }

  void setOnShowWindow(VoidCallback? callback) {
    _onShowWindow = callback;
  }

  void setOnQuitApp(VoidCallback? callback) {
    _onQuitApp = callback;
  }

  void setOnPauseAll(Future<void> Function()? callback) {
    _onPauseAll = callback;
  }

  void setOnResumeAll(Future<void> Function()? callback) {
    _onResumeAll = callback;
  }

  Future<void> updateMenuState({
    required String statusLabel,
    required String showWindowLabel,
    required String resumeAllLabel,
    required String pauseAllLabel,
    required String quitLabel,
    required bool resumeAllDisabled,
    required bool pauseAllDisabled,
  }) async {
    final hasChanged =
        _statusLabel != statusLabel ||
        _showWindowLabel != showWindowLabel ||
        _resumeAllLabel != resumeAllLabel ||
        _pauseAllLabel != pauseAllLabel ||
        _quitLabel != quitLabel ||
        _resumeAllDisabled != resumeAllDisabled ||
        _pauseAllDisabled != pauseAllDisabled;

    _statusLabel = statusLabel;
    _showWindowLabel = showWindowLabel;
    _resumeAllLabel = resumeAllLabel;
    _pauseAllLabel = pauseAllLabel;
    _quitLabel = quitLabel;
    _resumeAllDisabled = resumeAllDisabled;
    _pauseAllDisabled = pauseAllDisabled;

    if (!_isInitialized || !hasChanged) {
      return;
    }

    try {
      await trayManager.setContextMenu(_buildMenu());
    } catch (e, stackTrace) {
      w('Failed to update tray menu state', error: e, stackTrace: stackTrace);
    }
  }

  Future<void> initialize() async {
    while (true) {
      if (_isInitialized) {
        return;
      }

      final inFlightInitialization = _initializingTray;
      if (inFlightInitialization != null) {
        await inFlightInitialization;
        if (_isInitialized) {
          return;
        }
        continue;
      }

      final generation = ++_trayLifecycleGeneration;
      final initialization = _initializeTray(generation);
      _initializingTray = initialization;
      try {
        await initialization;
      } finally {
        if (identical(_initializingTray, initialization)) {
          _initializingTray = null;
        }
      }

      if (_isInitialized) {
        return;
      }
    }
  }

  Future<void> _initializeTray(int generation) async {
    try {
      await initializeNotifications();
      await _initSystemTray();

      if (generation != _trayLifecycleGeneration) {
        await _cleanupTrayArtifacts();
        return;
      }

      trayManager.addListener(this);
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

  Future<void> initializeNotifications() async {
    if (_notificationsInitialized) {
      return;
    }

    await _initNotifications();
  }

  Future<void> _initNotifications() async {
    if (kIsWeb ||
        !(Platform.isWindows || Platform.isLinux || Platform.isMacOS)) {
      return;
    }

    try {
      await localNotifier.setup(
        appName: 'Aria2 Desktop',
        // Shortcut creation belongs to an external installer, not the app.
        shortcutPolicy: ShortcutPolicy.ignore,
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

    await trayManager.setContextMenu(_buildMenu());
  }

  Future<void> _cleanupTrayArtifacts() async {
    try {
      await trayManager.destroy();
    } catch (e, stackTrace) {
      w(
        'Failed to clean up stale tray initialization',
        error: e,
        stackTrace: stackTrace,
      );
    }
  }

  Menu _buildMenu() {
    return Menu(
      items: [
        MenuItem(label: _statusLabel, disabled: true),
        MenuItem.separator(),
        MenuItem(key: 'show_window', label: _showWindowLabel),
        MenuItem.separator(),
        MenuItem(
          key: 'resume_all',
          label: _resumeAllLabel,
          disabled: _resumeAllDisabled,
        ),
        MenuItem(
          key: 'pause_all',
          label: _pauseAllLabel,
          disabled: _pauseAllDisabled,
        ),
        MenuItem.separator(),
        MenuItem(key: 'quit', label: _quitLabel),
      ],
    );
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
    if (!_notificationsInitialized) {
      return;
    }
    d('Tray notification: $title - $message');

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
    _trayLifecycleGeneration++;

    if (_isInitialized) {
      trayManager.removeListener(this);
      trayManager.destroy();
      _isInitialized = false;
      i('System tray destroyed');
      return;
    }

    if (_initializingTray != null) {
      unawaited(_cleanupTrayArtifacts());
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
