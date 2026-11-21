import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/checkpoint.dart';
import 'package:agentic_hive_shared/src/runs/run_event.dart';
import 'package:agentic_hive_shared/src/runs/run_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_dtos.freezed.dart';
part 'run_dtos.g.dart';

/// Paginated response body for `GET /api/v1/runs`.
@freezed
sealed class RunsListResponse with _$RunsListResponse {
  /// Creates a runs-list response.
  const factory({required List<RunSummary> items, required int total}) =
      _RunsListResponse;

  /// Decodes a runs-list response; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunsListResponseFromJson);
}

/// Paginated response body for `GET /api/v1/runs/:id/events`.
@freezed
sealed class RunEventsResponse with _$RunEventsResponse {
  /// Creates a run-events response.
  const factory({required List<RunEvent> items, required int lastSequence}) =
      _RunEventsResponse;

  /// Decodes a run-events response; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunEventsResponseFromJson);
}

/// Response body for `GET /api/v1/runs/:id/checkpoints`.
@freezed
sealed class RunCheckpointsResponse with _$RunCheckpointsResponse {
  /// Creates a run-checkpoints response.
  const factory({required List<Checkpoint> items}) = _RunCheckpointsResponse;

  /// Decodes a run-checkpoints response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunCheckpointsResponseFromJson);
}
