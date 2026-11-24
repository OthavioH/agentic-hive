import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) => jsonDecode(jsonEncode(json)) as JsonMap;

Object? _sampleValue(NodeConfigField field) => switch (field.kind) {
  NodeConfigFieldKind.string => field.values.isEmpty ? 'x' : field.values.first,
  NodeConfigFieldKind.integer => 1,
  NodeConfigFieldKind.boolean => true,
  NodeConfigFieldKind.stringList => ['x'],
  NodeConfigFieldKind.stringMap => {'k': 'v'},
  NodeConfigFieldKind.objectList => [_sample(field.itemFields)],
};

JsonMap _sample(List<NodeConfigField> fields) => {
  for (final field in fields) field.name: _sampleValue(field),
};

NodeConfigField _field(NodeDescriptor descriptor, String name) =>
    descriptor.configFields.singleWhere((f) => f.name == name);

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

    test('HarnessNodeConfig model and effort round-trip and validate', () {
      const config = HarnessNodeConfig(
        additionalInstructions: 'x',
        model: 'opus',
        effort: 'high',
      );
      final json = config.toJson();
      final decoded = HarnessNodeConfig.fromJson(_overTheWire(json));
      expect(decoded, config);
      expect(decoded.validate(), isEmpty);

      final defaultJson = const HarnessNodeConfig(
        additionalInstructions: 'x',
      ).toJson();
      expect(defaultJson.containsKey('model'), isFalse);
      expect(defaultJson.containsKey('effort'), isFalse);

      expect(
        const HarnessNodeConfig(
          additionalInstructions: 'x',
          effort: 'turbo',
        ).validate().map((i) => i.field),
        contains('effort'),
      );
      expect(
        const HarnessNodeConfig(
          additionalInstructions: 'x',
          model: '  ',
          effort: '',
        ).validate(),
        isEmpty,
      );
      expect(
        const HarnessNodeConfig(
          additionalInstructions: 'x',
          model: '--dangerously-skip-permissions',
        ).validate().map((i) => i.field),
        contains('model'),
      );
    });

    test('T-S6 harnessEffortIds mirrors HarnessEffort', () {
      expect(
        harnessEffortIds,
        HarnessEffort.values.map((e) => e.name).toSet(),
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

  group('Config fields', () {
    // Typed config round-trip per canonical type (drift guard).
    final typedRoundTrip = <String, JsonMap Function(JsonMap)>{
      NodeTypeId.claudeCode: (json) =>
          HarnessNodeConfig.fromJson(json).toJson(),
      NodeTypeId.codex: (json) => HarnessNodeConfig.fromJson(json).toJson(),
      NodeTypeId.geminiCli: (json) => HarnessNodeConfig.fromJson(json).toJson(),
      NodeTypeId.antigravity: (json) =>
          HarnessNodeConfig.fromJson(json).toJson(),
      NodeTypeId.terminal: (json) =>
          TerminalHarnessNodeConfig.fromJson(json).toJson(),
      NodeTypeId.command: (json) => CommandNodeConfig.fromJson(json).toJson(),
      NodeTypeId.testsValidator: (json) =>
          TestsValidatorNodeConfig.fromJson(json).toJson(),
      NodeTypeId.checklistValidator: (json) =>
          ChecklistValidatorNodeConfig.fromJson(json).toJson(),
      NodeTypeId.reviewValidator: (json) =>
          ReviewValidatorNodeConfig.fromJson(json).toJson(),
      NodeTypeId.humanApproval: (json) =>
          HumanApprovalNodeConfig.fromJson(json).toJson(),
    };

    test('T-S1 every descriptor declares config fields', () {
      for (final descriptor in NodeDescriptors.all) {
        expect(descriptor.configFields, isNotEmpty, reason: descriptor.typeId);
      }
    });

    test('T-S2 declared fields match the typed config class', () {
      for (final descriptor in NodeDescriptors.all) {
        final sampleJson = _sample(descriptor.configFields);
        final roundTrip = typedRoundTrip[descriptor.typeId]!(
          _overTheWire(sampleJson),
        );
        expect(
          roundTrip.keys.toSet(),
          descriptor.configFields.map((f) => f.name).toSet(),
          reason: descriptor.typeId,
        );
        if (descriptor.typeId == NodeTypeId.checklistValidator) {
          final rules = roundTrip['rules']! as List<Object?>;
          final firstRule = rules.first! as JsonMap;
          expect(
            firstRule.keys.toSet(),
            _field(descriptor, 'rules').itemFields.map((f) => f.name).toSet(),
          );
        }
        expect(
          descriptor.validateConfig(sampleJson),
          isEmpty,
          reason: descriptor.typeId,
        );
      }
    });

    test('T-S3 required flags match the freezed required parameters', () {
      expect(
        NodeDescriptors.claudeCode.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        isEmpty,
      );
      expect(
        NodeDescriptors.terminal.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        isEmpty,
      );
      expect(
        NodeDescriptors.command.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        ['command'],
      );
      expect(
        NodeDescriptors.testsValidator.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        ['command'],
      );
      final checklist = _field(NodeDescriptors.checklistValidator, 'rules');
      expect(
        NodeDescriptors.checklistValidator.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        ['rules'],
      );
      expect(checklist.itemFields.where((f) => f.required).map((f) => f.name), [
        'label',
        'kind',
      ]);
      expect(
        NodeDescriptors.reviewValidator.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        ['harnessType'],
      );
      expect(
        NodeDescriptors.humanApproval.configFields
            .where((f) => f.required)
            .map((f) => f.name),
        ['instructions'],
      );
    });

    test('T-S4 closed values come from the shared constants', () {
      expect(
        _field(NodeDescriptors.reviewValidator, 'harnessType').values,
        headlessHarnessTypeIds,
      );
      final kind = _field(
        NodeDescriptors.checklistValidator,
        'rules',
      ).itemFields.singleWhere((f) => f.name == 'kind');
      expect(kind.values, ChecklistRuleKind.values.map((k) => k.name).toSet());
    });

    test('T-S5 requiredOneOf mirrors validate()', () {
      expect(NodeDescriptors.claudeCode.requiredOneOf, [
        'agentId',
        'additionalInstructions',
      ]);
      expect(NodeDescriptors.terminal.requiredOneOf, [
        'agentId',
        'additionalInstructions',
        'command',
      ]);
      expect(NodeDescriptors.reviewValidator.requiredOneOf, [
        'agentId',
        'reviewCriteria',
      ]);
      expect(NodeDescriptors.command.requiredOneOf, isEmpty);
      expect(NodeDescriptors.testsValidator.requiredOneOf, isEmpty);
      expect(NodeDescriptors.checklistValidator.requiredOneOf, isEmpty);
      expect(NodeDescriptors.humanApproval.requiredOneOf, isEmpty);
    });

    test('T-S7 harness descriptors declare model and effort per support', () {
      for (final descriptor in [
        NodeDescriptors.claudeCode,
        NodeDescriptors.codex,
        NodeDescriptors.antigravity,
      ]) {
        expect(_field(descriptor, 'model').values, isEmpty);
        expect(_field(descriptor, 'effort').values, harnessEffortIds);
        expect(
          descriptor.configFields.map((f) => f.name).toList(),
          [
            'agentId',
            'additionalInstructions',
            'workingDirectory',
            'timeoutSeconds',
            'model',
            'effort',
            'extraArgs',
          ],
        );
      }

      expect(
        NodeDescriptors.geminiCli.configFields.map((f) => f.name).toList(),
        [
          'agentId',
          'additionalInstructions',
          'workingDirectory',
          'timeoutSeconds',
          'model',
          'extraArgs',
        ],
      );

      final terminalFieldNames = NodeDescriptors.terminal.configFields
          .map((f) => f.name)
          .toSet();
      expect(terminalFieldNames.contains('model'), isFalse);
      expect(terminalFieldNames.contains('effort'), isFalse);
    });

    test('T-S8 unsupported fields are refused', () {
      final geminiIssues = NodeDescriptors.geminiCli.validateConfig(const {
        'additionalInstructions': 'x',
        'effort': 'high',
      });
      expect(geminiIssues, hasLength(1));
      expect(geminiIssues.first.field, 'effort');
      expect(
        geminiIssues.first.message,
        'harness.gemini_cli does not support choosing an effort.',
      );

      final terminalIssues = NodeDescriptors.terminal.validateConfig(const {
        'command': 'x',
        'model': 'opus',
      });
      expect(terminalIssues, hasLength(1));
      expect(terminalIssues.first.field, 'model');
      expect(
        terminalIssues.first.message,
        'harness.terminal does not support choosing a model.',
      );

      expect(
        NodeDescriptors.geminiCli.validateConfig(const {
          'additionalInstructions': 'x',
          'effort': '',
        }),
        isEmpty,
      );
      expect(
        NodeDescriptors.claudeCode.validateConfig(const {
          'additionalInstructions': 'x',
          'model': 'opus',
          'effort': 'max',
        }),
        isEmpty,
      );
    });
  });
}
