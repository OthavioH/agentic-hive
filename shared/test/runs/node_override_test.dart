import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final workflow = Workflow(
    id: 'wf',
    name: 'wf',
    nodes: const [
      WorkflowNode(
        id: 'h',
        type: NodeTypeId.claudeCode,
        label: 'h',
        position: WorkflowPosition(x: 0, y: 0),
      ),
      WorkflowNode(
        id: 'g',
        type: NodeTypeId.geminiCli,
        label: 'g',
        position: WorkflowPosition(x: 0, y: 0),
      ),
      WorkflowNode(
        id: 't',
        type: NodeTypeId.terminal,
        label: 't',
        position: WorkflowPosition(x: 0, y: 0),
      ),
      WorkflowNode(
        id: 'c',
        type: NodeTypeId.command,
        label: 'c',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'h',
    createdAt: DateTime.utc(2026, 11, 24),
    updatedAt: DateTime.utc(2026, 11, 24),
  );

  group('NodeOverride', () {
    test('round-trips and omits null fields', () {
      const override = NodeOverride(model: 'm');
      final json = override.toJson();
      expect(json, {'model': 'm'});
      expect(NodeOverride.fromJson(json), override);
    });

    test('isEmpty is true for all-null and all-blank, false when one set', () {
      expect(const NodeOverride().isEmpty, isTrue);
      expect(
        const NodeOverride(agentId: '  ', model: '', effort: ' ').isEmpty,
        isTrue,
      );
      expect(const NodeOverride(model: 'm').isEmpty, isFalse);
      expect(const NodeOverride(agentId: 'a').isEmpty, isFalse);
      expect(const NodeOverride(effort: 'low').isEmpty, isFalse);
    });

    test('fields exposes every overridable field and its getter', () {
      const override = NodeOverride(agentId: 'a1', model: 'm1', effort: 'high');
      expect(
        {
          for (final (name, getter) in NodeOverride.fields)
            name: getter(override),
        },
        {'agentId': 'a1', 'model': 'm1', 'effort': 'high'},
      );
    });
  });

  group('NodeOverrideValidation', () {
    test('empty override is refused', () {
      final issues = NodeOverrideValidation.validate(const {
        'h': NodeOverride(),
      }, workflow);
      expect(issues.map((i) => i.field), contains('nodeOverrides.h'));
    });

    test('effort must be a known level', () {
      final bad = NodeOverrideValidation.validate(const {
        'h': NodeOverride(effort: 'extreme'),
      }, workflow);
      expect(bad.map((i) => i.field), contains('nodeOverrides.h.effort'));

      for (final level in ['low', 'medium', 'high', 'max']) {
        expect(
          NodeOverrideValidation.validate({
            'h': NodeOverride(effort: level),
          }, workflow),
          isEmpty,
        );
      }
    });

    test('model must not start with a dash', () {
      final issues = NodeOverrideValidation.validate(const {
        'h': NodeOverride(model: '--x'),
      }, workflow);
      expect(issues.map((i) => i.field), contains('nodeOverrides.h.model'));
    });

    test('unknown node id is refused', () {
      final issues = NodeOverrideValidation.validate(const {
        'zzz': NodeOverride(model: 'm'),
      }, workflow);
      expect(issues.map((i) => i.field), contains('nodeOverrides.zzz'));
    });

    test('unsupported fields are refused per descriptor', () {
      final geminiEffort = NodeOverrideValidation.validate(const {
        'g': NodeOverride(effort: 'low'),
      }, workflow);
      expect(geminiEffort, hasLength(1));
      expect(geminiEffort.first.field, 'nodeOverrides.g.effort');
      expect(geminiEffort.first.message, contains('does not support'));

      expect(
        NodeOverrideValidation.validate(const {
          'g': NodeOverride(model: 'm', agentId: 'a'),
        }, workflow),
        isEmpty,
      );

      final terminalModel = NodeOverrideValidation.validate(const {
        't': NodeOverride(model: 'm'),
      }, workflow);
      expect(
        terminalModel.map((i) => i.field),
        contains('nodeOverrides.t.model'),
      );

      expect(
        NodeOverrideValidation.validate(const {
          't': NodeOverride(agentId: 'a'),
        }, workflow),
        isEmpty,
      );

      final commandAgent = NodeOverrideValidation.validate(const {
        'c': NodeOverride(agentId: 'a'),
      }, workflow);
      expect(
        commandAgent.map((i) => i.field),
        contains('nodeOverrides.c.agentId'),
      );
    });

    test('valid map passes', () {
      final issues = NodeOverrideValidation.validate(const {
        'h': NodeOverride(agentId: 'a', model: 'm', effort: 'high'),
        'g': NodeOverride(model: 'm'),
      }, workflow);
      expect(issues, isEmpty);
    });

    test('all issues are returned', () {
      final issues = NodeOverrideValidation.validate(const {
        'h': NodeOverride(model: '--bad', effort: 'extreme'),
        'zzz': NodeOverride(model: 'm'),
      }, workflow);
      expect(issues.length, greaterThanOrEqualTo(3));
    });
  });
}
