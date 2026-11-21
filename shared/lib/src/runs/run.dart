import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/run_status.dart';
import 'package:agentic_hive_shared/src/workflows/workflow.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run.freezed.dart';
part 'run.g.dart';

/// One execution of a [Workflow], with its own state, history, and workspace.
@freezed
sealed class Run with _$Run {
  /// Creates a run record.
  const factory({
    required String id,
    required String workflowName,
    required Workflow workflowDefinition,
    required String workspacePath,
    required RunStatus status,
    required DateTime startedAt,
    String? workflowId,
    DateTime? finishedAt,
    String? errorMessage,
  }) = _Run;

  /// Decodes a run; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunFromJson);
}
