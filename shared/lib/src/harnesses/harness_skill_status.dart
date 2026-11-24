import 'package:json_annotation/json_annotation.dart';

/// State of the Agentic Hive skill inside a CLI harness (ADR 0028).
enum HarnessSkillStatus {
  /// The skill is installed and matches the one in the Bundle.
  @JsonValue('installed')
  installed,

  /// No skill folder exists.
  @JsonValue('not_installed')
  notInstalled,

  /// The sidecar records content that differs from the Bundle.
  @JsonValue('outdated')
  outdated,

  /// The installed files differ from the content hash in the sidecar.
  @JsonValue('modified')
  modified,

  /// A folder, file or symlink named `agentic-hive` exists that Agentic Hive
  /// did not install.
  @JsonValue('conflict')
  conflict,

  /// Detection could not read the disk or the Bundle.
  @JsonValue('unknown')
  unknown,
}
