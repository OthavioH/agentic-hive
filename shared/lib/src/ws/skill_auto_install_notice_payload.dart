import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/skills/skill_auto_install_notice.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_auto_install_notice_payload.freezed.dart';
part 'skill_auto_install_notice_payload.g.dart';

/// Payload of a `skills.auto_installed` WebSocket message.
@freezed
sealed class SkillAutoInstallNoticePayload
    with _$SkillAutoInstallNoticePayload {
  /// Creates a [SkillAutoInstallNoticePayload].
  const factory({required SkillAutoInstallNotice notice}) =
      _SkillAutoInstallNoticePayload;

  /// Decodes a [SkillAutoInstallNoticePayload]; throws a [FormatException] on
  /// a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SkillAutoInstallNoticePayloadFromJson);
}
