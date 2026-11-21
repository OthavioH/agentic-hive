import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [WorkflowRepository] backed by the drift [AppDatabase].
final class DriftWorkflowRepository implements WorkflowRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<List<Workflow>>> listAll() async {
    try {
      final query = _db.select(_db.workflows)
        ..orderBy([(row) => OrderingTerm.desc(row.updatedAt)]);
      final rows = await query.get();
      return Success(rows.map(_fromRow).toList());
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to list workflows.', cause: error),
      );
    }
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    try {
      final query = _db.select(_db.workflows)
        ..where((row) => row.id.equals(id));
      final row = await query.getSingleOrNull();
      if (row == null) {
        return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
      }
      return Success(_fromRow(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to load workflow "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    try {
      await _db.into(_db.workflows).insert(_toCompanion(workflow));
      return Success(workflow);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to create workflow "${workflow.id}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    try {
      final updated =
          await (_db.update(
            _db.workflows,
          )..where((row) => row.id.equals(workflow.id))).write(
            WorkflowsCompanion(
              name: Value(workflow.name),
              description: Value(workflow.description),
              definitionJson: Value(_encodeDefinition(workflow)),
              updatedAt: Value(workflow.updatedAt.toUtc().toIso8601String()),
            ),
          );
      if (updated == 0) {
        return FailureResult(
          NotFoundFailure('Workflow "${workflow.id}" not found.'),
        );
      }
      return Success(workflow);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to update workflow "${workflow.id}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      final deleted = await (_db.delete(
        _db.workflows,
      )..where((row) => row.id.equals(id))).go();
      if (deleted == 0) {
        return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
      }
      return const Success<void>(null);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to delete workflow "$id".', cause: error),
      );
    }
  }

  WorkflowsCompanion _toCompanion(Workflow workflow) =>
      WorkflowsCompanion.insert(
        id: workflow.id,
        name: workflow.name,
        description: Value(workflow.description),
        definitionJson: _encodeDefinition(workflow),
        createdAt: workflow.createdAt.toUtc().toIso8601String(),
        updatedAt: workflow.updatedAt.toUtc().toIso8601String(),
      );

  String _encodeDefinition(Workflow workflow) => jsonEncode({
    'nodes': workflow.nodes.map((n) => n.toJson()).toList(),
    'edges': workflow.edges.map((e) => e.toJson()).toList(),
    'entryNodeId': workflow.entryNodeId,
    'schemaVersion': workflow.schemaVersion,
  });

  Workflow _fromRow(WorkflowRow row) {
    final decoded = jsonDecode(row.definitionJson) as JsonMap;
    final rawNodes = decoded['nodes'] as List<Object?>? ?? const [];
    final rawEdges = decoded['edges'] as List<Object?>? ?? const [];
    return Workflow(
      id: row.id,
      name: row.name,
      description: row.description,
      nodes: rawNodes
          .map((item) => WorkflowNode.fromJson(item! as JsonMap))
          .toList(),
      edges: rawEdges
          .map((item) => WorkflowEdge.fromJson(item! as JsonMap))
          .toList(),
      entryNodeId: decoded['entryNodeId'] as String?,
      schemaVersion: decoded['schemaVersion'] as int? ?? 1,
      createdAt: DateTime.parse(row.createdAt).toUtc(),
      updatedAt: DateTime.parse(row.updatedAt).toUtc(),
    );
  }
}
