import 'dart:io';

import 'package:path/path.dart' as p;

/// The four files that carry the product version.
const versionTargetFiles = <String>[
  'shared/pubspec.yaml',
  'backend/pubspec.yaml',
  'frontend/pubspec.yaml',
  'backend/lib/src/version.dart',
];

final RegExp _semverPattern = RegExp(r'^(\d+\.\d+\.\d+)$');
final RegExp _pubspecVersionPattern = RegExp(
  r'^version:\s*\S+',
  multiLine: true,
);
final RegExp _backendVersionPattern = RegExp("const backendVersion = '[^']+';");

/// Normalizes and validates [raw] as `X.Y.Z` (with an optional leading `v`).
///
/// Throws a [FormatException] if [raw] is not a `X.Y.Z` version string.
String parseSemver(String raw) {
  final trimmed = raw.trim();
  final normalized = trimmed.startsWith('v') ? trimmed.substring(1) : trimmed;
  final match = _semverPattern.firstMatch(normalized);
  if (match == null) {
    throw FormatException(
      'Invalid version "$raw". Expected X.Y.Z (for example 0.4.0).',
    );
  }
  return match.group(1)!;
}

/// Replaces the `version:` field in a `pubspec.yaml` [content] with
/// [newVersion].
String updatePubspecVersion(String content, String newVersion) {
  if (!_pubspecVersionPattern.hasMatch(content)) {
    throw const FormatException('Missing "version:" field in pubspec.yaml.');
  }
  return content.replaceFirst(_pubspecVersionPattern, 'version: $newVersion');
}

/// Replaces `const backendVersion = '...';` in `backend/lib/src/version.dart`
/// [content] with [newVersion].
String updateBackendVersionDart(String content, String newVersion) {
  if (!_backendVersionPattern.hasMatch(content)) {
    throw const FormatException(
      'Missing "const backendVersion = ...;" in version.dart.',
    );
  }
  return content.replaceFirst(
    _backendVersionPattern,
    "const backendVersion = '$newVersion';",
  );
}

/// Updates the product version in all four tracked files under [rootDir].
void bumpVersionInDirectory(String rootDir, String newVersion) {
  final version = parseSemver(newVersion);
  for (final relative in const <String>[
    'shared/pubspec.yaml',
    'backend/pubspec.yaml',
    'frontend/pubspec.yaml',
  ]) {
    final file = File(p.joinAll(<String>[rootDir, ...relative.split('/')]));
    if (!file.existsSync()) {
      throw FileSystemException('Missing expected file', file.path);
    }
    file.writeAsStringSync(
      updatePubspecVersion(file.readAsStringSync(), version),
    );
  }

  final dartVersionFile = File(
    p.join(rootDir, 'backend', 'lib', 'src', 'version.dart'),
  );
  if (!dartVersionFile.existsSync()) {
    throw FileSystemException('Missing expected file', dartVersionFile.path);
  }
  dartVersionFile.writeAsStringSync(
    updateBackendVersionDart(dartVersionFile.readAsStringSync(), version),
  );
}
