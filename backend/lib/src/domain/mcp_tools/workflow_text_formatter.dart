import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Formats workspaces, workflow summaries and workflows as compact text for
/// MCP tool responses (§4.2, §4.3).
final class WorkflowTextFormatter {
  /// Creates a [WorkflowTextFormatter].
  const new();

  static final RegExp _bareString = RegExp(r'^[A-Za-z0-9_.\-/:]+$');
  static const int _maxValueLength = 80;

  /// Formats the `list_workspaces` response (R7).
  String workspaces({
    required int globalCount,
    required List<({Workspace workspace, int? count})> items,
  }) {
    final lines = <String>[
      'Workspaces (${items.length + 1}):',
      '- global "Global scope": $globalCount workflows',
      for (final item in items) _workspaceLine(item.workspace, item.count),
    ];
    return lines.join('\n');
  }

  /// Formats the `list_workflows` body (R8).
  String summaries(List<WorkflowSummary> items, {required String hint}) {
    if (items.isEmpty) {
      return 'No workflows in this scope.\n$hint';
    }
    final lines = <String>[
      'Workflows (${items.length}):',
      for (final item in items) _summaryLine(item),
      hint,
    ];
    return lines.join('\n');
  }

  String _workspaceLine(Workspace workspace, int? count) {
    final shown = count?.toString() ?? '?';
    return '- ${workspace.id} "${workspace.name}" '
        '${workspace.rootPath}: $shown workflows';
  }

  String _summaryLine(WorkflowSummary item) {
    final flag = item.hasValidationErrors ? ', has validation errors' : '';
    return '- ${item.id} "${item.name}": ${item.nodeCount} nodes, '
        '${item.edgeCount} edges, revision ${item.revision}$flag';
  }

  /// Formats the `get_workflow` compact body (§4.3).
  String workflow(WorkflowResponse r) {
    final wf = r.workflow;
    final lines = <String>[
      'Workflow ${wf.id} "${wf.name}" revision ${r.revision}',
    ];
    final desc = wf.description;
    if (desc != null && desc.trim().isNotEmpty) {
      lines.add('Description: $desc');
    }
    lines
      ..add('Entry: ${wf.entryNodeId}')
      ..add('Nodes (${wf.nodes.length}):');
    for (final node in wf.nodes) {
      lines.add(_formatNode(node));
    }
    lines.add('Edges (${wf.edges.length}):');
    for (final edge in wf.edges) {
      final retry = edge.maxRetries == null
          ? ''
          : ' (maxRetries ${edge.maxRetries})';
      lines.add(
        '- ${edge.sourceNodeId} -${edge.sourceOutput}-> '
        '${edge.targetNodeId}$retry',
      );
    }

    lines.add(validation(r.validation));
    return lines.join('\n');
  }

  /// Formats a validation result as a compact block.
  String validation(WorkflowValidationResult validation) {
    final issues = validation.issues;
    final lines = <String>[];
    if (issues.isEmpty) {
      lines.add('Validation: ok');
    } else {
      final errors = issues
          .where((i) => i.severity == WorkflowValidationSeverity.error)
          .length;
      final warnings = issues
          .where((i) => i.severity == WorkflowValidationSeverity.warning)
          .length;
      lines.add('Validation ($errors errors, $warnings warnings):');
      for (final issue in issues) {
        final nodePart = issue.nodeId == null ? '' : ' node ${issue.nodeId}';
        final edgePart = issue.edgeId == null ? '' : ' edge ${issue.edgeId}';
        lines.add(
          '- ${issue.severity.name} ${issue.code}$nodePart$edgePart: '
          '${issue.message}',
        );
      }
    }
    return lines.join('\n');
  }

  String _formatNode(WorkflowNode node) {
    final defaults = NodeDescriptors.byTypeId[node.type]?.defaultConfig();
    final pairs = <String>[];
    for (final entry in node.config.entries) {
      final value = entry.value;
      if (_isEmpty(value)) {
        continue;
      }
      if (defaults != null &&
          defaults.containsKey(entry.key) &&
          jsonEncode(value) == jsonEncode(defaults[entry.key])) {
        continue;
      }
      pairs.add('${entry.key}=${_value(value)}');
    }
    final suffix = pairs.isEmpty ? '' : ' ${pairs.join(' ')}';
    return '- ${node.id} (${node.type}) "${node.label}"$suffix';
  }

  static bool _isEmpty(Object? v) {
    if (v == null || v == '') {
      return true;
    }
    if (v is List && v.isEmpty) {
      return true;
    }
    if (v is Map && v.isEmpty) {
      return true;
    }
    return false;
  }

  String _value(Object? v) {
    if (v is String) {
      final truncated = _truncate(v);
      return _bareString.hasMatch(truncated)
          ? truncated
          : jsonEncode(truncated);
    }
    if (v is num || v is bool) {
      return v.toString();
    }
    return _truncate(jsonEncode(v));
  }

  static String _truncate(String s) => s.length > _maxValueLength
      ? '${s.substring(0, _maxValueLength - 3)}...'
      : s;
}
