import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_output_stream.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_output_payload.freezed.dart';
part 'run_output_payload.g.dart';

/// Payload of a `run.output` WebSocket message.
///
/// [offset] is the strictly increasing 1-based sequence number assigned by the
/// backend log store to each chunk within a `(runId, nodeId, attempt)` stream
/// as it is persisted. Clients can deduplicate live WebSocket frames against a
/// `RunNodeLogsResponse` snapshot by ignoring frames with
/// `offset <= response.offset`.
@freezed
sealed class RunOutputPayload with _$RunOutputPayload {
  /// Creates a run-output payload.
  const factory({
    required String runId,
    required String nodeId,
    required int attempt,
    required RunOutputStream stream,
    required String chunk,
    required DateTime timestamp,
    @Default(0) int offset,
  }) = _RunOutputPayload;

  /// Decodes a run-output payload; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunOutputPayloadFromJson);
}
