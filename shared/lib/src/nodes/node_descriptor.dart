import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/nodes/node_category.dart';
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
}

/// Static catalog of all 10 canonical [NodeDescriptor]s.
abstract final class NodeDescriptors {
  static const List<String> _standardOutputs = [
    NodeOutput.onSuccess,
    NodeOutput.onFailure,
  ];

  static JsonMap _defaultHarnessConfig() =>
      const HarnessNodeConfig(additionalInstructions: '').toJson();

  static List<NodeConfigIssue> _validateHarnessConfig(JsonMap raw) =>
      validateTypedConfig(raw, HarnessNodeConfig.fromJson, (c) => c.validate());

  static JsonMap _defaultTerminalConfig() =>
      const TerminalHarnessNodeConfig(command: '').toJson();

  static List<NodeConfigIssue> _validateTerminalConfig(JsonMap raw) =>
      validateTypedConfig(
        raw,
        TerminalHarnessNodeConfig.fromJson,
        (c) => c.validate(),
      );

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
    validateConfig: _validateHarnessConfig,
  );

  /// Descriptor for `harness.codex`.
  static const NodeDescriptor codex = NodeDescriptor(
    typeId: NodeTypeId.codex,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateHarnessConfig,
  );

  /// Descriptor for `harness.gemini_cli`.
  static const NodeDescriptor geminiCli = NodeDescriptor(
    typeId: NodeTypeId.geminiCli,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateHarnessConfig,
  );

  /// Descriptor for `harness.antigravity`.
  static const NodeDescriptor antigravity = NodeDescriptor(
    typeId: NodeTypeId.antigravity,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultHarnessConfig,
    validateConfig: _validateHarnessConfig,
  );

  /// Descriptor for `harness.terminal`.
  static const NodeDescriptor terminal = NodeDescriptor(
    typeId: NodeTypeId.terminal,
    category: NodeCategory.harnesses,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultTerminalConfig,
    validateConfig: _validateTerminalConfig,
  );

  /// Descriptor for `command`.
  static const NodeDescriptor command = NodeDescriptor(
    typeId: NodeTypeId.command,
    category: NodeCategory.execution,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultCommandConfig,
    validateConfig: _validateCommandConfig,
  );

  /// Descriptor for `validator.tests`.
  static const NodeDescriptor testsValidator = NodeDescriptor(
    typeId: NodeTypeId.testsValidator,
    category: NodeCategory.validators,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultTestsValidatorConfig,
    validateConfig: _validateTestsValidatorConfig,
  );

  /// Descriptor for `validator.checklist`.
  static const NodeDescriptor checklistValidator = NodeDescriptor(
    typeId: NodeTypeId.checklistValidator,
    category: NodeCategory.validators,
    availableOutputs: _standardOutputs,
    defaultConfig: _defaultChecklistValidatorConfig,
    validateConfig: _validateChecklistValidatorConfig,
  );

  /// Descriptor for `validator.review`.
  static const NodeDescriptor reviewValidator = NodeDescriptor(
    typeId: NodeTypeId.reviewValidator,
    category: NodeCategory.validators,
    availableOutputs: [NodeOutput.approved, NodeOutput.changesRequested],
    defaultConfig: _defaultReviewValidatorConfig,
    validateConfig: _validateReviewValidatorConfig,
  );

  /// Descriptor for `human_approval`.
  static const NodeDescriptor humanApproval = NodeDescriptor(
    typeId: NodeTypeId.humanApproval,
    category: NodeCategory.human,
    availableOutputs: [NodeOutput.approved, NodeOutput.rejected],
    defaultConfig: _defaultHumanApprovalConfig,
    validateConfig: _validateHumanApprovalConfig,
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
