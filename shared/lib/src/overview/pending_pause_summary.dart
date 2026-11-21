import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/pauses/pause_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'pending_pause_summary.freezed.dart';
part 'pending_pause_summary.g.dart';

/// Summary of a pending human-in-the-loop pause for Overview.
@freezed
sealed class PendingPauseSummary with _$PendingPauseSummary {
  /// Creates a pending pause summary.
  const factory({
    required String pauseId,
    required String runId,
    required String workflowName,
    required String nodeId,
    required String nodeLabel,
    required PauseKind pauseKind,
    required String prompt,
    required bool requiresFeedback,
    required DateTime createdAt,
  }) = _PendingPauseSummary;

  /// Decodes a pending pause summary; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$PendingPauseSummaryFromJson);
}
