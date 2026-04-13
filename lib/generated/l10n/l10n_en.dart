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
  String get add => 'Add';

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
  String get instanceNameTip => 'Enter instance name';

  @override
  String get host => 'Host';

  @override
  String get port => 'Port';

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

  @override
  String get instanceNameRequired => 'Instance name is required';

  @override
  String get instanceNameTooLong =>
      'Instance name must be 30 characters or less';

  @override
  String get hostRequired => 'Host is required';

  @override
  String get portRequired => 'Port is required';

  @override
  String get portInvalid => 'Port must be between 1 and 65535';

  @override
  String get failed => 'Failed';

  @override
  String get check => 'Check';

  @override
  String get addInstanceTooltip => 'Add instance';

  @override
  String get instanceReachable => 'Instance is reachable';

  @override
  String get instanceOfflineUnreachable => 'Instance is offline or unreachable';

  @override
  String failedToDeleteInstance(Object error) {
    return 'Failed to delete instance: $error';
  }

  @override
  String get disconnectedSuccessfully => 'Disconnected successfully';

  @override
  String get versionWillAppearAfterConnection =>
      'Version will appear after connection';

  @override
  String builtInDefaultInstance(Object name) {
    return '$name (Built-in default)';
  }

  @override
  String builtInInstance(Object name) {
    return '$name (Built-in)';
  }

  @override
  String get searchTasksHint => 'Search tasks by name, path, or instance';

  @override
  String get sortTasks => 'Sort tasks';

  @override
  String get ascending => 'Ascending';

  @override
  String get descending => 'Descending';

  @override
  String get name => 'Name';

  @override
  String get progress => 'Progress';

  @override
  String get size => 'Size';

  @override
  String get speed => 'Speed';

  @override
  String get pauseAll => 'Pause All';

  @override
  String get resumeAll => 'Resume All';

  @override
  String get deleteAll => 'Delete All';

  @override
  String get allTasksLabel => 'All tasks';

  @override
  String get byStatus => 'By status';

  @override
  String get byType => 'By type';

  @override
  String get byInstance => 'By instance';

  @override
  String get allInstances => 'All instances';

  @override
  String get chooseCategory => 'Choose a category';

  @override
  String get stoppedCompleted => 'Stopped / Completed';

  @override
  String get unknownPath => 'Unknown path';

  @override
  String selectedFile(Object name) {
    return 'Selected: $name';
  }

  @override
  String get addTaskDialogTitle => 'Add task';

  @override
  String get uriTab => 'URI';

  @override
  String get torrentTab => 'Torrent';

  @override
  String get metalinkTab => 'Metalink';

  @override
  String get urlOrMagnetLink => 'URL or magnet link';

  @override
  String get enterOneOrMoreLinks => 'Enter one or more links';

  @override
  String get pasteFromClipboard => 'Paste from clipboard';

  @override
  String get uriSupportHint =>
      'Supports HTTP/HTTPS, FTP, SFTP, magnet and more.';

  @override
  String get selectTorrentFile => 'Select torrent file';

  @override
  String get selectMetalinkFile => 'Select metalink file';

  @override
  String get targetInstance => 'Target instance';

  @override
  String get selectTargetInstanceFirst => 'Select a target instance first';

  @override
  String get noConnectedInstancesAvailable =>
      'No connected instances are available. Connect the built-in or a remote instance first.';

  @override
  String tasksWillBeSentTo(Object target) {
    return 'Tasks will be sent to $target.';
  }

  @override
  String get showAdvancedOptions => 'Show advanced options';

  @override
  String get advancedOptionsPlanned =>
      'Advanced per-task options are planned for a later stage.';

  @override
  String get saveLocation => 'Save location';

  @override
  String get useInstanceDefaultDirectory =>
      'Use the instance default directory';

  @override
  String get chooseSaveLocation => 'Choose save location';

  @override
  String failedToSelectDirectory(Object error) {
    return 'Failed to select directory: $error';
  }

  @override
  String selectedCount(Object count) {
    return '$count selected';
  }

  @override
  String get allVisibleSelected => 'All visible selected';

  @override
  String get selectAllVisible => 'Select all visible';

  @override
  String get clear => 'Clear';

  @override
  String failedToRefreshTasks(Object error) {
    return 'Failed to refresh tasks: $error';
  }

  @override
  String failedToLoadInstanceNames(Object error) {
    return 'Failed to load instance names: $error';
  }

  @override
  String get connectBeforeAddingTasks =>
      'Connect the built-in instance or a remote instance before adding tasks.';

  @override
  String taskAddedToInstanceSuccess(Object name) {
    return 'Task added to $name successfully';
  }

  @override
  String get resumeTasks => 'Resume tasks';

  @override
  String get pauseTasks => 'Pause tasks';

  @override
  String get deleteTasks => 'Delete tasks';

  @override
  String get removeOnly => 'Remove only';

  @override
  String get removeAndDeleteFiles => 'Remove and delete files';

  @override
  String get deleteFilesOptionHint =>
      'Only downloaded files from built-in tasks will be deleted.';

  @override
  String actionAcrossAllInstances(Object action) {
    return '$action across all connected instances';
  }

  @override
  String actionInInstance(Object action, Object instance) {
    return '$action in $instance';
  }

  @override
  String get chooseActionScope => 'Choose where to apply this action.';

  @override
  String get noConnectedInstancesForAction =>
      'No connected instances are available for this action.';

  @override
  String get noConnectedInstancesTitle =>
      'No connected instances. Connect an instance to view tasks.';

  @override
  String get combinedTaskListHint =>
      'The download list combines tasks from the built-in instance and any connected remote instances.';

  @override
  String get noTasksTitle => 'No tasks';

  @override
  String get noTasksHint =>
      'Add a task or switch filters to see downloads from connected instances.';

  @override
  String get noDownloadDirectoryAvailable => 'No download directory available';

  @override
  String get targetInstanceNotConnected =>
      'The target instance is not connected.';

  @override
  String failedToPauseTask(Object error) {
    return 'Failed to pause the task: $error';
  }

  @override
  String failedToRemoveTask(Object error) {
    return 'Failed to remove the task: $error';
  }

  @override
  String failedToResumeTask(Object error) {
    return 'Failed to resume the task: $error';
  }

  @override
  String failedToRemoveFailedTask(Object error) {
    return 'Failed to remove the failed task: $error';
  }

  @override
  String get taskRemovedWithFileWarnings =>
      'Task removed, but some files could not be deleted.';

  @override
  String taskActionNoMatchingTasks(Object action) {
    return 'No matching tasks for $action.';
  }

  @override
  String taskActionSummarySuccess(Object action, int success) {
    return '$action: $success succeeded.';
  }

  @override
  String taskActionSummaryDetailed(
    Object action,
    int success,
    int failed,
    int skipped,
  ) {
    return '$action: $success succeeded, $failed failed, $skipped skipped.';
  }

  @override
  String fileDeletionWarningsSummary(int count) {
    return 'Some files could not be deleted for $count task(s).';
  }

  @override
  String get paused => 'Paused';

  @override
  String get completed => 'Completed';

  @override
  String get downloading => 'Downloading';

  @override
  String get waiting => 'Waiting';

  @override
  String get stopped => 'Stopped';

  @override
  String get removeFailedTask => 'Remove failed task';

  @override
  String get taskDetails => 'Task details';

  @override
  String get overview => 'Overview';

  @override
  String get pieces => 'Pieces';

  @override
  String taskId(Object id) {
    return 'Task ID: $id';
  }

  @override
  String statusWithValue(Object status) {
    return 'Status: $status';
  }

  @override
  String sizeWithValue(Object bytes, Object size) {
    return 'Size: $size ($bytes bytes)';
  }

  @override
  String downloadedWithValue(Object bytes, Object size) {
    return 'Downloaded: $size ($bytes bytes)';
  }

  @override
  String progressWithValue(Object progress) {
    return 'Progress: $progress%';
  }

  @override
  String downloadSpeedWithValue(Object bytes, Object speed) {
    return 'Download speed: $speed ($bytes bytes/s)';
  }

  @override
  String uploadSpeedWithValue(Object bytes, Object speed) {
    return 'Upload speed: $speed ($bytes bytes/s)';
  }

  @override
  String connectionsWithValue(Object value) {
    return 'Connections: $value';
  }

  @override
  String saveLocationWithValue(Object value) {
    return 'Save location: $value';
  }

  @override
  String taskTypeWithValue(Object value) {
    return 'Task type: $value';
  }

  @override
  String errorWithValue(Object value) {
    return 'Error: $value';
  }

  @override
  String remainingTimeWithValue(Object value) {
    return 'Remaining time: $value';
  }

  @override
  String get filesTitle => 'Files';

  @override
  String get notSelected => '(not selected)';

  @override
  String get noFileInformation => 'No file information';

  @override
  String get close => 'Close';

  @override
  String get noPieceInformation =>
      'No piece information available for this task.';

  @override
  String get noPieceInformationHint =>
      'The task may not have started yet, or Aria2 did not expose piece data.';

  @override
  String get pieceStatistics => 'Piece statistics';

  @override
  String get totalPieces => 'Total pieces';

  @override
  String get partial => 'Partial';

  @override
  String get missing => 'Missing';

  @override
  String completion(Object value) {
    return 'Completion: $value%';
  }

  @override
  String get pieceMap => 'Piece map';

  @override
  String get legend => 'Legend';

  @override
  String get highProgress => 'High progress (8-b)';

  @override
  String get mediumProgress => 'Medium progress (4-7)';

  @override
  String get lowProgress => 'Low progress (1-3)';

  @override
  String get cannotGetDownloadDirectoryInformation =>
      'Cannot get download directory information';

  @override
  String get downloadDirectoryDoesNotExist =>
      'Download directory does not exist';

  @override
  String get cannotOpenDownloadDirectory => 'Cannot open download directory';

  @override
  String errorOpeningDirectory(Object error) {
    return 'Error opening directory: $error';
  }

  @override
  String get connectionSection => 'Connection';

  @override
  String get transferSection => 'Transfer';

  @override
  String get speedLimits => 'Speed Limits';

  @override
  String get btPtSection => 'BT / PT';

  @override
  String get networkSection => 'Network';

  @override
  String get filesSection => 'Files';

  @override
  String get leaveEmptyToDisableSecretAuth =>
      'Leave empty to disable secret auth';

  @override
  String get splitCount => 'Split count';

  @override
  String get continueUnfinishedDownloads => 'Continue unfinished downloads';

  @override
  String get maxOverallDownloadLimit => 'Max overall download limit (KB/s)';

  @override
  String get maxOverallUploadLimit => 'Max overall upload limit (KB/s)';

  @override
  String get keepSeedingAfterCompletion => 'Keep seeding after completion';

  @override
  String get seedRatio => 'Seed ratio';

  @override
  String get seedTimeMinutes => 'Seed time (minutes)';

  @override
  String get exampleProxy => 'Example: http://proxy:port';

  @override
  String get noProxyHosts => 'No-proxy hosts';

  @override
  String get multipleHostsComma => 'Separate multiple hosts with commas';

  @override
  String get autoRenameFiles => 'Auto rename files';

  @override
  String get allowOverwrite => 'Allow overwrite';

  @override
  String get userAgent => 'User agent';

  @override
  String get decrease => 'Decrease';

  @override
  String get increase => 'Increase';

  @override
  String get settingsSaved => 'Settings saved';

  @override
  String get settingsSaveOnlyHint =>
      'Save only stores your changes and leaves the running built-in instance unchanged.';

  @override
  String get settingsApplySpeedHint =>
      'Save and Apply will update speed limit changes immediately when the built-in instance is connected.';

  @override
  String get settingsApplyRestartHint =>
      'Save and Apply will restart the built-in instance to apply these changes.';

  @override
  String get settingsApplyNoPendingHint =>
      'Save and Apply updates the running built-in instance when possible.';

  @override
  String get restartingBuiltinInstance =>
      'Restarting the built-in instance, please wait...';

  @override
  String get builtinInstanceMissing => 'Built-in instance is missing';

  @override
  String get settingsSavedAppliedSuccess =>
      'Settings saved and applied successfully';

  @override
  String get settingsSavedRpcApplyFailed =>
      'Settings saved and instance restarted, but applying settings via RPC failed';

  @override
  String get settingsSavedRestartFailed =>
      'Settings were saved, but restarting the built-in instance failed';

  @override
  String settingsSavedRestartFailedWithError(Object error) {
    return 'Settings were saved, but restarting the built-in instance failed: $error';
  }

  @override
  String get leavePage => 'Leave this page?';

  @override
  String get unsavedChangesPrompt =>
      'You have unsaved changes. What would you like to do?';

  @override
  String get discard => 'Discard';

  @override
  String startedAtWithValue(Object value) {
    return 'Started at: $value';
  }

  @override
  String get sourceLinks => 'Source links';

  @override
  String get trackers => 'Trackers';

  @override
  String get peers => 'Peers';

  @override
  String get noTrackerInformation => 'No tracker information';

  @override
  String get noPeerInformation => 'No peer information';

  @override
  String get clientLabel => 'Client';

  @override
  String get uploadShort => 'Up';

  @override
  String get downloadShort => 'Down';

  @override
  String get english => 'English';

  @override
  String get chinese => 'Chinese';
}
