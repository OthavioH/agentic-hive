import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/nodes/harness_effort.dart';
import 'package:agentic_hive_shared/src/nodes/node_category.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_field.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_validation.dart';
import 'package:agentic_hive_shared/src/nodes/node_configs.dart';

/// Shared metadata and config contract for a canonical workflow node type.
final class NodeDescriptor {
  /// Creates a node descriptor.
  const new({
    required this.typeId,
    required this.category,
    required this.availableOutputs,
    required this.defaultConfig,
    required this.validateConfig,
    required this.configFields,
    this.requiredOneOf = const <String>[],
  });

  /// Canonical `WorkflowNode.type` string identifier.
  final String typeId;

  /// High-level category for grouping in editors and palettes.
  final NodeCategory category;

  /// Output edge labels this node type can emit.
  final List<String> availableOutputs;

  /// Produces a fresh default `WorkflowNode.config` map for this node type.
  final JsonMap Function() defaultConfig;

  /// Validates a raw `WorkflowNode.config` map and returns field-level issues.
  final List<NodeConfigIssue> Function(JsonMap config) validateConfig;

  /// Config keys this node type accepts, in display order (the single source
  /// for tools and editors).
  final List<NodeConfigField> configFields;

  /// Field names of which at least one must be non-blank; empty when there is
  /// no such rule.
  final List<String> requiredOneOf;
}

/// Static catalog of all 10 canonical [NodeDescriptor]s.
abstract final class NodeDescriptors {
  static const List<String> _standardOutputs = [
    NodeOutput.onSuccess,
    NodeOutput.onFailure,
  ];

  static const NodeConfigField _workingDirectory = NodeConfigField(
    name: 'workingDirectory',
  );
  static const NodeConfigField _timeoutSeconds = NodeConfigField(
    name: 'timeoutSeconds',
    kind: NodeConfigFieldKind.integer,
  );
  static const NodeConfigField _model = NodeConfigField(name: 'model');
  static const NodeConfigField _effort = NodeConfigField(
    name: 'effort',
    values: harnessEffortIds,
  );
  static const NodeConfigField _args = NodeConfigField(
    name: 'args',
    kind: NodeConfigFieldKind.stringList,
  );

  static const List<NodeConfigField> _claudeCodeFields = [
    NodeConfigField(name: 'agentId'),
    NodeConfigField(name: 'additionalInstructions'),
    _workingDirectory,
    _timeoutSeconds,
    _model,
    _effort,
    NodeConfigField(name: 'extraArgs', kind: NodeConfigFieldKind.stringList),
  ];
  static const List<NodeConfigField> _codexFields = _claudeCodeFields;
  static const List<NodeConfigField> _antigravityFields = _claudeCodeFields;
  static const List<NodeConfigField> _geminiCliFields = [
    NodeConfigField(name: 'agentId'),
    NodeConfigField(name: 'additionalInstructions'),
    _workingDirectory,
    _timeoutSeconds,
    _model,
    NodeConfigField(name: 'extraArgs', kind: NodeConfigFieldKind.stringList),
  ];
  static const List<NodeConfigField> _terminalFields = [
    NodeConfigField(name: 'agentId'),
    NodeConfigField(name: 'additionalInstructions'),
    _workingDirectory,
    _timeoutSeconds,
    NodeConfigField(name: 'extraArgs', kind: NodeConfigFieldKind.stringList),
    NodeConfigField(name: 'command'),
    _args,
    NodeConfigField(
      name: 'sendPromptToStdin',
      kind: NodeConfigFieldKind.boolean,
    ),
  ];
  static const List<NodeConfigField> _commandFields = [
    NodeConfigField(name: 'command', required: true),
    _args,
    _workingDirectory,
    _timeoutSeconds,
    NodeConfigField(name: 'env', kind: NodeConfigFieldKind.stringMap),
  ];
  static const List<NodeConfigField> _testsValidatorFields = [
    NodeConfigField(name: 'command', required: true),
    _args,
    _workingDirectory,
    _timeoutSeconds,
  ];

  /// Names of [ChecklistRuleKind] values as serialized in JSON.
  static const Set<String> _checklistRuleKinds = {
    'fileExists',
    'commandSucceeds',
    'outputMatchesRegex',
  };

  static const List<NodeConfigField> _checklistFields = [
    NodeConfigField(
      name: 'rules',
      kind: NodeConfigFieldKind.objectList,
      required: true,
      itemFields: [
        NodeConfigField(name: 'label', required: true),
        NodeConfigField(
          name: 'kind',
          required: true,
          values: _checklistRuleKinds,
        ),
        NodeConfigField(name: 'path'),
        NodeConfigField(name: 'command'),
        NodeConfigField(name: 'workingDirectory'),
        NodeConfigField(name: 'pattern'),
      ],
    ),
  ];
  static const List<NodeConfigField> _reviewFields = [
    NodeConfigField(
      name: 'harnessType',
      required: true,
      values: headlessHarnessTypeIds,
    ),
    NodeConfigField(name: 'agentId'),
    NodeConfigField(name: 'reviewCriteria'),
    _timeoutSeconds,
  ];
  static const List<NodeConfigField> _humanApprovalFields = [
    NodeConfigField(name: 'instructions', required: true),
    NodeConfigField(name: 'title'),
    NodeConfigField(name: 'allowFeedback', kind: NodeConfigFieldKind.boolean),
    NodeConfigField(name: 'proposalNodeId'),
    NodeConfigField(name: 'proposalPath'),
    NodeConfigField(name: 'proposalSchema'),
  ];

  static JsonMap _defaultHarnessConfig() =>
      const HarnessNodeConfig(additionalInstructions: '').toJson();

  static List<NodeConfigIssue> _validateHarnessConfigFor(
    JsonMap raw,
    String typeId,
    List<NodeConfigField> fields,
  ) {
    final issues = validateTypedConfig(
      raw,
      HarnessNodeConfig.fromJson,
      (c) => c.validate(),
    );
    if (issues.any((i) => i.field == 'config')) {
      return issues;
    }
    validateUndeclaredHarnessFields(
      raw,
      typeId: typeId,
      declaredFieldNames: {for (final f in fields) f.name},
      issues: issues,
    );
    return issues;
  }

  static List<NodeConfigIssue> _validateClaudeCodeConfig(JsonMap raw) =>
      _validateHarnessConfigFor(raw, NodeTypeId.claudeCode, _claudeCodeFields);

  static List<NodeConfigIssue> _validateCodexConfig(JsonMap raw) =>
      _validateHarnessConfigFor(raw, NodeTypeId.codex, _codexFields);

  static List<NodeConfigIssue> _validateGeminiCliConfig(JsonMap raw) =>
      _validateHarnessConfigFor(raw, NodeTypeId.geminiCli, _geminiCliFields);

  static List<NodeConfigIssue> _validateAntigravityConfig(JsonMap raw) =>
      _validateHarnessConfigFor(
        raw,
        NodeTypeId.antigravity,
        _antigravityFields,
      );

  static JsonMap _defaultTerminalConfig() =>
      const TerminalHarnessNodeConfig(command: '').toJson();

  static List<NodeConfigIssue> _validateTerminalConfig(JsonMap raw) {
    final issues = validateTypedConfig(
      raw,
      TerminalHarnessNodeConfig.fromJson,
      (c) => c.validate(),
    );
    if (issues.any((i) => i.field == 'config')) {
      return issues;
    }
    validateUndeclaredHarnessFields(
      raw,
      typeId: NodeTypeId.terminal,
      declaredFieldNames: {for (final f in _terminalFields) f.name},
      issues: issues,
    );
    return issues;
  }

  static JsonMap _defaultCommandConfig() =>
      const CommandNodeConfig(command: '').toJson();

  static List<NodeConfigIssue> _validateCommandConfig(JsonMap raw) =>
      validateTypedConfig(raw, CommandNodeConfig.fromJson, (c) => c.validate());

  static JsonMap _defaultTestsValidatorConfig() =>
      const TestsValidatorNodeConfig(command: '').toJson();

  static List<NodeConfigIssue> _validateTestsValidatorConfig(JsonMap raw) =>
      validateTypedConfig(
        raw,
        TestsValidatorNodeConfig.fromJson,
        (c) => c.validate(),
      );

  static JsonMap _defaultChecklistValidatorConfig() =>
      const ChecklistValidatorNodeConfig(rules: <ChecklistRule>[]).toJson();

  static List<NodeConfigIssue> _validateChecklistValidatorConfig(JsonMap raw) =>
      validateTypedConfig(
        raw,
        ChecklistValidatorNodeConfig.fromJson,
        (c) => c.validate(),
      );

  static JsonMap _defaultReviewValidatorConfig() =>
      const ReviewValidatorNodeConfig(
        harnessType: NodeTypeId.claudeCode,
        reviewCriteria: '',
      ).toJson();

  static List<NodeConfigIssue> _validateReviewValidatorConfig(JsonMap raw) =>
      validateTypedConfig(
        raw,
        ReviewValidatorNodeConfig.fromJson,
        (c) => c.validate(),
      );

  static JsonMap _defaultHumanApprovalConfig() =>
      const HumanApprovalNodeConfig(instructions: '').toJson();

  static List<NodeConfigIssue> _validateHumanApprovalConfig(JsonMap raw) =>
      validateTypedConfig(
        raw,
        HumanApprovalNodeConfig.fromJson,
        (c) => c.validate(),
      );

  /// Descriptor for `harness.claude_code`.
  static const NodeDescriptor claudeCode = NodeDescriptor(
    typeId: NodeTypeId.claudeCode,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateClaudeCodeConfig,
    configFields: _claudeCodeFields,
    requiredOneOf: ['agentId', 'additionalInstructions'],
  );

  /// Descriptor for `harness.codex`.
  static const NodeDescriptor codex = NodeDescriptor(
    typeId: NodeTypeId.codex,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateCodexConfig,
    configFields: _codexFields,
    requiredOneOf: ['agentId', 'additionalInstructions'],
  );

  /// Descriptor for `harness.gemini_cli`.
  static const NodeDescriptor geminiCli = NodeDescriptor(
    typeId: NodeTypeId.geminiCli,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateGeminiCliConfig,
    configFields: _geminiCliFields,
    requiredOneOf: ['agentId', 'additionalInstructions'],
  );

  /// Descriptor for `harness.antigravity`.
  static const NodeDescriptor antigravity = NodeDescriptor(
    typeId: NodeTypeId.antigravity,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateAntigravityConfig,
    configFields: _antigravityFields,
    requiredOneOf: ['agentId', 'additionalInstructions'],
  );

  /// Descriptor for `harness.terminal`.
  static const NodeDescriptor terminal = NodeDescriptor(
    typeId: NodeTypeId.terminal,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultTerminalConfig,
    validateConfig: _validateTerminalConfig,
    configFields: _terminalFields,
    requiredOneOf: ['agentId', 'additionalInstructions', 'command'],
  );

  /// Descriptor for `command`.
  static const NodeDescriptor command = NodeDescriptor(
    typeId: NodeTypeId.command,
    category: NodeCategory.execution,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultCommandConfig,
    validateConfig: _validateCommandConfig,
    configFields: _commandFields,
  );

  /// Descriptor for `validator.tests`.
  static const NodeDescriptor testsValidator = NodeDescriptor(
    typeId: NodeTypeId.testsValidator,
    category: NodeCategory.validators,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultTestsValidatorConfig,
    validateConfig: _validateTestsValidatorConfig,
    configFields: _testsValidatorFields,
  );

  /// Descriptor for `validator.checklist`.
  static const NodeDescriptor checklistValidator = NodeDescriptor(
    typeId: NodeTypeId.checklistValidator,
    category: NodeCategory.validators,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultChecklistValidatorConfig,
    validateConfig: _validateChecklistValidatorConfig,
    configFields: _checklistFields,
  );

  /// Descriptor for `validator.review`.
  static const NodeDescriptor reviewValidator = NodeDescriptor(
    typeId: NodeTypeId.reviewValidator,
    category: NodeCategory.validators,
    availableOutputs: [NodeOutput.approved, NodeOutput.changesRequested],
    defaultConfig: _defaultReviewValidatorConfig,
    validateConfig: _validateReviewValidatorConfig,
    configFields: _reviewFields,
    requiredOneOf: ['agentId', 'reviewCriteria'],
  );

  /// Descriptor for `human_approval`.
  static const NodeDescriptor humanApproval = NodeDescriptor(
    typeId: NodeTypeId.humanApproval,
    category: NodeCategory.human,
    availableOutputs: [NodeOutput.approved, NodeOutput.rejected],
    defaultConfig: _defaultHumanApprovalConfig,
    validateConfig: _validateHumanApprovalConfig,
    configFields: _humanApprovalFields,
  );

  /// All 10 canonical node descriptors.
  static const List<NodeDescriptor> all = [
    claudeCode,
    codex,
    geminiCli,
    antigravity,
    terminal,
    command,
    testsValidator,
    checklistValidator,
    reviewValidator,
    humanApproval,
  ];

  /// Lookup map keyed by [NodeDescriptor.typeId].
  static final Map<String, NodeDescriptor> byTypeId = Map.unmodifiable({
    for (final descriptor in all) descriptor.typeId: descriptor,
  });

  /// Returns the descriptor for [typeId], or `null` if unknown.
  static NodeDescriptor? of(String typeId) => byTypeId[typeId];
}
