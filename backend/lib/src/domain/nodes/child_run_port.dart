import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Where a child run executes.
enum ChildRunPlacement {
  /// A new git worktree created from [ChildRunRequest.baseCommit].
  worktree,

  /// The parent run's own folder, lent to one child at a time.
  lentFolder,
}

/// What the parent's workspace looks like to a fan-out node.
final class ParentWorkspaceInfo {
  /// Creates a [ParentWorkspaceInfo].
  const new({
    required this.isGit,
    this.headCommit,
    this.hasUncommittedChanges = false,
  });

  /// Whether the parent workspace is a git repository.
  final bool isGit;

  /// `HEAD` commit SHA of the parent's target folder when [isGit] is true.
  final String? headCommit;

  /// Whether the parent's target folder has uncommitted changes.
  final bool hasUncommittedChanges;
}

/// Everything needed to start one child run.
final class ChildRunRequest {
  /// Creates a [ChildRunRequest].
  const new({
    required this.parentRunId,
    required this.parentNodeId,
    required this.index,
    required this.name,
    required this.workflow,
    required this.workspaceId,
    required this.placement,
    this.worktreeName,
    this.baseCommit,
    this.input,
    this.nodeOverrides,
  });

  /// Identifier of the parent run.
  final String parentRunId;

  /// Identifier of the fan-out node starting this child.
  final String parentNodeId;

  /// 0-based index of this child within the fan-out execution.
  final int index;

  /// Display name stored on [Run.childName].
  final String name;

  /// Pinned workflow definition for this child run.
  final Workflow workflow;

  /// Identifier of the parent's registered workspace.
  final String workspaceId;

  /// Where this child executes.
  final ChildRunPlacement placement;

  /// Sanitized worktree folder name for [ChildRunPlacement.worktree].
  final String? worktreeName;

  /// Base commit SHA for [ChildRunPlacement.worktree].
  final String? baseCommit;

  /// Input text passed to the child's entry node.
  final String? input;

  /// Optional per-node overrides applied to [workflow].
  final Map<String, NodeOverride>? nodeOverrides;
}

/// What a fan-out node needs from the run layer.
abstract interface class ChildRunPort {
  /// Resolves and returns the child [Workflow] once for a fan-out execution.
  Future<Result<Workflow>> pinWorkflow({
    required String workflowId,
    required String workspaceId,
  });

  /// Inspects the parent run's workspace to choose child placement.
  Future<Result<ParentWorkspaceInfo>> inspectParentWorkspace({
    required String runId,
  });

  /// Creates and starts one child run.
  Future<Result<Run>> startChildRun(ChildRunRequest request);

  /// Loads the current state of [runId].
  Future<Result<Run>> getRun(String runId);

  /// Output map `{outputLabel, data, artifacts}` of the node completed last
  /// in [runId]'s latest checkpoint, or null when there is none.
  Future<Result<Map<String, Object?>?>> finalOutputOf(String runId);

  /// Appends a non-fatal warning event to [runId] for [nodeId].
  Future<void> recordWarning({
    required String runId,
    required String nodeId,
    required String message,
  });

  /// Child runs of [parentRunId] started by [parentNodeId], oldest first.
  Future<Result<List<Run>>> listChildRuns({
    required String parentRunId,
    required String parentNodeId,
  });

  /// Resumes the `interrupted` child run [runId] from its latest checkpoint.
  Future<Result<Run>> resumeChildRun(String runId);

  /// Cancels the child run [runId] and completes once the cancel settled.
  Future<Result<Run>> cancelChildRun(String runId);
}
