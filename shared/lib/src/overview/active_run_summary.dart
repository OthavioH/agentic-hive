import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'active_run_summary.freezed.dart';
part 'active_run_summary.g.dart';

/// Summary of a currently active (`running` or `paused`) run for Overview.
@freezed
sealed class ActiveRunSummary with _$ActiveRunSummary {
  /// Creates an active run summary.
  const factory({
    required String runId,
    required String workflowName,
    required RunStatus status,
    required DateTime startedAt,
    required int activeNodeCount,
    String? workflowId,
  }) = _ActiveRunSummary;

  /// Decodes an active run summary; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$ActiveRunSummaryFromJson);
}
