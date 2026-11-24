import 'dart:convert';
import 'dart:typed_data';

import 'package:crypto/crypto.dart';

/// A skill folder read from disk: files plus a stable content hash.
final class BundledSkill {
  /// Creates a skill. [files] maps POSIX relative path to LF-normalized bytes.
  const new({
    required this.name,
    required this.files,
    required this.contentHash,
  });

  /// Folder name, for example `agentic-hive`.
  final String name;

  /// POSIX relative path (for example `SKILL.md`, `references/x.md`) to bytes.
  final Map<String, List<int>> files;

  /// Lowercase hex SHA-256, 64 characters. See [computeSkillContentHash].
  final String contentHash;
}

/// Content hash of [files] (POSIX relative path to bytes).
String computeSkillContentHash(Map<String, List<int>> files) {
  final keys = files.keys.toList()..sort((a, b) => a.compareTo(b));
  final builder = BytesBuilder(copy: false);
  for (final key in keys) {
    final bytes = files[key]!;
    builder
      ..add(utf8.encode(key))
      ..addByte(0)
      ..add(utf8.encode('${bytes.length}'))
      ..addByte(0)
      ..add(bytes)
      ..addByte(10);
  }
  return sha256.convert(builder.takeBytes()).toString();
}
