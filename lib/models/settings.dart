import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:path/path.dart' as p;

import '../utils/default_download_directory.dart';
import '../utils/file_category.dart';
import '../utils/logging.dart';
import '../utils/speed_schedule.dart';
import '../repositories/settings_repository.dart';

enum AppRunMode { standard, tray, hideTray }

class Settings extends ChangeNotifier with Loggable {
  Settings({SettingsRepository? repository})
    : _repository = repository ?? SettingsRepository();

  final SettingsRepository _repository;
  bool _credentialsBlocked = false;

  static const String _defaultTrackerSource =
      'https://fastly.jsdelivr.net/gh/ngosang/trackerslist/trackers_best_ip.txt';
  static const String _defaultUserAgent =
      'Mozilla/5.0 (Windows NT 10.0; Win64; x64) '
      'AppleWebKit/537.36 (KHTML, like Gecko) '
      'Chrome/120.0.0.0 Safari/537.36';

  // Global settings
  bool _autoStart = false; // Auto-run on system startup
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
  bool _keepAwake = false; // Prevent idle sleep while downloads are active
  bool _shutdownWhenComplete = false; // Shut down after downloads finish
  bool _fileCategoryRoutingEnabled =
      false; // Route URIs into category subdirectories
  String _fileCategoryRulesJson =
      '[]'; // JSON array of encoded FileCategoryRule entries
  int _lastUpdateCheckTimestamp = 0; // Millis since epoch of last update check
  bool _clipboardMonitorEnabled =
      false; // Watch the clipboard for downloadable URIs
  int _clipboardMonitorSchemes = 0xF; // Scheme bitmask for clipboard watching
  bool _hideTitleBar = false; // Hide the native desktop title bar
  bool _isLoaded = false; // Whether settings have finished loading

  // Appearance settings
  ThemeMode _themeMode = ThemeMode.system; // Appearance settings
  // Default theme color
  Color _primaryColor = Colors.blue; // Default theme color
  String? _customColorCode; // Custom color code

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
  String _downloadDir = ''; // Default download directory

  // Speed settings
  int _maxOverallDownloadLimit =
      0; // Global download speed limit (0 = unlimited)
  int _maxOverallUploadLimit = 0; // Global upload speed limit (0 = unlimited)
  bool _speedLimitEnabled = true; // Master switch for the overall limits
  bool _speedScheduleEnabled = false; // Enforce limits only inside a window
  int _speedScheduleDays = allDaysBitmask; // Monday..Sunday bitmask
  int _speedScheduleStartMinutes = 0; // Minutes since midnight
  int _speedScheduleEndMinutes =
      minutesPerDay; // Minutes since midnight (1440 = 24:00)

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
  String _trackerSource = _defaultTrackerSource; // Selected tracker source
  bool _autoFileRenaming = true; // Auto rename files
  bool _allowOverwrite = false; // Allow overwrite
  String _userAgent = _defaultUserAgent; // User agent

  Future<String> _defaultDownloadDirectory() {
    return Future.value(getDefaultDownloadDirectorySync());
  }

  void _assignDefaultSettings({required String defaultDownloadDir}) {
    _autoStart = false;
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
    _keepAwake = false;
    _hideTitleBar = false;
    _themeMode = ThemeMode.system;
    _primaryColor = Colors.blue;
    _customColorCode = null;
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
    _downloadDir = defaultDownloadDir;

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
    _trackerSource = _defaultTrackerSource;
    _autoFileRenaming = true;
    _allowOverwrite = false;
    _userAgent = _defaultUserAgent;
  }

  @visibleForTesting
  String normalizeBtTracker(String trackers) {
    return trackers
        .split(RegExp(r'[\n\r,]+'))
        .map((tracker) => tracker.trim())
        .where((tracker) => tracker.isNotEmpty)
        .join(',');
  }

  // Getters
  bool get autoStart => _autoStart;
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
  bool get keepAwake => _keepAwake;
  bool get shutdownWhenComplete => _shutdownWhenComplete;
  bool get fileCategoryRoutingEnabled => _fileCategoryRoutingEnabled;
  int get lastUpdateCheckTimestamp => _lastUpdateCheckTimestamp;

  /// Parsed file-category rules (invalid entries dropped).
  List<FileCategoryRule> get fileCategoryRules {
    try {
      final decoded = jsonDecode(_fileCategoryRulesJson);
      if (decoded is! List) {
        return const [];
      }
      return parseFileCategoryRules(
        decoded.map((entry) => '$entry').toList(growable: false),
      );
    } catch (_) {
      return const [];
    }
  }

  bool get clipboardMonitorEnabled => _clipboardMonitorEnabled;
  int get clipboardMonitorSchemes => _clipboardMonitorSchemes;
  bool get hideTitleBar => _hideTitleBar;
  bool get isLoaded => _isLoaded;
  ThemeMode get themeMode => _themeMode;
  Color get primaryColor => _primaryColor;
  String? get customColorCode => _customColorCode;
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
  String get downloadDir => _downloadDir;

  // Speed settings
  int get maxOverallDownloadLimit => _maxOverallDownloadLimit;
  int get maxOverallUploadLimit => _maxOverallUploadLimit;
  bool get speedLimitEnabled => _speedLimitEnabled;
  bool get speedScheduleEnabled => _speedScheduleEnabled;
  int get speedScheduleDays => _speedScheduleDays;
  int get speedScheduleStartMinutes => _speedScheduleStartMinutes;
  int get speedScheduleEndMinutes => _speedScheduleEndMinutes;

  /// Whether the configured overall limits are currently being enforced
  /// according to the master switch and the schedule window.
  bool isSpeedLimitWindowActive([DateTime? now]) {
    return isWithinSpeedScheduleWindow(
      scheduleEnabled: _speedScheduleEnabled,
      daysBitmask: _speedScheduleDays,
      startMinutes: _speedScheduleStartMinutes,
      endMinutes: _speedScheduleEndMinutes,
      now: now ?? DateTime.now(),
    );
  }

  /// The limits that should be applied to aria2 right now.
  ({int download, int upload}) effectiveOverallLimits([DateTime? now]) {
    final windowActive = isSpeedLimitWindowActive(now);
    return (
      download: effectiveSpeedLimit(
        limitsEnabled: _speedLimitEnabled,
        windowActive: windowActive,
        configuredValue: _maxOverallDownloadLimit,
      ),
      upload: effectiveSpeedLimit(
        limitsEnabled: _speedLimitEnabled,
        windowActive: windowActive,
        configuredValue: _maxOverallUploadLimit,
      ),
    );
  }

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

  Map<String, dynamic> toBuiltinInstanceSettings() {
    return <String, dynamic>{
      'rpcListenPort': _rpcListenPort,
      'rpcSecret': _rpcSecret,
      'maxConcurrentDownloads': _maxConcurrentDownloads,
      'maxConnectionPerServer': _maxConnectionPerServer,
      'split': _split,
      'continueDownloads': _continueDownloads,
      'downloadDir': _downloadDir,
      'maxOverallDownloadLimit': _maxOverallDownloadLimit,
      'maxOverallUploadLimit': _maxOverallUploadLimit,
      'speedLimitEnabled': _speedLimitEnabled,
      'speedScheduleEnabled': _speedScheduleEnabled,
      'speedScheduleDays': _speedScheduleDays,
      'speedScheduleStartMinutes': _speedScheduleStartMinutes,
      'speedScheduleEndMinutes': _speedScheduleEndMinutes,
      'btSaveMetadata': _btSaveMetadata,
      'btForceEncryption': _btForceEncryption,
      'btLoadSavedMetadata': _btLoadSavedMetadata,
      'keepSeeding': _keepSeeding,
      'seedRatio': _seedRatio,
      'seedTime': _seedTime,
      'btListenPort': _btListenPort,
      'btTracker': _btTracker,
      'btExcludeTracker': _btExcludeTracker,
      'proxyEnabled': _proxyEnabled,
      'allProxy': _allProxy,
      'noProxy': _noProxy,
      'dhtListenPort': _dhtListenPort,
      'enableDht6': _enableDht6,
      'enableUpnp': _enableUpnp,
      'sessionPath': _sessionPath,
      'logPath': _logPath,
      'autoFileRenaming': _autoFileRenaming,
      'allowOverwrite': _allowOverwrite,
      'userAgent': _userAgent,
    };
  }

  // Load all settings from JSON file
  Future<void> loadSettings() async {
    try {
      final loadResult = await _repository.load();
      _credentialsBlocked = loadResult.credentialsBlocked;
      final settingsMap = loadResult.values;

      if (settingsMap != null) {
        var needsSave = false;
        final defaultDownloadDir = await _defaultDownloadDirectory();
        _assignDefaultSettings(defaultDownloadDir: defaultDownloadDir);

        bool readBool(String key, bool fallback) {
          final rawValue = settingsMap[key];
          if (rawValue == null) {
            return fallback;
          }
          if (rawValue is bool) {
            return rawValue;
          }
          if (rawValue is String) {
            final normalized = rawValue.trim().toLowerCase();
            if (normalized == 'true' || normalized == 'false') {
              needsSave = true;
              return normalized == 'true';
            }
          }
          if (rawValue is num && (rawValue == 0 || rawValue == 1)) {
            needsSave = true;
            return rawValue == 1;
          }
          needsSave = true;
          return fallback;
        }

        int readInt(String key, int fallback, {int? min, int? max}) {
          final rawValue = settingsMap[key];
          if (rawValue == null) {
            return fallback;
          }

          int? parsed;
          if (rawValue is int) {
            parsed = rawValue;
          } else if (rawValue is num && rawValue.isFinite) {
            final candidate = rawValue.toInt();
            if (candidate == rawValue) {
              parsed = candidate;
              needsSave = true;
            }
          } else if (rawValue is String) {
            parsed = int.tryParse(rawValue.trim());
            if (parsed != null) {
              needsSave = true;
            }
          }

          if (parsed == null ||
              (min != null && parsed < min) ||
              (max != null && parsed > max)) {
            needsSave = true;
            return fallback;
          }
          return parsed;
        }

        double readDouble(
          String key,
          double fallback, {
          double? min,
          double? max,
        }) {
          final rawValue = settingsMap[key];
          if (rawValue == null) {
            return fallback;
          }

          double? parsed;
          if (rawValue is num && rawValue.isFinite) {
            parsed = rawValue.toDouble();
            if (rawValue is! double) {
              needsSave = true;
            }
          } else if (rawValue is String) {
            parsed = double.tryParse(rawValue.trim());
            if (parsed != null && parsed.isFinite) {
              needsSave = true;
            } else {
              parsed = null;
            }
          }

          if (parsed == null ||
              (min != null && parsed < min) ||
              (max != null && parsed > max)) {
            needsSave = true;
            return fallback;
          }
          return parsed;
        }

        String readString(
          String key,
          String fallback, {
          bool allowEmpty = true,
        }) {
          final rawValue = settingsMap[key];
          if (rawValue == null) {
            return fallback;
          }
          if (rawValue is! String || (!allowEmpty && rawValue.trim().isEmpty)) {
            needsSave = true;
            return fallback;
          }
          return rawValue;
        }

        String? readNullableString(String key) {
          final rawValue = settingsMap[key];
          if (rawValue == null) {
            return null;
          }
          if (rawValue is String) {
            return rawValue.trim().isEmpty ? null : rawValue;
          }
          needsSave = true;
          return null;
        }

        // Global settings
        _autoStart = readBool('autoStart', false);
        final minimizeToTray = readBool('minimizeToTray', true);
        final runModeValue = settingsMap['runMode'];
        if (runModeValue is String &&
            AppRunMode.values.any((mode) => mode.name == runModeValue)) {
          _runMode = AppRunMode.values.byName(runModeValue);
        } else {
          if (runModeValue != null) {
            needsSave = true;
            _runMode = AppRunMode.tray;
          } else {
            _runMode = minimizeToTray ? AppRunMode.tray : AppRunMode.standard;
            needsSave = true;
          }
        }
        _autoHideWindow = readBool('autoHideWindow', false);
        _showTraySpeed = readBool('showTraySpeed', true);
        _taskNotification = readBool('taskNotification', true);
        _protocolMagnetEnabled = readBool('protocolMagnetEnabled', false);
        _protocolThunderEnabled = readBool('protocolThunderEnabled', false);
        _skipDeleteConfirm = readBool('skipDeleteConfirm', false);
        _resumeAllOnLaunch = readBool('resumeAllOnLaunch', false);
        _showDownloadsAfterAdd = readBool('showDownloadsAfterAdd', true);
        _showProgressBar = readBool('showProgressBar', true);
        _keepAwake = readBool('keepAwake', false);
        _shutdownWhenComplete = readBool('shutdownWhenComplete', false);
        _fileCategoryRoutingEnabled = readBool(
          'fileCategoryRoutingEnabled',
          false,
        );
        _fileCategoryRulesJson = readString('fileCategoryRulesJson', '[]');
        _lastUpdateCheckTimestamp = readInt(
          'lastUpdateCheckTimestamp',
          0,
          min: 0,
        );
        _clipboardMonitorEnabled = readBool('clipboardMonitorEnabled', false);
        final loadedSchemes = readInt(
          'clipboardMonitorSchemes',
          0xF,
          min: 0,
          max: 0xF,
        );
        _clipboardMonitorSchemes = loadedSchemes == 0
            ? 0xF
            : loadedSchemes & 0xF;
        _hideTitleBar = readBool('hideTitleBar', false);

        // Appearance settings
        final themeModeValue = settingsMap['themeMode'];
        if (themeModeValue is String &&
            ThemeMode.values.any((mode) => mode.name == themeModeValue)) {
          _themeMode = ThemeMode.values.byName(themeModeValue);
        } else if (themeModeValue != null) {
          needsSave = true;
        }

        final colorCode = settingsMap['primaryColor'];
        if (colorCode != null) {
          final parsedColor = colorCode is int
              ? colorCode
              : int.tryParse(colorCode.toString());
          if (parsedColor != null &&
              parsedColor >= 0 &&
              parsedColor <= 0xFFFFFFFF) {
            _primaryColor = Color(parsedColor);
            if (colorCode is! String) {
              needsSave = true;
            }
          } else {
            _primaryColor = Colors.blue;
            needsSave = true;
          }
        }

        _customColorCode = readNullableString('customColorCode');

        // Locale settings
        final localeCode = readNullableString('locale');
        if (localeCode != null) {
          final normalizedLocale = localeCode
              .trim()
              .split(RegExp('[-_]'))
              .first
              .toLowerCase();
          if (normalizedLocale == 'en' || normalizedLocale == 'zh') {
            _locale = Locale(normalizedLocale);
            if (normalizedLocale != localeCode) {
              needsSave = true;
            }
          } else {
            needsSave = true;
          }
        }

        // Built-in Aria2 instance settings
        // Connection settings
        _rpcListenPort = readInt('rpcListenPort', 16800, min: 1, max: 65535);
        _rpcSecret = readString('rpcSecret', '');

        // Transfer settings
        _maxConcurrentDownloads = readInt(
          'maxConcurrentDownloads',
          5,
          min: 1,
          max: 16,
        );
        _maxConnectionPerServer = readInt(
          'maxConnectionPerServer',
          16,
          min: 1,
          max: 128,
        );
        _split = readInt('split', 16, min: 1, max: 128);
        _continueDownloads = readBool('continueDownloads', true);
        final configuredDownloadDir = readString('downloadDir', '').trim();
        if (configuredDownloadDir.isEmpty) {
          _downloadDir = defaultDownloadDir;
          needsSave = true;
        } else {
          _downloadDir = p.normalize(configuredDownloadDir);
          if (_downloadDir != configuredDownloadDir) {
            needsSave = true;
          }
        }

        // Speed settings
        _maxOverallDownloadLimit = readInt(
          'maxOverallDownloadLimit',
          0,
          min: 0,
          max: 65535,
        );
        _maxOverallUploadLimit = readInt(
          'maxOverallUploadLimit',
          0,
          min: 0,
          max: 65535,
        );
        _speedLimitEnabled = readBool('speedLimitEnabled', true);
        _speedScheduleEnabled = readBool('speedScheduleEnabled', false);
        final loadedDays = readInt(
          'speedScheduleDays',
          allDaysBitmask,
          min: 0,
          max: allDaysBitmask,
        );
        _speedScheduleDays = loadedDays == 0
            ? allDaysBitmask
            : loadedDays & allDaysBitmask;
        _speedScheduleStartMinutes = readInt(
          'speedScheduleStartMinutes',
          0,
          min: 0,
          max: minutesPerDay,
        );
        _speedScheduleEndMinutes = readInt(
          'speedScheduleEndMinutes',
          minutesPerDay,
          min: 0,
          max: minutesPerDay,
        );

        // BT settings
        _btSaveMetadata = readBool('btSaveMetadata', true);
        _btForceEncryption = readBool('btForceEncryption', false);
        _btLoadSavedMetadata = readBool('btLoadSavedMetadata', true);
        _keepSeeding = readBool('keepSeeding', false);
        _seedRatio = readDouble('seedRatio', 1.0, min: 0, max: 100);
        _seedTime = readInt('seedTime', 60, min: 0, max: 10080);
        _btListenPort = readString('btListenPort', '6881-6999');
        final rawBtTracker = readString('btTracker', '');
        _btTracker = normalizeBtTracker(rawBtTracker);
        if (_btTracker != rawBtTracker) {
          needsSave = true;
        }
        _btExcludeTracker = readString('btExcludeTracker', '');

        // Advanced settings
        _allProxy = readString('allProxy', '');
        _proxyEnabled = settingsMap.containsKey('proxyEnabled')
            ? readBool('proxyEnabled', false)
            : _allProxy.isNotEmpty;
        if (!settingsMap.containsKey('proxyEnabled')) {
          needsSave = true;
        }
        _noProxy = readString('noProxy', '');
        _dhtListenPort = readInt('dhtListenPort', 26701, min: 1024, max: 65535);
        _enableDht6 = readBool('enableDht6', true);
        _enableUpnp = readBool('enableUpnp', true);
        _sessionPath = readString('sessionPath', '');
        _logPath = readString('logPath', '');
        _autoSyncTracker = readBool('autoSyncTracker', true);
        _lastSyncTrackerTime = readInt('lastSyncTrackerTime', 0, min: 0);
        _trackerSource = readString(
          'trackerSource',
          _defaultTrackerSource,
          allowEmpty: false,
        );
        _autoFileRenaming = readBool('autoFileRenaming', true);
        _allowOverwrite = readBool('allowOverwrite', false);
        _userAgent = readString(
          'userAgent',
          _defaultUserAgent,
          allowEmpty: false,
        );

        if (needsSave && !_credentialsBlocked) {
          await _saveAllSettings();
        }
      } else {
        await _applyDefaultSettings(save: true);
      }

      _isLoaded = true;

      // Schedule notifyListeners to run after the current frame is built
      SchedulerBinding.instance.addPostFrameCallback((_) {
        notifyListeners();
      });
    } catch (e, stackTrace) {
      this.e('Failed to load settings', error: e, stackTrace: stackTrace);
      // Apply default settings
      try {
        await _applyDefaultSettings(save: true);
      } catch (fallbackError, fallbackStackTrace) {
        this.e(
          'Failed to persist fallback settings; continuing with in-memory defaults',
          error: fallbackError,
          stackTrace: fallbackStackTrace,
        );
        SchedulerBinding.instance.addPostFrameCallback((_) {
          notifyListeners();
        });
      }
      _isLoaded = true;
    }
  }

  // Apply default settings
  Future<void> _applyDefaultSettings({bool save = false}) async {
    _assignDefaultSettings(
      defaultDownloadDir: await _defaultDownloadDirectory(),
    );
    if (save) {
      await _saveAllSettings();
    }
    // Schedule notifyListeners to run after the current frame is built
    SchedulerBinding.instance.addPostFrameCallback((_) {
      notifyListeners();
    });
  }

  // Save all settings to JSON file
  Future<void> _saveAllSettings() async {
    try {
      final settingsMap = {
        'autoStart': _autoStart,
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
        'keepAwake': _keepAwake,
        'shutdownWhenComplete': _shutdownWhenComplete,
        'fileCategoryRoutingEnabled': _fileCategoryRoutingEnabled,
        'fileCategoryRulesJson': _fileCategoryRulesJson,
        'lastUpdateCheckTimestamp': _lastUpdateCheckTimestamp,
        'clipboardMonitorEnabled': _clipboardMonitorEnabled,
        'clipboardMonitorSchemes': _clipboardMonitorSchemes,
        'hideTitleBar': _hideTitleBar,
        'themeMode': _themeMode.name,
        'primaryColor': _primaryColor.toARGB32().toString(),
        'customColorCode': _customColorCode,
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
        'downloadDir': _downloadDir,

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

      await _repository.save(
        settingsMap,
        credentialsBlocked: _credentialsBlocked,
      );
    } catch (e) {
      this.e('Failed to save settings', error: e);
      rethrow;
    }
  }

  Future<void> resetToDefaults() async {
    _assignDefaultSettings(
      defaultDownloadDir: await _defaultDownloadDirectory(),
    );
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

  /// RPC listen port of the built-in instance; also persisted when the
  /// engine recovers from a port conflict by moving to a free port.
  Future<void> setRpcListenPort(int value) async {
    if (_rpcListenPort == value) {
      return;
    }
    _rpcListenPort = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setSpeedLimitEnabled(bool value) async {
    if (_speedLimitEnabled == value) {
      return;
    }
    _speedLimitEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  /// Configured overall download limit in KB/s (0 = unlimited).
  Future<void> setMaxOverallDownloadLimit(int kiloBytesPerSecond) async {
    final value = kiloBytesPerSecond.clamp(0, 65535).toInt();
    if (_maxOverallDownloadLimit == value) {
      return;
    }
    _maxOverallDownloadLimit = value;
    notifyListeners();
    await _saveAllSettings();
  }

  /// Configured overall upload limit in KB/s (0 = unlimited).
  Future<void> setMaxOverallUploadLimit(int kiloBytesPerSecond) async {
    final value = kiloBytesPerSecond.clamp(0, 65535).toInt();
    if (_maxOverallUploadLimit == value) {
      return;
    }
    _maxOverallUploadLimit = value;
    notifyListeners();
    await _saveAllSettings();
  }

  /// Updates the speed-limit schedule; pass only the fields that changed so
  /// unrelated values are preserved.
  Future<void> setSpeedSchedule({
    bool? enabled,
    int? days,
    int? startMinutes,
    int? endMinutes,
  }) async {
    final nextEnabled = enabled ?? _speedScheduleEnabled;
    var nextDays = (days ?? _speedScheduleDays) & allDaysBitmask;
    if (nextDays == 0) {
      nextDays = allDaysBitmask;
    }
    final nextStart = startMinutes ?? _speedScheduleStartMinutes;
    final nextEnd = endMinutes ?? _speedScheduleEndMinutes;

    if (nextEnabled == _speedScheduleEnabled &&
        nextDays == _speedScheduleDays &&
        nextStart == _speedScheduleStartMinutes &&
        nextEnd == _speedScheduleEndMinutes) {
      return;
    }

    _speedScheduleEnabled = nextEnabled;
    _speedScheduleDays = nextDays;
    _speedScheduleStartMinutes = nextStart.clamp(0, minutesPerDay).toInt();
    _speedScheduleEndMinutes = nextEnd.clamp(0, minutesPerDay).toInt();
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setRunMode(AppRunMode value) async {
    _runMode = value;
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

  Future<void> setKeepAwake(bool value) async {
    _keepAwake = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setHideTitleBar(bool value) async {
    _hideTitleBar = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setShutdownWhenComplete(bool value) async {
    if (_shutdownWhenComplete == value) {
      return;
    }
    _shutdownWhenComplete = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setFileCategoryRoutingEnabled(bool value) async {
    if (_fileCategoryRoutingEnabled == value) {
      return;
    }
    _fileCategoryRoutingEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setFileCategoryRules(List<FileCategoryRule> rules) async {
    final encoded = jsonEncode(
      rules.take(maxFileCategoryRules).map((rule) => rule.encode()).toList(),
    );
    if (_fileCategoryRulesJson == encoded) {
      return;
    }
    _fileCategoryRulesJson = encoded;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setLastUpdateCheckTimestamp(int millisSinceEpoch) async {
    if (_lastUpdateCheckTimestamp == millisSinceEpoch) {
      return;
    }
    _lastUpdateCheckTimestamp = millisSinceEpoch;
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setClipboardMonitorEnabled(bool value) async {
    if (_clipboardMonitorEnabled == value) {
      return;
    }
    _clipboardMonitorEnabled = value;
    notifyListeners();
    await _saveAllSettings();
  }

  /// Scheme bitmask for clipboard watching: bit0 http(s), bit1 ftp,
  /// bit2 magnet, bit3 thunder.
  Future<void> setClipboardMonitorSchemes(int value) async {
    final masked = value & 0xF;
    if (_clipboardMonitorSchemes == masked) {
      return;
    }
    _clipboardMonitorSchemes = masked == 0 ? 0xF : masked;
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
  }

  // Locale setting
  Future<void> setLocale(Locale? locale) async {
    _locale = locale;
    notifyListeners();
    await _saveAllSettings();
  }

  // Built-in Aria2 instance setters
  Future<void> setBtTracker(String trackers) async {
    _btTracker = normalizeBtTracker(trackers);
    notifyListeners();
    await _saveAllSettings();
  }

  Future<void> setLastSyncTrackerTime(int value) async {
    _lastSyncTrackerTime = value;
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
    required String downloadDir,
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
    _downloadDir = downloadDir;
    _maxOverallDownloadLimit = maxOverallDownloadLimit;
    _maxOverallUploadLimit = maxOverallUploadLimit;
    _btSaveMetadata = btSaveMetadata;
    _btForceEncryption = btForceEncryption;
    _btLoadSavedMetadata = btLoadSavedMetadata;
    _keepSeeding = keepSeeding;
    _seedRatio = seedRatio;
    _seedTime = seedTime;
    _btListenPort = btListenPort;
    _btTracker = normalizeBtTracker(btTracker);
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
