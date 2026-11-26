import 'package:agentic_hive_backend/src/domain/engine/fallback_config.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

WorkflowNode _node({
  String type = NodeTypeId.claudeCode,
  JsonMap config = const <String, Object?>{},
}) => WorkflowNode(
  id: 'n1',
  type: type,
  label: 'Node',
  position: const WorkflowPosition(x: 0, y: 0),
  config: config,
);

void main() {
  group('FallbackConfig', () {
    test('null index returns the node own type and config unchanged', () {
      const cfg = <String, Object?>{
        'additionalInstructions': 'Do X',
        'model': 'sonnet',
        'effort': 'high',
        'extraArgs': ['--verbose'],
      };
      final node = _node(config: cfg);

      final (type, effective) = FallbackConfig.effective(node, null);

      expect(type, NodeTypeId.claudeCode);
      expect(effective, cfg);
    });

    test('different harness drops extraArgs and replaces model and effort', () {
      final node = _node(
        config: const <String, Object?>{
          'agentId': 'coder',
          'additionalInstructions': 'Do X',
          'workingDirectory': 'sub',
          'timeoutSeconds': 120,
          'model': 'sonnet',
          'effort': 'high',
          'extraArgs': ['--verbose'],
          'fallback': [
            <String, Object?>{'harness': NodeTypeId.codex, 'model': 'gpt-5'},
          ],
        },
      );

      final (type, effective) = FallbackConfig.effective(node, 0);

      expect(type, NodeTypeId.codex);
      expect(effective['model'], 'gpt-5');
      expect(effective.containsKey('effort'), isFalse);
      expect(effective.containsKey('extraArgs'), isFalse);
      expect(effective['agentId'], 'coder');
      expect(effective['additionalInstructions'], 'Do X');
      expect(effective['workingDirectory'], 'sub');
      expect(effective['timeoutSeconds'], 120);
      expect(effective['fallback'], isNotNull);
    });

    test('same harness keeps extraArgs and applies entry model and effort', () {
      final node = _node(
        config: const <String, Object?>{
          'additionalInstructions': 'Do X',
          'model': 'sonnet',
          'extraArgs': ['--verbose'],
          'fallback': [
            <String, Object?>{
              'harness': NodeTypeId.claudeCode,
              'model': 'opus',
              'effort': 'max',
            },
          ],
        },
      );

      final (type, effective) = FallbackConfig.effective(node, 0);

      expect(type, NodeTypeId.claudeCode);
      expect(effective['model'], 'opus');
      expect(effective['effort'], 'max');
      expect(effective['extraArgs'], ['--verbose']);
    });

    test('entriesOf returns empty for non-headless nodes', () {
      final command = _node(
        type: NodeTypeId.command,
        config: const <String, Object?>{
          'command': 'echo ok',
          'fallback': [
            <String, Object?>{'harness': NodeTypeId.codex},
          ],
        },
      );
      final terminal = _node(
        type: NodeTypeId.terminal,
        config: const <String, Object?>{
          'additionalInstructions': 'Do X',
          'fallback': [
            <String, Object?>{'harness': NodeTypeId.codex},
          ],
        },
      );

      expect(FallbackConfig.entriesOf(command), isEmpty);
      expect(FallbackConfig.entriesOf(terminal), isEmpty);
    });
  });
}
