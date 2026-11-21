import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Abstract base for all automated validator nodes (ADR 0006).
abstract base class ValidatorNode extends Node {
  /// Creates a validator node.
  const new();
}

/// Runs a configured test command and emits `onSuccess` or `onFailure`.
final class TestsValidatorNode extends ValidatorNode {
  /// Creates a tests validator node.
  const new({required this.processRunner});

  /// Process runner port.
  final NodeProcessRunner processRunner;

  @override
  String get typeId => NodeTypeId.testsValidator;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = TestsValidatorNodeConfig.fromJson(context.config);
    final workingDirResult = resolveWorkspacePath(
      context.workspacePath,
      config.workingDirectory,
    );
    if (workingDirResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final workingDirectory = workingDirResult.valueOrNull!;

    final runResult = await processRunner.run(
      ProcessInvocation(
        executable: config.command,
        arguments: config.args,
        workingDirectory: workingDirectory,
        timeout: config.timeoutSeconds != null
            ? Duration(seconds: config.timeoutSeconds!)
            : null,
      ),
      onOutput: context.onOutput,
    );
    if (runResult case FailureResult<ProcessExecutionResult>(:final failure)) {
      return FailureResult(failure);
    }
    final result = runResult.valueOrNull!;

    final passed = !result.timedOut && result.exitCode == 0;
    return Success(
      NodeOutcome(
        outputLabel: passed ? NodeOutput.onSuccess : NodeOutput.onFailure,
        data: <String, Object?>{
          'exitCode': result.exitCode,
          'timedOut': result.timedOut,
          'stdout': result.stdout,
          'stderr': result.stderr,
        },
      ),
    );
  }
}

/// Evaluates deterministic [ChecklistRule]s without an LLM.
final class ChecklistValidatorNode extends ValidatorNode {
  /// Creates a checklist validator node.
  const new({required this.processRunner});

  /// Process runner port used by `commandSucceeds` and `outputMatchesRegex`.
  final NodeProcessRunner processRunner;

  @override
  String get typeId => NodeTypeId.checklistValidator;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = ChecklistValidatorNodeConfig.fromJson(context.config);
    final failedRules = <Map<String, Object?>>[];

    for (final rule in config.rules) {
      final evalResult = await _evaluateRule(rule, context);
      if (evalResult case FailureResult<String?>(:final failure)) {
        return FailureResult(failure);
      }
      final failureReason = evalResult.valueOrNull;
      if (failureReason != null) {
        failedRules.add(<String, Object?>{
          'label': rule.label,
          'kind': rule.kind.name,
          'reason': failureReason,
        });
      }
    }

    final passed = failedRules.isEmpty;
    return Success(
      NodeOutcome(
        outputLabel: passed ? NodeOutput.onSuccess : NodeOutput.onFailure,
        data: <String, Object?>{
          'totalRules': config.rules.length,
          'failedRules': failedRules,
        },
      ),
    );
  }

  Future<Result<String?>> _evaluateRule(
    ChecklistRule rule,
    NodeExecutionContext context,
  ) async {
    switch (rule.kind) {
      case ChecklistRuleKind.fileExists:
        final pathResult = resolveWorkspacePath(
          context.workspacePath,
          rule.path,
          fieldName: 'path',
        );
        if (pathResult case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }
        final file = File(pathResult.valueOrNull!);
        if (!file.existsSync()) {
          return Success('File "${rule.path}" does not exist.');
        }
        return const Success(null);

      case ChecklistRuleKind.commandSucceeds:
      case ChecklistRuleKind.outputMatchesRegex:
        final workingDirResult = resolveWorkspacePath(
          context.workspacePath,
          rule.workingDirectory,
        );
        if (workingDirResult case FailureResult<String>(:final failure)) {
          return FailureResult(failure);
        }

        final parts = rule.command!.trim().split(RegExp(r'\s+'));
        final executable = parts.first;
        final args = parts.skip(1).toList();
        final runResult = await processRunner.run(
          ProcessInvocation(
            executable: executable,
            arguments: args,
            workingDirectory: workingDirResult.valueOrNull!,
          ),
          onOutput: context.onOutput,
        );
        if (runResult case FailureResult<ProcessExecutionResult>(
          :final failure,
        )) {
          return FailureResult(failure);
        }
        final result = runResult.valueOrNull!;
        if (result.timedOut) {
          return const Success('Command timed out.');
        }
        if (result.exitCode != 0) {
          return Success('Command exited with code ${result.exitCode}.');
        }
        if (rule.kind == ChecklistRuleKind.outputMatchesRegex) {
          final regex = RegExp(rule.pattern!);
          final combined = '${result.stdout}\n${result.stderr}';
          if (!regex.hasMatch(combined)) {
            return Success(
              'Command output did not match pattern "${rule.pattern}".',
            );
          }
        }
        return const Success(null);
    }
  }
}

/// Lookup callback returning a [Node] for a `typeId`, avoiding coupling
/// [ReviewValidatorNode] to concrete harness classes or `switch` statements.
typedef NodeFactoryLookup = Result<Node> Function(String typeId);

/// Delegates code/artifact review to a configured headless harness node.
final class ReviewValidatorNode extends ValidatorNode {
  /// Creates a review validator node.
  const new({required this.resolveNode});

  /// Factory lookup (typically bound to `NodeRegistry.create`).
  final NodeFactoryLookup resolveNode;

  @override
  String get typeId => NodeTypeId.reviewValidator;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = ReviewValidatorNodeConfig.fromJson(context.config);
    final nodeResult = resolveNode(config.harnessType);
    if (nodeResult case FailureResult<Node>(:final failure)) {
      return FailureResult(failure);
    }
    final harnessNode = nodeResult.valueOrNull!;

    final criteria = config.reviewCriteria?.trim();
    const reviewPromptSuffix =
        'Review the workspace and report "approved" if all criteria are met, '
        'or "changesRequested" / "failure" with details otherwise.';
    final instructions = <String>[
      if (criteria != null && criteria.isNotEmpty) criteria,
      reviewPromptSuffix,
    ].join('\n\n');

    final delegatedConfig = HarnessNodeConfig(
      agentId: config.agentId,
      additionalInstructions: instructions,
      timeoutSeconds: config.timeoutSeconds,
    ).toJson();

    final executionResult = await harnessNode.execute(
      NodeExecutionContext(
        runId: context.runId,
        nodeId: context.nodeId,
        workspacePath: context.workspacePath,
        config: delegatedConfig,
        inputs: context.inputs,
        resultJsonPath: context.resultJsonPath,
        onOutput: context.onOutput,
      ),
    );
    if (executionResult case FailureResult<NodeOutcome>(:final failure)) {
      return FailureResult(failure);
    }

    final outcome = executionResult.valueOrNull!;
    final contractStatus = outcome.data['contractStatus'];
    final approved =
        outcome.outputLabel == NodeOutput.onSuccess &&
        contractStatus != ResultContractStatus.changesRequested.name;

    return Success(
      NodeOutcome(
        outputLabel: approved
            ? NodeOutput.approved
            : NodeOutput.changesRequested,
        data: outcome.data,
        artifacts: outcome.artifacts,
      ),
    );
  }
}
