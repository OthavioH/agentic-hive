import 'package:agentic_hive_backend/src/domain/nodes/approval_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('approvalOutcome', () {
    test('without proposal produces decision and optional feedback only', () {
      final approved = approvalOutcome(
        decision: HumanApprovalDecision.approved,
      );
      expect(approved.outputLabel, NodeOutput.approved);
      expect(approved.data, {'decision': 'approved'});

      final rejected = approvalOutcome(
        decision: HumanApprovalDecision.rejected,
        feedback: 'Needs work',
      );
      expect(rejected.outputLabel, NodeOutput.rejected);
      expect(rejected.data, {'decision': 'rejected', 'feedback': 'Needs work'});
    });

    test('approved with proposal includes proposal and edited', () {
      final outcome = approvalOutcome(
        decision: HumanApprovalDecision.approved,
        proposal: const [1, 2],
        edited: true,
      );
      expect(outcome.outputLabel, NodeOutput.approved);
      expect(outcome.data, {
        'decision': 'approved',
        'proposal': [1, 2],
        'edited': true,
      });
    });

    test(
      'rejected with proposal includes original proposal and edited false',
      () {
        final outcome = approvalOutcome(
          decision: HumanApprovalDecision.rejected,
          feedback: 'Try again',
          proposal: const {'a': 1},
        );
        expect(outcome.outputLabel, NodeOutput.rejected);
        expect(outcome.data, {
          'decision': 'rejected',
          'feedback': 'Try again',
          'proposal': {'a': 1},
          'edited': false,
        });
      },
    );
  });
}
