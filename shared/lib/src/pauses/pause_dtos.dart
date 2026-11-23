import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/pauses/pause.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pause_dtos.freezed.dart';
part 'pause_dtos.g.dart';

/// Request body for `POST /api/v1/pauses/:id/answer`.
///
/// The wire payload is a flat JSON object (`{"decision": ..., "feedback": ...}`
/// or `{"answer": ...}`) without a discriminator field because the pause kind
/// is stored on the target [Pause] record. For `PauseKind.humanApproval`,
/// supply [decision] (`approved` or `rejected`) and optional [feedback]. For
/// `PauseKind.askHuman`, supply a non-blank [answer]. Kind-specific validation
/// against the persisted [Pause] lives in the backend's `PauseAnswerHandler`
/// strategies.
@freezed
sealed class AnswerPauseRequest with _$AnswerPauseRequest {
  /// Creates an answer-pause request.
  const factory({String? decision, String? feedback, String? answer}) =
      _AnswerPauseRequest;

  /// Decodes an answer-pause request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$AnswerPauseRequestFromJson);
}

/// Paginated response body for `GET /api/v1/pauses`.
@freezed
sealed class PausesListResponse with _$PausesListResponse {
  /// Creates a pauses-list response.
  const factory({required List<Pause> items, required int total}) =
      _PausesListResponse;

  /// Decodes a pauses-list response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PausesListResponseFromJson);
}
