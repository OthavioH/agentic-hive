import 'package:freezed_annotation/freezed_annotation.dart';

/// What the automatic install did for one step (skill or MCP) of a harness.
enum SkillAutoInstallOutcome {
  /// Written now.
  @JsonValue('installed')
  installed,

  /// Already up to date; nothing written.
  @JsonValue('already_installed')
  alreadyInstalled,

  /// Present but outdated/modified/conflict/unknown/unsupported; untouched.
  @JsonValue('skipped')
  skipped,

  /// The install failed; message says why.
  @JsonValue('failed')
  failed,
}
