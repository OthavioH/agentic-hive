import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_edit_copy.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/workflow_node_ids.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// One `edit_workflow` operation (spec rule 12).
abstract base class WorkflowEditOperation {
  /// Creates an operation.
  const new();

  /// Name used in the `op` field.
  String get name;

  /// Checks [args] against [copy] and applies them.
  Result<void> apply(JsonMap args, WorkflowEditCopy copy);
}

FailureResult<void> _reason(String reason) =>
    FailureResult(ValidationFailure(reason));

const Success<void> _ok = Success<void>(null);

/// Adds a node to the mutable workflow copy.
final class AddNodeOperation extends WorkflowEditOperation {
  /// Creates an add operation with node descriptor lookup.
  const new(this._describe);

  final NodeDescriptor? Function(String typeId) _describe;

  @override
  String get name => 'add_node';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final id = args['id'];
    if (id is! String) return _reason('id must be a node id.');
    if (!WorkflowNodeIds.isValid(id)) {
      return _reason(
        'id "$id" is not a valid node id: use 1-32 lowercase letters, '
        'digits or _, starting with a letter (for example review or '
        'fix_tests).',
      );
    }
    if (copy.hasNode(id)) return _reason('node "$id" already exists.');
    final type = args['type'];
    if (type is! String || type.trim().isEmpty) {
      return _reason('type must be a non-blank string.');
    }
    final label = args['label'];
    if (label is! String || label.trim().isEmpty) {
      return _reason('label must be a non-blank string.');
    }
    final rawConfig = args['config'];
    if (rawConfig != null && rawConfig is! Map) {
      return _reason('config must be an object.');
    }
    final config = rawConfig == null
        ? <String, Object?>{}
        : Map<String, Object?>.from(rawConfig as Map);
    final rawPosition = args['position'];
    WorkflowPosition? position;
    if (rawPosition != null) {
      if (rawPosition is! Map ||
          rawPosition['x'] is! num ||
          rawPosition['y'] is! num ||
          !(rawPosition['x'] as num).isFinite ||
          !(rawPosition['y'] as num).isFinite) {
        return _reason('position must be {"x": number, "y": number}.');
      }
      position = WorkflowPosition(
        x: (rawPosition['x']! as num).toDouble(),
        y: (rawPosition['y']! as num).toDouble(),
      );
    }
    final trimmedType = type.trim();
    copy.nodes.add(
      WorkflowNode(
        id: id,
        type: trimmedType,
        label: label.trim(),
        position: position ?? const WorkflowPosition(x: 0, y: 0),
        config: {...?_describe(trimmedType)?.defaultConfig(), ...config},
      ),
    );
    copy.tally.nodesAdded++;
    if (position == null) {
      copy.autoPlace.add(id);
      copy.tally.autoPlaced++;
    }
    return _ok;
  }
}

/// Updates a node label, shallow config values and/or headless harness type.
final class UpdateNodeOperation extends WorkflowEditOperation {
  /// Creates an update operation.
  const new();

  @override
  String get name => 'update_node';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final id = args['id'];
    if (id is! String) return _reason('id must be a node id.');
    final index = copy.indexOfNode(id);
    if (index < 0) return _reason('node "$id" does not exist.');
    final hasLabel = args.containsKey('label') && args['label'] != null;
    final hasConfig = args.containsKey('config') && args['config'] != null;
    final hasType = args.containsKey('type') && args['type'] != null;
    if (!hasLabel && !hasConfig && !hasType) {
      return _reason('pass label, config or type.');
    }
    final label = args['label'];
    if (hasLabel && (label is! String || label.trim().isEmpty)) {
      return _reason('label must be a non-blank string.');
    }
    final rawType = args['type'];
    if (hasType && (rawType is! String || rawType.trim().isEmpty)) {
      return _reason('type must be a non-blank string.');
    }
    final rawConfig = args['config'];
    if (hasConfig && rawConfig is! Map) {
      return _reason('config must be an object.');
    }
    final node = copy.nodes[index];
    final newType = hasType ? (rawType! as String).trim() : node.type;
    final changesType = newType != node.type;
    if (changesType && !NodeTypeChange.isAllowed(node.type, newType)) {
      return _reason(
        'cannot change type from ${node.type} to $newType: only the headless '
        'harnesses (${headlessHarnessTypeIds.join(', ')}) can change into one '
        'another; use remove_node and add_node.',
      );
    }
    final merged = <String, Object?>{...node.config};
    if (hasConfig) {
      for (final entry in Map<String, Object?>.from(
        rawConfig! as Map,
      ).entries) {
        if (entry.value == null) {
          merged.remove(entry.key);
        } else {
          merged[entry.key] = entry.value;
        }
      }
    }
    if (changesType) {
      final dropped = NodeTypeChange.droppedFields(merged, newType)
        ..forEach(merged.remove);
      final droppedText = dropped.isEmpty ? 'none' : dropped.join(', ');
      copy.tally.typeChanges.add(
        '$id: ${node.type} -> $newType, dropped config fields: $droppedText',
      );
    }
    copy.nodes[index] = node.copyWith(
      type: newType,
      label: hasLabel ? (label! as String).trim() : node.label,
      config: merged,
    );
    copy.tally.nodesUpdated++;
    return _ok;
  }
}

/// Removes a node and its incident edges.
final class RemoveNodeOperation extends WorkflowEditOperation {
  /// Creates a remove operation.
  const new();

  @override
  String get name => 'remove_node';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final id = args['id'];
    if (id is! String) return _reason('id must be a node id.');
    final index = copy.indexOfNode(id);
    if (index < 0) return _reason('node "$id" does not exist.');
    final removed = copy.edges
        .where((edge) => edge.sourceNodeId == id || edge.targetNodeId == id)
        .length;
    copy.nodes.removeAt(index);
    copy.edges.removeWhere(
      (edge) => edge.sourceNodeId == id || edge.targetNodeId == id,
    );
    if (copy.entryNodeId == id) copy.entryNodeId = null;
    copy.autoPlace.remove(id);
    copy.tally.nodesRemoved++;
    copy.tally.edgesRemoved += removed;
    return _ok;
  }
}

/// Adds an edge between existing nodes.
final class ConnectOperation extends WorkflowEditOperation {
  /// Creates a connect operation with node descriptor lookup.
  const new(this._describe);

  final NodeDescriptor? Function(String typeId) _describe;

  @override
  String get name => 'connect';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final from = args['from'];
    if (from is! String) return _reason('from must be a node id.');
    final to = args['to'];
    if (to is! String) return _reason('to must be a node id.');
    if (!copy.hasNode(from)) {
      return _reason('from "$from" is not a node of the workflow.');
    }
    if (!copy.hasNode(to)) {
      return _reason('to "$to" is not a node of the workflow.');
    }
    final output = args['output'];
    if (output is! String || output.trim().isEmpty) {
      return _reason('output must be a non-blank string.');
    }
    final node = copy.nodes[copy.indexOfNode(from)];
    final descriptor = _describe(node.type);
    if (descriptor != null && !descriptor.availableOutputs.contains(output)) {
      return _reason(
        'output "$output" is not an output of ${node.type} (node "$from"); '
        'use one of: ${descriptor.availableOutputs.join(', ')}.',
      );
    }
    final retries = args['maxRetries'];
    if (retries != null && retries is! int) {
      return _reason('maxRetries must be an integer.');
    }
    copy.edges.add(
      WorkflowEdge(
        id: copy.nextEdgeId(),
        sourceNodeId: from,
        sourceOutput: output,
        targetNodeId: to,
        maxRetries: retries as int?,
      ),
    );
    copy.tally.edgesAdded++;
    return _ok;
  }
}

/// Removes edges between two nodes, optionally matching an output.
final class DisconnectOperation extends WorkflowEditOperation {
  /// Creates a disconnect operation.
  const new();

  @override
  String get name => 'disconnect';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final from = args['from'];
    if (from is! String) return _reason('"from" must be a string.');
    final to = args['to'];
    if (to is! String) return _reason('"to" must be a string.');
    final rawOutput = args['output'];
    if (rawOutput != null && rawOutput is! String) {
      return _reason('output must be a string.');
    }
    final output = rawOutput as String?;
    final removed = copy.edges.where((edge) {
      return edge.sourceNodeId == from &&
          edge.targetNodeId == to &&
          (output == null || edge.sourceOutput == output);
    }).length;
    if (removed == 0) {
      return _reason(
        output == null
            ? 'there is no edge from "$from" to "$to".'
            : 'there is no edge from "$from" to "$to" with output "$output".',
      );
    }
    copy.edges.removeWhere((edge) {
      return edge.sourceNodeId == from &&
          edge.targetNodeId == to &&
          (output == null || edge.sourceOutput == output);
    });
    copy.tally.edgesRemoved += removed;
    return _ok;
  }
}

/// Changes the workflow entry node.
final class SetEntryOperation extends WorkflowEditOperation {
  /// Creates a set-entry operation.
  const new();

  @override
  String get name => 'set_entry';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    final id = args['id'];
    if (id is! String) return _reason('id must be a node id.');
    if (!copy.hasNode(id)) {
      return _reason('node "$id" does not exist.');
    }
    copy.entryNodeId = id;
    copy.tally.entrySet = id;
    return _ok;
  }
}

/// Changes the workflow name and/or description.
final class SetMetaOperation extends WorkflowEditOperation {
  /// Creates a metadata operation.
  const new();

  @override
  String get name => 'set_meta';

  @override
  Result<void> apply(JsonMap args, WorkflowEditCopy copy) {
    if (!args.containsKey('name') && !args.containsKey('description')) {
      return _reason('pass name or description.');
    }
    if (args.containsKey('name')) {
      final name = args['name'];
      if (name is! String || name.trim().isEmpty) {
        return _reason('name must be a non-blank string.');
      }
      copy.name = name.trim();
    }
    if (args.containsKey('description')) {
      final description = args['description'];
      if (description != null && description is! String) {
        return _reason('description must be a string.');
      }
      final trimmed = (description as String?)?.trim();
      copy.description = trimmed == null || trimmed.isEmpty ? null : trimmed;
    }
    copy.tally.metaChanged = true;
    return _ok;
  }
}
