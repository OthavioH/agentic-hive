import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Callback receiving streamed stdout/stderr lines from a running node.
typedef NodeOutputCallback = void Function(String stream, String line);

/// Execution inputs passed to `Node.execute`.
final class NodeExecutionContext {
  /// Creates a node execution context.
  const new({
    required this.runId,
    required this.nodeId,
    required this.workspacePath,
    this.attempt = 1,
    this.availableOutputs = const <String>[
      NodeOutput.onSuccess,
      NodeOutput.onFailure,
    ],
    this.config = const <String, Object?>{},
    this.inputs = const <String, Object?>{},
    this.resultJsonPath,
    this.humanAnswer,
    this.onOutput,
  });

  /// Identifier of the active workflow run.
  final String runId;

  /// Identifier of the node being executed.
  final String nodeId;

  /// Absolute path to the run's workspace directory.
  final String workspacePath;

  /// 1-based attempt number for this node execution.
  final int attempt;

  /// Output edge labels declared by the executing node.
  final List<String> availableOutputs;

  /// Raw `WorkflowNode.config` map for this node.
  final JsonMap config;

  /// Structured outputs passed from upstream nodes.
  final Map<String, Object?> inputs;

  /// Optional path to `result.json` for harnesses without MCP.
  final String? resultJsonPath;

  /// The human's answer to an earlier `ask_human` question, set when the
  /// engine re-runs a node after resuming its paused run (ADR 0019).
  final String? humanAnswer;

  /// Optional callback for streamed output lines.
  final NodeOutputCallback? onOutput;
}
