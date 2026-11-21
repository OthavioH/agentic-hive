import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/checkpoint.dart';
import 'package:agentic_hive_shared/src/runs/run_event.dart';
import 'package:agentic_hive_shared/src/runs/run_output_stream.dart';
import 'package:agentic_hive_shared/src/runs/run_summary.dart';
import 'package:agentic_hive_shared/src/workspace/workspace_isolation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_dtos.freezed.dart';
part 'run_dtos.g.dart';

/// Request body for `POST /api/v1/runs`.
@freezed
sealed class StartRunRequest with _$StartRunRequest {
  /// Creates a start-run request.
  const factory({
    required String workflowId,
    required String workspacePath,
    WorkspaceIsolationMode? workspaceIsolationMode,
    List<String>? ignorePatterns,
  }) = _StartRunRequest;

  /// Decodes a start-run request; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$StartRunRequestFromJson);
}

/// One line or chunk of captured output from a node attempt log.
///
/// [offset] is the strictly increasing 1-based sequence number assigned to
/// this chunk within its `(runId, nodeId, attempt)` log stream. It matches
/// `RunOutputPayload.offset` on WebSocket `run.output` frames so clients can
/// deduplicate REST snapshots against live WebSocket chunks.
@freezed
sealed class RunLogEntry with _$RunLogEntry {
  /// Creates a run log entry.
  const factory({
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
    @Default(0) int offset,
  }) = _RunLogEntry;

  /// Decodes a run log entry; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunLogEntryFromJson);
}

/// Response body for `GET /api/v1/runs/:id/nodes/:nodeId/logs`.
///
/// [offset] is the 1-based sequence number of the last entry included in
/// [entries] (or `0` when [entries] is empty). Live `run.output` WebSocket
/// frames with `payload.offset <= response.offset` are already represented in
/// [entries] and should be skipped when merging live output after a REST fetch.
@freezed
sealed class RunNodeLogsResponse with _$RunNodeLogsResponse {
  /// Creates a run-node-logs response.
  const factory({
    required String runId,
    required String nodeId,
    required int attempt,
    @Default(<int>[]) List<int> availableAttempts,
    @Default(<RunLogEntry>[]) List<RunLogEntry> entries,
    @Default(false) bool truncated,
    @Default(0) int offset,
  }) = _RunNodeLogsResponse;

  /// Decodes a run-node-logs response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunNodeLogsResponseFromJson);
}

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
