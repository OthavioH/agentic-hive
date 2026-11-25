import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_text_formatter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  const formatter = WorkflowTextFormatter();

  test('validation ok', () {
    expect(
      formatter.validation(const WorkflowValidationResult(isValid: true)),
      'Validation: ok',
    );
  });

  test('validation lists errors and warnings with node and edge', () {
    expect(
      formatter.validation(
        const WorkflowValidationResult(
          isValid: false,
          issues: [
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.error,
              code: 'MISSING_ENTRY',
              message: 'Entry missing',
              nodeId: 'plan',
            ),
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.warning,
              code: 'ORPHAN_EDGE',
              message: 'Orphan',
              edgeId: 'edge_1',
            ),
          ],
        ),
      ),
      'Validation (1 errors, 1 warnings):\n'
      '- error MISSING_ENTRY node plan: Entry missing\n'
      '- warning ORPHAN_EDGE edge edge_1: Orphan',
    );
  });

  test('workflow output is unchanged by the extraction', () {
    final workflow = Workflow(
      id: 'review-loop',
      name: 'Review loop',
      entryNodeId: 'plan',
      nodes: [
        const WorkflowNode(
          id: 'plan',
          type: 'harness.claude_code',
          label: 'Plan',
          position: WorkflowPosition(x: 100, y: 200),
          config: {'agentId': 'planner'},
        ),
        const WorkflowNode(
          id: 'review',
          type: 'validator.review',
          label: 'Review',
          position: WorkflowPosition(x: 300, y: 200),
          config: {
            'harnessType': 'codex',
            'reviewCriteria': 'Check the tests pass.',
          },
        ),
      ],
      edges: [
        const WorkflowEdge(
          id: 'e1',
          sourceNodeId: 'plan',
          sourceOutput: 'onSuccess',
          targetNodeId: 'review',
        ),
        const WorkflowEdge(
          id: 'e2',
          sourceNodeId: 'review',
          sourceOutput: 'onFailure',
          targetNodeId: 'plan',
          maxRetries: 2,
        ),
      ],
      createdAt: DateTime.utc(2026),
      updatedAt: DateTime.utc(2026),
    );
    expect(
      formatter.workflow(
        WorkflowResponse(
          workflow: workflow,
          validation: const WorkflowValidationResult(isValid: true),
          revision: '0123456789abcdef',
        ),
      ),
      'Workflow review-loop "Review loop" revision 0123456789abcdef\n'
      'Entry: plan\nNodes (2):\n'
      '- plan (harness.claude_code) "Plan" agentId=planner\n'
      '- review (validator.review) "Review" harnessType=codex '
      'reviewCriteria="Check the tests pass."\n'
      'Edges (2):\n- plan -onSuccess-> review\n'
      '- review -onFailure-> plan (maxRetries 2)\nValidation: ok',
    );
  });
}
