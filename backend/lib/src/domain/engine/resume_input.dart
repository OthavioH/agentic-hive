import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';

/// What a human supplies to resume a `paused` run.
sealed class ResumeInput {
  /// Creates a resume input, optionally targeting one paused [nodeId].
  const new({this.nodeId});

  /// The paused node this input answers. Optional when exactly one node is
  /// paused.
  final String? nodeId;
}

/// A decision for a paused `human_approval` node. The engine resolves the node
/// directly to `approved` or `rejected` without re-running it (ADR 0007).
final class ApprovalDecisionInput extends ResumeInput {
  /// Creates an approval decision.
  const new({required this.decision, this.feedback, super.nodeId});

  /// The human's decision.
  final HumanApprovalDecision decision;

  /// Optional free-form reviewer feedback.
  final String? feedback;
}

/// An answer to an `ask_human` question. The engine re-runs the paused node
/// with the answer in `NodeExecutionContext.humanAnswer` (ADR 0019).
final class HumanAnswerInput extends ResumeInput {
  /// Creates a human answer.
  const new({required this.answer, super.nodeId});

  /// The human's answer.
  final String answer;
}
