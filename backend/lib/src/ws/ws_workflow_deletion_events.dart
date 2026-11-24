import 'package:agentic_hive_backend/src/api/workflows/workflow_deletion_mapper.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_backend/src/util/ids.dart';
import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Broadcasts workflow deletion progress and result messages to all clients.
final class WsWorkflowDeletionEvents implements WorkflowDeletionEvents {
  /// Creates a publisher backed by the connection registry.
  new(this._registry, {String Function()? generateId})
    : _generateId = generateId ?? randomId;

  final ConnectionRegistry _registry;
  final String Function() _generateId;

  @override
  void progress(WorkflowDeletionOperation operation) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.workflowDeleteProgress,
      id: _generateId(),
      payload: workflowDeletionStatusOf(operation).toJson(),
    ),
  );

  @override
  void deleted(WorkflowDeletionOperation operation) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.workflowDeleted,
      id: _generateId(),
      payload: workflowDeletedPayloadOf(operation).toJson(),
    ),
  );

  @override
  void failed(WorkflowDeletionOperation operation) => _registry.broadcast(
    WsEnvelope(
      type: WsMessageType.workflowDeleteFailed,
      id: _generateId(),
      payload: workflowDeleteFailedPayloadOf(operation).toJson(),
    ),
  );
}
