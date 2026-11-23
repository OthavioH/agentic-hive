import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart';

/// One chat-mode message a node published: its `summary` text.
@immutable
final class RunOutputMessage {
  /// Creates a [RunOutputMessage].
  const new({
    required this.checkpointId,
    required this.nodeId,
    required this.nodeLabel,
    required this.text,
  });

  /// ID of the checkpoint recorded when the node finished.
  final String checkpointId;

  /// ID of the node that published [text].
  final String nodeId;

  /// Display name of the node (its workflow label, or [nodeId] if unknown).
  final String nodeLabel;

  /// Plain summary text the node published.
  final String text;
}

/// Derives the chronological chat messages of a run from its checkpoints.
///
/// Each checkpoint records the node that just finished and its outcome data;
/// the `summary` field of that data is the text published in chat mode.
/// Nodes without a non-blank summary are skipped.
final class BuildRunOutputMessages {
  /// Creates the use case.
  const new();

  /// Builds the messages for [checkpoints] using [nodes] for display names.
  List<RunOutputMessage> call({
    required List<Checkpoint> checkpoints,
    required List<WorkflowNode> nodes,
  }) {
    final labels = <String, String>{
      for (final node in nodes) node.id: node.label,
    };
    final ordered = List<Checkpoint>.of(checkpoints)
      ..sort((a, b) => a.sequence.compareTo(b.sequence));
    final messages = <RunOutputMessage>[];
    for (final checkpoint in ordered) {
      final nodeId = checkpoint.completedNodeId;
      if (nodeId == null) continue;
      final data = checkpoint.nodeOutputs[nodeId]?['data'];
      if (data is! Map<String, Object?>) continue;
      final summary = data['summary'];
      if (summary is! String || summary.trim().isEmpty) continue;
      messages.add(
        RunOutputMessage(
          checkpointId: checkpoint.id,
          nodeId: nodeId,
          nodeLabel: labels[nodeId] ?? nodeId,
          text: summary.trim(),
        ),
      );
    }
    return messages;
  }
}
