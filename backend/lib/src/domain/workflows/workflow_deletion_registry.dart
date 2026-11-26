import 'dart:async';

import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// In-memory registry for recent workflow deletion operations (ADR 0027).
final class WorkflowDeletionRegistry {
  /// Creates an empty registry.
  new() : _operations = {}, _running = {}, _completers = {};

  /// Maximum number of retained operations.
  static const retainedOperations = 50;

  final Map<String, WorkflowDeletionOperation> _operations;
  final Map<String, String> _running;
  final Map<String, Completer<WorkflowDeletionOperation>> _completers;

  /// Returns an operation snapshot by id, or null when unknown or evicted.
  WorkflowDeletionOperation? byId(String operationId) =>
      _operations[operationId];

  /// Returns the running operation for the workflow scope, when present.
  WorkflowDeletionOperation? runningFor(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) {
    final id = _running[_key(workflowId, scope)];
    return id == null ? null : _operations[id];
  }

  /// Starts tracking an operation, throwing if that workflow scope is running.
  WorkflowDeletionOperation start(WorkflowDeletionOperation operation) {
    final key = _key(operation.workflowId, operation.scope);
    if (_running.containsKey(key)) {
      throw StateError('Workflow deletion is already running.');
    }
    _operations[operation.id] = operation;
    _running[key] = operation.id;
    _completers[operation.id] = Completer<WorkflowDeletionOperation>();
    _prune();
    return operation;
  }

  /// Replaces a snapshot and completes listeners when it becomes finished.
  WorkflowDeletionOperation update(
    String operationId,
    WorkflowDeletionOperation Function(WorkflowDeletionOperation current)
    change,
  ) {
    final current = _operations[operationId];
    if (current == null) {
      throw StateError('Unknown workflow deletion operation.');
    }
    final updated = change(current);
    _operations[operationId] = updated;
    if (updated.isFinished) {
      _running.remove(_key(updated.workflowId, updated.scope));
      final completer = _completers[operationId];
      if (completer != null && !completer.isCompleted) {
        completer.complete(updated);
      }
      _prune();
    }
    return updated;
  }

  /// Completes when an operation finishes, or null when the id is unknown.
  Future<WorkflowDeletionOperation>? whenFinished(String operationId) {
    final operation = _operations[operationId];
    if (operation == null) return null;
    if (operation.isFinished) return Future.value(operation);
    return _completers[operationId]?.future;
  }

  String _key(String workflowId, DefinitionScope scope) => switch (scope) {
    GlobalScope() => '\u0000$workflowId',
    WorkspaceScope(:final workspaceId) => '$workspaceId\u0000$workflowId',
  };

  void _prune() {
    while (_operations.length > retainedOperations) {
      final finishedId = _operations.entries
          .where((entry) => entry.value.isFinished)
          .map((entry) => entry.key)
          .firstOrNull;
      if (finishedId == null) return;
      _operations.remove(finishedId);
      _completers.remove(finishedId);
    }
  }
}
