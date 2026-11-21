import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_status.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run_summary.freezed.dart';
part 'run_summary.g.dart';

/// Lightweight summary of a run for list responses.
@freezed
sealed class RunSummary with _$RunSummary {
  /// Creates a run summary.
  const factory({
    required String id,
    required String workflowName,
    required RunStatus status,
    required DateTime startedAt,
    required int checkpointCount,
    String? workflowId,
    DateTime? finishedAt,
  }) = _RunSummary;

  /// Decodes a run summary; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunSummaryFromJson);
}
