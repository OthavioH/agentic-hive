import 'dart:convert';
import 'dart:math' as math;

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/child_run_port.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/proposal_path.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Executes a child workflow once per item in an upstream list output.
///
/// Known limitations for ticket 130-3:
/// - Cancelling the parent run while children are running does not cascade to
///   children yet (ticket 130-4).
/// - A backend restart mid-fan-out interrupts the parent, and resuming it
///   starts children again (ticket 130-4).
final class FanOutNode extends Node {
  /// Creates a [FanOutNode].
  new({
    required this.childRuns,
    this.pollInterval = const Duration(milliseconds: 500),
  });

  /// Port used to pin the child workflow, start children, and poll status.
  final ChildRunPort childRuns;

  /// Interval between `getRun` polls while waiting for a child to finish.
  final Duration pollInterval;

  static const Set<RunStatus> _finalStatuses = {
    RunStatus.succeeded,
    RunStatus.failed,
    RunStatus.cancelled,
    RunStatus.cancellationUncertain,
  };

  static final RegExp _invalidWorktreeChars = RegExp('[^A-Za-z0-9._-]+');
  static final RegExp _leadingNonAlnum = RegExp('^[^A-Za-z0-9]+');

  @override
  String get typeId => NodeTypeId.fanOut;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final configResult = _validate(context);
    if (configResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final config = configResult.valueOrNull!;

    final itemsResult = _readItems(context, config);
    if (itemsResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final items = itemsResult.valueOrNull!;

    if (items.isEmpty) {
      await _warn(context, 'The item list is empty; no child run was started.');
      return const Success(
        NodeOutcome(
          outputLabel: NodeOutput.onSuccess,
          data: {
            'total': 0,
            'succeeded': 0,
            'failed': 0,
            'children': <Object?>[],
          },
        ),
      );
    }

    final nodeLabel = _nodeLabel(context);
    if (items.length > config.maxItems) {
      return FailureResult(
        ValidationFailure(
          'Fan-out node "$nodeLabel" has ${items.length} items; '
          'the limit is ${config.maxItems}.',
        ),
      );
    }

    final pinResult = await childRuns.pinWorkflow(
      workflowId: config.workflowId,
      workspaceId: context.workspaceId!,
    );
    if (pinResult case FailureResult(:final failure)) {
      return FailureResult(
        ValidationFailure(
          'Child workflow "${config.workflowId}" does not resolve: '
          '${failure.message}',
        ),
      );
    }
    final pinnedWorkflow = pinResult.valueOrNull!;
    if (pinnedWorkflow.nodes.any((n) => n.type == NodeTypeId.fanOut)) {
      return FailureResult(
        ValidationFailure(
          'Child workflow "${pinnedWorkflow.name}" contains a fan-out node; '
          'nested fan-out is not supported.',
        ),
      );
    }

    final infoResult = await childRuns.inspectParentWorkspace(
      runId: context.runId,
    );
    if (infoResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final info = infoResult.valueOrNull!;
    final placement = info.isGit
        ? ChildRunPlacement.worktree
        : ChildRunPlacement.lentFolder;
    if (info.isGit && info.hasUncommittedChanges) {
      await _warn(
        context,
        "The parent's target folder has uncommitted changes; "
        'child worktrees start from the HEAD commit and do not include them.',
      );
    }

    final usedWorktreeNames = <String>{};
    final plans = [
      for (var i = 0; i < items.length; i++)
        _planItem(
          index: i,
          item: items[i],
          config: config,
          nodeLabel: nodeLabel,
          placement: placement,
          usedWorktreeNames: usedWorktreeNames,
        ),
    ];

    final concurrency = placement == ChildRunPlacement.lentFolder
        ? 1
        : config.concurrency;
    final entries = List<Map<String, Object?>?>.filled(plans.length, null);
    var next = 0;
    final workerCount = math.min(concurrency, plans.length);
    final workers = List.generate(workerCount, (_) async {
      while (next < plans.length) {
        final i = next++;
        entries[i] = await _runChild(
          plans[i],
          context: context,
          workflow: pinnedWorkflow,
          placement: placement,
          baseCommit: info.headCommit,
        );
      }
    });
    await Future.wait(workers);

    final children = entries.cast<Map<String, Object?>>();
    final succeeded = children
        .where((c) => c['status'] == RunStatus.succeeded.name)
        .length;
    final failed = children.length - succeeded;
    return Success(
      NodeOutcome(
        outputLabel: failed == 0 ? NodeOutput.onSuccess : NodeOutput.onFailure,
        data: {
          'total': children.length,
          'succeeded': succeeded,
          'failed': failed,
          'children': children,
        },
      ),
    );
  }

  Result<FanOutNodeConfig> _validate(NodeExecutionContext context) {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }
    if (context.workspaceId == null) {
      return const FailureResult(
        ValidationFailure('Fan-out needs a registered workspace.'),
      );
    }
    return Success(FanOutNodeConfig.fromJson(context.config));
  }

  Result<List<Object?>> _readItems(
    NodeExecutionContext context,
    FanOutNodeConfig config,
  ) {
    final nodeOutputs = context.inputs['nodeOutputs'];
    final entry = nodeOutputs is Map ? nodeOutputs[config.itemsNodeId] : null;
    if (entry is! Map) {
      return FailureResult(
        ValidationFailure(
          'Node "${config.itemsNodeId}" has not produced an output.',
        ),
      );
    }
    final path = config.itemsPath.trim();
    final value = ProposalPath.resolve(entry['data'], path);
    if (value == null) {
      return FailureResult(
        ValidationFailure(
          'Items path "$path" is missing in the output of node '
          '"${config.itemsNodeId}".',
        ),
      );
    }
    if (value is! List) {
      return FailureResult(
        ValidationFailure('Items path "$path" is not a list.'),
      );
    }
    return Success(List<Object?>.from(value));
  }

  _ChildPlan _planItem({
    required int index,
    required Object? item,
    required FanOutNodeConfig config,
    required String nodeLabel,
    required ChildRunPlacement placement,
    required Set<String> usedWorktreeNames,
  }) {
    final oneBased = index + 1;
    final name = _resolveChildName(
      item: item,
      nameField: config.nameField,
      defaultName: '$nodeLabel-$oneBased',
    );
    final worktreeName = placement == ChildRunPlacement.worktree
        ? _uniqueWorktreeName(name, oneBased, usedWorktreeNames)
        : null;

    String? input;
    String? error;
    final inputField = config.inputField?.trim() ?? '';
    if (inputField.isNotEmpty) {
      final selected = ProposalPath.resolve(item, inputField);
      if (selected == null) {
        error = 'Item $oneBased has no value at "$inputField".';
      } else {
        input = _formatInput(selected);
      }
    } else {
      input = _formatInput(item);
    }

    Map<String, NodeOverride>? overrides;
    if (error == null) {
      final overridesField = config.overridesField?.trim() ?? '';
      if (overridesField.isNotEmpty) {
        final raw = ProposalPath.resolve(item, overridesField);
        if (raw != null) {
          final parsed = _parseOverrides(raw, oneBased);
          if (parsed case FailureResult(:final failure)) {
            error = failure.message;
          } else {
            overrides = parsed.valueOrNull;
          }
        }
      }
    }

    return _ChildPlan(
      index: index,
      name: name,
      worktreeName: worktreeName,
      input: input,
      overrides: overrides,
      error: error,
    );
  }

  String _resolveChildName({
    required Object? item,
    required String? nameField,
    required String defaultName,
  }) {
    final field = nameField?.trim() ?? '';
    if (field.isEmpty) return defaultName;
    final raw = ProposalPath.resolve(item, field);
    if (raw is String) {
      final trimmed = raw.trim();
      if (trimmed.isNotEmpty) return trimmed;
    } else if (raw is num) {
      return raw.toString();
    }
    return defaultName;
  }

  String _uniqueWorktreeName(
    String childName,
    int oneBasedIndex,
    Set<String> usedLower,
  ) {
    var sanitized = childName
        .replaceAll(_invalidWorktreeChars, '-')
        .replaceFirst(_leadingNonAlnum, '');
    if (sanitized.isEmpty) sanitized = 'item';
    var candidate = sanitized;
    while (!usedLower.add(candidate.toLowerCase())) {
      candidate = '$sanitized-$oneBasedIndex';
    }
    return candidate;
  }

  String _formatInput(Object? value) {
    if (value is String) return value;
    return const JsonEncoder.withIndent('  ').convert(value);
  }

  Result<Map<String, NodeOverride>> _parseOverrides(
    Object raw,
    int oneBasedIndex,
  ) {
    if (raw is! Map) {
      return FailureResult(
        ValidationFailure(
          'Item $oneBasedIndex: invalid overrides: expected a map.',
        ),
      );
    }
    final result = <String, NodeOverride>{};
    for (final entry in raw.entries) {
      final key = entry.key;
      final value = entry.value;
      if (key is! String || value is! Map) {
        return FailureResult(
          ValidationFailure(
            'Item $oneBasedIndex: invalid overrides: '
            'each entry must map a node id to an object.',
          ),
        );
      }
      try {
        result[key] = NodeOverride.fromJson(Map<String, Object?>.from(value));
      } on FormatException catch (error) {
        return FailureResult(
          ValidationFailure(
            'Item $oneBasedIndex: invalid overrides: ${error.message}',
          ),
        );
      }
    }
    return Success(result);
  }

  Future<Map<String, Object?>> _runChild(
    _ChildPlan plan, {
    required NodeExecutionContext context,
    required Workflow workflow,
    required ChildRunPlacement placement,
    required String? baseCommit,
  }) async {
    if (plan.error != null) {
      return _entry(
        index: plan.index,
        name: plan.name,
        status: RunStatus.failed.name,
        error: plan.error,
      );
    }
    try {
      final started = await childRuns.startChildRun(
        ChildRunRequest(
          parentRunId: context.runId,
          parentNodeId: context.nodeId,
          index: plan.index,
          name: plan.name,
          workflow: workflow,
          workspaceId: context.workspaceId!,
          placement: placement,
          worktreeName: plan.worktreeName,
          baseCommit: baseCommit,
          input: plan.input,
          nodeOverrides: plan.overrides,
        ),
      );
      if (started case FailureResult(:final failure)) {
        return _entry(
          index: plan.index,
          name: plan.name,
          status: RunStatus.failed.name,
          error: failure.message,
        );
      }
      final runId = started.valueOrNull!.id;
      final finalRunResult = await _awaitFinal(runId);
      if (finalRunResult case FailureResult(:final failure)) {
        final message = failure is NotFoundFailure
            ? 'Child run was deleted.'
            : failure.message;
        return _entry(
          index: plan.index,
          name: plan.name,
          status: RunStatus.failed.name,
          runId: runId,
          error: message,
        );
      }
      final finalRun = finalRunResult.valueOrNull!;
      final outputResult = await childRuns.finalOutputOf(runId);
      final output = outputResult.valueOrNull;
      final error = finalRun.status == RunStatus.succeeded
          ? null
          : (finalRun.errorMessage ??
                'Child run ended as ${finalRun.status.name}.');
      return _entry(
        index: plan.index,
        name: plan.name,
        status: finalRun.status.name,
        runId: runId,
        output: output,
        error: error,
      );
    } on Object catch (error) {
      return _entry(
        index: plan.index,
        name: plan.name,
        status: RunStatus.failed.name,
        error: '$error',
      );
    }
  }

  Future<Result<Run>> _awaitFinal(String runId) async {
    while (true) {
      final res = await childRuns.getRun(runId);
      if (res case FailureResult(:final failure)) {
        return FailureResult(failure);
      }
      final run = res.valueOrNull!;
      if (_finalStatuses.contains(run.status)) {
        return Success(run);
      }
      await Future<void>.delayed(pollInterval);
    }
  }

  Future<void> _warn(NodeExecutionContext context, String message) =>
      childRuns.recordWarning(
        runId: context.runId,
        nodeId: context.nodeId,
        message: message,
      );

  String _nodeLabel(NodeExecutionContext context) {
    final label = context.nodeLabel?.trim();
    if (label != null && label.isNotEmpty) return label;
    return context.nodeId;
  }

  Map<String, Object?> _entry({
    required int index,
    required String name,
    required String status,
    String? runId,
    Map<String, Object?>? output,
    String? error,
  }) => {
    'index': index,
    'name': name,
    'status': status,
    'runId': runId,
    'output': output,
    'error': error,
  };
}

final class _ChildPlan {
  const new({
    required this.index,
    required this.name,
    this.worktreeName,
    this.input,
    this.overrides,
    this.error,
  });

  final int index;
  final String name;
  final String? worktreeName;
  final String? input;
  final Map<String, NodeOverride>? overrides;
  final String? error;
}
