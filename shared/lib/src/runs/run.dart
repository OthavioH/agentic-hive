import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/runs/node_override.dart';
import 'package:agentic_hive_shared/src/runs/run_attachment.dart';
import 'package:agentic_hive_shared/src/runs/run_status.dart';
import 'package:agentic_hive_shared/src/workflows/workflow.dart';
import 'package:agentic_hive_shared/src/workspace/workspace_isolation_mode.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'run.freezed.dart';
part 'run.g.dart';

/// One execution of a [Workflow], with its own state, history, and workspace.
///
/// A run with a `parentRunId` is a child run started by fan-out node
/// `parentNodeId`. [attachments] holds metadata only; whether the files still
/// exist is derived from [status] (ADR 0030).
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
    @Default(WorkspaceIsolationMode.direct)
    WorkspaceIsolationMode isolationMode,
    String? worktreePath,
    String? worktreeBranch,
    String? workspaceId,
    String? workflowId,
    DateTime? finishedAt,
    String? errorMessage,
    String? input,
    String? parentRunId,
    String? parentNodeId,
    int? childIndex,
    String? childName,
    Map<String, NodeOverride>? nodeOverrides,
    List<RunAttachment>? attachments,
  }) = _Run;

  /// Decodes a run; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$RunFromJson);
}
