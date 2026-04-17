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

  /// No description provided for @showMainWindow.
  ///
  /// In en, this message translates to:
  /// **'Show main window'**
  String get showMainWindow;

  /// No description provided for @hideMainWindow.
  ///
  /// In en, this message translates to:
  /// **'Hide main window'**
  String get hideMainWindow;

  /// No description provided for @quitApp.
  ///
  /// In en, this message translates to:
  /// **'Quit'**
  String get quitApp;

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

  /// No description provided for @runMode.
  ///
  /// In en, this message translates to:
  /// **'Run mode'**
  String get runMode;

  /// No description provided for @runModeStandard.
  ///
  /// In en, this message translates to:
  /// **'Standard'**
  String get runModeStandard;

  /// No description provided for @runModeStandardTip.
  ///
  /// In en, this message translates to:
  /// **'Use normal window behavior. Closing the main window exits the app.'**
  String get runModeStandardTip;

  /// No description provided for @runModeTray.
  ///
  /// In en, this message translates to:
  /// **'Tray'**
  String get runModeTray;

  /// No description provided for @runModeTrayTip.
  ///
  /// In en, this message translates to:
  /// **'Keep the app available in the system tray. Closing the main window hides it to the tray.'**
  String get runModeTrayTip;

  /// No description provided for @runModeHideTray.
  ///
  /// In en, this message translates to:
  /// **'Hide tray'**
  String get runModeHideTray;

  /// No description provided for @runModeHideTrayTip.
  ///
  /// In en, this message translates to:
  /// **'Disable system tray integration entirely. Closing the main window exits the app.'**
  String get runModeHideTrayTip;

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

  /// No description provided for @autoHideWindow.
  ///
  /// In en, this message translates to:
  /// **'Auto hide window'**
  String get autoHideWindow;

  /// No description provided for @autoHideWindowTip.
  ///
  /// In en, this message translates to:
  /// **'Hide the main window automatically when it loses focus'**
  String get autoHideWindowTip;

  /// No description provided for @showTraySpeed.
  ///
  /// In en, this message translates to:
  /// **'Show tray speed'**
  String get showTraySpeed;

  /// No description provided for @showTraySpeedTip.
  ///
  /// In en, this message translates to:
  /// **'Display total download speed in the tray tooltip'**
  String get showTraySpeedTip;

  /// No description provided for @taskNotification.
  ///
  /// In en, this message translates to:
  /// **'Task notifications'**
  String get taskNotification;

  /// No description provided for @taskNotificationTip.
  ///
  /// In en, this message translates to:
  /// **'Show notifications when downloads complete or fail'**
  String get taskNotificationTip;

  /// No description provided for @systemIntegration.
  ///
  /// In en, this message translates to:
  /// **'System Integration'**
  String get systemIntegration;

  /// No description provided for @setAsDefaultClient.
  ///
  /// In en, this message translates to:
  /// **'Default client'**
  String get setAsDefaultClient;

  /// No description provided for @setAsDefaultClientTip.
  ///
  /// In en, this message translates to:
  /// **'Register this app to handle supported download links from Windows.'**
  String get setAsDefaultClientTip;

  /// No description provided for @handleMagnetLinks.
  ///
  /// In en, this message translates to:
  /// **'Handle magnet links'**
  String get handleMagnetLinks;

  /// No description provided for @handleMagnetLinksTip.
  ///
  /// In en, this message translates to:
  /// **'Open magnet:// links with this app.'**
  String get handleMagnetLinksTip;

  /// No description provided for @handleThunderLinks.
  ///
  /// In en, this message translates to:
  /// **'Handle thunder links'**
  String get handleThunderLinks;

  /// No description provided for @handleThunderLinksTip.
  ///
  /// In en, this message translates to:
  /// **'Open thunder:// links with this app.'**
  String get handleThunderLinksTip;

  /// No description provided for @protocolPreferenceRetryWarning.
  ///
  /// In en, this message translates to:
  /// **'The preference for {protocol} was saved, but Windows registration failed. The app will retry on next launch.'**
  String protocolPreferenceRetryWarning(Object protocol);

  /// No description provided for @protocolReconcileFailed.
  ///
  /// In en, this message translates to:
  /// **'Could not apply saved protocol preferences for: {protocols}.'**
  String protocolReconcileFailed(Object protocols);

  /// No description provided for @connectBeforeHandlingExternalLink.
  ///
  /// In en, this message translates to:
  /// **'Connect an instance before opening external download links.'**
  String get connectBeforeHandlingExternalLink;

  /// No description provided for @skipDeleteConfirm.
  ///
  /// In en, this message translates to:
  /// **'Skip delete confirmation'**
  String get skipDeleteConfirm;

  /// No description provided for @skipDeleteConfirmTip.
  ///
  /// In en, this message translates to:
  /// **'Delete tasks immediately without asking whether to remove downloaded files'**
  String get skipDeleteConfirmTip;

  /// No description provided for @resumeAllOnLaunch.
  ///
  /// In en, this message translates to:
  /// **'Resume all on launch'**
  String get resumeAllOnLaunch;

  /// No description provided for @resumeAllOnLaunchTip.
  ///
  /// In en, this message translates to:
  /// **'Automatically resume paused tasks after the app starts'**
  String get resumeAllOnLaunchTip;

  /// No description provided for @showDownloadsAfterAdd.
  ///
  /// In en, this message translates to:
  /// **'Show downloading tasks after add'**
  String get showDownloadsAfterAdd;

  /// No description provided for @showDownloadsAfterAddTip.
  ///
  /// In en, this message translates to:
  /// **'Switch to the downloading task view after adding a new task'**
  String get showDownloadsAfterAddTip;

  /// No description provided for @showProgressBar.
  ///
  /// In en, this message translates to:
  /// **'Show progress bars'**
  String get showProgressBar;

  /// No description provided for @showProgressBarTip.
  ///
  /// In en, this message translates to:
  /// **'Display task progress bars in the download list'**
  String get showProgressBarTip;

  /// No description provided for @hideTitleBar.
  ///
  /// In en, this message translates to:
  /// **'Hide title bar'**
  String get hideTitleBar;

  /// No description provided for @hideTitleBarTip.
  ///
  /// In en, this message translates to:
  /// **'Use a custom desktop window frame instead of the native title bar.'**
  String get hideTitleBarTip;

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

  /// No description provided for @viewLogs.
  ///
  /// In en, this message translates to:
  /// **'View logs'**
  String get viewLogs;

  /// No description provided for @viewLogsTip.
  ///
  /// In en, this message translates to:
  /// **'View in-app logs and debug output'**
  String get viewLogsTip;

  /// No description provided for @maintenance.
  ///
  /// In en, this message translates to:
  /// **'Maintenance'**
  String get maintenance;

  /// No description provided for @resetAppSettings.
  ///
  /// In en, this message translates to:
  /// **'Reset app settings'**
  String get resetAppSettings;

  /// No description provided for @resetAppSettingsTip.
  ///
  /// In en, this message translates to:
  /// **'Restore app preferences and built-in defaults without deleting tasks or downloaded files'**
  String get resetAppSettingsTip;

  /// No description provided for @resetAppSettingsConfirmMessage.
  ///
  /// In en, this message translates to:
  /// **'Reset all app preferences and built-in aria2 settings to their defaults? Existing tasks and downloaded files will be kept.'**
  String get resetAppSettingsConfirmMessage;

  /// No description provided for @resetAppSettingsAction.
  ///
  /// In en, this message translates to:
  /// **'Reset settings'**
  String get resetAppSettingsAction;

  /// No description provided for @resetAppSettingsSuccess.
  ///
  /// In en, this message translates to:
  /// **'App settings were reset to defaults.'**
  String get resetAppSettingsSuccess;

  /// No description provided for @about.
  ///
  /// In en, this message translates to:
  /// **'About'**
  String get about;

  /// No description provided for @aboutProject.
  ///
  /// In en, this message translates to:
  /// **'Project'**
  String get aboutProject;

  /// No description provided for @aboutProjectDescription.
  ///
  /// In en, this message translates to:
  /// **'Setsuna is a modern aria2 desktop client focused on Motrix-level compatibility while adding built-in and remote instance management.'**
  String get aboutProjectDescription;

  /// No description provided for @sourceCode.
  ///
  /// In en, this message translates to:
  /// **'Source Code'**
  String get sourceCode;

  /// No description provided for @reportIssue.
  ///
  /// In en, this message translates to:
  /// **'Report Issue'**
  String get reportIssue;

  /// No description provided for @participants.
  ///
  /// In en, this message translates to:
  /// **'Participants'**
  String get participants;

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

  /// No description provided for @rpcPath.
  ///
  /// In en, this message translates to:
  /// **'RPC Path'**
  String get rpcPath;

  /// No description provided for @rpcPathTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use jsonrpc'**
  String get rpcPathTip;

  /// No description provided for @rpcRequestHeaders.
  ///
  /// In en, this message translates to:
  /// **'RPC Request Headers'**
  String get rpcRequestHeaders;

  /// No description provided for @rpcRequestHeadersTip.
  ///
  /// In en, this message translates to:
  /// **'One header per line, in the form Header-Name: value'**
  String get rpcRequestHeadersTip;

  /// No description provided for @instanceNameAutoHint.
  ///
  /// In en, this message translates to:
  /// **'Leave blank to use {fallback} as a reference name'**
  String instanceNameAutoHint(Object fallback);

  /// No description provided for @testConnection.
  ///
  /// In en, this message translates to:
  /// **'Test Connection'**
  String get testConnection;

  /// No description provided for @testingConnection.
  ///
  /// In en, this message translates to:
  /// **'Testing...'**
  String get testingConnection;

  /// No description provided for @rpcHeadersConfigured.
  ///
  /// In en, this message translates to:
  /// **'Custom RPC headers configured'**
  String get rpcHeadersConfigured;

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

  /// No description provided for @btListenPort.
  ///
  /// In en, this message translates to:
  /// **'BT Listen Port'**
  String get btListenPort;

  /// No description provided for @btListenPortTip.
  ///
  /// In en, this message translates to:
  /// **'Supports a single port or range, for example 6881-6999'**
  String get btListenPortTip;

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

  /// No description provided for @enableProxy.
  ///
  /// In en, this message translates to:
  /// **'Enable proxy'**
  String get enableProxy;

  /// No description provided for @enableProxyTip.
  ///
  /// In en, this message translates to:
  /// **'Enable or disable proxy settings without losing the saved proxy address'**
  String get enableProxyTip;

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

  /// No description provided for @enableUpnp.
  ///
  /// In en, this message translates to:
  /// **'Enable UPnP / NAT-PMP'**
  String get enableUpnp;

  /// No description provided for @enableUpnpTip.
  ///
  /// In en, this message translates to:
  /// **'Use router port mapping for BT and DHT ports. Restart required.'**
  String get enableUpnpTip;

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

  /// No description provided for @defaultDownloadDir.
  ///
  /// In en, this message translates to:
  /// **'Default Download Directory'**
  String get defaultDownloadDir;

  /// No description provided for @remoteDownloadDirHint.
  ///
  /// In en, this message translates to:
  /// **'Enter the remote server path manually'**
  String get remoteDownloadDirHint;

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

  /// No description provided for @failed.
  ///
  /// In en, this message translates to:
  /// **'Failed'**
  String get failed;

  /// No description provided for @check.
  ///
  /// In en, this message translates to:
  /// **'Check'**
  String get check;

  /// No description provided for @addInstanceTooltip.
  ///
  /// In en, this message translates to:
  /// **'Add instance'**
  String get addInstanceTooltip;

  /// No description provided for @instanceReachable.
  ///
  /// In en, this message translates to:
  /// **'Instance is reachable'**
  String get instanceReachable;

  /// No description provided for @instanceOfflineUnreachable.
  ///
  /// In en, this message translates to:
  /// **'Instance is offline or unreachable'**
  String get instanceOfflineUnreachable;

  /// No description provided for @failedToDeleteInstance.
  ///
  /// In en, this message translates to:
  /// **'Failed to delete instance: {error}'**
  String failedToDeleteInstance(Object error);

  /// No description provided for @disconnectedSuccessfully.
  ///
  /// In en, this message translates to:
  /// **'Disconnected successfully'**
  String get disconnectedSuccessfully;

  /// No description provided for @versionWillAppearAfterConnection.
  ///
  /// In en, this message translates to:
  /// **'Version will appear after connection'**
  String get versionWillAppearAfterConnection;

  /// No description provided for @builtInDefaultInstance.
  ///
  /// In en, this message translates to:
  /// **'{name} (Built-in default)'**
  String builtInDefaultInstance(Object name);

  /// No description provided for @builtInInstance.
  ///
  /// In en, this message translates to:
  /// **'{name} (Built-in)'**
  String builtInInstance(Object name);

  /// No description provided for @searchTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Search tasks by name, path, or instance'**
  String get searchTasksHint;

  /// No description provided for @sortTasks.
  ///
  /// In en, this message translates to:
  /// **'Sort tasks'**
  String get sortTasks;

  /// No description provided for @ascending.
  ///
  /// In en, this message translates to:
  /// **'Ascending'**
  String get ascending;

  /// No description provided for @descending.
  ///
  /// In en, this message translates to:
  /// **'Descending'**
  String get descending;

  /// No description provided for @name.
  ///
  /// In en, this message translates to:
  /// **'Name'**
  String get name;

  /// No description provided for @progress.
  ///
  /// In en, this message translates to:
  /// **'Progress'**
  String get progress;

  /// No description provided for @size.
  ///
  /// In en, this message translates to:
  /// **'Size'**
  String get size;

  /// No description provided for @speed.
  ///
  /// In en, this message translates to:
  /// **'Speed'**
  String get speed;

  /// No description provided for @pauseAll.
  ///
  /// In en, this message translates to:
  /// **'Pause All'**
  String get pauseAll;

  /// No description provided for @resumeAll.
  ///
  /// In en, this message translates to:
  /// **'Resume All'**
  String get resumeAll;

  /// No description provided for @deleteAll.
  ///
  /// In en, this message translates to:
  /// **'Delete All'**
  String get deleteAll;

  /// No description provided for @allTasksLabel.
  ///
  /// In en, this message translates to:
  /// **'All tasks'**
  String get allTasksLabel;

  /// No description provided for @byStatus.
  ///
  /// In en, this message translates to:
  /// **'By status'**
  String get byStatus;

  /// No description provided for @byType.
  ///
  /// In en, this message translates to:
  /// **'By type'**
  String get byType;

  /// No description provided for @byInstance.
  ///
  /// In en, this message translates to:
  /// **'By instance'**
  String get byInstance;

  /// No description provided for @allInstances.
  ///
  /// In en, this message translates to:
  /// **'All instances'**
  String get allInstances;

  /// No description provided for @chooseCategory.
  ///
  /// In en, this message translates to:
  /// **'Choose a category'**
  String get chooseCategory;

  /// No description provided for @stoppedCompleted.
  ///
  /// In en, this message translates to:
  /// **'Stopped / Completed'**
  String get stoppedCompleted;

  /// No description provided for @unknownPath.
  ///
  /// In en, this message translates to:
  /// **'Unknown path'**
  String get unknownPath;

  /// No description provided for @selectedFile.
  ///
  /// In en, this message translates to:
  /// **'Selected: {name}'**
  String selectedFile(Object name);

  /// No description provided for @addTaskDialogTitle.
  ///
  /// In en, this message translates to:
  /// **'Add task'**
  String get addTaskDialogTitle;

  /// No description provided for @uriTab.
  ///
  /// In en, this message translates to:
  /// **'URI'**
  String get uriTab;

  /// No description provided for @torrentTab.
  ///
  /// In en, this message translates to:
  /// **'Torrent'**
  String get torrentTab;

  /// No description provided for @metalinkTab.
  ///
  /// In en, this message translates to:
  /// **'Metalink'**
  String get metalinkTab;

  /// No description provided for @urlOrMagnetLink.
  ///
  /// In en, this message translates to:
  /// **'URL or magnet link'**
  String get urlOrMagnetLink;

  /// No description provided for @enterOneOrMoreLinks.
  ///
  /// In en, this message translates to:
  /// **'Enter one or more links'**
  String get enterOneOrMoreLinks;

  /// No description provided for @pasteFromClipboard.
  ///
  /// In en, this message translates to:
  /// **'Paste from clipboard'**
  String get pasteFromClipboard;

  /// No description provided for @uriSupportHint.
  ///
  /// In en, this message translates to:
  /// **'Supports HTTP/HTTPS, FTP, SFTP, magnet and more.'**
  String get uriSupportHint;

  /// No description provided for @selectTorrentFile.
  ///
  /// In en, this message translates to:
  /// **'Select torrent file'**
  String get selectTorrentFile;

  /// No description provided for @selectMetalinkFile.
  ///
  /// In en, this message translates to:
  /// **'Select metalink file'**
  String get selectMetalinkFile;

  /// No description provided for @targetInstance.
  ///
  /// In en, this message translates to:
  /// **'Target instance'**
  String get targetInstance;

  /// No description provided for @selectTargetInstanceFirst.
  ///
  /// In en, this message translates to:
  /// **'Select a target instance first'**
  String get selectTargetInstanceFirst;

  /// No description provided for @noConnectedInstancesAvailable.
  ///
  /// In en, this message translates to:
  /// **'No connected instances are available. Connect the built-in or a remote instance first.'**
  String get noConnectedInstancesAvailable;

  /// No description provided for @tasksWillBeSentTo.
  ///
  /// In en, this message translates to:
  /// **'Tasks will be sent to {target}.'**
  String tasksWillBeSentTo(Object target);

  /// No description provided for @showAdvancedOptions.
  ///
  /// In en, this message translates to:
  /// **'Show advanced options'**
  String get showAdvancedOptions;

  /// No description provided for @saveLocation.
  ///
  /// In en, this message translates to:
  /// **'Save location'**
  String get saveLocation;

  /// No description provided for @useInstanceDefaultDirectory.
  ///
  /// In en, this message translates to:
  /// **'Use the instance default directory'**
  String get useInstanceDefaultDirectory;

  /// No description provided for @chooseSaveLocation.
  ///
  /// In en, this message translates to:
  /// **'Choose save location'**
  String get chooseSaveLocation;

  /// No description provided for @failedToSelectDirectory.
  ///
  /// In en, this message translates to:
  /// **'Failed to select directory: {error}'**
  String failedToSelectDirectory(Object error);

  /// No description provided for @selectedCount.
  ///
  /// In en, this message translates to:
  /// **'{count} selected'**
  String selectedCount(Object count);

  /// No description provided for @allVisibleSelected.
  ///
  /// In en, this message translates to:
  /// **'All visible selected'**
  String get allVisibleSelected;

  /// No description provided for @selectAllVisible.
  ///
  /// In en, this message translates to:
  /// **'Select all visible'**
  String get selectAllVisible;

  /// No description provided for @clear.
  ///
  /// In en, this message translates to:
  /// **'Clear'**
  String get clear;

  /// No description provided for @failedToRefreshTasks.
  ///
  /// In en, this message translates to:
  /// **'Failed to refresh tasks: {error}'**
  String failedToRefreshTasks(Object error);

  /// No description provided for @failedToLoadInstanceNames.
  ///
  /// In en, this message translates to:
  /// **'Failed to load instance names: {error}'**
  String failedToLoadInstanceNames(Object error);

  /// No description provided for @connectBeforeAddingTasks.
  ///
  /// In en, this message translates to:
  /// **'Connect the built-in instance or a remote instance before adding tasks.'**
  String get connectBeforeAddingTasks;

  /// No description provided for @dragDropFilesHere.
  ///
  /// In en, this message translates to:
  /// **'Drop files to add tasks'**
  String get dragDropFilesHere;

  /// No description provided for @dragDropSupportedHint.
  ///
  /// In en, this message translates to:
  /// **'Supports .torrent and .metalink files'**
  String get dragDropSupportedHint;

  /// No description provided for @dragDropUnsupportedFiles.
  ///
  /// In en, this message translates to:
  /// **'Only .torrent and .metalink files are supported when dragging into the window.'**
  String get dragDropUnsupportedFiles;

  /// No description provided for @dragDropOnlyFirstFileUsed.
  ///
  /// In en, this message translates to:
  /// **'Multiple supported files were dropped. Only the first file will be used for now.'**
  String get dragDropOnlyFirstFileUsed;

  /// No description provided for @taskAddedToInstanceSuccess.
  ///
  /// In en, this message translates to:
  /// **'Task added to {name} successfully'**
  String taskAddedToInstanceSuccess(Object name);

  /// No description provided for @addTaskNoFileSelected.
  ///
  /// In en, this message translates to:
  /// **'No file selected yet'**
  String get addTaskNoFileSelected;

  /// No description provided for @addTaskSplitInvalid.
  ///
  /// In en, this message translates to:
  /// **'Split count must be a positive integer.'**
  String get addTaskSplitInvalid;

  /// No description provided for @renameOutput.
  ///
  /// In en, this message translates to:
  /// **'Rename'**
  String get renameOutput;

  /// No description provided for @renameOutputTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to keep the original filename'**
  String get renameOutputTip;

  /// No description provided for @renameOutputPlaceholder.
  ///
  /// In en, this message translates to:
  /// **'Optional'**
  String get renameOutputPlaceholder;

  /// No description provided for @authorization.
  ///
  /// In en, this message translates to:
  /// **'Authorization'**
  String get authorization;

  /// No description provided for @referer.
  ///
  /// In en, this message translates to:
  /// **'Referer'**
  String get referer;

  /// No description provided for @cookie.
  ///
  /// In en, this message translates to:
  /// **'Cookie'**
  String get cookie;

  /// No description provided for @perTaskProxy.
  ///
  /// In en, this message translates to:
  /// **'Proxy'**
  String get perTaskProxy;

  /// No description provided for @perTaskProxyTip.
  ///
  /// In en, this message translates to:
  /// **'Used only for this task. Leave empty to follow the instance default.'**
  String get perTaskProxyTip;

  /// No description provided for @addTaskShowDownloadsAfterAddTip.
  ///
  /// In en, this message translates to:
  /// **'Only affects this submission and does not change the global preference.'**
  String get addTaskShowDownloadsAfterAddTip;

  /// No description provided for @thunderLinkNormalizationFailed.
  ///
  /// In en, this message translates to:
  /// **'The thunder link could not be decoded into a downloadable URL.'**
  String get thunderLinkNormalizationFailed;

  /// No description provided for @resumeTasks.
  ///
  /// In en, this message translates to:
  /// **'Resume tasks'**
  String get resumeTasks;

  /// No description provided for @pauseTasks.
  ///
  /// In en, this message translates to:
  /// **'Pause tasks'**
  String get pauseTasks;

  /// No description provided for @deleteTasks.
  ///
  /// In en, this message translates to:
  /// **'Delete tasks'**
  String get deleteTasks;

  /// No description provided for @removeOnly.
  ///
  /// In en, this message translates to:
  /// **'Remove only'**
  String get removeOnly;

  /// No description provided for @removeAndDeleteFiles.
  ///
  /// In en, this message translates to:
  /// **'Remove and delete files'**
  String get removeAndDeleteFiles;

  /// No description provided for @deleteFilesOptionHint.
  ///
  /// In en, this message translates to:
  /// **'Only downloaded files from built-in tasks will be deleted.'**
  String get deleteFilesOptionHint;

  /// No description provided for @actionAcrossAllInstances.
  ///
  /// In en, this message translates to:
  /// **'{action} across all connected instances'**
  String actionAcrossAllInstances(Object action);

  /// No description provided for @actionInInstance.
  ///
  /// In en, this message translates to:
  /// **'{action} in {instance}'**
  String actionInInstance(Object action, Object instance);

  /// No description provided for @chooseActionScope.
  ///
  /// In en, this message translates to:
  /// **'Choose where to apply this action.'**
  String get chooseActionScope;

  /// No description provided for @noConnectedInstancesForAction.
  ///
  /// In en, this message translates to:
  /// **'No connected instances are available for this action.'**
  String get noConnectedInstancesForAction;

  /// No description provided for @noConnectedInstancesTitle.
  ///
  /// In en, this message translates to:
  /// **'No connected instances. Connect an instance to view tasks.'**
  String get noConnectedInstancesTitle;

  /// No description provided for @combinedTaskListHint.
  ///
  /// In en, this message translates to:
  /// **'The download list combines tasks from the built-in instance and any connected remote instances.'**
  String get combinedTaskListHint;

  /// No description provided for @noTasksTitle.
  ///
  /// In en, this message translates to:
  /// **'No tasks'**
  String get noTasksTitle;

  /// No description provided for @noTasksHint.
  ///
  /// In en, this message translates to:
  /// **'Add a task or switch filters to see downloads from connected instances.'**
  String get noTasksHint;

  /// No description provided for @noDownloadDirectoryAvailable.
  ///
  /// In en, this message translates to:
  /// **'No download directory available'**
  String get noDownloadDirectoryAvailable;

  /// No description provided for @targetInstanceNotConnected.
  ///
  /// In en, this message translates to:
  /// **'The target instance is not connected.'**
  String get targetInstanceNotConnected;

  /// No description provided for @failedToPauseTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to pause the task: {error}'**
  String failedToPauseTask(Object error);

  /// No description provided for @failedToRetryTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to retry the task: {error}'**
  String failedToRetryTask(Object error);

  /// No description provided for @retryTaskSourceUnavailable.
  ///
  /// In en, this message translates to:
  /// **'This task cannot be retried because its original source link is unavailable.'**
  String get retryTaskSourceUnavailable;

  /// No description provided for @failedToRemoveTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove the task: {error}'**
  String failedToRemoveTask(Object error);

  /// No description provided for @failedToResumeTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to resume the task: {error}'**
  String failedToResumeTask(Object error);

  /// No description provided for @failedToRemoveFailedTask.
  ///
  /// In en, this message translates to:
  /// **'Failed to remove the failed task: {error}'**
  String failedToRemoveFailedTask(Object error);

  /// No description provided for @taskRemovedWithFileWarnings.
  ///
  /// In en, this message translates to:
  /// **'Task removed, but some files could not be deleted.'**
  String get taskRemovedWithFileWarnings;

  /// No description provided for @taskActionNoMatchingTasks.
  ///
  /// In en, this message translates to:
  /// **'No matching tasks for {action}.'**
  String taskActionNoMatchingTasks(Object action);

  /// No description provided for @taskActionSummarySuccess.
  ///
  /// In en, this message translates to:
  /// **'{action}: {success} succeeded.'**
  String taskActionSummarySuccess(Object action, int success);

  /// No description provided for @taskActionSummaryDetailed.
  ///
  /// In en, this message translates to:
  /// **'{action}: {success} succeeded, {failed} failed, {skipped} skipped.'**
  String taskActionSummaryDetailed(
    Object action,
    int success,
    int failed,
    int skipped,
  );

  /// No description provided for @fileDeletionWarningsSummary.
  ///
  /// In en, this message translates to:
  /// **'Some files could not be deleted for {count} task(s).'**
  String fileDeletionWarningsSummary(int count);

  /// No description provided for @paused.
  ///
  /// In en, this message translates to:
  /// **'Paused'**
  String get paused;

  /// No description provided for @completed.
  ///
  /// In en, this message translates to:
  /// **'Completed'**
  String get completed;

  /// No description provided for @downloading.
  ///
  /// In en, this message translates to:
  /// **'Downloading'**
  String get downloading;

  /// No description provided for @waiting.
  ///
  /// In en, this message translates to:
  /// **'Waiting'**
  String get waiting;

  /// No description provided for @stopped.
  ///
  /// In en, this message translates to:
  /// **'Stopped'**
  String get stopped;

  /// No description provided for @removeFailedTask.
  ///
  /// In en, this message translates to:
  /// **'Remove failed task'**
  String get removeFailedTask;

  /// No description provided for @taskDetails.
  ///
  /// In en, this message translates to:
  /// **'Task details'**
  String get taskDetails;

  /// No description provided for @overview.
  ///
  /// In en, this message translates to:
  /// **'Overview'**
  String get overview;

  /// No description provided for @pieces.
  ///
  /// In en, this message translates to:
  /// **'Pieces'**
  String get pieces;

  /// No description provided for @taskId.
  ///
  /// In en, this message translates to:
  /// **'Task ID: {id}'**
  String taskId(Object id);

  /// No description provided for @statusWithValue.
  ///
  /// In en, this message translates to:
  /// **'Status: {status}'**
  String statusWithValue(Object status);

  /// No description provided for @sizeWithValue.
  ///
  /// In en, this message translates to:
  /// **'Size: {size} ({bytes} bytes)'**
  String sizeWithValue(Object bytes, Object size);

  /// No description provided for @downloadedWithValue.
  ///
  /// In en, this message translates to:
  /// **'Downloaded: {size} ({bytes} bytes)'**
  String downloadedWithValue(Object bytes, Object size);

  /// No description provided for @progressWithValue.
  ///
  /// In en, this message translates to:
  /// **'Progress: {progress}%'**
  String progressWithValue(Object progress);

  /// No description provided for @downloadSpeedWithValue.
  ///
  /// In en, this message translates to:
  /// **'Download speed: {speed} ({bytes} bytes/s)'**
  String downloadSpeedWithValue(Object bytes, Object speed);

  /// No description provided for @uploadSpeedWithValue.
  ///
  /// In en, this message translates to:
  /// **'Upload speed: {speed} ({bytes} bytes/s)'**
  String uploadSpeedWithValue(Object bytes, Object speed);

  /// No description provided for @connectionsWithValue.
  ///
  /// In en, this message translates to:
  /// **'Connections: {value}'**
  String connectionsWithValue(Object value);

  /// No description provided for @saveLocationWithValue.
  ///
  /// In en, this message translates to:
  /// **'Save location: {value}'**
  String saveLocationWithValue(Object value);

  /// No description provided for @taskTypeWithValue.
  ///
  /// In en, this message translates to:
  /// **'Task type: {value}'**
  String taskTypeWithValue(Object value);

  /// No description provided for @errorWithValue.
  ///
  /// In en, this message translates to:
  /// **'Error: {value}'**
  String errorWithValue(Object value);

  /// No description provided for @remainingTimeWithValue.
  ///
  /// In en, this message translates to:
  /// **'Remaining time: {value}'**
  String remainingTimeWithValue(Object value);

  /// No description provided for @filesTitle.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesTitle;

  /// No description provided for @notSelected.
  ///
  /// In en, this message translates to:
  /// **'(not selected)'**
  String get notSelected;

  /// No description provided for @noFileInformation.
  ///
  /// In en, this message translates to:
  /// **'No file information'**
  String get noFileInformation;

  /// No description provided for @close.
  ///
  /// In en, this message translates to:
  /// **'Close'**
  String get close;

  /// No description provided for @noPieceInformation.
  ///
  /// In en, this message translates to:
  /// **'No piece information available for this task.'**
  String get noPieceInformation;

  /// No description provided for @noPieceInformationHint.
  ///
  /// In en, this message translates to:
  /// **'The task may not have started yet, or Aria2 did not expose piece data.'**
  String get noPieceInformationHint;

  /// No description provided for @pieceStatistics.
  ///
  /// In en, this message translates to:
  /// **'Piece statistics'**
  String get pieceStatistics;

  /// No description provided for @totalPieces.
  ///
  /// In en, this message translates to:
  /// **'Total pieces'**
  String get totalPieces;

  /// No description provided for @partial.
  ///
  /// In en, this message translates to:
  /// **'Partial'**
  String get partial;

  /// No description provided for @missing.
  ///
  /// In en, this message translates to:
  /// **'Missing'**
  String get missing;

  /// No description provided for @completion.
  ///
  /// In en, this message translates to:
  /// **'Completion: {value}%'**
  String completion(Object value);

  /// No description provided for @pieceMap.
  ///
  /// In en, this message translates to:
  /// **'Piece map'**
  String get pieceMap;

  /// No description provided for @legend.
  ///
  /// In en, this message translates to:
  /// **'Legend'**
  String get legend;

  /// No description provided for @highProgress.
  ///
  /// In en, this message translates to:
  /// **'High progress (8-b)'**
  String get highProgress;

  /// No description provided for @mediumProgress.
  ///
  /// In en, this message translates to:
  /// **'Medium progress (4-7)'**
  String get mediumProgress;

  /// No description provided for @lowProgress.
  ///
  /// In en, this message translates to:
  /// **'Low progress (1-3)'**
  String get lowProgress;

  /// No description provided for @cannotGetDownloadDirectoryInformation.
  ///
  /// In en, this message translates to:
  /// **'Cannot get download directory information'**
  String get cannotGetDownloadDirectoryInformation;

  /// No description provided for @downloadDirectoryDoesNotExist.
  ///
  /// In en, this message translates to:
  /// **'Download directory does not exist'**
  String get downloadDirectoryDoesNotExist;

  /// No description provided for @cannotOpenDownloadDirectory.
  ///
  /// In en, this message translates to:
  /// **'Cannot open download directory'**
  String get cannotOpenDownloadDirectory;

  /// No description provided for @errorOpeningDirectory.
  ///
  /// In en, this message translates to:
  /// **'Error opening directory: {error}'**
  String errorOpeningDirectory(Object error);

  /// No description provided for @connectionSection.
  ///
  /// In en, this message translates to:
  /// **'Connection'**
  String get connectionSection;

  /// No description provided for @transferSection.
  ///
  /// In en, this message translates to:
  /// **'Transfer'**
  String get transferSection;

  /// No description provided for @speedLimits.
  ///
  /// In en, this message translates to:
  /// **'Speed Limits'**
  String get speedLimits;

  /// No description provided for @btPtSection.
  ///
  /// In en, this message translates to:
  /// **'BT / PT'**
  String get btPtSection;

  /// No description provided for @networkSection.
  ///
  /// In en, this message translates to:
  /// **'Network'**
  String get networkSection;

  /// No description provided for @filesSection.
  ///
  /// In en, this message translates to:
  /// **'Files'**
  String get filesSection;

  /// No description provided for @leaveEmptyToDisableSecretAuth.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to disable secret auth'**
  String get leaveEmptyToDisableSecretAuth;

  /// No description provided for @splitCount.
  ///
  /// In en, this message translates to:
  /// **'Split count'**
  String get splitCount;

  /// No description provided for @continueUnfinishedDownloads.
  ///
  /// In en, this message translates to:
  /// **'Continue unfinished downloads'**
  String get continueUnfinishedDownloads;

  /// No description provided for @maxOverallDownloadLimit.
  ///
  /// In en, this message translates to:
  /// **'Max overall download limit (KB/s)'**
  String get maxOverallDownloadLimit;

  /// No description provided for @maxOverallUploadLimit.
  ///
  /// In en, this message translates to:
  /// **'Max overall upload limit (KB/s)'**
  String get maxOverallUploadLimit;

  /// No description provided for @keepSeedingAfterCompletion.
  ///
  /// In en, this message translates to:
  /// **'Keep seeding after completion'**
  String get keepSeedingAfterCompletion;

  /// No description provided for @seedRatio.
  ///
  /// In en, this message translates to:
  /// **'Seed ratio'**
  String get seedRatio;

  /// No description provided for @seedTimeMinutes.
  ///
  /// In en, this message translates to:
  /// **'Seed time (minutes)'**
  String get seedTimeMinutes;

  /// No description provided for @trackerSource.
  ///
  /// In en, this message translates to:
  /// **'Tracker source'**
  String get trackerSource;

  /// No description provided for @syncTrackerList.
  ///
  /// In en, this message translates to:
  /// **'Sync tracker list'**
  String get syncTrackerList;

  /// No description provided for @autoSyncTracker.
  ///
  /// In en, this message translates to:
  /// **'Auto sync tracker list'**
  String get autoSyncTracker;

  /// No description provided for @btTrackerServers.
  ///
  /// In en, this message translates to:
  /// **'Tracker servers'**
  String get btTrackerServers;

  /// No description provided for @btTrackerServersTip.
  ///
  /// In en, this message translates to:
  /// **'Tracker servers, one per line or separated by commas'**
  String get btTrackerServersTip;

  /// No description provided for @exampleProxy.
  ///
  /// In en, this message translates to:
  /// **'Example: http://proxy:port'**
  String get exampleProxy;

  /// No description provided for @noProxyHosts.
  ///
  /// In en, this message translates to:
  /// **'No-proxy hosts'**
  String get noProxyHosts;

  /// No description provided for @multipleHostsComma.
  ///
  /// In en, this message translates to:
  /// **'Separate multiple hosts with commas'**
  String get multipleHostsComma;

  /// No description provided for @autoRenameFiles.
  ///
  /// In en, this message translates to:
  /// **'Auto rename files'**
  String get autoRenameFiles;

  /// No description provided for @allowOverwrite.
  ///
  /// In en, this message translates to:
  /// **'Allow overwrite'**
  String get allowOverwrite;

  /// No description provided for @sessionFilePath.
  ///
  /// In en, this message translates to:
  /// **'Session file path'**
  String get sessionFilePath;

  /// No description provided for @sessionFilePathTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default data/core/aria2.session path. Restart required.'**
  String get sessionFilePathTip;

  /// No description provided for @logFilePath.
  ///
  /// In en, this message translates to:
  /// **'Log file path'**
  String get logFilePath;

  /// No description provided for @logFilePathTip.
  ///
  /// In en, this message translates to:
  /// **'Leave empty to use the default data/core/aria2.log path. Restart required.'**
  String get logFilePathTip;

  /// No description provided for @userAgent.
  ///
  /// In en, this message translates to:
  /// **'User agent'**
  String get userAgent;

  /// No description provided for @decrease.
  ///
  /// In en, this message translates to:
  /// **'Decrease'**
  String get decrease;

  /// No description provided for @increase.
  ///
  /// In en, this message translates to:
  /// **'Increase'**
  String get increase;

  /// No description provided for @settingsSaved.
  ///
  /// In en, this message translates to:
  /// **'Settings saved'**
  String get settingsSaved;

  /// No description provided for @settingsSaveOnlyHint.
  ///
  /// In en, this message translates to:
  /// **'Save only stores your changes and leaves the running built-in instance unchanged.'**
  String get settingsSaveOnlyHint;

  /// No description provided for @settingsApplySpeedHint.
  ///
  /// In en, this message translates to:
  /// **'Save and Apply will update speed limit changes immediately when the built-in instance is connected.'**
  String get settingsApplySpeedHint;

  /// No description provided for @settingsApplyLiveHint.
  ///
  /// In en, this message translates to:
  /// **'Save and Apply updates supported settings immediately when the built-in instance is connected.'**
  String get settingsApplyLiveHint;

  /// No description provided for @settingsApplyRestartHint.
  ///
  /// In en, this message translates to:
  /// **'Save and Apply will restart the built-in instance to apply these changes.'**
  String get settingsApplyRestartHint;

  /// No description provided for @settingsApplyNoPendingHint.
  ///
  /// In en, this message translates to:
  /// **'Save and Apply updates the running built-in instance when possible.'**
  String get settingsApplyNoPendingHint;

  /// No description provided for @restartingBuiltinInstance.
  ///
  /// In en, this message translates to:
  /// **'Restarting the built-in instance, please wait...'**
  String get restartingBuiltinInstance;

  /// No description provided for @builtinInstanceMissing.
  ///
  /// In en, this message translates to:
  /// **'Built-in instance is missing'**
  String get builtinInstanceMissing;

  /// No description provided for @settingsSavedAppliedSuccess.
  ///
  /// In en, this message translates to:
  /// **'Settings saved and applied successfully'**
  String get settingsSavedAppliedSuccess;

  /// No description provided for @settingsSavedRpcApplyFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved, but applying them to the running built-in instance failed'**
  String get settingsSavedRpcApplyFailed;

  /// No description provided for @settingsSavedApplyWhenConnected.
  ///
  /// In en, this message translates to:
  /// **'Settings saved. Supported changes will apply the next time the built-in instance connects'**
  String get settingsSavedApplyWhenConnected;

  /// No description provided for @settingsSavedRestartFailed.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved, but restarting the built-in instance failed'**
  String get settingsSavedRestartFailed;

  /// No description provided for @settingsSavedRestartFailedWithError.
  ///
  /// In en, this message translates to:
  /// **'Settings were saved, but restarting the built-in instance failed: {error}'**
  String settingsSavedRestartFailedWithError(Object error);

  /// No description provided for @trackerSyncSuccess.
  ///
  /// In en, this message translates to:
  /// **'Tracker list synced into the draft settings'**
  String get trackerSyncSuccess;

  /// No description provided for @trackerSyncFailed.
  ///
  /// In en, this message translates to:
  /// **'Failed to sync tracker list: {error}'**
  String trackerSyncFailed(Object error);

  /// No description provided for @leavePage.
  ///
  /// In en, this message translates to:
  /// **'Leave this page?'**
  String get leavePage;

  /// No description provided for @unsavedChangesPrompt.
  ///
  /// In en, this message translates to:
  /// **'You have unsaved changes. What would you like to do?'**
  String get unsavedChangesPrompt;

  /// No description provided for @discard.
  ///
  /// In en, this message translates to:
  /// **'Discard'**
  String get discard;

  /// No description provided for @startedAtWithValue.
  ///
  /// In en, this message translates to:
  /// **'Started at: {value}'**
  String startedAtWithValue(Object value);

  /// No description provided for @sourceLinks.
  ///
  /// In en, this message translates to:
  /// **'Source links'**
  String get sourceLinks;

  /// No description provided for @trackers.
  ///
  /// In en, this message translates to:
  /// **'Trackers'**
  String get trackers;

  /// No description provided for @peers.
  ///
  /// In en, this message translates to:
  /// **'Peers'**
  String get peers;

  /// No description provided for @noTrackerInformation.
  ///
  /// In en, this message translates to:
  /// **'No tracker information'**
  String get noTrackerInformation;

  /// No description provided for @noPeerInformation.
  ///
  /// In en, this message translates to:
  /// **'No peer information'**
  String get noPeerInformation;

  /// No description provided for @clientLabel.
  ///
  /// In en, this message translates to:
  /// **'Client'**
  String get clientLabel;

  /// No description provided for @uploadShort.
  ///
  /// In en, this message translates to:
  /// **'Up'**
  String get uploadShort;

  /// No description provided for @downloadShort.
  ///
  /// In en, this message translates to:
  /// **'Down'**
  String get downloadShort;

  /// No description provided for @seeding.
  ///
  /// In en, this message translates to:
  /// **'Seeding'**
  String get seeding;

  /// No description provided for @stoppingSeedingTip.
  ///
  /// In en, this message translates to:
  /// **'Stopping seeding, it may take some time to disconnect. Please wait.'**
  String get stoppingSeedingTip;

  /// No description provided for @failedToStopSeeding.
  ///
  /// In en, this message translates to:
  /// **'Failed to stop seeding: {error}'**
  String failedToStopSeeding(Object error);

  /// No description provided for @torrentInfo.
  ///
  /// In en, this message translates to:
  /// **'Torrent Info'**
  String get torrentInfo;

  /// No description provided for @torrentHash.
  ///
  /// In en, this message translates to:
  /// **'Hash'**
  String get torrentHash;

  /// No description provided for @torrentPieceSize.
  ///
  /// In en, this message translates to:
  /// **'Piece size'**
  String get torrentPieceSize;

  /// No description provided for @torrentPieceCount.
  ///
  /// In en, this message translates to:
  /// **'Piece count'**
  String get torrentPieceCount;

  /// No description provided for @torrentCreationDate.
  ///
  /// In en, this message translates to:
  /// **'Creation date'**
  String get torrentCreationDate;

  /// No description provided for @torrentComment.
  ///
  /// In en, this message translates to:
  /// **'Comment'**
  String get torrentComment;

  /// No description provided for @torrentConnections.
  ///
  /// In en, this message translates to:
  /// **'Connections'**
  String get torrentConnections;

  /// No description provided for @torrentSeeders.
  ///
  /// In en, this message translates to:
  /// **'Seeders'**
  String get torrentSeeders;

  /// No description provided for @torrentUploaded.
  ///
  /// In en, this message translates to:
  /// **'Uploaded'**
  String get torrentUploaded;

  /// No description provided for @torrentRatio.
  ///
  /// In en, this message translates to:
  /// **'Ratio'**
  String get torrentRatio;

  /// No description provided for @english.
  ///
  /// In en, this message translates to:
  /// **'English'**
  String get english;

  /// No description provided for @chinese.
  ///
  /// In en, this message translates to:
  /// **'Chinese'**
  String get chinese;
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
