class AddTaskOptionsData {
  const AddTaskOptionsData({
    this.taskName = '',
    this.split = '',
    this.userAgent = '',
    this.continueDownloads = true,
    this.autoFileRenaming = true,
    this.allowOverwrite = false,
  });

  final String taskName;
  final String split;
  final String userAgent;
  final bool continueDownloads;
  final bool autoFileRenaming;
  final bool allowOverwrite;
}

Map<String, dynamic> buildAria2TaskOptions(AddTaskOptionsData data) {
  final options = <String, dynamic>{};

  final taskName = data.taskName.trim();
  if (taskName.isNotEmpty) {
    options['out'] = taskName;
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

  return options;
}
