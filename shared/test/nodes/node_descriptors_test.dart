import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) => jsonDecode(jsonEncode(json)) as JsonMap;

void main() {
  group('NodeDescriptors catalog', () {
    test('contains all 10 canonical node types across 4 categories', () {
      expect(NodeDescriptors.all, hasLength(10));
      expect(
        NodeDescriptors.byTypeId.keys,
        unorderedEquals([
          NodeTypeId.claudeCode,
          NodeTypeId.codex,
          NodeTypeId.geminiCli,
          NodeTypeId.antigravity,
          NodeTypeId.terminal,
          NodeTypeId.command,
          NodeTypeId.testsValidator,
          NodeTypeId.checklistValidator,
          NodeTypeId.reviewValidator,
          NodeTypeId.humanApproval,
        ]),
      );

      expect(
        NodeDescriptors.all
            .where((d) => d.category == NodeCategory.harnesses)
            .length,
        5,
      );
      expect(
        NodeDescriptors.all
            .where((d) => d.category == NodeCategory.execution)
            .length,
        1,
      );
      expect(
        NodeDescriptors.all
            .where((d) => d.category == NodeCategory.validators)
            .length,
        3,
      );
      expect(
        NodeDescriptors.all
            .where((d) => d.category == NodeCategory.human)
            .length,
        1,
      );
    });

    test('each descriptor exposes non-empty outputs and defaultConfig', () {
      for (final descriptor in NodeDescriptors.all) {
        expect(descriptor.availableOutputs, isNotEmpty);
        final defaults = descriptor.defaultConfig();
        expect(defaults, isA<JsonMap>());
        expect(NodeDescriptors.of(descriptor.typeId), same(descriptor));
      }
      expect(NodeDescriptors.of('nonexistent'), isNull);
    });

    test('descriptor validateConfig catches invalid JSON shape', () {
      final issues = NodeDescriptors.command.validateConfig(const {
        'command': 123,
      });
      expect(issues, hasLength(1));
      expect(issues.first.field, 'config');
    });
  });

  group('Typed NodeConfig models', () {
    test('HarnessNodeConfig round-trips and validates', () {
      const config = HarnessNodeConfig(
        agentId: 'reviewer',
        additionalInstructions: 'Focus on correctness.',
        workingDirectory: 'packages/core',
        timeoutSeconds: 120,
        extraArgs: ['--verbose'],
      );
      final decoded = HarnessNodeConfig.fromJson(_overTheWire(config.toJson()));
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      expect(
        const HarnessNodeConfig(
          workingDirectory: '../escape',
          timeoutSeconds: 0,
        ).validate().map((i) => i.field),
        containsAll(['agentId', 'workingDirectory', 'timeoutSeconds']),
      );
      expect(
        const HarnessNodeConfig(
          additionalInstructions: 'ok',
          workingDirectory: '/abs/path',
        ).validate().map((i) => i.field),
        contains('workingDirectory'),
      );
      expect(
        const HarnessNodeConfig(
          additionalInstructions: 'ok',
          workingDirectory: r'C:\Windows\System32',
        ).validate().map((i) => i.field),
        contains('workingDirectory'),
      );
    });

    test('TerminalHarnessNodeConfig round-trips and validates', () {
      const config = TerminalHarnessNodeConfig(
        command: 'claude',
        args: ['--dangerously-skip-permissions'],
        workingDirectory: 'sub',
        timeoutSeconds: 60,
        sendPromptToStdin: true,
      );
      final decoded = TerminalHarnessNodeConfig.fromJson(
        _overTheWire(config.toJson()),
      );
      expect(decoded, config);
      expect(decoded.sendPromptToStdin, isTrue);
      expect(const TerminalHarnessNodeConfig().sendPromptToStdin, isFalse);
      expect(decoded.validate(), isEmpty);

      expect(
        const TerminalHarnessNodeConfig().validate().map((i) => i.field),
        contains('command'),
      );
    });

    test('CommandNodeConfig round-trips and validates', () {
      const config = CommandNodeConfig(
        command: 'dart',
        args: ['test'],
        workingDirectory: 'backend',
        timeoutSeconds: 30,
        env: {'CI': 'true'},
      );
      final decoded = CommandNodeConfig.fromJson(_overTheWire(config.toJson()));
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      expect(
        const CommandNodeConfig(
          command: '  ',
          workingDirectory: '/root',
          timeoutSeconds: -5,
        ).validate().map((i) => i.field),
        containsAll(['command', 'workingDirectory', 'timeoutSeconds']),
      );
    });

    test('TestsValidatorNodeConfig round-trips and validates', () {
      const config = TestsValidatorNodeConfig(
        command: 'dart',
        args: ['test', '-r', 'expanded'],
        workingDirectory: 'shared',
        timeoutSeconds: 90,
      );
      final decoded = TestsValidatorNodeConfig.fromJson(
        _overTheWire(config.toJson()),
      );
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      expect(
        const TestsValidatorNodeConfig(command: '').validate(),
        isNotEmpty,
      );
    });

    test(
      'ChecklistValidatorNodeConfig round-trips and validates all kinds',
      () {
        const config = ChecklistValidatorNodeConfig(
          rules: [
            ChecklistRule(
              label: 'Readme present',
              kind: ChecklistRuleKind.fileExists,
              path: 'README.md',
            ),
            ChecklistRule(
              label: 'Analyzer passes',
              kind: ChecklistRuleKind.commandSucceeds,
              command: 'dart analyze',
              workingDirectory: 'backend',
            ),
            ChecklistRule(
              label: 'Version printed',
              kind: ChecklistRuleKind.outputMatchesRegex,
              command: 'dart --version',
              pattern: r'Dart SDK version: \d+',
            ),
          ],
        );
        final decoded = ChecklistValidatorNodeConfig.fromJson(
          _overTheWire(config.toJson()),
        );
        expect(decoded, config);
        expect(decoded.validate(), isEmpty);

        expect(
          const ChecklistValidatorNodeConfig(rules: []).validate().first.field,
          'rules',
        );
        expect(
          const ChecklistValidatorNodeConfig(
            rules: [
              ChecklistRule(
                label: '',
                kind: ChecklistRuleKind.fileExists,
                path: '../secret',
              ),
              ChecklistRule(
                label: 'Bad regex',
                kind: ChecklistRuleKind.outputMatchesRegex,
                command: '',
                pattern: '[unclosed',
              ),
            ],
          ).validate().map((i) => i.field),
          containsAll([
            'rules[0].label',
            'rules[0].path',
            'rules[1].command',
            'rules[1].pattern',
          ]),
        );
      },
    );

    test('ReviewValidatorNodeConfig round-trips and validates', () {
      const config = ReviewValidatorNodeConfig(
        harnessType: NodeTypeId.codex,
        reviewCriteria: 'Check error handling.',
        timeoutSeconds: 180,
      );
      final decoded = ReviewValidatorNodeConfig.fromJson(
        _overTheWire(config.toJson()),
      );
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      expect(
        const ReviewValidatorNodeConfig(harnessType: NodeTypeId.terminal)
            .validate()
            .map((i) => i.field),
        containsAll(['harnessType', 'agentId']),
      );
    });

    test('HumanApprovalNodeConfig round-trips and validates', () {
      const config = HumanApprovalNodeConfig(
        title: 'Deploy check',
        instructions: 'Confirm staging looks healthy.',
        allowFeedback: false,
      );
      final decoded = HumanApprovalNodeConfig.fromJson(
        _overTheWire(config.toJson()),
      );
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      expect(
        const HumanApprovalNodeConfig(instructions: '   ').validate(),
        isNotEmpty,
      );
    });
  });
}
