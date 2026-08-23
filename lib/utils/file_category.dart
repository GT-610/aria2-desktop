import 'dart:convert';

/// IDM-style file-type categorization: maps URI file names to subdirectories
/// based on user-defined extension rules.

const int maxFileCategoryRules = 20;

class FileCategoryRule {
  const FileCategoryRule({
    required this.extensions,
    required this.subdirectory,
  });

  /// Lowercase extensions without the leading dot, e.g. {'mp4', 'mkv'}.
  final Set<String> extensions;

  /// Target subdirectory appended to the task download directory.
  final String subdirectory;

  String encode() => jsonEncode(<String, dynamic>{
    'extensions': extensions.toList(growable: false),
    'subdirectory': subdirectory,
  });

  static FileCategoryRule? tryParse(String raw) {
    try {
      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) {
        return null;
      }
      final rawExtensions = decoded['extensions'];
      final extensions = <String>{};
      if (rawExtensions is List) {
        for (final entry in rawExtensions) {
          final normalized = _normalizeExtension('$entry');
          if (normalized != null) {
            extensions.add(normalized);
          }
        }
      }
      final subdirectory = _sanitizeSubdirectory(
        '${decoded['subdirectory'] ?? ''}',
      );
      if (extensions.isEmpty || subdirectory.isEmpty) {
        return null;
      }
      return FileCategoryRule(
        extensions: extensions,
        subdirectory: subdirectory,
      );
    } on FormatException {
      return null;
    }
  }
}

/// Parses rules from persisted JSON strings; malformed entries are skipped
/// and at most [maxFileCategoryRules] rules are kept.
List<FileCategoryRule> parseFileCategoryRules(List<String> rawRules) {
  final rules = <FileCategoryRule>[];
  for (final raw in rawRules.take(maxFileCategoryRules)) {
    final rule = FileCategoryRule.tryParse(raw);
    if (rule != null) {
      rules.add(rule);
    }
  }
  return rules;
}

/// Returns the subdirectory for [uri] according to the first matching rule,
/// or null when nothing matches or the URI carries no routable file name.
String? categorySubdirFor(String uri, List<FileCategoryRule> rules) {
  if (rules.isEmpty) {
    return null;
  }

  Uri parsed;
  try {
    parsed = Uri.parse(uri.trim());
  } on FormatException {
    return null;
  }
  final scheme = parsed.scheme.toLowerCase();
  if (!{'http', 'https', 'ftp', 'ftps'}.contains(scheme)) {
    // Magnets and torrents have their name only after metadata; routing
    // applies to plain URIs with a concrete file name.
    return null;
  }

  final segments = parsed.path
      .split('/')
      .where((segment) => segment.isNotEmpty)
      .toList();
  if (segments.isEmpty) {
    return null;
  }
  final fileName = segments.last;
  final dotIndex = fileName.lastIndexOf('.');
  if (dotIndex <= 0 || dotIndex == fileName.length - 1) {
    return null;
  }
  final extension = fileName.substring(dotIndex + 1).toLowerCase();
  if (extension.length > 12 || extension.contains(RegExp(r'[^a-z0-9]'))) {
    return null;
  }

  for (final rule in rules) {
    if (rule.extensions.contains(extension)) {
      return rule.subdirectory;
    }
  }
  return null;
}

String? _normalizeExtension(String value) {
  var normalized = value.trim().toLowerCase();
  while (normalized.startsWith('.')) {
    normalized = normalized.substring(1);
  }
  if (normalized.isEmpty || normalized.length > 12) {
    return null;
  }
  if (normalized.contains(RegExp(r'[^a-z0-9]'))) {
    return null;
  }
  return normalized;
}

String _sanitizeSubdirectory(String value) {
  var sanitized = value.trim().replaceAll('\\', '/');
  if (sanitized.startsWith('/')) {
    return '';
  }
  while (sanitized.endsWith('/')) {
    sanitized = sanitized.substring(0, sanitized.length - 1);
  }
  final parts = sanitized.split('/');
  if (sanitized.isEmpty ||
      parts.any(
        (part) =>
            part.isEmpty || part == '.' || part == '..' || part.contains(':'),
      )) {
    return '';
  }
  return sanitized;
}

/// Multi-URI variant: returns the first category match across the URI list.
String? categorySubdirForUris(
  String multiLineUris,
  List<FileCategoryRule> rules,
) {
  for (final line in multiLineUris.split(RegExp(r'[\r\n]+'))) {
    final trimmed = line.trim();
    if (trimmed.isEmpty) {
      continue;
    }
    final subdir = categorySubdirFor(trimmed, rules);
    if (subdir != null) {
      return subdir;
    }
  }
  return null;
}
