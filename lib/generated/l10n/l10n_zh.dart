// ignore: unused_import
import 'package:intl/intl.dart' as intl;
import 'l10n.dart';

// ignore_for_file: type=lint

/// The translations for Chinese (`zh`).
class AppLocalizationsZh extends AppLocalizations {
  AppLocalizationsZh([String locale = 'zh']) : super(locale);

  @override
  String get download => '下载';

  @override
  String get instance => '实例';

  @override
  String get settings => '设置';

  @override
  String totalSpeed(Object speed) {
    return '总速度: $speed';
  }

  @override
  String activeTasks(Object count) {
    return '活跃: $count';
  }

  @override
  String waitingTasks(Object count) {
    return '等待: $count';
  }

  @override
  String get builtinInstanceConnectFailed => '内建实例连接失败';

  @override
  String get builtinInstanceConnectFailedTip => '内建实例连接失败，仅远程功能可用';

  @override
  String get ok => '确定';

  @override
  String get notConnected => '未连接';

  @override
  String get connecting => '连接中';

  @override
  String get connected => '已连接';

  @override
  String get showMainWindow => '显示主窗口';

  @override
  String get hideMainWindow => '隐藏主窗口';

  @override
  String get quitApp => '退出';

  @override
  String get connectFailed => '连接失败';

  @override
  String get connect => '连接';

  @override
  String get reconnect => '重新连接';

  @override
  String get disconnect => '断开';

  @override
  String get settings2 => '设置';

  @override
  String get edit => '编辑';

  @override
  String get delete => '删除';

  @override
  String get builtin => '内建';

  @override
  String get remote => '远程';

  @override
  String aria2Version(Object version) {
    return 'Aria2 版本: $version';
  }

  @override
  String get gettingVersion => '获取版本中...';

  @override
  String get loadSettingsFailed => '加载设置失败';

  @override
  String get saveSettingsFailed => '保存设置失败';

  @override
  String get globalSettings => '全局设置';

  @override
  String get runAtStartup => '系统启动时运行';

  @override
  String get runAtStartupTip => '设置应用随系统启动而运行';

  @override
  String get runMode => '运行模式';

  @override
  String get runModeStandard => '标准';

  @override
  String get runModeStandardTip => '使用普通窗口行为。关闭主窗口时直接退出应用。';

  @override
  String get runModeTray => '托盘';

  @override
  String get runModeTrayTip => '保持应用在系统托盘中可用。关闭主窗口时隐藏到托盘。';

  @override
  String get runModeHideTray => '隐藏托盘';

  @override
  String get runModeHideTrayTip => '完全禁用系统托盘集成。关闭主窗口时直接退出应用。';

  @override
  String get minimizeToTray => '最小化到系统托盘';

  @override
  String get minimizeToTrayTip => '关闭窗口时最小化到系统托盘而不是退出';

  @override
  String get autoHideWindow => '自动隐藏窗口';

  @override
  String get autoHideWindowTip => '主窗口失去焦点时自动隐藏到托盘';

  @override
  String get showTraySpeed => '显示托盘速度';

  @override
  String get showTraySpeedTip => '在托盘提示中显示总下载速度';

  @override
  String get taskNotification => '任务通知';

  @override
  String get taskNotificationTip => '在下载完成或失败时显示通知';

  @override
  String get systemIntegration => '系统集成';

  @override
  String get setAsDefaultClient => '默认客户端';

  @override
  String get setAsDefaultClientTip => '将此应用注册为 Windows 中受支持下载链接的处理程序。';

  @override
  String get handleMagnetLinks => '处理 magnet 链接';

  @override
  String get handleMagnetLinksTip => '使用此应用打开 magnet:// 链接。';

  @override
  String get handleThunderLinks => '处理 thunder 链接';

  @override
  String get handleThunderLinksTip => '使用此应用打开 thunder:// 链接。';

  @override
  String protocolPreferenceRetryWarning(Object protocol) {
    return '$protocol 的偏好已保存，但 Windows 注册失败。应用会在下次启动时重试。';
  }

  @override
  String protocolReconcileFailed(Object protocols) {
    return '以下协议的已保存偏好未能成功应用：$protocols。';
  }

  @override
  String get connectBeforeHandlingExternalLink => '请先连接实例，再打开外部下载链接。';

  @override
  String get skipDeleteConfirm => '跳过删除确认';

  @override
  String get skipDeleteConfirmTip => '删除任务时不再询问是否同时删除已下载文件';

  @override
  String get resumeAllOnLaunch => '启动时继续全部';

  @override
  String get resumeAllOnLaunchTip => '应用启动后自动继续所有已暂停任务';

  @override
  String get showDownloadsAfterAdd => '添加后显示下载中任务';

  @override
  String get showDownloadsAfterAddTip => '添加新任务后自动切换到下载中任务视图';

  @override
  String get showProgressBar => '显示进度条';

  @override
  String get showProgressBarTip => '在下载列表中显示任务进度条';

  @override
  String get hideTitleBar => '隐藏标题栏';

  @override
  String get hideTitleBarTip => '使用自定义桌面窗口框架来替代系统原生标题栏。';

  @override
  String get appearance => '外观';

  @override
  String get appearanceTip => '自定义应用程序的主题和颜色';

  @override
  String get light => '亮色';

  @override
  String get dark => '暗色';

  @override
  String get system => '系统';

  @override
  String get language => '语言';

  @override
  String get themeMode => '主题模式';

  @override
  String get themeColor => '主题色';

  @override
  String get preset => '预设';

  @override
  String get custom => '自定义';

  @override
  String get colorCode => '颜色代码';

  @override
  String get done => '完成';

  @override
  String failedToSetThemeMode(Object error) {
    return '设置主题模式失败: $error';
  }

  @override
  String failedToSetThemeColor(Object error) {
    return '设置主题色失败: $error';
  }

  @override
  String failedToSetCustomThemeColor(Object error) {
    return '设置自定义主题色失败: $error';
  }

  @override
  String get viewLogs => '查看日志';

  @override
  String get viewLogsTip => '查看应用内日志与调试输出';

  @override
  String get maintenance => '维护与恢复';

  @override
  String get resetAppSettings => '重置应用设置';

  @override
  String get resetAppSettingsTip => '恢复应用偏好和内建默认设置，不删除任务或已下载文件';

  @override
  String get resetAppSettingsConfirmMessage =>
      '要将全部应用偏好和内建 aria2 设置恢复为默认值吗？现有任务和已下载文件会保留。';

  @override
  String get resetAppSettingsAction => '重置设置';

  @override
  String get resetAppSettingsSuccess => '应用设置已恢复为默认值。';

  @override
  String get about => '关于';

  @override
  String get aboutProject => '项目';

  @override
  String get aboutProjectDescription =>
      'Setsuna 是一个现代化的 aria2 桌面客户端，目标是在兼容 Motrix 核心能力的同时，提供内建实例与远程实例管理能力。';

  @override
  String get sourceCode => '源代码';

  @override
  String get reportIssue => '反馈问题';

  @override
  String get participants => '参与者';

  @override
  String get version => '版本号';

  @override
  String get versionLoading => '加载中...';

  @override
  String get contributors => '贡献者';

  @override
  String get license => '许可协议';

  @override
  String get instanceSettings => '实例设置';

  @override
  String get remoteAria2Settings => '远程 aria2 设置';

  @override
  String get remoteSettingsInfoTip => '这里修改的是当前正在运行的远程 aria2 全局选项，不是本地保存的连接档案。';

  @override
  String get remoteSettingsRequiresConnectedInstance =>
      '请先连接此远程实例，再打开它的 aria2 设置。';

  @override
  String get remoteSettingsLoadFailed => '加载远程 aria2 设置失败';

  @override
  String remoteSettingsLoadFailedWithError(Object error) {
    return '加载远程 aria2 设置失败: $error';
  }

  @override
  String get remoteSettingsSaved => '远程 aria2 设置已保存';

  @override
  String get remoteSettingsSaveFailed => '保存远程 aria2 设置失败';

  @override
  String remoteSettingsSaveFailedWithError(Object error) {
    return '保存远程 aria2 设置失败: $error';
  }

  @override
  String get remoteSettingsNoChanges => '没有需要保存的远程 aria2 设置改动';

  @override
  String get remoteSettingsDownloadDirRequired => '远程下载目录不能为空';

  @override
  String get remoteSettingsInvalidSeedRatio => '做种比例必须是有效数字';

  @override
  String get remoteSettingsBtPortRequired => 'BT 监听端口不能为空';

  @override
  String get save => '保存';

  @override
  String get saveAndApply => '保存并应用';

  @override
  String get basicSettings => '基础设置';

  @override
  String get rpcListenPort => 'RPC监听端口';

  @override
  String get rpcPortDefault => '默认：16800';

  @override
  String get rpcSecret => 'RPC密钥';

  @override
  String get rpcSecretTip => '留空则不需要密钥';

  @override
  String get rpcPath => 'RPC 路径';

  @override
  String get rpcPathTip => '留空则使用 jsonrpc';

  @override
  String get rpcRequestHeaders => 'RPC 请求头';

  @override
  String get rpcRequestHeadersTip => '每行一个请求头，格式为 Header-Name: value';

  @override
  String instanceNameAutoHint(Object fallback) {
    return '留空时可参考 $fallback 作为实例名称';
  }

  @override
  String get testConnection => '测试连接';

  @override
  String get testingConnection => '测试中...';

  @override
  String get rpcHeadersConfigured => '已配置自定义 RPC 请求头';

  @override
  String get transferSettings => '传输设置';

  @override
  String get maxConcurrentDownloads => '最大并发下载数';

  @override
  String get maxConnectionPerServer => '单服务器最大连接数';

  @override
  String get downloadSegments => '下载分片数';

  @override
  String get enableContinueDownload => '允许断点续传';

  @override
  String get speedLimit => '速度限制';

  @override
  String get globalDownloadLimit => '全局下载限速 (KB/s)';

  @override
  String get downloadLimitTip => '0表示不限速';

  @override
  String get globalUploadLimit => '全局上传限速 (KB/s)';

  @override
  String get uploadLimitTip => '0表示不限速';

  @override
  String get btPtSettings => 'BT/PT 设置';

  @override
  String get saveBtMetadata => '保存BT元数据';

  @override
  String get loadSavedBtMetadata => '加载已保存的BT元数据';

  @override
  String get forceBtEncryption => '强制BT加密';

  @override
  String get keepSeeding => '持续做种';

  @override
  String get seedingRatio => '做种比率';

  @override
  String get seedingRatioTip => '0表示无限做种';

  @override
  String get seedingTime => '做种时间 (分钟)';

  @override
  String get seedingTimeTip => '0表示无限做种';

  @override
  String get btListenPort => 'BT监听端口';

  @override
  String get btListenPortTip => '支持单个端口或端口范围，例如 6881-6999';

  @override
  String get excludedTrackers => '排除的Tracker';

  @override
  String get trackersTip => '多个Tracker用逗号分隔';

  @override
  String get networkSettings => '网络设置';

  @override
  String get globalProxy => '全局代理';

  @override
  String get enableProxy => '启用代理';

  @override
  String get enableProxyTip => '可在不丢失已保存代理地址的情况下启用或禁用代理设置';

  @override
  String get proxyFormat => '格式: http://proxy:port';

  @override
  String get noProxyAddresses => '不使用代理的地址';

  @override
  String get noProxyTip => '多个地址用逗号分隔';

  @override
  String get dhtListenPort => 'DHT监听端口';

  @override
  String get enableDht6 => '启用DHT6';

  @override
  String get enableUpnp => '启用 UPnP / NAT-PMP';

  @override
  String get enableUpnpTip => '为 BT 和 DHT 端口使用路由器端口映射。需要重启后生效。';

  @override
  String get fileSettings => '文件设置';

  @override
  String get downloadDir => '下载目录';

  @override
  String get defaultDownloadDir => '默认下载路径';

  @override
  String get remoteDownloadDirHint => '请输入远程服务器上的路径字符串';

  @override
  String get selectDir => '选择';

  @override
  String failedToGetTasks(Object error) {
    return '获取任务数据失败: $error';
  }

  @override
  String get taskAddedSuccess => '任务添加成功';

  @override
  String get noConnectedInstance => '当前没有连接的实例';

  @override
  String addTaskFailed(Object error) {
    return '添加任务失败: $error';
  }

  @override
  String get unknownInstance => '未知实例';

  @override
  String get pause => '暂停';

  @override
  String get stop => '停止';

  @override
  String get resume => '继续';

  @override
  String get retry => '重试';

  @override
  String get openDownloadDir => '打开下载目录';

  @override
  String get filterAll => '全部';

  @override
  String get filterDownloading => '下载中';

  @override
  String get filterPaused => '已暂停';

  @override
  String get filterStopped => '已停止';

  @override
  String get filterComplete => '已完成';

  @override
  String get addTask => '添加任务';

  @override
  String get addUrl => '添加链接';

  @override
  String get addTorrent => '添加种子';

  @override
  String get addMetalink => '添加Metalink';

  @override
  String get addUri => '添加URI';

  @override
  String get enterUrl => '输入链接';

  @override
  String get urlHint => 'http://example.com/file.zip';

  @override
  String get saveTo => '保存到';

  @override
  String get selectDownloadDir => '选择下载目录';

  @override
  String get taskName => '任务名称';

  @override
  String get taskNameTip => '留空则使用原始文件名';

  @override
  String get instances => '实例';

  @override
  String get noSavedInstances => '暂无保存的实例';

  @override
  String get clickToAddInstance => '点击右下角按钮添加新实例';

  @override
  String get instanceOnline => '实例在线';

  @override
  String get instanceOffline => '实例离线或无法连接';

  @override
  String checkStatusFailed(Object error) {
    return '检查状态失败: $error';
  }

  @override
  String get disconnected => '已断开连接';

  @override
  String get confirmDelete => '确认删除';

  @override
  String confirmDeleteInstance(Object name) {
    return '确定要删除实例 \"$name\" 吗？';
  }

  @override
  String get cancel => '取消';

  @override
  String get instanceDeletedSuccess => '实例删除成功';

  @override
  String deleteFailed(Object error) {
    return '删除失败: $error';
  }

  @override
  String get instanceUpdatedSuccess => '实例更新成功';

  @override
  String get instanceAddedSuccess => '实例添加成功';

  @override
  String operationFailed(Object error) {
    return '操作失败: $error';
  }

  @override
  String get addInstance => '添加实例';

  @override
  String get add => '添加';

  @override
  String successConnected(Object name) {
    return '成功连接到实例: $name';
  }

  @override
  String get connectionFailedCheckConfig => '连接失败，请检查配置';

  @override
  String connectionFailedError(Object error) {
    return '连接失败: $error';
  }

  @override
  String get editInstance => '编辑实例';

  @override
  String get instanceName => '实例名称';

  @override
  String get instanceNameTip => '输入实例名称';

  @override
  String get host => '主机';

  @override
  String get port => '端口';

  @override
  String get hostTip => '例如：localhost:6800 或 http://aria2.example.com:6800';

  @override
  String get protocol => '协议';

  @override
  String get http => 'HTTP';

  @override
  String get https => 'HTTPS';

  @override
  String get rpcSecretHint => 'RPC密钥';

  @override
  String get confirmDeleteTip => '确定要删除此实例吗？';

  @override
  String get confirm => '确认';

  @override
  String get debug => '调试';

  @override
  String get info => '信息';

  @override
  String get warning => '警告';

  @override
  String get error => '错误';

  @override
  String get instanceNameRequired => '实例名称不能为空';

  @override
  String get instanceNameTooLong => '实例名称不能超过30个字符';

  @override
  String get hostRequired => '主机地址不能为空';

  @override
  String get portRequired => '端口不能为空';

  @override
  String get portInvalid => '端口必须在1到65535之间';

  @override
  String get failed => '失败';

  @override
  String get check => '检查';

  @override
  String get addInstanceTooltip => '添加实例';

  @override
  String get instanceReachable => '实例可连接';

  @override
  String get instanceOfflineUnreachable => '实例离线或无法访问';

  @override
  String failedToDeleteInstance(Object error) {
    return '删除实例失败: $error';
  }

  @override
  String get disconnectedSuccessfully => '已成功断开连接';

  @override
  String get versionWillAppearAfterConnection => '连接后将显示版本';

  @override
  String builtInDefaultInstance(Object name) {
    return '$name（内建默认）';
  }

  @override
  String builtInInstance(Object name) {
    return '$name（内建）';
  }

  @override
  String get searchTasksHint => '按名称、路径或实例搜索任务';

  @override
  String get sortTasks => '排序任务';

  @override
  String get ascending => '升序';

  @override
  String get descending => '降序';

  @override
  String get name => '名称';

  @override
  String get progress => '进度';

  @override
  String get size => '大小';

  @override
  String get speed => '速度';

  @override
  String get pauseAll => '全部暂停';

  @override
  String get resumeAll => '全部继续';

  @override
  String get deleteAll => '全部删除';

  @override
  String get allTasksLabel => '全部任务';

  @override
  String get byStatus => '按状态';

  @override
  String get byType => '按类型';

  @override
  String get byInstance => '按实例';

  @override
  String get allInstances => '全部实例';

  @override
  String get chooseCategory => '选择分类';

  @override
  String get stoppedCompleted => '已停止 / 已完成';

  @override
  String get unknownPath => '未知路径';

  @override
  String selectedFile(Object name) {
    return '已选择: $name';
  }

  @override
  String get addTaskDialogTitle => '添加任务';

  @override
  String get uriTab => 'URI';

  @override
  String get torrentTab => 'Torrent';

  @override
  String get metalinkTab => 'Metalink';

  @override
  String get urlOrMagnetLink => 'URL 或 Magnet 链接';

  @override
  String get enterOneOrMoreLinks => '输入一个或多个链接';

  @override
  String get pasteFromClipboard => '从剪贴板粘贴';

  @override
  String get uriSupportHint => '支持 HTTP/HTTPS、FTP、SFTP、Magnet 等协议。';

  @override
  String get selectTorrentFile => '选择 Torrent 文件';

  @override
  String get selectMetalinkFile => '选择 Metalink 文件';

  @override
  String get targetInstance => '目标实例';

  @override
  String get selectTargetInstanceFirst => '请先选择目标实例';

  @override
  String get noConnectedInstancesAvailable => '没有可用的已连接实例。请先连接内建或远程实例。';

  @override
  String tasksWillBeSentTo(Object target) {
    return '任务将发送到 $target。';
  }

  @override
  String get showAdvancedOptions => '显示高级选项';

  @override
  String get saveLocation => '保存位置';

  @override
  String get useInstanceDefaultDirectory => '使用实例默认目录';

  @override
  String get chooseSaveLocation => '选择保存位置';

  @override
  String failedToSelectDirectory(Object error) {
    return '选择目录失败: $error';
  }

  @override
  String selectedCount(Object count) {
    return '已选择 $count 项';
  }

  @override
  String get allVisibleSelected => '已选择全部可见项';

  @override
  String get selectAllVisible => '选择全部可见项';

  @override
  String get clear => '清除';

  @override
  String failedToRefreshTasks(Object error) {
    return '刷新任务失败: $error';
  }

  @override
  String failedToLoadInstanceNames(Object error) {
    return '加载实例名称失败: $error';
  }

  @override
  String get connectBeforeAddingTasks => '添加任务前请先连接内建或远程实例。';

  @override
  String get dragDropFilesHere => '拖放文件以添加任务';

  @override
  String get dragDropSupportedHint => '支持 .torrent 和 .metalink 文件';

  @override
  String get dragDropUnsupportedFiles => '拖入窗口时目前只支持 .torrent 和 .metalink 文件。';

  @override
  String get dragDropOnlyFirstFileUsed => '检测到多个受支持文件，当前仅会使用第一个文件。';

  @override
  String taskAddedToInstanceSuccess(Object name) {
    return '已成功向 $name 添加任务';
  }

  @override
  String get addTaskNoFileSelected => '尚未选择文件';

  @override
  String get addTaskSplitInvalid => '分片数必须是大于 0 的整数。';

  @override
  String get renameOutput => '重命名';

  @override
  String get renameOutputTip => '留空则保持原始文件名';

  @override
  String get renameOutputPlaceholder => '选填';

  @override
  String get authorization => 'Authorization';

  @override
  String get referer => 'Referer';

  @override
  String get cookie => 'Cookie';

  @override
  String get perTaskProxy => '代理';

  @override
  String get perTaskProxyTip => '仅对当前任务生效。留空则沿用实例默认设置。';

  @override
  String get addTaskShowDownloadsAfterAddTip => '只影响本次提交，不会改动全局偏好。';

  @override
  String get thunderLinkNormalizationFailed => '无法将 thunder 链接解码为可下载的 URL。';

  @override
  String get resumeTasks => '继续任务';

  @override
  String get pauseTasks => '暂停任务';

  @override
  String get deleteTasks => '删除任务';

  @override
  String get removeOnly => '仅移除任务';

  @override
  String get removeAndDeleteFiles => '移除任务并删除文件';

  @override
  String get deleteFilesOptionHint => '只会删除内建实例任务已下载到本地的文件。';

  @override
  String actionAcrossAllInstances(Object action) {
    return '在全部已连接实例中$action';
  }

  @override
  String actionInInstance(Object action, Object instance) {
    return '在 $instance 中$action';
  }

  @override
  String get chooseActionScope => '选择将此操作应用到哪里。';

  @override
  String get noConnectedInstancesForAction => '没有可用于此操作的已连接实例。';

  @override
  String get noConnectedInstancesTitle => '没有已连接的实例。连接一个实例后即可查看任务。';

  @override
  String get combinedTaskListHint => '下载列表会合并内建实例与所有已连接远程实例的任务。';

  @override
  String get noTasksTitle => '暂无任务';

  @override
  String get noTasksHint => '添加任务或切换筛选条件以查看已连接实例的下载。';

  @override
  String get noDownloadDirectoryAvailable => '没有可用的下载目录';

  @override
  String get targetInstanceNotConnected => '目标实例未连接。';

  @override
  String failedToPauseTask(Object error) {
    return '暂停任务失败: $error';
  }

  @override
  String failedToRetryTask(Object error) {
    return '重试任务失败: $error';
  }

  @override
  String get retryTaskSourceUnavailable => '当前任务缺少原始来源链接，无法重试。';

  @override
  String failedToRemoveTask(Object error) {
    return '删除任务失败: $error';
  }

  @override
  String failedToResumeTask(Object error) {
    return '继续任务失败: $error';
  }

  @override
  String failedToRemoveFailedTask(Object error) {
    return '删除失败任务失败: $error';
  }

  @override
  String get taskRemovedWithFileWarnings => '任务已移除，但部分文件未能删除。';

  @override
  String taskActionNoMatchingTasks(Object action) {
    return '$action：没有匹配的任务。';
  }

  @override
  String taskActionSummarySuccess(Object action, int success) {
    return '$action：成功 $success 项。';
  }

  @override
  String taskActionSummaryDetailed(
    Object action,
    int success,
    int failed,
    int skipped,
  ) {
    return '$action：成功 $success 项，失败 $failed 项，跳过 $skipped 项。';
  }

  @override
  String fileDeletionWarningsSummary(int count) {
    return '$count 个任务存在文件删除警告。';
  }

  @override
  String get paused => '已暂停';

  @override
  String get completed => '已完成';

  @override
  String get downloading => '下载中';

  @override
  String get waiting => '等待中';

  @override
  String get stopped => '已停止';

  @override
  String get removeFailedTask => '移除失败任务';

  @override
  String get taskDetails => '任务详情';

  @override
  String get overview => '概览';

  @override
  String get pieces => '分片';

  @override
  String taskId(Object id) {
    return '任务 ID: $id';
  }

  @override
  String statusWithValue(Object status) {
    return '状态: $status';
  }

  @override
  String sizeWithValue(Object bytes, Object size) {
    return '大小: $size ($bytes 字节)';
  }

  @override
  String downloadedWithValue(Object bytes, Object size) {
    return '已下载: $size ($bytes 字节)';
  }

  @override
  String progressWithValue(Object progress) {
    return '进度: $progress%';
  }

  @override
  String downloadSpeedWithValue(Object bytes, Object speed) {
    return '下载速度: $speed ($bytes 字节/秒)';
  }

  @override
  String uploadSpeedWithValue(Object bytes, Object speed) {
    return '上传速度: $speed ($bytes 字节/秒)';
  }

  @override
  String connectionsWithValue(Object value) {
    return '连接数: $value';
  }

  @override
  String saveLocationWithValue(Object value) {
    return '保存位置: $value';
  }

  @override
  String taskTypeWithValue(Object value) {
    return '任务类型: $value';
  }

  @override
  String errorWithValue(Object value) {
    return '错误: $value';
  }

  @override
  String remainingTimeWithValue(Object value) {
    return '剩余时间: $value';
  }

  @override
  String get filesTitle => '文件';

  @override
  String get notSelected => '（未选择）';

  @override
  String get noFileInformation => '没有文件信息';

  @override
  String get close => '关闭';

  @override
  String get noPieceInformation => '该任务没有可用的分片信息。';

  @override
  String get noPieceInformationHint => '任务可能尚未开始，或 Aria2 没有提供分片数据。';

  @override
  String get pieceStatistics => '分片统计';

  @override
  String get totalPieces => '总分片数';

  @override
  String get partial => '部分完成';

  @override
  String get missing => '缺失';

  @override
  String completion(Object value) {
    return '完成度: $value%';
  }

  @override
  String get pieceMap => '分片图';

  @override
  String get legend => '图例';

  @override
  String get highProgress => '高进度 (8-b)';

  @override
  String get mediumProgress => '中等进度 (4-7)';

  @override
  String get lowProgress => '低进度 (1-3)';

  @override
  String get cannotGetDownloadDirectoryInformation => '无法获取下载目录信息';

  @override
  String get downloadDirectoryDoesNotExist => '下载目录不存在';

  @override
  String get cannotOpenDownloadDirectory => '无法打开下载目录';

  @override
  String errorOpeningDirectory(Object error) {
    return '打开目录时出错: $error';
  }

  @override
  String get connectionSection => '连接';

  @override
  String get transferSection => '传输';

  @override
  String get speedLimits => '速度限制';

  @override
  String get btPtSection => 'BT / PT';

  @override
  String get networkSection => '网络';

  @override
  String get filesSection => '文件';

  @override
  String get leaveEmptyToDisableSecretAuth => '留空则禁用 Secret 验证';

  @override
  String get splitCount => '分片数';

  @override
  String get continueUnfinishedDownloads => '继续未完成的下载';

  @override
  String get maxOverallDownloadLimit => '全局最大下载限速 (KB/s)';

  @override
  String get maxOverallUploadLimit => '全局最大上传限速 (KB/s)';

  @override
  String get keepSeedingAfterCompletion => '完成后继续做种';

  @override
  String get seedRatio => '做种比例';

  @override
  String get seedTimeMinutes => '做种时间 (分钟)';

  @override
  String get trackerSource => 'Tracker 来源';

  @override
  String get syncTrackerList => '同步 Tracker 列表';

  @override
  String get autoSyncTracker => '自动同步 Tracker 列表';

  @override
  String get btTrackerServers => 'Tracker 服务器';

  @override
  String get btTrackerServersTip => 'Tracker 服务器，可按每行一个或逗号分隔填写';

  @override
  String get exampleProxy => '示例: http://proxy:port';

  @override
  String get noProxyHosts => '不使用代理的主机';

  @override
  String get multipleHostsComma => '多个主机用逗号分隔';

  @override
  String get autoRenameFiles => '自动重命名文件';

  @override
  String get allowOverwrite => '允许覆盖';

  @override
  String get sessionFilePath => 'Session 文件路径';

  @override
  String get sessionFilePathTip =>
      '留空则使用默认的 data/core/aria2.session 路径。需要重启后生效。';

  @override
  String get logFilePath => '日志文件路径';

  @override
  String get logFilePathTip => '留空则使用默认的 data/core/aria2.log 路径。需要重启后生效。';

  @override
  String get reset => '重置';

  @override
  String get resetSessionRecord => '重置 Session 记录';

  @override
  String get resetSessionRecordTip =>
      '仅清理内建 aria2 的 Session 记录，不会修改设置，也不会删除已下载文件。';

  @override
  String resetSessionRecordConfirm(Object path) {
    return '要重置位于“$path”的内建 aria2 Session 记录吗？已下载文件和已保存设置都会保留。';
  }

  @override
  String get userAgent => 'User Agent';

  @override
  String get decrease => '减少';

  @override
  String get increase => '增加';

  @override
  String get settingsSaved => '设置已保存';

  @override
  String get settingsSaveOnlyHint => '“仅保存”只会保存改动，不会影响当前正在运行的内建实例。';

  @override
  String get settingsApplySpeedHint => '“保存并应用”会在内建实例已连接时立即应用限速改动。';

  @override
  String get settingsApplyLiveHint => '“保存并应用”会在内建实例已连接时立即应用支持在线更新的设置。';

  @override
  String get settingsApplyRestartHint => '“保存并应用”会重启内建实例来应用这些改动。';

  @override
  String get settingsApplyNoPendingHint => '“保存并应用”会在可能时把设置更新到当前运行中的内建实例。';

  @override
  String get restartingBuiltinInstance => '正在重启内建实例，请稍候...';

  @override
  String get resettingSessionRecord => '正在重置内建实例的 Session 记录，请稍候...';

  @override
  String get builtinInstanceMissing => '缺少内建实例';

  @override
  String get settingsSavedAppliedSuccess => '设置已保存并成功应用';

  @override
  String get settingsSavedRpcApplyFailed => '设置已保存，但将其应用到当前运行中的内建实例失败';

  @override
  String get settingsSavedApplyWhenConnected => '设置已保存。支持在线更新的改动会在内建实例下次连接时应用';

  @override
  String get settingsSavedRestartFailed => '设置已保存，但重启内建实例失败';

  @override
  String settingsSavedRestartFailedWithError(Object error) {
    return '设置已保存，但重启内建实例失败: $error';
  }

  @override
  String get sessionRecordResetSuccess => 'Session 记录已重置';

  @override
  String get sessionRecordAlreadyClean => 'Session 记录已经是干净状态';

  @override
  String get sessionRecordResetReconnectFailed => 'Session 记录已重置，但重新连接内建实例失败';

  @override
  String sessionRecordResetFailedWithError(Object error) {
    return '重置 Session 记录失败: $error';
  }

  @override
  String get trackerSyncSuccess => 'Tracker 列表已同步到当前草稿设置';

  @override
  String trackerSyncFailed(Object error) {
    return '同步 Tracker 列表失败: $error';
  }

  @override
  String get leavePage => '离开此页面？';

  @override
  String get unsavedChangesPrompt => '你有未保存的更改。你想怎么做？';

  @override
  String get discard => '丢弃';

  @override
  String startedAtWithValue(Object value) {
    return '开始时间: $value';
  }

  @override
  String get sourceLinks => '来源链接';

  @override
  String get trackers => 'Trackers';

  @override
  String get peers => 'Peers';

  @override
  String get noTrackerInformation => '没有 Tracker 信息';

  @override
  String get noPeerInformation => '没有 Peer 信息';

  @override
  String get clientLabel => '客户端';

  @override
  String get uploadShort => '上传';

  @override
  String get downloadShort => '下载';

  @override
  String get seeding => '做种中';

  @override
  String get stoppingSeedingTip => '正在停止做种，断开连接需要些时间，请耐心等待...';

  @override
  String failedToStopSeeding(Object error) {
    return '停止做种失败: $error';
  }

  @override
  String get torrentInfo => '种子信息';

  @override
  String get torrentHash => 'Hash';

  @override
  String get torrentPieceSize => '分片大小';

  @override
  String get torrentPieceCount => '分片数量';

  @override
  String get torrentCreationDate => '发布时间';

  @override
  String get torrentComment => '备注';

  @override
  String get torrentConnections => '连接数';

  @override
  String get torrentSeeders => '种子数';

  @override
  String get torrentUploaded => '已上传';

  @override
  String get torrentRatio => '分享率';

  @override
  String get english => 'English';

  @override
  String get chinese => '中文';
}
