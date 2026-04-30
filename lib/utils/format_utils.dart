import 'dart:math';

String formatBytes(int bytes, {int decimals = 2}) {
  if (bytes <= 0) return '0 B';

  const suffixes = ['B', 'KB', 'MB', 'GB', 'TB', 'PB', 'EB', 'ZB', 'YB'];
  var i = (log(bytes) / log(1024)).floor();
  i = i.clamp(0, suffixes.length - 1);

  return '${(bytes / pow(1024, i)).toStringAsFixed(decimals)} ${suffixes[i]}';
}

String formatRemainingTime({
  required int totalBytes,
  required int completedBytes,
  required int downloadSpeedBytes,
}) {
  if (totalBytes <= 0) {
    return '--';
  }

  final remainingBytes = totalBytes - completedBytes;
  if (remainingBytes <= 0) {
    return '0s';
  }

  if (downloadSpeedBytes <= 0) {
    return '--';
  }

  final remainingSeconds = (remainingBytes / downloadSpeedBytes).ceil();
  if (remainingSeconds < 60) {
    return '${remainingSeconds}s';
  }
  if (remainingSeconds < 3600) {
    final minutes = remainingSeconds ~/ 60;
    final seconds = remainingSeconds % 60;
    return '${minutes}m ${seconds}s';
  }
  if (remainingSeconds < 86400) {
    final hours = remainingSeconds ~/ 3600;
    final minutes = (remainingSeconds % 3600) ~/ 60;
    return '${hours}h ${minutes}m';
  }

  final days = remainingSeconds ~/ 86400;
  final hours = (remainingSeconds % 86400) ~/ 3600;
  return '${days}d ${hours}h';
}

List<int> parseHexBitfield(String bitfield) {
  final pieces = <int>[];

  for (var i = 0; i < bitfield.length; i++) {
    try {
      pieces.add(int.parse(bitfield[i], radix: 16));
    } catch (e) {
      pieces.add(0);
    }
  }

  return pieces;
}

String formatSpeed(int bytesPerSecond) {
  if (bytesPerSecond < 1024) {
    return '$bytesPerSecond B/s';
  } else if (bytesPerSecond < 1024 * 1024) {
    return '${(bytesPerSecond / 1024).toStringAsFixed(2)} KB/s';
  } else {
    return '${(bytesPerSecond / (1024 * 1024)).toStringAsFixed(2)} MB/s';
  }
}

String formatSpeedLimitOption(int value) {
  return value > 0 ? '${value}K' : '0';
}
