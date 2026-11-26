import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/nodes/harness_effort.dart';
import 'package:agentic_hive_shared/src/nodes/node_category.dart';
import 'package:agentic_hive_shared/src/nodes/node_config_validation.dart';
import 'package:agentic_hive_shared/src/nodes/node_type_change.dart';
import 'package:agentic_hive_shared/src/pauses/proposal_schema.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'node_configs.freezed.dart';
part 'node_configs.g.dart';

/// Headless harness types permitted for
/// `ReviewValidatorNodeConfig.harnessType`.
const Set<String> headlessHarnessTypeIds = {
  NodeTypeId.claudeCode,
  NodeTypeId.codex,
  NodeTypeId.geminiCli,
  NodeTypeId.antigravity,
};

/// Configuration for headless harness nodes (`claude_code`, `codex`,
/// `gemini_cli`, `antigravity`).
@freezed
sealed class HarnessNodeConfig with _$HarnessNodeConfig {
  /// Creates a headless harness configuration.
  const factory({
    String? agentId,
    String? additionalInstructions,
    String? workingDirectory,
    int? timeoutSeconds,
    String? model,
    String? effort,
    @Default(<String>[]) List<String> extraArgs,
    @Default(<FallbackEntry>[]) List<FallbackEntry> fallback,
  }) = _HarnessNodeConfig;

  const new _();

  /// Decodes a harness config; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$HarnessNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(agentId) && isBlank(additionalInstructions)) {
      issues.add(
        const NodeConfigIssue(
          field: 'agentId',
          message:
              'At least one of agentId or additionalInstructions must be '
              'non-blank.',
        ),
      );
    }
    validateRelativePath(
      workingDirectory,
      field: 'workingDirectory',
      issues: issues,
    );
    validatePositiveInt(
      timeoutSeconds,
      field: 'timeoutSeconds',
      issues: issues,
    );
    if (!isBlank(effort) && !harnessEffortIds.contains(effort)) {
      issues.add(
        NodeConfigIssue(
          field: 'effort',
          message: 'Must be one of: ${harnessEffortIds.join(', ')}.',
        ),
      );
    }
    if (!isBlank(model) && model!.trim().startsWith('-')) {
      issues.add(
        const NodeConfigIssue(
          field: 'model',
          message: 'Must not start with "-".',
        ),
      );
    }
    for (var i = 0; i < fallback.length; i++) {
      issues.addAll(fallback[i].validate(prefix: 'fallback[$i].'));
    }
    return issues;
  }
}

/// Configuration for `harness.terminal` (PTY fallback harness).
@freezed
sealed class TerminalHarnessNodeConfig with _$TerminalHarnessNodeConfig {
  /// Creates a terminal harness configuration.
  const factory({
    String? agentId,
    String? additionalInstructions,
    String? workingDirectory,
    int? timeoutSeconds,
    @Default(<String>[]) List<String> extraArgs,
    String? command,
    @Default(<String>[]) List<String> args,
    @Default(false) bool sendPromptToStdin,
  }) = _TerminalHarnessNodeConfig;

  const new _();

  /// Decodes a terminal harness config; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$TerminalHarnessNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(agentId) &&
        isBlank(additionalInstructions) &&
        isBlank(command)) {
      issues.add(
        const NodeConfigIssue(
          field: 'command',
          message:
              'At least one of agentId, additionalInstructions, or command '
              'must be non-blank.',
        ),
      );
    }
    validateRelativePath(
      workingDirectory,
      field: 'workingDirectory',
      issues: issues,
    );
    validatePositiveInt(
      timeoutSeconds,
      field: 'timeoutSeconds',
      issues: issues,
    );
    return issues;
  }
}

/// Configuration for the `command` execution node.
@freezed
sealed class CommandNodeConfig with _$CommandNodeConfig {
  /// Creates a command node configuration.
  const factory({
    required String command,
    @Default(<String>[]) List<String> args,
    String? workingDirectory,
    int? timeoutSeconds,
    @Default(<String, String>{}) Map<String, String> env,
  }) = _CommandNodeConfig;

  const new _();

  /// Decodes a command config; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$CommandNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(command)) {
      issues.add(
        const NodeConfigIssue(field: 'command', message: 'Must not be blank.'),
      );
    }
    validateRelativePath(
      workingDirectory,
      field: 'workingDirectory',
      issues: issues,
    );
    validatePositiveInt(
      timeoutSeconds,
      field: 'timeoutSeconds',
      issues: issues,
    );
    return issues;
  }
}

/// Configuration for `validator.tests`.
@freezed
sealed class TestsValidatorNodeConfig with _$TestsValidatorNodeConfig {
  /// Creates a tests validator configuration.
  const factory({
    required String command,
    @Default(<String>[]) List<String> args,
    String? workingDirectory,
    int? timeoutSeconds,
  }) = _TestsValidatorNodeConfig;

  const new _();

  /// Decodes a tests validator config; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$TestsValidatorNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(command)) {
      issues.add(
        const NodeConfigIssue(field: 'command', message: 'Must not be blank.'),
      );
    }
    validateRelativePath(
      workingDirectory,
      field: 'workingDirectory',
      issues: issues,
    );
    validatePositiveInt(
      timeoutSeconds,
      field: 'timeoutSeconds',
      issues: issues,
    );
    return issues;
  }
}

/// One **Fallback entry** in [HarnessNodeConfig.fallback].
@freezed
sealed class FallbackEntry with _$FallbackEntry {
  /// Creates a fallback entry.
  const factory({required String harness, String? model, String? effort}) =
      _FallbackEntry;

  const new _();

  /// Decodes a fallback entry; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$FallbackEntryFromJson);

  /// Validates this entry, prefixing field names with `fallback[index].` when
  /// [prefix] is provided.
  List<NodeConfigIssue> validate({String prefix = ''}) {
    final issues = <NodeConfigIssue>[];
    final validHarness = headlessHarnessTypeIds.contains(harness);
    if (!validHarness) {
      issues.add(
        NodeConfigIssue(
          field: '${prefix}harness',
          message:
              'Must be one of the headless harness types: '
              '${headlessHarnessTypeIds.join(', ')}.',
        ),
      );
    }
    if (!isBlank(model) && model!.trim().startsWith('-')) {
      issues.add(
        NodeConfigIssue(
          field: '${prefix}model',
          message: 'Must not start with "-".',
        ),
      );
    }
    if (!isBlank(effort)) {
      if (!harnessEffortIds.contains(effort)) {
        issues.add(
          NodeConfigIssue(
            field: '${prefix}effort',
            message: 'Must be one of: ${harnessEffortIds.join(', ')}.',
          ),
        );
      } else if (validHarness &&
          !NodeTypeChange.supportedFields(harness).contains('effort')) {
        issues.add(
          NodeConfigIssue(
            field: '${prefix}effort',
            message: '$harness does not support choosing an effort.',
          ),
        );
      }
    }
    return issues;
  }
}

/// Deterministic check kind for [ChecklistRule].
enum ChecklistRuleKind {
  /// Verifies that a relative [ChecklistRule.path] exists in the workspace.
  fileExists,

  /// Verifies that [ChecklistRule.command] exits with code 0.
  commandSucceeds,

  /// Verifies that [ChecklistRule.command] exits with code 0 and its output
  /// matches [ChecklistRule.pattern].
  outputMatchesRegex,
}

/// One deterministic rule inside a [ChecklistValidatorNodeConfig].
@freezed
sealed class ChecklistRule with _$ChecklistRule {
  /// Creates a checklist rule.
  const factory({
    required String label,
    required ChecklistRuleKind kind,
    String? path,
    String? command,
    String? workingDirectory,
    String? pattern,
  }) = _ChecklistRule;

  const new _();

  /// Decodes a checklist rule; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$ChecklistRuleFromJson);

  /// Validates this rule, prefixing field names with `rules[index].` when
  /// [prefix] is provided.
  List<NodeConfigIssue> validate({String prefix = ''}) {
    final issues = <NodeConfigIssue>[];
    if (isBlank(label)) {
      issues.add(
        NodeConfigIssue(field: '${prefix}label', message: 'Must not be blank.'),
      );
    }

    switch (kind) {
      case ChecklistRuleKind.fileExists:
        validateRelativePath(
          path,
          field: '${prefix}path',
          issues: issues,
          required: true,
        );
      case ChecklistRuleKind.commandSucceeds:
        if (isBlank(command)) {
          issues.add(
            NodeConfigIssue(
              field: '${prefix}command',
              message: 'Must not be blank for commandSucceeds.',
            ),
          );
        }
        validateRelativePath(
          workingDirectory,
          field: '${prefix}workingDirectory',
          issues: issues,
        );
      case ChecklistRuleKind.outputMatchesRegex:
        if (isBlank(command)) {
          issues.add(
            NodeConfigIssue(
              field: '${prefix}command',
              message: 'Must not be blank for outputMatchesRegex.',
            ),
          );
        }
        validateRelativePath(
          workingDirectory,
          field: '${prefix}workingDirectory',
          issues: issues,
        );
        final rawPattern = pattern;
        if (rawPattern == null || rawPattern.isEmpty) {
          issues.add(
            NodeConfigIssue(
              field: '${prefix}pattern',
              message: 'Must not be empty for outputMatchesRegex.',
            ),
          );
        } else {
          try {
            RegExp(rawPattern);
          } on FormatException catch (e) {
            issues.add(
              NodeConfigIssue(
                field: '${prefix}pattern',
                message: 'Invalid RegExp: ${e.message}',
              ),
            );
          }
        }
    }

    return issues;
  }
}

/// Configuration for `validator.checklist`.
@freezed
sealed class ChecklistValidatorNodeConfig with _$ChecklistValidatorNodeConfig {
  /// Creates a checklist validator configuration.
  const factory({required List<ChecklistRule> rules}) =
      _ChecklistValidatorNodeConfig;

  const new _();

  /// Decodes a checklist validator config; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ChecklistValidatorNodeConfigFromJson);

  /// Validates all fields and rules of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (rules.isEmpty) {
      issues.add(
        const NodeConfigIssue(
          field: 'rules',
          message: 'Must contain at least one checklist rule.',
        ),
      );
      return issues;
    }

    for (var i = 0; i < rules.length; i++) {
      issues.addAll(rules[i].validate(prefix: 'rules[$i].'));
    }
    return issues;
  }
}

/// Configuration for `validator.review`.
@freezed
sealed class ReviewValidatorNodeConfig with _$ReviewValidatorNodeConfig {
  /// Creates a review validator configuration.
  const factory({
    required String harnessType,
    String? agentId,
    String? reviewCriteria,
    int? timeoutSeconds,
  }) = _ReviewValidatorNodeConfig;

  const new _();

  /// Decodes a review validator config; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$ReviewValidatorNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (!headlessHarnessTypeIds.contains(harnessType)) {
      issues.add(
        NodeConfigIssue(
          field: 'harnessType',
          message:
              'Must be one of the headless harness types: '
              '${headlessHarnessTypeIds.join(', ')}.',
        ),
      );
    }
    if (isBlank(agentId) && isBlank(reviewCriteria)) {
      issues.add(
        const NodeConfigIssue(
          field: 'agentId',
          message:
              'At least one of agentId or reviewCriteria must be non-blank.',
        ),
      );
    }
    validatePositiveInt(
      timeoutSeconds,
      field: 'timeoutSeconds',
      issues: issues,
    );
    return issues;
  }
}

/// Configuration for `human_approval`.
@freezed
sealed class HumanApprovalNodeConfig with _$HumanApprovalNodeConfig {
  /// Creates a human approval node configuration.
  const factory({
    required String instructions,
    String? title,
    @Default(true) bool allowFeedback,
    String? proposalNodeId,
    String? proposalPath,
    String? proposalSchema,
  }) = _HumanApprovalNodeConfig;

  const new _();

  /// Decodes a human approval config; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$HumanApprovalNodeConfigFromJson);

  /// Validates all fields of this configuration.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(instructions)) {
      issues.add(
        const NodeConfigIssue(
          field: 'instructions',
          message: 'Must not be blank.',
        ),
      );
    }
    final hasNodeId = !isBlank(proposalNodeId);
    final hasPath = !isBlank(proposalPath);
    final hasSchema = !isBlank(proposalSchema);

    if (hasNodeId && !hasPath) {
      issues.add(
        const NodeConfigIssue(
          field: 'proposalPath',
          message: 'Must be set together with proposalNodeId.',
        ),
      );
    } else if (!hasNodeId && hasPath) {
      issues.add(
        const NodeConfigIssue(
          field: 'proposalNodeId',
          message: 'Must be set together with proposalPath.',
        ),
      );
    }

    if (hasPath) {
      final path = proposalPath!.trim();
      if (path.split('.').any((s) => s.isEmpty)) {
        issues.add(
          const NodeConfigIssue(
            field: 'proposalPath',
            message: 'Must be a dot path with no empty segment.',
          ),
        );
      }
    }

    if (hasSchema && !hasNodeId) {
      issues.add(
        const NodeConfigIssue(
          field: 'proposalSchema',
          message: 'Requires proposalNodeId.',
        ),
      );
    } else if (hasSchema) {
      for (final msg in ProposalSchema.checkSchema(proposalSchema!.trim())) {
        issues.add(NodeConfigIssue(field: 'proposalSchema', message: msg));
      }
    }
    return issues;
  }
}

/// Default simultaneous children of a fan-out node.
const int fanOutDefaultConcurrency = 2;

/// Default maximum number of items of a fan-out node.
const int fanOutDefaultMaxItems = 20;

/// Typed configuration for `fan_out` nodes.
@freezed
sealed class FanOutNodeConfig with _$FanOutNodeConfig {
  /// Creates a fan-out node configuration.
  const factory({
    required String workflowId,
    required String itemsNodeId,
    required String itemsPath,
    String? inputField,
    String? overridesField,
    String? nameField,
    @Default(fanOutDefaultConcurrency) int concurrency,
    @Default(fanOutDefaultMaxItems) int maxItems,
  }) = _FanOutNodeConfig;

  const new _();

  /// Decodes a [FanOutNodeConfig] from JSON.
  factory fromJson(JsonMap json) => parseJson(json, _$FanOutNodeConfigFromJson);

  /// Validates the configuration and returns any field-level issues.
  List<NodeConfigIssue> validate() {
    final issues = <NodeConfigIssue>[];
    if (isBlank(workflowId)) {
      issues.add(
        const NodeConfigIssue(
          field: 'workflowId',
          message: 'Must not be blank.',
        ),
      );
    }
    if (isBlank(itemsNodeId)) {
      issues.add(
        const NodeConfigIssue(
          field: 'itemsNodeId',
          message: 'Must not be blank.',
        ),
      );
    }
    if (isBlank(itemsPath)) {
      issues.add(
        const NodeConfigIssue(
          field: 'itemsPath',
          message: 'Must not be blank.',
        ),
      );
    } else {
      validateDotPath(itemsPath, field: 'itemsPath', issues: issues);
    }
    validateDotPath(inputField, field: 'inputField', issues: issues);
    validateDotPath(overridesField, field: 'overridesField', issues: issues);
    validateDotPath(nameField, field: 'nameField', issues: issues);
    validatePositiveInt(concurrency, field: 'concurrency', issues: issues);
    validatePositiveInt(maxItems, field: 'maxItems', issues: issues);
    return issues;
  }
}
