import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Callback receiving streamed stdout/stderr lines from a running node.
typedef NodeOutputCallback = void Function(String stream, String line);

/// A stored Run attachment as a node sees it (ADR 0030).
final class RunAttachmentFile {
  /// Creates a stored Run attachment reference.
  const new({required this.path, required this.fileName});

  /// Absolute path of the stored file.
  final String path;

  /// Display name the user gave the file.
  final String fileName;
}

/// Identifies a harness attempt stopped by a rate limit before a fallback.
final class StoppedAttempt {
  /// Creates a stopped-attempt descriptor.
  const new({required this.harness, this.model});

  /// Canonical `WorkflowNode.type` of the harness that hit the rate limit.
  final String harness;

  /// Optional model name used on that attempt.
  final String? model;
}

/// Execution inputs passed to `Node.execute`.
final class NodeExecutionContext {
  /// Creates a node execution context.
  const new({
    required this.runId,
    required this.nodeId,
    required this.targetFolder,
    this.nodeLabel,
    this.workspaceRoot,
    this.workspaceId,
    this.attempt = 1,
    this.availableOutputs = const <String>[
      NodeOutput.onSuccess,
      NodeOutput.onFailure,
    ],
    this.config = const <String, Object?>{},
    this.inputs = const <String, Object?>{},
    this.isolationMode = WorkspaceIsolationMode.direct,
    this.resultJsonPath,
    this.humanAnswer,
    this.runInput,
    this.stoppedAttempt,
    this.runAttachments = const <RunAttachmentFile>[],
    this.onOutput,
  });

  /// Identifier of the active workflow run.
  final String runId;

  /// Identifier of the node being executed.
  final String nodeId;

  /// Display label of the node being executed.
  final String? nodeLabel;

  /// Absolute path to the run's target folder (the workspace root or a
  /// worktree).
  final String targetFolder;

  /// Root folder of the registered workspace the run belongs to, which can
  /// differ from [targetFolder] under worktree isolation. Used to find
  /// workspace-scoped agents (ADR 0025).
  final String? workspaceRoot;

  /// Identifier of the registered workspace the run belongs to. Used to
  /// resolve the workspace's effective execution settings (ADR 0025).
  final String? workspaceId;

  /// 1-based attempt number for this node execution.
  final int attempt;

  /// Output edge labels declared by the executing node.
  final List<String> availableOutputs;

  /// Raw `WorkflowNode.config` map for this node.
  final JsonMap config;

  /// Structured outputs passed from upstream nodes.
  final Map<String, Object?> inputs;

  /// Workspace isolation mode for the active run (`worktree` or `direct`).
  final WorkspaceIsolationMode isolationMode;

  /// Optional path to `result.json` for harnesses without MCP.
  final String? resultJsonPath;

  /// The human's answer to an earlier `ask_human` question, set when the
  /// engine re-runs a node after resuming its paused run (ADR 0019).
  final String? humanAnswer;

  /// Optional free-text run input passed only to the workflow's entry node.
  final String? runInput;

  /// The harness attempt a rate limit stopped just before this one.
  final StoppedAttempt? stoppedAttempt;

  /// Stored Run attachments of the run, all in one folder; empty when none.
  final List<RunAttachmentFile> runAttachments;

  /// Optional callback for streamed output lines.
  final NodeOutputCallback? onOutput;
}
