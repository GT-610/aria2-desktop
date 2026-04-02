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
  String get minimizeToTray => '最小化到系统托盘';

  @override
  String get minimizeToTrayTip => '关闭窗口时最小化到系统托盘而不是退出';

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
  String get logSettings => '日志设置';

  @override
  String get logLevel => '日志级别';

  @override
  String get saveLogToFile => '保存日志到文件';

  @override
  String get viewLogFiles => '查看日志文件';

  @override
  String get thisFeatureWillBeImplemented => '此功能将在后续版本中实现';

  @override
  String get cannotOpenLogDirectory => '无法打开日志目录';

  @override
  String get about => '关于';

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
  String get excludedTrackers => '排除的Tracker';

  @override
  String get trackersTip => '多个Tracker用逗号分隔';

  @override
  String get networkSettings => '网络设置';

  @override
  String get globalProxy => '全局代理';

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
  String get fileSettings => '文件设置';

  @override
  String get downloadDir => '下载目录';

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
  String get testConnection => '测试连接';

  @override
  String get connectionSuccess => '连接成功';

  @override
  String connectionFailed(Object error) {
    return '连接失败: $error';
  }

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
}
