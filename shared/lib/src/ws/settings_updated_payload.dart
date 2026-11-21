import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/settings/app_settings.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'settings_updated_payload.freezed.dart';
part 'settings_updated_payload.g.dart';

/// Payload of a `settings.updated` WebSocket message.
@freezed
sealed class SettingsUpdatedPayload with _$SettingsUpdatedPayload {
  /// Creates a settings updated payload.
  const factory({required AppSettings settings}) = _SettingsUpdatedPayload;

  /// Decodes a settings updated payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SettingsUpdatedPayloadFromJson);
}
