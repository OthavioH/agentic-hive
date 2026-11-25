import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/skills/skill_auto_install_harness_result.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_auto_install_notice.freezed.dart';
part 'skill_auto_install_notice.g.dart';

/// What the automatic install did since the user last dismissed the notice.
@freezed
sealed class SkillAutoInstallNotice with _$SkillAutoInstallNotice {
  /// Creates a [SkillAutoInstallNotice].
  const factory({
    required String id,
    required DateTime createdAt,
    required List<SkillAutoInstallHarnessResult> results,
  }) = _SkillAutoInstallNotice;

  /// Decodes a [SkillAutoInstallNotice]; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SkillAutoInstallNoticeFromJson);
}
