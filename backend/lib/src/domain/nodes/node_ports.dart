import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';

/// Status reported by an agent harness through the result contract (ADR 0003).
enum ResultContractStatus {
  /// Task completed successfully.
  success,

  /// Task failed logically.
  failure,

  /// Review approved.
  approved,

  /// Review requested changes.
  changesRequested,
}

/// Structured report submitted by a harness via `report_result` or
/// `result.json`.
final class ResultContractReport {
  /// Creates a result contract report.
  const new({
    required this.status,
    this.output = const <String, Object?>{},
    this.artifacts = const <String>[],
    this.summary,
  });

  /// Reported completion status.
  final ResultContractStatus status;

  /// Structured output data.
  final Map<String, Object?> output;

  /// Artifact references reported by the agent.
  final List<String> artifacts;

  /// Optional human-readable summary.
  final String? summary;
}

/// Port for reading and instructing the ADR 0003 result contract.
///
/// Concretely implemented by F7 (MCP `report_result` + `result.json` reader).
abstract interface class ResultContract {
  /// Prompt instructions telling the harness how to submit its result report.
  String instructionsFor(NodeExecutionContext context);

  /// Reads the submitted report for [context], or `null` if none was
  /// submitted.
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  );
}

/// Specification for running a non-interactive child process.
final class ProcessInvocation {
  /// Creates a process invocation.
  const new({
    required this.executable,
    required this.workingDirectory,
    this.arguments = const <String>[],
    this.environment = const <String, String>{},
    this.stdinContent,
    this.timeout,
  });

  /// Executable name or path.
  final String executable;

  /// CLI arguments (must never contain prompt text per ADR 0005).
  final List<String> arguments;

  /// Working directory for the child process.
  final String workingDirectory;

  /// Extra environment variables merged with the process environment.
  final Map<String, String> environment;

  /// Optional content written to `stdin` before closing it.
  final String? stdinContent;

  /// Optional execution timeout.
  final Duration? timeout;
}

/// Captured output and exit status of a finished process or PTY session.
final class ProcessExecutionResult {
  /// Creates a process execution result.
  const new({
    required this.exitCode,
    this.stdout = '',
    this.stderr = '',
    this.timedOut = false,
  });

  /// Exit code reported by the process (`-1` if killed on timeout).
  final int exitCode;

  /// Collected standard output.
  final String stdout;

  /// Collected standard error.
  final String stderr;

  /// Whether execution was terminated due to exceeding its timeout.
  final bool timedOut;
}

/// Port for running headless child processes.
abstract interface class NodeProcessRunner {
  /// Runs [invocation], optionally streaming lines to [onOutput].
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  });
}

/// Specification for running an interactive pseudo-terminal (PTY) session.
final class PtyInvocation {
  /// Creates a PTY invocation.
  const new({
    required this.executable,
    required this.workingDirectory,
    this.arguments = const <String>[],
    this.environment = const <String, String>{},
    this.initialInput,
    this.timeout,
  });

  /// Executable to launch inside the PTY.
  final String executable;

  /// CLI arguments.
  final List<String> arguments;

  /// Working directory for the PTY session.
  final String workingDirectory;

  /// Extra environment variables.
  final Map<String, String> environment;

  /// Optional initial input written to the PTY stdin (never as a CLI arg).
  final String? initialInput;

  /// Optional session timeout.
  final Duration? timeout;
}

/// Port for running interactive PTY sessions (ConPTY/PTY fallback, ADR 0005).
///
/// Concretely implemented by F12.
abstract interface class PtyRunner {
  /// Starts and waits for a PTY session for [invocation].
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  });
}

/// Human decision on a `human_approval` node.
enum HumanApprovalDecision {
  /// Approved to proceed.
  approved,

  /// Rejected.
  rejected,
}

/// Request sent to [HumanApprovalPort].
final class HumanApprovalRequest {
  /// Creates a human approval request.
  const new({
    required this.runId,
    required this.nodeId,
    required this.instructions,
    this.title,
    this.allowFeedback = true,
  });

  /// Active run id.
  final String runId;

  /// Node id requesting approval.
  final String nodeId;

  /// Optional title shown in the UI.
  final String? title;

  /// Instructions shown to the human reviewer.
  final String instructions;

  /// Whether free-form feedback is allowed.
  final bool allowFeedback;
}

/// Response returned by [HumanApprovalPort].
final class HumanApprovalResponse {
  /// Creates a human approval response.
  const new({required this.decision, this.feedback});

  /// Human decision.
  final HumanApprovalDecision decision;

  /// Optional reviewer feedback.
  final String? feedback;
}

/// Port for pausing a run to request human approval.
///
/// Concretely implemented by F10/F11.
abstract interface class HumanApprovalPort {
  /// Requests approval and resolves once the human responds.
  Future<Result<HumanApprovalResponse>> requestApproval(
    HumanApprovalRequest request,
  );
}

/// Port for resolving an `agentId` to its prompt content without coupling
/// nodes to F2's concrete agent repository.
abstract interface class AgentPromptResolver {
  /// Resolves the prompt for [agentId], or returns `NotFoundFailure`.
  Future<Result<String>> resolvePrompt(String agentId);
}
