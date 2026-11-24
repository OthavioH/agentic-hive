import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [HumanApprovalPort] for checkpoint-driven pauses (ADR 0007).
///
/// It never waits for a human. It answers every request with a
/// [PauseRequestedFailure] so `HumanApprovalNode` returns immediately and the
/// graph engine can persist a checkpoint and release the run from memory. The
/// decision arrives later through `GraphEngine.resume`.
final class PausingHumanApprovalPort implements HumanApprovalPort {
  /// Creates a pausing approval port.
  const new();

  @override
  Future<Result<HumanApprovalResponse>> requestApproval(
    HumanApprovalRequest request,
  ) async => FailureResult(
    PauseRequestedFailure(
      'Run "${request.runId}" paused for approval at node '
      '"${request.nodeId}".',
      kind: PauseKind.humanApproval,
      runId: request.runId,
      nodeId: request.nodeId,
      question: request.instructions,
      proposalNodeId: request.proposalNodeId,
      proposal: request.proposal,
      proposalSchema: request.proposalSchema,
    ),
  );
}
