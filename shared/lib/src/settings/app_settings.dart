import 'package:agentic_hive_shared/src/harnesses/harness_id.dart';
import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'app_settings.freezed.dart';
part 'app_settings.g.dart';

/// Current runtime application settings returned by `GET /api/v1/settings`
/// and `PUT /api/v1/settings`.
@freezed
sealed class AppSettings with _$AppSettings {
  /// Creates an application settings snapshot.
  const factory({
    required String agentsDir,
    required String defaultAgentsDir,
    String? defaultWorkspaceDir,
    @Default(<HarnessId, String>{}) Map<HarnessId, String> harnessOverrides,
  }) = _AppSettings;

  /// Decodes an [AppSettings] object; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) => parseJson(json, _$AppSettingsFromJson);
}
