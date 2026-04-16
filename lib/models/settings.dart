import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import '../utils/logging.dart';
import 'dart:convert' show jsonDecode, jsonEncode;

enum AppLogLevel { debug, info, warning, error }

enum AppRunMode { standard, tray, hideTray }

class Settings extends ChangeNotifier with Loggable {
  // Global settings
  bool _autoStart = false; // Auto-run on system startup
  bool _minimizeToTray = true; // Legacy migration field
  AppRunMode _runMode = AppRunMode.tray; // Desktop shell mode
  bool _autoHideWindow = false; // Hide window when it loses focus
  bool _showTraySpeed = true; // Show download speed in tray tooltip
  bool _taskNotification = true; // Show task completion/failure notifications
  bool _protocolMagnetEnabled = false; // Handle magnet:// links
  bool _protocolThunderEnabled = false; // Handle thunder:// links
  bool _skipDeleteConfirm = false; // Skip delete confirmation dialog
  bool _resumeAllOnLaunch = false; // Resume paused tasks on app launch
  bool _showDownloadsAfterAdd =
      true; // Focus downloading view after adding tasks
  bool _showProgressBar = true; // Show progress bars in task list
  bool _isLoaded = false; // Whether settings have finished loading

  // Appearance settings
  ThemeMode _themeMode = ThemeMode.system; // Appearance settings
  // Default theme color
  Color _primaryColor = Colors.blue; // Default theme color
  String? _customColorCode; // Custom color code
  // Log settings
  AppLogLevel _logLevel = AppLogLevel.info; // Log level

  // Locale settings
  Locale? _locale; // App locale

  // Built-in Aria2 instance settings
  int _rpcListenPort = 16800; // RPC listen port
  String _rpcSecret = ''; // RPC secret

  // Transfer settings
  int _maxConcurrentDownloads = 5; // Max concurrent downloads
  int _maxConnectionPerServer = 16; // Max connections per server
  int _split = 16; // Split downloads into N parts
  bool _continueDownloads = true; // Continue downloads

  // Speed settings
  int _maxOverallDownloadLimit =
      0; // Global download speed limit (0 = unlimited)
  int _maxOverallUploadLimit = 0; // Global upload speed limit (0 = unlimited)

  // BT settings
  bool _btSaveMetadata = true; // Save BT metadata
  bool _btForceEncryption = false; // Force BT encryption
  bool _btLoadSavedMetadata = true; // Load saved BT metadata
  bool _keepSeeding = false; // Keep seeding after download completion
  double _seedRatio = 1.0; // Seed ratio
  int _seedTime = 60; // Seed time in minutes
  String _btListenPort = '6881-6999'; // BT listen port or port range
  String _btTracker = ''; // BT tracker servers
  String _btExcludeTracker = ''; // Exclude trackers

  // Advanced settings
  bool _proxyEnabled = false; // Whether proxy settings are enabled
  String _allProxy = ''; // All proxy setting
  String _noProxy = ''; // No proxy setting
  int _dhtListenPort = 26701; // DHT listen port
  bool _enableDht6 = true; // Enable DHT6
  bool _enableUpnp = true; // Enable UPnP/NAT-PMP port mapping
  String _sessionPath = ''; // Custom aria2 session file path
  String _logPath = ''; // Custom aria2 log file path
  bool _autoSyncTracker = true; // Auto sync tracker list
  int _lastSyncTrackerTime = 0; // Last successful tracker sync time
  String _trackerSource =
      'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt'; // Selected tracker source
  bool _autoFileRenaming = true; // Auto rename files
  bool _allowOverwrite = false; // Allow overwrite
  String _userAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36'; // User agent

  // Settings file name
  final String _settingsFileName = 'settings.json';

  // Constructor initialization
  Settings() {
    i('Settings instance created');
  }

  /// Get program data directory
  Directory _getDataDirectory() {
    // Get the executable path
    String executablePath = Platform.resolvedExecutable;
    Directory executableDir = Directory(executablePath).parent;

    // Data directory: data/config relative to executable
    String dataDirPath = '${executableDir.path}/data';
    Directory dataDir = Directory(dataDirPath);
    if (!dataDir.existsSync()) {
      this.d('Creating data directory: $dataDirPath');
      dataDir.createSync(recursive: true);
    }

    return dataDir;
  }

  String _defaultBuiltinLogFilePath() {
    final executablePath = Platform.resolvedExecutable;
    final executableDir = Directory(executablePath).parent;
    return '${executableDir.path}/data/core/aria2.log';
  }

  void _assignDefaultSettings() {
    _autoStart = false;
    _minimizeToTray = true;
    _runMode = AppRunMode.tray;
    _autoHideWindow = false;
    _showTraySpeed = true;
    _taskNotification = true;
    _protocolMagnetEnabled = false;
    _protocolThunderEnabled = false;
    _skipDeleteConfirm = false;
    _resumeAllOnLaunch = false;
    _showDownloadsAfterAdd = true;
    _showProgressBar = true;
    _themeMode = ThemeMode.system;
    _primaryColor = Colors.blue;
    _customColorCode = null;
    _logLevel = AppLogLevel.info;
    _locale = null;

    // Built-in Aria2 instance settings defaults
    // Connection settings
    _rpcListenPort = 16800;
    _rpcSecret = '';

    // Transfer settings
    _maxConcurrentDownloads = 5;
    _maxConnectionPerServer = 16;
    _split = 16;
    _continueDownloads = true;

    // Speed settings
    _maxOverallDownloadLimit = 0;
    _maxOverallUploadLimit = 0;

    // BT settings
    _btSaveMetadata = true;
    _btForceEncryption = false;
    _btLoadSavedMetadata = true;
    _keepSeeding = false;
    _seedRatio = 1.0;
    _seedTime = 60;
    _btListenPort = '6881-6999';
    _btTracker = '';
    _btExcludeTracker = '';

    // Advanced settings
    _proxyEnabled = false;
    _allProxy = '';
    _noProxy = '';
    _dhtListenPort = 26701;
    _enableDht6 = true;
    _enableUpnp = true;
    _sessionPath = '';
    _logPath = '';
    _autoSyncTracker = true;
    _lastSyncTrackerTime = 0;
    _trackerSource =
        'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt';
    _autoFileRenaming = true;
    _allowOverwrite = false;
    _userAgent =
        'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';
  }

  /// Get settings file path
  String _getSettingsFilePath() {
    final dataDir = _getDataDirectory();
    final configDir = Directory('${dataDir.path}/config');
    if (!configDir.existsSync()) {
      this.d('Creating config directory: ${configDir.path}');
      configDir.createSync(recursive: true);
    }
    return '${configDir.path}/$_settingsFileName';
  }

  String _normalizeBtTracker(String trackers) {
    return trackers
        .split(RegExp(r'[\n\r,]+'))
        .map((tracker) => tracker.trim())
        .where((tracker) => tracker.isNotEmpty)
        .join(',');
  }

  // Getters
  bool get autoStart => _autoStart;
  bool get minimizeToTray => _minimizeToTray;
  AppRunMode get runMode => _runMode;
  bool get autoHideWindow => _autoHideWindow;
  bool get showTraySpeed => _showTraySpeed;
  bool get taskNotification => _taskNotification;
  bool get protocolMagnetEnabled => _protocolMagnetEnabled;
  bool get protocolThunderEnabled => _protocolThunderEnabled;
  bool get skipDeleteConfirm => _skipDeleteConfirm;
  bool get resumeAllOnLaunch => _resumeAllOnLaunch;
  bool get showDownloadsAfterAdd => _showDownloadsAfterAdd;
  bool get showProgressBar => _showProgressBar;
  bool get isLoaded => _isLoaded;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String? get customColorCode => _customColorCode;
  AppLogLevel get logLevel => _logLevel;
  String get logLevelString => _logLevel.name;
  Locale? get locale => _locale;

  // Built-in Aria2 instance getters
  // Connection settings
  int get rpcListenPort => _rpcListenPort;
  String get rpcSecret => _rpcSecret;

  // Transfer settings
  int get maxConcurrentDownloads => _maxConcurrentDownloads;
  int get maxConnectionPerServer => _maxConnectionPerServer;
  int get split => _split;
  bool get continueDownloads => _continueDownloads;

  // Speed settings
  int get maxOverallDownloadLimit => _maxOverallDownloadLimit;
  int get maxOverallUploadLimit => _maxOverallUploadLimit;

  // BT settings
  bool get btSaveMetadata => _btSaveMetadata;
  bool get btForceEncryption => _btForceEncryption;
  bool get btLoadSavedMetadata => _btLoadSavedMetadata;
  bool get keepSeeding => _keepSeeding;
  double get seedRatio => _seedRatio;
  int get seedTime => _seedTime;
  String get btListenPort => _btListenPort;
  String get btTracker => _btTracker;
  String get btExcludeTracker => _btExcludeTracker;

  // Advanced settings
  bool get proxyEnabled => _proxyEnabled;
  String get allProxy => _allProxy;
  String get noProxy => _noProxy;
  int get dhtListenPort => _dhtListenPort;
  bool get enableDht6 => _enableDht6;
  bool get enableUpnp => _enableUpnp;
  String get sessionPath => _sessionPath;
  String get logPath => _logPath;
  bool get autoSyncTracker => _autoSyncTracker;
  int get lastSyncTrackerTime => _lastSyncTrackerTime;
  String get trackerSource => _trackerSource;
  bool get autoFileRenaming => _autoFileRenaming;
  bool get allowOverwrite => _allowOverwrite;
  String get userAgent => _userAgent;
  String get dataDirectoryPath => _getDataDirectory().path;
  String get effectiveBuiltinLogFilePath {
    final configuredPath = _logPath.trim();
    return configuredPath.isNotEmpty
        ? configuredPath
        : _defaultBuiltinLogFilePath();
  }

  // Load all settings from JSON file
  Future<void> loadSettings() async {
    try {
      this.i('Loading settings from JSON file...');
      final filePath = _getSettingsFilePath();
      final file = File(filePath);

      if (file.existsSync()) {
        final jsonString = await file.readAsString();
        final settingsMap = jsonDecode(jsonString);

        // Global settings
        _autoStart = settingsMap['autoStart'] ?? false;
        _minimizeToTray = settingsMap['minimizeToTray'] ?? true;
        final runModeValue = settingsMap['runMode'];
        if (runModeValue != null) {
          _runMode = AppRunMode.values.firstWhere(
            (mode) => mode.name == runModeValue,
            orElse: () => AppRunMode.tray,
          );
        } else {
          _runMode = _minimizeToTray ? AppRunMode.tray : AppRunMode.standard;
        }
        _autoHideWindow = settingsMap['autoHideWindow'] ?? false;
        _showTraySpeed = settingsMap['showTraySpeed'] ?? true;
        _taskNotification = settingsMap['taskNotification'] ?? true;
        _protocolMagnetEnabled = settingsMap['protocolMagnetEnabled'] ?? false;
        _protocolThunderEnabled =
            settingsMap['protocolThunderEnabled'] ?? false;
        _skipDeleteConfirm = settingsMap['skipDeleteConfirm'] ?? false;
        _resumeAllOnLaunch = settingsMap['resumeAllOnLaunch'] ?? false;
        _showDownloadsAfterAdd = settingsMap['showDownloadsAfterAdd'] ?? true;
        _showProgressBar = settingsMap['showProgressBar'] ?? true;

        // Appearance settings
        final themeModeValue = settingsMap['themeMode'];
        if (themeModeValue != null) {
          _themeMode = ThemeMode.values.firstWhere(
            (e) => e.name == themeModeValue,
            orElse: () => ThemeMode.system,
          );
        }

        final colorCode = settingsMap['primaryColor'];
        if (colorCode != null) {
          try {
            _primaryColor = Color(int.parse(colorCode));
          } catch (e) {
            this.w('Invalid color code, using default', error: e);
            _primaryColor = Colors.blue;
          }
        }

        _customColorCode = settingsMap['customColorCode'];

        // Log settings
        final logLevelValue = settingsMap['logLevel'];
        if (logLevelValue != null) {
          _logLevel = AppLogLevel.values.firstWhere(
            (e) => e.name == logLevelValue,
            orElse: () => AppLogLevel.info,
          );
        }
        // Locale settings
        final localeCode = settingsMap['locale'];
        if (localeCode != null && localeCode.isNotEmpty) {
          _locale = Locale(localeCode);
        }

        // Built-in Aria2 instance settings
        // Connection settings
        _rpcListenPort = settingsMap['rpcListenPort'] ?? 16800;
        _rpcSecret = settingsMap['rpcSecret'] ?? '';

        // Transfer settings
        _maxConcurrentDownloads = settingsMap['maxConcurrentDownloads'] ?? 5;
        _maxConnectionPerServer = settingsMap['maxConnectionPerServer'] ?? 16;
        _split = settingsMap['split'] ?? 16;
        _continueDownloads = settingsMap['continueDownloads'] ?? true;

        // Speed settings
        _maxOverallDownloadLimit = settingsMap['maxOverallDownloadLimit'] ?? 0;
        _maxOverallUploadLimit = settingsMap['maxOverallUploadLimit'] ?? 0;

        // BT settings
        _btSaveMetadata = settingsMap['btSaveMetadata'] ?? true;
        _btForceEncryption = settingsMap['btForceEncryption'] ?? false;
        _btLoadSavedMetadata = settingsMap['btLoadSavedMetadata'] ?? true;
        _keepSeeding = settingsMap['keepSeeding'] ?? false;
        _seedRatio = settingsMap['seedRatio'] ?? 1.0;
        _seedTime = settingsMap['seedTime'] ?? 60;
        _btListenPort = settingsMap['btListenPort'] ?? '6881-6999';
        _btTracker = _normalizeBtTracker(settingsMap['btTracker'] ?? '');
        _btExcludeTracker = settingsMap['btExcludeTracker'] ?? '';

        // Advanced settings
        _allProxy = settingsMap['allProxy'] ?? '';
        _proxyEnabled = settingsMap.containsKey('proxyEnabled')
            ? (settingsMap['proxyEnabled'] ?? false)
            : _allProxy.isNotEmpty;
        _noProxy = settingsMap['noProxy'] ?? '';
        _dhtListenPort = settingsMap['dhtListenPort'] ?? 26701;
        _enableDht6 = settingsMap['enableDht6'] ?? true;
        _enableUpnp = settingsMap['enableUpnp'] ?? true;
        _sessionPath = settingsMap['sessionPath'] ?? '';
        _logPath = settingsMap['logPath'] ?? '';
        _autoSyncTracker = settingsMap['autoSyncTracker'] ?? true;
        _lastSyncTrackerTime = settingsMap['lastSyncTrackerTime'] ?? 0;
        _trackerSource =
            settingsMap['trackerSource'] ??
            'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt';
        _autoFileRenaming = settingsMap['autoFileRenaming'] ?? true;
        _allowOverwrite = settingsMap['allowOverwrite'] ?? false;
        _userAgent =
            settingsMap['userAgent'] ??
            'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/120.0.0.0 Safari/537.36';

        this.i('Settings loaded successfully from $filePath');
      } else {
        this.d('Settings file does not exist, applying default settings');
        _applyDefaultSettings();
      }

      _isLoaded = true;

      // Schedule notifyListeners to run after the current frame is built
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e) {
      this.e('Failed to load settings', error: e);
      // Apply default settings
      _applyDefaultSettings();
      _isLoaded = true;
    }
  }

  // Apply default settings
  void _applyDefaultSettings() {
    this.i('Applying default settings');
    _assignDefaultSettings();
    // Schedule notifyListeners to run after the current frame is built
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Save all settings to JSON file
  Future<void> _saveAllSettings() async {
    try {
      final filePath = _getSettingsFilePath();
      final file = File(filePath);

      final settingsMap = {
        'autoStart': _autoStart,
        'minimizeToTray': _minimizeToTray,
        'runMode': _runMode.name,
        'autoHideWindow': _autoHideWindow,
        'showTraySpeed': _showTraySpeed,
        'taskNotification': _taskNotification,
        'protocolMagnetEnabled': _protocolMagnetEnabled,
        'protocolThunderEnabled': _protocolThunderEnabled,
        'skipDeleteConfirm': _skipDeleteConfirm,
        'resumeAllOnLaunch': _resumeAllOnLaunch,
        'showDownloadsAfterAdd': _showDownloadsAfterAdd,
        'showProgressBar': _showProgressBar,
        'themeMode': _themeMode.name,
        'primaryColor': _primaryColor.toARGB32().toString(),
        'customColorCode': _customColorCode,
        'logLevel': _logLevel.name,
        'locale': _locale?.languageCode,

        // Built-in Aria2 instance settings
        // Connection settings
        'rpcListenPort': _rpcListenPort,
        'rpcSecret': _rpcSecret,

        // Transfer settings
        'maxConcurrentDownloads': _maxConcurrentDownloads,
        'maxConnectionPerServer': _maxConnectionPerServer,
        'split': _split,
        'continueDownloads': _continueDownloads,

        // Speed settings
        'maxOverallDownloadLimit': _maxOverallDownloadLimit,
        'maxOverallUploadLimit': _maxOverallUploadLimit,

        // BT settings
        'btSaveMetadata': _btSaveMetadata,
        'btForceEncryption': _btForceEncryption,
        'btLoadSavedMetadata': _btLoadSavedMetadata,
        'keepSeeding': _keepSeeding,
        'seedRatio': _seedRatio,
        'seedTime': _seedTime,
        'btListenPort': _btListenPort,
        'btTracker': _btTracker,
        'btExcludeTracker': _btExcludeTracker,

        // Advanced settings
        'proxyEnabled': _proxyEnabled,
        'allProxy': _allProxy,
        'noProxy': _noProxy,
        'dhtListenPort': _dhtListenPort,
        'enableDht6': _enableDht6,
        'enableUpnp': _enableUpnp,
        'sessionPath': _sessionPath,
        'logPath': _logPath,
        'autoSyncTracker': _autoSyncTracker,
        'lastSyncTrackerTime': _lastSyncTrackerTime,
        'trackerSource': _trackerSource,
        'autoFileRenaming': _autoFileRenaming,
        'allowOverwrite': _allowOverwrite,
        'userAgent': _userAgent,
      };

      final jsonString = jsonEncode(settingsMap);
      await file.writeAsString(jsonString);

      this.i('All settings saved successfully to $filePath');
    } catch (e) {
      this.e('Failed to save settings', error: e);
    }
  }

  /// Public method to save all settings
  Future<void> saveAllSettings() async {
    await _saveAllSettings();
  }

  Future<void> resetToDefaults() async {
    _assignDefaultSettings();
    _isLoaded = true;
    notifyListeners();
    await _saveAllSettings();
  }

  // Auto-run on system startup setting
  Future<void> setAutoStart(bool value) async {
    _autoStart = value;
    notifyListeners();
    await _saveAllSettings();
  }

  // Minimize to system tray setting
  Future<void> setMinimizeToTray(bool value) async {
    _minimizeToTray = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setRunMode(AppRunMode value) async {
    _runMode = value;
    _minimizeToTray = value == AppRunMode.tray;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setAutoHideWindow(bool value) async {
    _autoHideWindow = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setShowTraySpeed(bool value) async {
    _showTraySpeed = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setTaskNotification(bool value) async {
    _taskNotification = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setProtocolMagnetEnabled(bool value) async {
    _protocolMagnetEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setProtocolThunderEnabled(bool value) async {
    _protocolThunderEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSkipDeleteConfirm(bool value) async {
    _skipDeleteConfirm = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setResumeAllOnLaunch(bool value) async {
    _resumeAllOnLaunch = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setShowDownloadsAfterAdd(bool value) async {
    _showDownloadsAfterAdd = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setShowProgressBar(bool value) async {
    _showProgressBar = value;
    notifyListeners();
    await _saveAllSettings();
  }

  // Theme mode setting
  Future<void> setThemeMode(ThemeMode themeMode) async {
    _themeMode = themeMode;
    notifyListeners();
    await _saveAllSettings();
  }

  // Theme color setting
  Future<void> setPrimaryColor(Color color, {bool isCustom = false}) async {
    _primaryColor = color;
    _customColorCode = isCustom ? color.toARGB32().toString() : null;
    notifyListeners();
    await _saveAllSettings();

    if (isCustom) {
      this.d('Custom primary color saved: $color');
    } else {
      this.d('Standard primary color saved: $color');
    }
  }

  // Log level setting
  Future<void> setAppLogLevel(AppLogLevel level) async {
    _logLevel = level;
    notifyListeners();
    await _saveAllSettings();
  }

  // Locale setting
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    await _saveAllSettings();
  }

  // Built-in Aria2 instance setters
  // Connection settings
  Future<void> setRpcListenPort(int port) async {
    _rpcListenPort = port;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setRpcSecret(String secret) async {
    _rpcSecret = secret;
    notifyListeners();
    await _saveAllSettings();
  }

  // Transfer settings
  Future<void> setMaxConcurrentDownloads(int value) async {
    _maxConcurrentDownloads = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setMaxConnectionPerServer(int value) async {
    _maxConnectionPerServer = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSplit(int value) async {
    _split = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setContinueDownloads(bool value) async {
    _continueDownloads = value;
    notifyListeners();
    await _saveAllSettings();
  }

  // Speed settings
  Future<void> setMaxOverallDownloadLimit(int limit) async {
    _maxOverallDownloadLimit = limit;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setMaxOverallUploadLimit(int limit) async {
    _maxOverallUploadLimit = limit;
    notifyListeners();
    await _saveAllSettings();
  }

  // BT settings
  Future<void> setBtSaveMetadata(bool value) async {
    _btSaveMetadata = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setBtForceEncryption(bool value) async {
    _btForceEncryption = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setBtLoadSavedMetadata(bool value) async {
    _btLoadSavedMetadata = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setKeepSeeding(bool value) async {
    _keepSeeding = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSeedRatio(double ratio) async {
    _seedRatio = ratio;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSeedTime(int minutes) async {
    _seedTime = minutes;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setBtListenPort(String port) async {
    _btListenPort = port;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setBtTracker(String trackers) async {
    _btTracker = _normalizeBtTracker(trackers);
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setBtExcludeTracker(String trackers) async {
    _btExcludeTracker = trackers;
    notifyListeners();
    await _saveAllSettings();
  }

  // Advanced settings
  Future<void> setProxyEnabled(bool value) async {
    _proxyEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setAllProxy(String proxy) async {
    _allProxy = proxy;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setNoProxy(String noProxy) async {
    _noProxy = noProxy;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setDhtListenPort(int port) async {
    _dhtListenPort = port;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setEnableDht6(bool value) async {
    _enableDht6 = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setEnableUpnp(bool value) async {
    _enableUpnp = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSessionPath(String path) async {
    _sessionPath = path;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setLogPath(String path) async {
    _logPath = path;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setAutoSyncTracker(bool value) async {
    _autoSyncTracker = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setLastSyncTrackerTime(int value) async {
    _lastSyncTrackerTime = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setTrackerSource(String value) async {
    _trackerSource = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setAutoFileRenaming(bool value) async {
    _autoFileRenaming = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setAllowOverwrite(bool value) async {
    _allowOverwrite = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setUserAgent(String userAgent) async {
    _userAgent = userAgent;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> updateBuiltinInstanceSettings({
    required int rpcListenPort,
    required String rpcSecret,
    required int maxConcurrentDownloads,
    required int maxConnectionPerServer,
    required int split,
    required bool continueDownloads,
    required int maxOverallDownloadLimit,
    required int maxOverallUploadLimit,
    required bool btSaveMetadata,
    required bool btForceEncryption,
    required bool btLoadSavedMetadata,
    required bool keepSeeding,
    required double seedRatio,
    required int seedTime,
    required String btListenPort,
    required String btTracker,
    required String btExcludeTracker,
    required bool proxyEnabled,
    required String allProxy,
    required String noProxy,
    required int dhtListenPort,
    required bool enableDht6,
    required bool enableUpnp,
    required String sessionPath,
    required String logPath,
    required bool autoSyncTracker,
    required int lastSyncTrackerTime,
    required String trackerSource,
    required bool autoFileRenaming,
    required bool allowOverwrite,
    required String userAgent,
  }) async {
    _rpcListenPort = rpcListenPort;
    _rpcSecret = rpcSecret;
    _maxConcurrentDownloads = maxConcurrentDownloads;
    _maxConnectionPerServer = maxConnectionPerServer;
    _split = split;
    _continueDownloads = continueDownloads;
    _maxOverallDownloadLimit = maxOverallDownloadLimit;
    _maxOverallUploadLimit = maxOverallUploadLimit;
    _btSaveMetadata = btSaveMetadata;
    _btForceEncryption = btForceEncryption;
    _btLoadSavedMetadata = btLoadSavedMetadata;
    _keepSeeding = keepSeeding;
    _seedRatio = seedRatio;
    _seedTime = seedTime;
    _btListenPort = btListenPort;
    _btTracker = _normalizeBtTracker(btTracker);
    _btExcludeTracker = btExcludeTracker;
    _proxyEnabled = proxyEnabled;
    _allProxy = allProxy;
    _noProxy = noProxy;
    _dhtListenPort = dhtListenPort;
    _enableDht6 = enableDht6;
    _enableUpnp = enableUpnp;
    _sessionPath = sessionPath;
    _logPath = logPath;
    _autoSyncTracker = autoSyncTracker;
    _lastSyncTrackerTime = lastSyncTrackerTime;
    _trackerSource = trackerSource;
    _autoFileRenaming = autoFileRenaming;
    _allowOverwrite = allowOverwrite;
    _userAgent = userAgent;
    notifyListeners();
    await _saveAllSettings();
  }
}
