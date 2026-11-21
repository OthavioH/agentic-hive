import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/runs/pausing_human_approval_port.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  test('answers an approval request with a pause request', () async {
    final result = await const PausingHumanApprovalPort().requestApproval(
      const HumanApprovalRequest(
        runId: 'run-1',
        nodeId: 'gate',
        instructions: 'Check the diff.',
      ),
    );

    final failure = result.failureOrNull! as PauseRequestedFailure;
    expect(failure.kind, PauseKind.humanApproval);
    expect(failure.runId, 'run-1');
    expect(failure.nodeId, 'gate');
    expect(failure.question, 'Check the diff.');
  });
}
