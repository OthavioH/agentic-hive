import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('NodeTypeChange', () {
    test('supportedFields returns descriptor config fields or empty set', () {
      expect(
        NodeTypeChange.supportedFields(NodeTypeId.claudeCode),
        contains('effort'),
      );
      expect(
        NodeTypeChange.supportedFields(NodeTypeId.geminiCli),
        isNot(contains('effort')),
      );
      expect(NodeTypeChange.supportedFields('unknown.type'), isEmpty);
    });

    test('isAllowed allows only distinct headless harness types', () {
      for (final from in headlessHarnessTypeIds) {
        expect(NodeTypeChange.isAllowed(from, from), isFalse);
        for (final to in headlessHarnessTypeIds) {
          if (from != to) {
            expect(NodeTypeChange.isAllowed(from, to), isTrue);
          }
        }
        expect(NodeTypeChange.isAllowed(from, NodeTypeId.terminal), isFalse);
        expect(
          NodeTypeChange.isAllowed(from, NodeTypeId.reviewValidator),
          isFalse,
        );
        expect(NodeTypeChange.isAllowed(from, NodeTypeId.command), isFalse);
        expect(NodeTypeChange.isAllowed(from, 'custom'), isFalse);
      }

      expect(
        NodeTypeChange.isAllowed(NodeTypeId.terminal, NodeTypeId.claudeCode),
        isFalse,
      );
      expect(
        NodeTypeChange.isAllowed(NodeTypeId.reviewValidator, NodeTypeId.codex),
        isFalse,
      );
      expect(
        NodeTypeChange.isAllowed(NodeTypeId.command, NodeTypeId.geminiCli),
        isFalse,
      );
      expect(
        NodeTypeChange.isAllowed('custom', NodeTypeId.antigravity),
        isFalse,
      );
    });

    test('droppedFields returns sorted keys unsupported by target type', () {
      const config = <String, Object?>{
        'agentId': 'a',
        'effort': 'high',
        'model': 'm',
      };
      expect(NodeTypeChange.droppedFields(config, NodeTypeId.geminiCli), [
        'effort',
      ]);
      expect(NodeTypeChange.droppedFields(config, NodeTypeId.codex), isEmpty);
      expect(
        NodeTypeChange.droppedFields(<String, Object?>{
          'old': true,
          'effort': 'low',
          'model': 'm',
        }, NodeTypeId.geminiCli),
        ['effort', 'old'],
      );
    });
  });
}
