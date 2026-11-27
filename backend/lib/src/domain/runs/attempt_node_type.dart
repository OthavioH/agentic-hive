import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Resolves the effective node type id for [nodeId] on [attempt] of [run].
///
/// Starts from the configured node type in [Run.workflowDefinition] and replays
/// `node.fallback` and `node.started` events for [nodeId] in sequence order.
/// Returns `null` if [nodeId] is not in the workflow definition and no
/// fallback event set a type.
String? nodeTypeForAttempt({
  required Run run,
  required List<RunEvent> events,
  required String nodeId,
  required int attempt,
}) {
  String? current;
  for (final node in run.workflowDefinition.nodes) {
    if (node.id == nodeId) {
      current = node.type;
      break;
    }
  }

  final sorted = events.where((e) => e.nodeId == nodeId).toList()
    ..sort((a, b) => a.sequence.compareTo(b.sequence));

  // shortcut: when a resume restarts attempt numbers at 1, earlier lines in
  // the shared attempt file get the newest interpreter; upgrade path is unique
  // attempt numbers across resumes in the engine.
  String? resolved;
  var startedCount = 0;
  for (final event in sorted) {
    if (event.type == RunEventType.nodeFallback) {
      final to = event.payload['to'];
      if (to is Map) {
        final harness = to['harness'];
        if (harness is String && harness.isNotEmpty) {
          current = harness;
        }
      }
    } else if (event.type == RunEventType.nodeStarted) {
      final rawAttempt = event.payload['attempt'];
      final startedAttempt = rawAttempt is int ? rawAttempt : startedCount + 1;
      startedCount++;
      if (startedAttempt == attempt) {
        resolved = current;
      }
    }
  }

  return resolved ?? current;
}
