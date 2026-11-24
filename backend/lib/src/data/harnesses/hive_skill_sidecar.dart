import 'dart:convert';

/// Contents of `hive-skill.json`, written next to `SKILL.md`.
final class HiveSkillSidecar {
  /// Creates a sidecar record.
  const new({required this.appVersion, required this.contentHash});

  /// File name of the sidecar inside the installed skill folder.
  static const fileName = 'hive-skill.json';

  /// Supported sidecar schema version.
  static const currentSchemaVersion = 1;

  static final RegExp _sha256HexPattern = RegExp(r'^[0-9a-f]{64}$');

  /// Version of Agentic Hive that wrote this skill copy.
  final String appVersion;

  /// SHA-256 hex digest of the bundled skill content.
  final String contentHash;

  /// Encodes this sidecar as pretty JSON with a trailing LF and fixed key
  /// order.
  String encode() {
    const encoder = JsonEncoder.withIndent('  ');
    final json = encoder.convert(<String, Object?>{
      'schemaVersion': currentSchemaVersion,
      'appVersion': appVersion,
      'contentHash': contentHash,
    });
    return '$json\n';
  }

  /// Parses [text] into a [HiveSkillSidecar], or returns `null` if invalid.
  static HiveSkillSidecar? tryParse(String text) {
    final Object? decoded;
    try {
      decoded = jsonDecode(text);
    } on FormatException {
      return null;
    }
    if (decoded is! Map<String, Object?>) {
      return null;
    }
    final schemaVersion = decoded['schemaVersion'];
    final appVersion = decoded['appVersion'];
    final contentHash = decoded['contentHash'];
    if (schemaVersion is! int || schemaVersion != currentSchemaVersion) {
      return null;
    }
    if (appVersion is! String) {
      return null;
    }
    if (contentHash is! String || !_sha256HexPattern.hasMatch(contentHash)) {
      return null;
    }
    return HiveSkillSidecar(appVersion: appVersion, contentHash: contentHash);
  }
}
