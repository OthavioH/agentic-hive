import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  WorkflowNode fanOutNode(
    String id, {
    String workflowId = 'child',
    String itemsNodeId = 'planner',
  }) => WorkflowNode(
    id: id,
    type: NodeTypeId.fanOut,
    label: id,
    position: const WorkflowPosition(x: 0, y: 0),
    config: {
      'workflowId': workflowId,
      'itemsNodeId': itemsNodeId,
      'itemsPath': 'issues',
    },
  );

  Workflow wf(String id, List<WorkflowNode> nodes) => Workflow(
    id: id,
    name: id,
    nodes: nodes,
    edges: const [],
    entryNodeId: nodes.first.id,
    createdAt: DateTime.utc(2026, 11, 24),
    updatedAt: DateTime.utc(2026, 11, 24),
  );

  const planner = WorkflowNode(
    id: 'planner',
    type: NodeTypeId.claudeCode,
    label: 'planner',
    position: WorkflowPosition(x: 0, y: 0),
  );

  const cmd = WorkflowNode(
    id: 'cmd',
    type: NodeTypeId.command,
    label: 'cmd',
    position: WorkflowPosition(x: 0, y: 0),
  );

  group('FanOutValidation', () {
    test('no fan-out nodes -> no issues', () {
      final issues = FanOutValidation.validate(
        wf('p', [planner]),
        findWorkflow: (_) => null,
      );
      expect(issues, isEmpty);
    });

    test('valid reference passes', () {
      final parent = wf('p', [planner, fanOutNode('fan')]);
      final child = wf('child', [cmd]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (id) => id == 'child' ? child : null,
      );
      expect(issues, isEmpty);
    });

    test('unresolved child workflow is a warning', () {
      final parent = wf('p', [planner, fanOutNode('fan')]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (_) => null,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, WorkflowValidationSeverity.warning);
      expect(issues.first.code, WorkflowValidationCode.unresolvedChildWorkflow);
      expect(issues.first.code, 'unresolved_child_workflow');
      expect(issues.first.nodeId, 'fan');
    });

    test('child with a fan-out node is an error', () {
      final parent = wf('p', [planner, fanOutNode('fan')]);
      final child = wf('child', [cmd, fanOutNode('inner')]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (_) => child,
      );
      expect(issues, hasLength(1));
      expect(issues.first.severity, WorkflowValidationSeverity.error);
      expect(issues.first.code, WorkflowValidationCode.nestedFanOut);
      expect(issues.first.code, 'nested_fan_out');
      expect(issues.first.nodeId, 'fan');
    });

    test('self reference is a nested fan-out', () {
      final parent = wf('p', [planner, fanOutNode('fan', workflowId: 'p')]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (_) => parent,
      );
      expect(issues, hasLength(1));
      expect(issues.first.code, WorkflowValidationCode.nestedFanOut);
    });

    test('itemsNodeId must exist and not be the node itself', () {
      final missing = wf('p', [
        planner,
        fanOutNode('fan', itemsNodeId: 'missing'),
      ]);
      final missingIssues = FanOutValidation.validate(
        missing,
        findWorkflow: (_) => wf('child', [cmd]),
      );
      expect(missingIssues, hasLength(1));
      expect(missingIssues.first.severity, WorkflowValidationSeverity.error);
      expect(
        missingIssues.first.code,
        WorkflowValidationCode.invalidNodeConfig,
      );
      expect(missingIssues.first.message, contains('does not exist'));

      final self = wf('p', [planner, fanOutNode('fan', itemsNodeId: 'fan')]);
      final selfIssues = FanOutValidation.validate(
        self,
        findWorkflow: (_) => wf('child', [cmd]),
      );
      expect(selfIssues, hasLength(1));
      expect(selfIssues.first.severity, WorkflowValidationSeverity.error);
      expect(selfIssues.first.code, WorkflowValidationCode.invalidNodeConfig);
      expect(selfIssues.first.message, contains('itself'));
    });

    test('blank workflowId produces no reference issue', () {
      final parent = wf('p', [planner, fanOutNode('fan', workflowId: '')]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (_) => throw StateError('should not be called'),
      );
      expect(issues, isEmpty);
    });

    test('malformed config values do not throw', () {
      final parent = wf('p', [
        planner,
        const WorkflowNode(
          id: 'fan',
          type: NodeTypeId.fanOut,
          label: 'fan',
          position: WorkflowPosition(x: 0, y: 0),
          config: {'workflowId': 5, 'itemsNodeId': 5},
        ),
      ]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (_) => null,
      );
      expect(issues, isEmpty);
    });

    test('each fan-out node is checked independently', () {
      final child = wf('child', [cmd]);
      final parent = wf('p', [
        planner,
        fanOutNode('fan1'),
        fanOutNode('fan2', workflowId: 'missing'),
      ]);
      final issues = FanOutValidation.validate(
        parent,
        findWorkflow: (id) => id == 'child' ? child : null,
      );
      expect(issues, hasLength(1));
      expect(issues.first.nodeId, 'fan2');
    });
  });
}
