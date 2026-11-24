import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'skill_row_models.freezed.dart';

/// Which skill operation is running or failed for a harness.
enum SkillRowAction {
  /// Installing the skill where none was installed.
  install,

  /// Updating an outdated or modified skill.
  update,

  /// Removing an installed skill.
  remove,
}

/// A failed skill operation shown in the harness card.
@freezed
sealed class SkillRowError with _$SkillRowError {
  /// Creates a [SkillRowError].
  const factory({
    required Failure failure,
    required SkillRowAction action,
    @Default(false) bool overwriteModified,
  }) = _SkillRowError;
}
