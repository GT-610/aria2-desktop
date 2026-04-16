class AddTaskOptionsData {
  const AddTaskOptionsData({
    this.outputFileName = '',
    this.split = '',
    this.userAgent = '',
    this.referer = '',
    this.cookie = '',
    this.authorization = '',
    this.allProxy = '',
    this.continueDownloads = true,
    this.autoFileRenaming = true,
    this.allowOverwrite = false,
  });

  final String outputFileName;
  final String split;
  final String userAgent;
  final String referer;
  final String cookie;
  final String authorization;
  final String allProxy;
  final bool continueDownloads;
  final bool autoFileRenaming;
  final bool allowOverwrite;
}

Map<String, dynamic> buildAria2TaskOptions(AddTaskOptionsData data) {
  final options = <String, dynamic>{};

  final outputFileName = data.outputFileName.trim();
  if (outputFileName.isNotEmpty) {
    options['out'] = outputFileName;
  }

  final splitValue = data.split.trim();
  if (splitValue.isNotEmpty) {
    final parsed = int.tryParse(splitValue);
    if (parsed == null || parsed <= 0) {
      throw const FormatException('split');
    }
    options['split'] = parsed.toString();
  }

  options['continue'] = data.continueDownloads.toString();
  options['auto-file-renaming'] = data.autoFileRenaming.toString();
  options['allow-overwrite'] = data.allowOverwrite.toString();

  final userAgent = data.userAgent.trim();
  if (userAgent.isNotEmpty) {
    options['user-agent'] = userAgent;
  }

  final referer = data.referer.trim();
  if (referer.isNotEmpty) {
    options['referer'] = referer;
  }

  final allProxy = data.allProxy.trim();
  if (allProxy.isNotEmpty) {
    options['all-proxy'] = allProxy;
  }

  final headers = <String>[];
  final cookie = data.cookie.trim();
  if (cookie.isNotEmpty) {
    headers.add('Cookie: $cookie');
  }

  final authorization = data.authorization.trim();
  if (authorization.isNotEmpty) {
    headers.add('Authorization: $authorization');
  }

  if (headers.isNotEmpty) {
    options['header'] = headers;
  }

  return options;
}
