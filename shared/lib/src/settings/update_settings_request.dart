import 'package:agentic_hive_shared/src/harnesses/harness_id.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'update_settings_request.freezed.dart';
part 'update_settings_request.g.dart';

/// Body of `PUT /api/v1/settings`.
@freezed
sealed class UpdateSettingsRequest with _$UpdateSettingsRequest {
  /// Creates a request to update runtime application settings.
  const factory({
    String? agentsDir,
    @Default(<HarnessId, String>{}) Map<HarnessId, String> harnessOverrides,
    bool? autoInstallSkills,
  }) = _UpdateSettingsRequest;

  /// Decodes an [UpdateSettingsRequest]; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$UpdateSettingsRequestFromJson);
}
