import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Builds the [NodeOutcome] for a `human_approval` node (R16-R19).
NodeOutcome approvalOutcome({
  required HumanApprovalDecision decision,
  String? feedback,
  Object? proposal,
  bool edited = false,
}) {
  final label = switch (decision) {
    HumanApprovalDecision.approved => NodeOutput.approved,
    HumanApprovalDecision.rejected => NodeOutput.rejected,
  };
  return NodeOutcome(
    outputLabel: label,
    data: {
      'decision': decision.name,
      'feedback': ?feedback,
      if (proposal != null) ...{'proposal': proposal, 'edited': edited},
    },
  );
}
