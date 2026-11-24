import 'package:agentic_hive_shared/src/harnesses/harness_id.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/skills/skill_auto_install_step.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_auto_install_harness_result.freezed.dart';
part 'skill_auto_install_harness_result.g.dart';

/// Automatic skill and MCP install result for one harness.
@freezed
sealed class SkillAutoInstallHarnessResult
    with _$SkillAutoInstallHarnessResult {
  /// Creates a [SkillAutoInstallHarnessResult].
  const factory({
    required HarnessId harnessId,
    required SkillAutoInstallStep skill,
    required SkillAutoInstallStep mcp,
  }) = _SkillAutoInstallHarnessResult;

  /// Decodes a [SkillAutoInstallHarnessResult]; throws a [FormatException] on
  /// a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SkillAutoInstallHarnessResultFromJson);
}
