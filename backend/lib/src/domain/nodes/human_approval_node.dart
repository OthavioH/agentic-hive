import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/approval_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/proposal_path.dart';
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
    final rawProposalNodeId = config.proposalNodeId?.trim();
    final proposalNodeId =
        (rawProposalNodeId == null || rawProposalNodeId.isEmpty)
        ? null
        : rawProposalNodeId;
    Object? proposal;
    String? proposalSchema;
    if (proposalNodeId != null) {
      final nodeOutputs = context.inputs['nodeOutputs'];
      final sourceOutput = nodeOutputs is Map
          ? nodeOutputs[proposalNodeId]
          : null;
      if (sourceOutput is! Map) {
        return FailureResult(
          ValidationFailure(
            'Proposal source node "$proposalNodeId" has not produced an '
            'output.',
          ),
        );
      }
      final path = config.proposalPath!.trim();
      proposal = ProposalPath.resolve(sourceOutput['data'], path);
      if (proposal == null) {
        return FailureResult(
          ValidationFailure(
            'Proposal field "$path" is missing or null in the output of '
            'node "$proposalNodeId".',
          ),
        );
      }
      final rawSchema = config.proposalSchema?.trim();
      proposalSchema = (rawSchema == null || rawSchema.isEmpty)
          ? null
          : rawSchema;
    }

    final decisionResult = await approvalPort.requestApproval(
      HumanApprovalRequest(
        runId: context.runId,
        nodeId: context.nodeId,
        title: config.title,
        instructions: config.instructions,
        allowFeedback: config.allowFeedback,
        proposalNodeId: proposalNodeId,
        proposal: proposal,
        proposalSchema: proposalSchema,
      ),
    );
    if (decisionResult case FailureResult<HumanApprovalResponse>(
      :final failure,
    )) {
      return FailureResult(failure);
    }

    final response = decisionResult.valueOrNull!;
    return Success(
      approvalOutcome(
        decision: response.decision,
        feedback: response.feedback,
        proposal: response.proposal,
        edited: response.edited,
      ),
    );
  }
}
