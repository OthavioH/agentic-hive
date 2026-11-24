import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/skills/skill_auto_install_notice.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_auto_install_notice_response.freezed.dart';
part 'skill_auto_install_notice_response.g.dart';

/// Body of `GET /api/v1/skills/auto-install/notice`.
@freezed
sealed class SkillAutoInstallNoticeResponse
    with _$SkillAutoInstallNoticeResponse {
  /// Creates a [SkillAutoInstallNoticeResponse].
  const factory({SkillAutoInstallNotice? notice}) =
      _SkillAutoInstallNoticeResponse;

  /// Decodes a [SkillAutoInstallNoticeResponse]; throws a [FormatException] on
  /// a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SkillAutoInstallNoticeResponseFromJson);
}
