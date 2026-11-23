import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Pauses execution and requests human approval via [HumanApprovalPort].
final class HumanApprovalNode extends Node {
  /// Creates a human approval node.
  const new({required this.approvalPort});

  /// Port used to pause and await a human decision (implemented by F10/F11).
  final HumanApprovalPort approvalPort;

  @override
  String get typeId => NodeTypeId.humanApproval;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = HumanApprovalNodeConfig.fromJson(context.config);
    final decisionResult = await approvalPort.requestApproval(
      HumanApprovalRequest(
        runId: context.runId,
        nodeId: context.nodeId,
        title: config.title,
        instructions: config.instructions,
        allowFeedback: config.allowFeedback,
      ),
    );
    if (decisionResult case FailureResult<HumanApprovalResponse>(
      :final failure,
    )) {
      return FailureResult(failure);
    }

    final response = decisionResult.valueOrNull!;
    final outputLabel = switch (response.decision) {
      HumanApprovalDecision.approved => NodeOutput.approved,
      HumanApprovalDecision.rejected => NodeOutput.rejected,
    };

    return Success(
      NodeOutcome(
        outputLabel: outputLabel,
        data: <String, Object?>{
          'decision': response.decision.name,
          if (response.feedback != null) 'feedback': response.feedback,
        },
      ),
    );
  }
}
