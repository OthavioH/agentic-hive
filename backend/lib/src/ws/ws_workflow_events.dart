import 'package:agentic_hive_backend/src/domain/workflows/workflow_events.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Workflow event publisher that broadcasts `workflows.changed` frames.
final class WsWorkflowEvents implements WorkflowEvents {
  /// Creates a publisher that broadcasts through [_registry].
  new(this._registry, {String Function()? generateId})
    : _generateId = generateId ?? randomId;

  final ConnectionRegistry _registry;
  final String Function() _generateId;

  @override
  void workflowChanged(
    WorkflowChangeKind kind,
    String id, {
    String? workspaceId,
    WorkflowSummary? workflow,
  }) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.workflowsChanged,
      id: _generateId(),
      payload: WorkflowsChangedPayload(
        kind: kind,
        id: id,
        workspaceId: workspaceId,
        workflow: workflow,
      ).toJson(),
    ),
  );
}
