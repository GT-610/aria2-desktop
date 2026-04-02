import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/intl.dart' as intl;

import 'l10n_en.dart';
import 'l10n_zh.dart';

// ignore_for_file: type=lint

/// Callers can lookup localized strings with an instance of AppLocalizations
/// returned by `AppLocalizations.of(context)`.
///
/// Applications need to include `AppLocalizations.delegate()` in their app's
/// `localizationDelegates` list, and the locales they support in the app's
/// `supportedLocales` list. For example:
///
/// ```dart
/// import 'l10n/l10n.dart';
///
/// return MaterialApp(
///   localizationsDelegates: AppLocalizations.localizationsDelegates,
///   supportedLocales: AppLocalizations.supportedLocales,
///   home: MyApplicationHome(),
/// );
/// ```
///
/// ## Update pubspec.yaml
///
/// Please make sure to update your pubspec.yaml to include the following
/// packages:
///
/// ```yaml
/// dependencies:
///   # Internationalization support.
///   flutter_localizations:
///     sdk: flutter
///   intl: any # Use the pinned version from flutter_localizations
///
///   # Rest of dependencies
/// ```
///
/// ## iOS Applications
///
/// iOS applications define key application metadata, including supported
/// locales, in an Info.plist file that is built into the application bundle.
/// To configure the locales supported by your app, you’ll need to edit this
/// file.
///
/// First, open your project’s ios/Runner.xcworkspace Xcode workspace file.
/// Then, in the Project Navigator, open the Info.plist file under the Runner
/// project’s Runner folder.
///
/// Next, select the Information Property List item, select Add Item from the
/// Editor menu, then select Localizations from the pop-up menu.
///
/// Select and expand the newly-created Localizations item then, for each
/// locale your application supports, add a new item and select the locale
/// you wish to add from the pop-up menu in the Value field. This list should
/// be consistent with the languages listed in the AppLocalizations.supportedLocales
/// property.
abstract class AppLocalizations {
  AppLocalizations(String locale)
    : localeName = intl.Intl.canonicalizedLocale(locale.toString());

  final String localeName;

  static AppLocalizations? of(BuildContext context) {
    return Localizations.of<AppLocalizations>(context, AppLocalizations);
  }

  static const LocalizationsDelegate<AppLocalizations> delegate =
      _AppLocalizationsDelegate();

  /// A list of this localizations delegate along with the default localizations
  /// delegates.
  ///
  /// Returns a list of localizations delegates containing this delegate along with
  /// GlobalMaterialLocalizations.delegate, GlobalCupertinoLocalizations.delegate,
  /// and GlobalWidgetsLocalizations.delegate.
  ///
  /// Additional delegates can be added by appending to this list in
  /// MaterialApp. This list does not have to be used at all if a custom list
  /// of delegates is preferred or required.
  static const List<LocalizationsDelegate<dynamic>> localizationsDelegates =
      <LocalizationsDelegate<dynamic>>[
        delegate,
        GlobalMaterialLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
      ];

  /// A list of this localizations delegate's supported locales.
  static const List<Locale> supportedLocales = <Locale>[
    Locale('en'),
    Locale('zh'),
  ];

  /// No description provided for @download.
  ///
  /// In en, this message translates to:
  /// **'Download'**
  String get download;

  /// No description provided for @instance.
  ///
  /// In en, this message translates to:
  /// **'Instance'**
  String get instance;

  /// No description provided for @settings.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings;

  /// No description provided for @totalSpeed.
  ///
  /// In en, this message translates to:
  /// **'Total Speed: {speed}'**
  String totalSpeed(Object speed);

  /// No description provided for @activeTasks.
  ///
  /// In en, this message translates to:
  /// **'Active: {count}'**
  String activeTasks(Object count);

  /// No description provided for @waitingTasks.
  ///
  /// In en, this message translates to:
  /// **'Waiting: {count}'**
  String waitingTasks(Object count);

  /// No description provided for @builtinInstanceConnectFailed.
  ///
  /// In en, this message translates to:
  /// **'Built-in Instance Connection Failed'**
  String get builtinInstanceConnectFailed;

  /// No description provided for @builtinInstanceConnectFailedTip.
  ///
  /// In en, this message translates to:
  /// **'Built-in instance connection failed, only remote features available'**
  String get builtinInstanceConnectFailedTip;

  /// No description provided for @ok.
  ///
  /// In en, this message translates to:
  /// **'OK'**
  String get ok;

  /// No description provided for @notConnected.
  ///
  /// In en, this message translates to:
  /// **'Not Connected'**
  String get notConnected;

  /// No description provided for @connecting.
  ///
  /// In en, this message translates to:
  /// **'Connecting'**
  String get connecting;

  /// No description provided for @connected.
  ///
  /// In en, this message translates to:
  /// **'Connected'**
  String get connected;

  /// No description provided for @connectFailed.
  ///
  /// In en, this message translates to:
  /// **'Connect Failed'**
  String get connectFailed;

  /// No description provided for @connect.
  ///
  /// In en, this message translates to:
  /// **'Connect'**
  String get connect;

  /// No description provided for @reconnect.
  ///
  /// In en, this message translates to:
  /// **'Reconnect'**
  String get reconnect;

  /// No description provided for @disconnect.
  ///
  /// In en, this message translates to:
  /// **'Disconnect'**
  String get disconnect;

  /// No description provided for @settings2.
  ///
  /// In en, this message translates to:
  /// **'Settings'**
  String get settings2;

  /// No description provided for @edit.
  ///
  /// In en, this message translates to:
  /// **'Edit'**
  String get edit;

  /// No description provided for @delete.
  ///
  /// In en, this message translates to:
  /// **'Delete'**
  String get delete;

  /// No description provided for @builtin.
  ///
  /// In en, this message translates to:
  /// **'Built-in'**
  String get builtin;

  /// No description provided for @remote.
  ///
  /// In en, this message translates to:
  /// **'Remote'**
  String get remote;

  /// No description provided for @aria2Version.
  ///
  /// In en, this message translates to:
  /// **'Aria2 Version: {version}'**
  String aria2Version(Object version);

  /// No description provided for @gettingVersion.
  ///
  /// In en, this message translates to:
  /// **'Getting version...'**
  String get gettingVersion;

  /// No description provided for @loadSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to load settings'**
  String get loadSettingsFailed;

  /// No description provided for @saveSettingsFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to save settings'**
  String get saveSettingsFailed;

  /// No description provided for @globalSettings.
  ///
  /// In en, this message translates to:
  /// **'Global Settings'**
  String get globalSettings;

  /// No description provided for @runAtStartup.
  ///
  /// In en, this message translates to:
  /// **'Run at startup'**
  String get runAtStartup;

  /// No description provided for @runAtStartupTip.
  ///
  /// In en, this message translates to:
  /// **'Start app when system starts'**
  String get runAtStartupTip;

  /// No description provided for @minimizeToTray.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray'**
  String get minimizeToTray;

  /// No description provided for @minimizeToTrayTip.
  ///
  /// In en, this message translates to:
  /// **'Minimize to tray when closing window instead of exiting'**
  String get minimizeToTrayTip;

  /// No description provided for @appearance.
  ///
  /// In en, this message translates to:
  /// **'Appearance'**
  String get appearance;

  /// No description provided for @appearanceTip.
  ///
  /// In en, this message translates to:
  /// **'Customize app theme and colors'**
  String get appearanceTip;

  /// No description provided for @light.
  ///
  /// In en, this message translates to:
  /// **'Light'**
  String get light;

  /// No description provided for @dark.
  ///
  /// In en, this message translates to:
  /// **'Dark'**
  String get dark;

  /// No description provided for @system.
  ///
  /// In en, this message translates to:
  /// **'System'**
  String get system;

  /// No description provided for @language.
  ///
  /// In en, this message translates to:
  /// **'Language'**
  String get language;

  /// No description provided for @themeMode.
  ///
  /// In en, this message translates to:
  /// **'Theme Mode'**
  String get themeMode;

  /// No description provided for @themeColor.
  ///
  /// In en, this message translates to:
  /// **'Theme Color'**
  String get themeColor;

  /// No description provided for @preset.
  ///
  /// In en, this message translates to:
  /// **'Preset'**
  String get preset;

  /// No description provided for @custom.
  ///
  /// In en, this message translates to:
  /// **'Custom'**
  String get custom;

  /// No description provided for @colorCode.
  ///
  /// In en, this message translates to:
  /// **'Color Code'**
  String get colorCode;

  /// No description provided for @done.
  ///
  /// In en, this message translates to:
  /// **'Done'**
  String get done;

  /// No description provided for @failedToSetThemeMode.
  ///
  /// In en, this message translates to:
  /// **'Failed to set theme mode: {error}'**
  String failedToSetThemeMode(Object error);

  /// No description provided for @failedToSetThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Failed to set theme color: {error}'**
  String failedToSetThemeColor(Object error);

  /// No description provided for @failedToSetCustomThemeColor.
  ///
  /// In en, this message translates to:
  /// **'Failed to set custom theme color: {error}'**
  String failedToSetCustomThemeColor(Object error);

  /// No description provided for @logSettings.
  ///
  /// In en, this message translates to:
  /// **'Log Settings'**
  String get logSettings;

  /// No description provided for @logLevel.
  ///
  /// In en, this message translates to:
  /// **'Log Level'**
  String get logLevel;

  /// No description provided for @saveLogToFile.
  ///
  /// In en, this message translates to:
  /// **'Save log to file'**
  String get saveLogToFile;

  /// No description provided for @viewLogFiles.
  ///
  /// In en, this message translates to:
  /// **'View log files'**
  String get viewLogFiles;

  /// No description provided for @thisFeatureWillBeImplemented.
  ///
  /// In en, this message translates to:
  /// **'This feature will be implemented in future versions'**
  String get thisFeatureWillBeImplemented;

  /// No description provided for @cannotOpenLogDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cannot open log directory'**
  String get cannotOpenLogDirectory;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @version.
  ///
  /// In en, this message translates to:
  /// **'Version'**
  String get version;

  /// No description provided for @versionLoading.
  ///
  /// In en, this message translates to:
  /// **'Loading...'**
  String get versionLoading;

  /// No description provided for @contributors.
  ///
  /// In en, this message translates to:
  /// **'Contributors'**
  String get contributors;

  /// No description provided for @license.
  ///
  /// In en, this message translates to:
  /// **'License'**
  String get license;

  /// No description provided for @instanceSettings.
  ///
  /// In en, this message translates to:
  /// **'Instance Settings'**
  String get instanceSettings;

  /// No description provided for @save.
  ///
  /// In en, this message translates to:
  /// **'Save'**
  String get save;

  /// No description provided for @saveAndApply.
  ///
  /// In en, this message translates to:
  /// **'Save & Apply'**
  String get saveAndApply;

  /// No description provided for @basicSettings.
  ///
  /// In en, this message translates to:
  /// **'Basic Settings'**
  String get basicSettings;

  /// No description provided for @rpcListenPort.
  ///
  /// In en, this message translates to:
  /// **'RPC Listen Port'**
  String get rpcListenPort;

  /// No description provided for @rpcPortDefault.
  ///
  /// In en, this message translates to:
  /// **'Default: 16800'**
  String get rpcPortDefault;

  /// No description provided for @rpcSecret.
  ///
  /// In en, this message translates to:
  /// **'RPC Secret'**
  String get rpcSecret;

  /// No description provided for @rpcSecretTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty if no secret required'**
  String get rpcSecretTip;

  /// No description provided for @transferSettings.
  ///
  /// In en, this message translates to:
  /// **'Transfer Settings'**
  String get transferSettings;

  /// No description provided for @maxConcurrentDownloads.
  ///
  /// In en, this message translates to:
  /// **'Max Concurrent Downloads'**
  String get maxConcurrentDownloads;

  /// No description provided for @maxConnectionPerServer.
  ///
  /// In en, this message translates to:
  /// **'Max Connections Per Server'**
  String get maxConnectionPerServer;

  /// No description provided for @downloadSegments.
  ///
  /// In en, this message translates to:
  /// **'Download Segments'**
  String get downloadSegments;

  /// No description provided for @enableContinueDownload.
  ///
  /// In en, this message translates to:
  /// **'Enable Continue Download'**
  String get enableContinueDownload;

  /// No description provided for @speedLimit.
  ///
  /// In en, this message translates to:
  /// **'Speed Limit'**
  String get speedLimit;

  /// No description provided for @globalDownloadLimit.
  ///
  /// In en, this message translates to:
  /// **'Global Download Limit (KB/s)'**
  String get globalDownloadLimit;

  /// No description provided for @downloadLimitTip.
  ///
  /// In en, this message translates to:
  /// **'0 means no limit'**
  String get downloadLimitTip;

  /// No description provided for @globalUploadLimit.
  ///
  /// In en, this message translates to:
  /// **'Global Upload Limit (KB/s)'**
  String get globalUploadLimit;

  /// No description provided for @uploadLimitTip.
  ///
  /// In en, this message translates to:
  /// **'0 means no limit'**
  String get uploadLimitTip;

  /// No description provided for @btPtSettings.
  ///
  /// In en, this message translates to:
  /// **'BT/PT Settings'**
  String get btPtSettings;

  /// No description provided for @saveBtMetadata.
  ///
  /// In en, this message translates to:
  /// **'Save BT Metadata'**
  String get saveBtMetadata;

  /// No description provided for @loadSavedBtMetadata.
  ///
  /// In en, this message translates to:
  /// **'Load Saved BT Metadata'**
  String get loadSavedBtMetadata;

  /// No description provided for @forceBtEncryption.
  ///
  /// In en, this message translates to:
  /// **'Force BT Encryption'**
  String get forceBtEncryption;

  /// No description provided for @keepSeeding.
  ///
  /// In en, this message translates to:
  /// **'Keep Seeding'**
  String get keepSeeding;

  /// No description provided for @seedingRatio.
  ///
  /// In en, this message translates to:
  /// **'Seeding Ratio'**
  String get seedingRatio;

  /// No description provided for @seedingRatioTip.
  ///
  /// In en, this message translates to:
  /// **'0 means infinite'**
  String get seedingRatioTip;

  /// No description provided for @seedingTime.
  ///
  /// In en, this message translates to:
  /// **'Seeding Time (minutes)'**
  String get seedingTime;

  /// No description provided for @seedingTimeTip.
  ///
  /// In en, this message translates to:
  /// **'0 means infinite'**
  String get seedingTimeTip;

  /// No description provided for @excludedTrackers.
  ///
  /// In en, this message translates to:
  /// **'Excluded Trackers'**
  String get excludedTrackers;

  /// No description provided for @trackersTip.
  ///
  /// In en, this message translates to:
  /// **'Separate multiple trackers with commas'**
  String get trackersTip;

  /// No description provided for @networkSettings.
  ///
  /// In en, this message translates to:
  /// **'Network Settings'**
  String get networkSettings;

  /// No description provided for @globalProxy.
  ///
  /// In en, this message translates to:
  /// **'Global Proxy'**
  String get globalProxy;

  /// No description provided for @proxyFormat.
  ///
  /// In en, this message translates to:
  /// **'Format: http://proxy:port'**
  String get proxyFormat;

  /// No description provided for @noProxyAddresses.
  ///
  /// In en, this message translates to:
  /// **'No Proxy Addresses'**
  String get noProxyAddresses;

  /// No description provided for @noProxyTip.
  ///
  /// In en, this message translates to:
  /// **'Separate multiple addresses with commas'**
  String get noProxyTip;

  /// No description provided for @dhtListenPort.
  ///
  /// In en, this message translates to:
  /// **'DHT Listen Port'**
  String get dhtListenPort;

  /// No description provided for @enableDht6.
  ///
  /// In en, this message translates to:
  /// **'Enable DHT6'**
  String get enableDht6;

  /// No description provided for @fileSettings.
  ///
  /// In en, this message translates to:
  /// **'File Settings'**
  String get fileSettings;

  /// No description provided for @downloadDir.
  ///
  /// In en, this message translates to:
  /// **'Download Directory'**
  String get downloadDir;

  /// No description provided for @selectDir.
  ///
  /// In en, this message translates to:
  /// **'Select'**
  String get selectDir;

  /// No description provided for @failedToGetTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed to get tasks: {error}'**
  String failedToGetTasks(Object error);

  /// No description provided for @taskAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task added successfully'**
  String get taskAddedSuccess;

  /// No description provided for @noConnectedInstance.
  ///
  /// In en, this message translates to:
  /// **'No connected instance'**
  String get noConnectedInstance;

  /// No description provided for @addTaskFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to add task: {error}'**
  String addTaskFailed(Object error);

  /// No description provided for @unknownInstance.
  ///
  /// In en, this message translates to:
  /// **'Unknown Instance'**
  String get unknownInstance;

  /// No description provided for @pause.
  ///
  /// In en, this message translates to:
  /// **'Pause'**
  String get pause;

  /// No description provided for @stop.
  ///
  /// In en, this message translates to:
  /// **'Stop'**
  String get stop;

  /// No description provided for @resume.
  ///
  /// In en, this message translates to:
  /// **'Resume'**
  String get resume;

  /// No description provided for @retry.
  ///
  /// In en, this message translates to:
  /// **'Retry'**
  String get retry;

  /// No description provided for @openDownloadDir.
  ///
  /// In en, this message translates to:
  /// **'Open Download Directory'**
  String get openDownloadDir;

  /// No description provided for @filterAll.
  ///
  /// In en, this message translates to:
  /// **'All'**
  String get filterAll;

  /// No description provided for @filterDownloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get filterDownloading;

  /// No description provided for @filterPaused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get filterPaused;

  /// No description provided for @filterStopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get filterStopped;

  /// No description provided for @filterComplete.
  ///
  /// In en, this message translates to:
  /// **'Complete'**
  String get filterComplete;

  /// No description provided for @addTask.
  ///
  /// In en, this message translates to:
  /// **'Add Task'**
  String get addTask;

  /// No description provided for @addUrl.
  ///
  /// In en, this message translates to:
  /// **'Add URL'**
  String get addUrl;

  /// No description provided for @addTorrent.
  ///
  /// In en, this message translates to:
  /// **'Add Torrent'**
  String get addTorrent;

  /// No description provided for @addMetalink.
  ///
  /// In en, this message translates to:
  /// **'Add Metalink'**
  String get addMetalink;

  /// No description provided for @addUri.
  ///
  /// In en, this message translates to:
  /// **'Add URI'**
  String get addUri;

  /// No description provided for @enterUrl.
  ///
  /// In en, this message translates to:
  /// **'Enter URL'**
  String get enterUrl;

  /// No description provided for @urlHint.
  ///
  /// In en, this message translates to:
  /// **'http://example.com/file.zip'**
  String get urlHint;

  /// No description provided for @saveTo.
  ///
  /// In en, this message translates to:
  /// **'Save to'**
  String get saveTo;

  /// No description provided for @selectDownloadDir.
  ///
  /// In en, this message translates to:
  /// **'Select download directory'**
  String get selectDownloadDir;

  /// No description provided for @taskName.
  ///
  /// In en, this message translates to:
  /// **'Task Name'**
  String get taskName;

  /// No description provided for @taskNameTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use original filename'**
  String get taskNameTip;

  /// No description provided for @instances.
  ///
  /// In en, this message translates to:
  /// **'Instances'**
  String get instances;

  /// No description provided for @noSavedInstances.
  ///
  /// In en, this message translates to:
  /// **'No saved instances'**
  String get noSavedInstances;

  /// No description provided for @clickToAddInstance.
  ///
  /// In en, this message translates to:
  /// **'Click the button in the bottom right to add a new instance'**
  String get clickToAddInstance;

  /// No description provided for @instanceOnline.
  ///
  /// In en, this message translates to:
  /// **'Instance online'**
  String get instanceOnline;

  /// No description provided for @instanceOffline.
  ///
  /// In en, this message translates to:
  /// **'Instance offline or cannot connect'**
  String get instanceOffline;

  /// No description provided for @checkStatusFailed.
  ///
  /// In en, this message translates to:
  /// **'Check status failed: {error}'**
  String checkStatusFailed(Object error);

  /// No description provided for @disconnected.
  ///
  /// In en, this message translates to:
  /// **'Disconnected'**
  String get disconnected;

  /// No description provided for @confirmDelete.
  ///
  /// In en, this message translates to:
  /// **'Confirm Delete'**
  String get confirmDelete;

  /// No description provided for @confirmDeleteInstance.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete instance \"{name}\"?'**
  String confirmDeleteInstance(Object name);

  /// No description provided for @cancel.
  ///
  /// In en, this message translates to:
  /// **'Cancel'**
  String get cancel;

  /// No description provided for @instanceDeletedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Instance deleted successfully'**
  String get instanceDeletedSuccess;

  /// No description provided for @deleteFailed.
  ///
  /// In en, this message translates to:
  /// **'Delete failed: {error}'**
  String deleteFailed(Object error);

  /// No description provided for @instanceUpdatedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Instance updated successfully'**
  String get instanceUpdatedSuccess;

  /// No description provided for @instanceAddedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Instance added successfully'**
  String get instanceAddedSuccess;

  /// No description provided for @operationFailed.
  ///
  /// In en, this message translates to:
  /// **'Operation failed: {error}'**
  String operationFailed(Object error);

  /// No description provided for @addInstance.
  ///
  /// In en, this message translates to:
  /// **'Add Instance'**
  String get addInstance;

  /// No description provided for @add.
  ///
  /// In en, this message translates to:
  /// **'Add'**
  String get add;

  /// No description provided for @successConnected.
  ///
  /// In en, this message translates to:
  /// **'Successfully connected to instance: {name}'**
  String successConnected(Object name);

  /// No description provided for @connectionFailedCheckConfig.
  ///
  /// In en, this message translates to:
  /// **'Connection failed, please check configuration'**
  String get connectionFailedCheckConfig;

  /// No description provided for @connectionFailedError.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailedError(Object error);

  /// No description provided for @editInstance.
  ///
  /// In en, this message translates to:
  /// **'Edit Instance'**
  String get editInstance;

  /// No description provided for @instanceName.
  ///
  /// In en, this message translates to:
  /// **'Instance Name'**
  String get instanceName;

  /// No description provided for @instanceNameTip.
  ///
  /// In en, this message translates to:
  /// **'Enter instance name'**
  String get instanceNameTip;

  /// No description provided for @host.
  ///
  /// In en, this message translates to:
  /// **'Host'**
  String get host;

  /// No description provided for @port.
  ///
  /// In en, this message translates to:
  /// **'Port'**
  String get port;

  /// No description provided for @hostTip.
  ///
  /// In en, this message translates to:
  /// **'e.g., localhost:6800 or http://aria2.example.com:6800'**
  String get hostTip;

  /// No description provided for @protocol.
  ///
  /// In en, this message translates to:
  /// **'Protocol'**
  String get protocol;

  /// No description provided for @http.
  ///
  /// In en, this message translates to:
  /// **'HTTP'**
  String get http;

  /// No description provided for @https.
  ///
  /// In en, this message translates to:
  /// **'HTTPS'**
  String get https;

  /// No description provided for @rpcSecretHint.
  ///
  /// In en, this message translates to:
  /// **'RPC secret token'**
  String get rpcSecretHint;

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @connectionSuccess.
  ///
  /// In en, this message translates to:
  /// **'Connection successful'**
  String get connectionSuccess;

  /// No description provided for @connectionFailed.
  ///
  /// In en, this message translates to:
  /// **'Connection failed: {error}'**
  String connectionFailed(Object error);

  /// No description provided for @confirmDeleteTip.
  ///
  /// In en, this message translates to:
  /// **'Are you sure you want to delete this instance?'**
  String get confirmDeleteTip;

  /// No description provided for @confirm.
  ///
  /// In en, this message translates to:
  /// **'Confirm'**
  String get confirm;

  /// No description provided for @debug.
  ///
  /// In en, this message translates to:
  /// **'Debug'**
  String get debug;

  /// No description provided for @info.
  ///
  /// In en, this message translates to:
  /// **'Info'**
  String get info;

  /// No description provided for @warning.
  ///
  /// In en, this message translates to:
  /// **'Warning'**
  String get warning;

  /// No description provided for @error.
  ///
  /// In en, this message translates to:
  /// **'Error'**
  String get error;

  /// No description provided for @instanceNameRequired.
  ///
  /// In en, this message translates to:
  /// **'Instance name is required'**
  String get instanceNameRequired;

  /// No description provided for @instanceNameTooLong.
  ///
  /// In en, this message translates to:
  /// **'Instance name must be 30 characters or less'**
  String get instanceNameTooLong;

  /// No description provided for @hostRequired.
  ///
  /// In en, this message translates to:
  /// **'Host is required'**
  String get hostRequired;

  /// No description provided for @portRequired.
  ///
  /// In en, this message translates to:
  /// **'Port is required'**
  String get portRequired;

  /// No description provided for @portInvalid.
  ///
  /// In en, this message translates to:
  /// **'Port must be between 1 and 65535'**
  String get portInvalid;
}

class _AppLocalizationsDelegate
    extends LocalizationsDelegate<AppLocalizations> {
  const _AppLocalizationsDelegate();

  @override
  Future<AppLocalizations> load(Locale locale) {
    return SynchronousFuture<AppLocalizations>(lookupAppLocalizations(locale));
  }

  @override
  bool isSupported(Locale locale) =>
      <String>['en', 'zh'].contains(locale.languageCode);

  @override
  bool shouldReload(_AppLocalizationsDelegate old) => false;
}

AppLocalizations lookupAppLocalizations(Locale locale) {
  // Lookup logic when only language code is specified.
  switch (locale.languageCode) {
    case 'en':
      return AppLocalizationsEn();
    case 'zh':
      return AppLocalizationsZh();
  }

  throw FlutterError(
    'AppLocalizations.delegate failed to load unsupported locale "$locale". This is likely '
    'an issue with the localizations generation tool. Please file an issue '
    'on GitHub with a reproducible sample app and the gen-l10n configuration '
    'that was used.',
  );
}
