import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/skills/skill_auto_install_outcome.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_auto_install_step.freezed.dart';
part 'skill_auto_install_step.g.dart';

/// Result of one automatic install step (skill or MCP).
@freezed
sealed class SkillAutoInstallStep with _$SkillAutoInstallStep {
  /// Creates a [SkillAutoInstallStep].
  const factory({
    required SkillAutoInstallOutcome outcome,
    @Default(<String>[]) List<String> paths,
    String? message,
  }) = _SkillAutoInstallStep;

  /// Decodes a [SkillAutoInstallStep]; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SkillAutoInstallStepFromJson);
}
