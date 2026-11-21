import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';

/// Default [ResultContract] placeholder until F7 wires the MCP/result.json
/// implementation.
final class UnconfiguredResultContract implements ResultContract {
  /// Creates an unconfigured result contract.
  const new();

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async => const FailureResult(
    NodeExecutionFailure('ResultContract is not configured.'),
  );

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Submit your result via the report_result MCP tool or '
      '${context.resultJsonPath ?? 'result.json'}.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async => const FailureResult(
    NodeExecutionFailure('ResultContract is not configured.'),
  );
}

/// Default [PtyRunner] placeholder until F12 wires ConPTY/PTY support.
final class UnconfiguredPtyRunner implements PtyRunner {
  /// Creates an unconfigured PTY runner.
  const new();

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async =>
      const FailureResult(NodeExecutionFailure('PtyRunner is not configured.'));
}

/// Default [HumanApprovalPort] placeholder until F10/F11 wires pause/resume.
final class UnconfiguredHumanApprovalPort implements HumanApprovalPort {
  /// Creates an unconfigured human approval port.
  const new();

  @override
  Future<Result<HumanApprovalResponse>> requestApproval(
    HumanApprovalRequest request,
  ) async => const FailureResult(
    NodeExecutionFailure('HumanApprovalPort is not configured.'),
  );
}

/// Default [AgentPromptResolver] placeholder until F2 wires the agent
/// repository.
final class UnconfiguredAgentPromptResolver implements AgentPromptResolver {
  /// Creates an unconfigured agent prompt resolver.
  const new();

  @override
  Future<Result<String>> resolvePrompt(String agentId) async =>
      FailureResult(NotFoundFailure('Agent "$agentId" could not be resolved.'));
}
