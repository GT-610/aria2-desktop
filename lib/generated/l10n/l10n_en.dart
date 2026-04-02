// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for English (`en`).
class AppLocalizationsEn extends AppLocalizations {
  AppLocalizationsEn([String locale = 'en']) : super(locale);

  @override
  String get download => 'Download';

  @override
  String get instance => 'Instance';

  @override
  String get settings => 'Settings';

  @override
  String totalSpeed(Object speed) {
    return 'Total Speed: $speed';
  }

  @override
  String activeTasks(Object count) {
    return 'Active: $count';
  }

  @override
  String waitingTasks(Object count) {
    return 'Waiting: $count';
  }

  @override
  String get builtinInstanceConnectFailed =>
      'Built-in Instance Connection Failed';

  @override
  String get builtinInstanceConnectFailedTip =>
      'Built-in instance connection failed, only remote features available';

  @override
  String get ok => 'OK';

  @override
  String get notConnected => 'Not Connected';

  @override
  String get connecting => 'Connecting';

  @override
  String get connected => 'Connected';

  @override
  String get connectFailed => 'Connect Failed';

  @override
  String get connect => 'Connect';

  @override
  String get reconnect => 'Reconnect';

  @override
  String get disconnect => 'Disconnect';

  @override
  String get settings2 => 'Settings';

  @override
  String get edit => 'Edit';

  @override
  String get delete => 'Delete';

  @override
  String get builtin => 'Built-in';

  @override
  String get remote => 'Remote';

  @override
  String aria2Version(Object version) {
    return 'Aria2 Version: $version';
  }

  @override
  String get gettingVersion => 'Getting version...';

  @override
  String get loadSettingsFailed => 'Failed to load settings';

  @override
  String get saveSettingsFailed => 'Failed to save settings';

  @override
  String get globalSettings => 'Global Settings';

  @override
  String get runAtStartup => 'Run at startup';

  @override
  String get runAtStartupTip => 'Start app when system starts';

  @override
  String get minimizeToTray => 'Minimize to tray';

  @override
  String get minimizeToTrayTip =>
      'Minimize to tray when closing window instead of exiting';

  @override
  String get appearance => 'Appearance';

  @override
  String get appearanceTip => 'Customize app theme and colors';

  @override
  String get light => 'Light';

  @override
  String get dark => 'Dark';

  @override
  String get system => 'System';

  @override
  String get language => 'Language';

  @override
  String get themeMode => 'Theme Mode';

  @override
  String get themeColor => 'Theme Color';

  @override
  String get preset => 'Preset';

  @override
  String get custom => 'Custom';

  @override
  String get colorCode => 'Color Code';

  @override
  String get done => 'Done';

  @override
  String failedToSetThemeMode(Object error) {
    return 'Failed to set theme mode: $error';
  }

  @override
  String failedToSetThemeColor(Object error) {
    return 'Failed to set theme color: $error';
  }

  @override
  String failedToSetCustomThemeColor(Object error) {
    return 'Failed to set custom theme color: $error';
  }

  @override
  String get logSettings => 'Log Settings';

  @override
  String get logLevel => 'Log Level';

  @override
  String get saveLogToFile => 'Save log to file';

  @override
  String get viewLogFiles => 'View log files';

  @override
  String get thisFeatureWillBeImplemented =>
      'This feature will be implemented in future versions';

  @override
  String get cannotOpenLogDirectory => 'Cannot open log directory';

  @override
  String get about => 'About';

  @override
  String get version => 'Version';

  @override
  String get versionLoading => 'Loading...';

  @override
  String get contributors => 'Contributors';

  @override
  String get license => 'License';

  @override
  String get instanceSettings => 'Instance Settings';

  @override
  String get save => 'Save';

  @override
  String get saveAndApply => 'Save & Apply';

  @override
  String get basicSettings => 'Basic Settings';

  @override
  String get rpcListenPort => 'RPC Listen Port';

  @override
  String get rpcPortDefault => 'Default: 16800';

  @override
  String get rpcSecret => 'RPC Secret';

  @override
  String get rpcSecretTip => 'Leave empty if no secret required';

  @override
  String get transferSettings => 'Transfer Settings';

  @override
  String get maxConcurrentDownloads => 'Max Concurrent Downloads';

  @override
  String get maxConnectionPerServer => 'Max Connections Per Server';

  @override
  String get downloadSegments => 'Download Segments';

  @override
  String get enableContinueDownload => 'Enable Continue Download';

  @override
  String get speedLimit => 'Speed Limit';

  @override
  String get globalDownloadLimit => 'Global Download Limit (KB/s)';

  @override
  String get downloadLimitTip => '0 means no limit';

  @override
  String get globalUploadLimit => 'Global Upload Limit (KB/s)';

  @override
  String get uploadLimitTip => '0 means no limit';

  @override
  String get btPtSettings => 'BT/PT Settings';

  @override
  String get saveBtMetadata => 'Save BT Metadata';

  @override
  String get loadSavedBtMetadata => 'Load Saved BT Metadata';

  @override
  String get forceBtEncryption => 'Force BT Encryption';

  @override
  String get keepSeeding => 'Keep Seeding';

  @override
  String get seedingRatio => 'Seeding Ratio';

  @override
  String get seedingRatioTip => '0 means infinite';

  @override
  String get seedingTime => 'Seeding Time (minutes)';

  @override
  String get seedingTimeTip => '0 means infinite';

  @override
  String get excludedTrackers => 'Excluded Trackers';

  @override
  String get trackersTip => 'Separate multiple trackers with commas';

  @override
  String get networkSettings => 'Network Settings';

  @override
  String get globalProxy => 'Global Proxy';

  @override
  String get proxyFormat => 'Format: http://proxy:port';

  @override
  String get noProxyAddresses => 'No Proxy Addresses';

  @override
  String get noProxyTip => 'Separate multiple addresses with commas';

  @override
  String get dhtListenPort => 'DHT Listen Port';

  @override
  String get enableDht6 => 'Enable DHT6';

  @override
  String get fileSettings => 'File Settings';

  @override
  String get downloadDir => 'Download Directory';

  @override
  String get selectDir => 'Select';

  @override
  String failedToGetTasks(Object error) {
    return 'Failed to get tasks: $error';
  }

  @override
  String get taskAddedSuccess => 'Task added successfully';

  @override
  String get noConnectedInstance => 'No connected instance';

  @override
  String addTaskFailed(Object error) {
    return 'Failed to add task: $error';
  }

  @override
  String get unknownInstance => 'Unknown Instance';

  @override
  String get pause => 'Pause';

  @override
  String get stop => 'Stop';

  @override
  String get resume => 'Resume';

  @override
  String get retry => 'Retry';

  @override
  String get openDownloadDir => 'Open Download Directory';

  @override
  String get filterAll => 'All';

  @override
  String get filterDownloading => 'Downloading';

  @override
  String get filterPaused => 'Paused';

  @override
  String get filterStopped => 'Stopped';

  @override
  String get filterComplete => 'Complete';

  @override
  String get addTask => 'Add Task';

  @override
  String get addUrl => 'Add URL';

  @override
  String get addTorrent => 'Add Torrent';

  @override
  String get addMetalink => 'Add Metalink';

  @override
  String get addUri => 'Add URI';

  @override
  String get enterUrl => 'Enter URL';

  @override
  String get urlHint => 'http://example.com/file.zip';

  @override
  String get saveTo => 'Save to';

  @override
  String get selectDownloadDir => 'Select download directory';

  @override
  String get taskName => 'Task Name';

  @override
  String get taskNameTip => 'Leave empty to use original filename';

  @override
  String get instances => 'Instances';

  @override
  String get noSavedInstances => 'No saved instances';

  @override
  String get clickToAddInstance =>
      'Click the button in the bottom right to add a new instance';

  @override
  String get instanceOnline => 'Instance online';

  @override
  String get instanceOffline => 'Instance offline or cannot connect';

  @override
  String checkStatusFailed(Object error) {
    return 'Check status failed: $error';
  }

  @override
  String get disconnected => 'Disconnected';

  @override
  String get confirmDelete => 'Confirm Delete';

  @override
  String confirmDeleteInstance(Object name) {
    return 'Are you sure you want to delete instance \"$name\"?';
  }

  @override
  String get cancel => 'Cancel';

  @override
  String get instanceDeletedSuccess => 'Instance deleted successfully';

  @override
  String deleteFailed(Object error) {
    return 'Delete failed: $error';
  }

  @override
  String get instanceUpdatedSuccess => 'Instance updated successfully';

  @override
  String get instanceAddedSuccess => 'Instance added successfully';

  @override
  String operationFailed(Object error) {
    return 'Operation failed: $error';
  }

  @override
  String get addInstance => 'Add Instance';

  @override
  String successConnected(Object name) {
    return 'Successfully connected to instance: $name';
  }

  @override
  String get connectionFailedCheckConfig =>
      'Connection failed, please check configuration';

  @override
  String connectionFailedError(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get editInstance => 'Edit Instance';

  @override
  String get instanceName => 'Instance Name';

  @override
  String get host => 'Host';

  @override
  String get hostTip => 'e.g., localhost:6800 or http://aria2.example.com:6800';

  @override
  String get protocol => 'Protocol';

  @override
  String get http => 'HTTP';

  @override
  String get https => 'HTTPS';

  @override
  String get rpcSecretHint => 'RPC secret token';

  @override
  String get testConnection => 'Test Connection';

  @override
  String get connectionSuccess => 'Connection successful';

  @override
  String connectionFailed(Object error) {
    return 'Connection failed: $error';
  }

  @override
  String get confirmDeleteTip =>
      'Are you sure you want to delete this instance?';

  @override
  String get confirm => 'Confirm';

  @override
  String get debug => 'Debug';

  @override
  String get info => 'Info';

  @override
  String get warning => 'Warning';

  @override
  String get error => 'Error';
}
