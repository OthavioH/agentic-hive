import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/runs/checkpoint_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [CheckpointRepository] backed by the drift [AppDatabase].
final class DriftCheckpointRepository implements CheckpointRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<Checkpoint>> append({
    required String id,
    required String runId,
    required List<String> pendingNodeIds,
    required Map<String, int> attemptsByEdge,
    required int circuitBreakerCount,
    required Map<String, JsonMap> nodeOutputs,
    required DateTime createdAt,
    String? completedNodeId,
    int? sequence,
  }) async {
    try {
      return await _db.transaction(() async {
        final runRow =
            await (_db.selectOnly(_db.runs)
                  ..addColumns([_db.runs.id])
                  ..where(_db.runs.id.equals(runId)))
                .getSingleOrNull();
        if (runRow == null) {
          return FailureResult(NotFoundFailure('Run "$runId" not found.'));
        }

        final maxExpr = _db.checkpoints.sequence.max();
        final maxRow =
            await (_db.selectOnly(_db.checkpoints)
                  ..addColumns([maxExpr])
                  ..where(_db.checkpoints.runId.equals(runId)))
                .getSingle();
        final nextSequence = (maxRow.read(maxExpr) ?? 0) + 1;
        if (sequence != null && sequence != nextSequence) {
          return FailureResult(
            ValidationFailure(
              'Expected checkpoint sequence $nextSequence for run "$runId", '
              'got $sequence.',
            ),
          );
        }

        final utcCreatedAt = createdAt.toUtc();
        await _db
            .into(_db.checkpoints)
            .insert(
              CheckpointsCompanion.insert(
                id: id,
                runId: runId,
                sequence: nextSequence,
                completedNodeId: Value(completedNodeId),
                pendingNodeIdsJson: jsonEncode(pendingNodeIds),
                attemptsByEdgeJson: jsonEncode(attemptsByEdge),
                circuitBreakerCount: circuitBreakerCount,
                nodeOutputsJson: jsonEncode(nodeOutputs),
                createdAt: utcCreatedAt.toIso8601String(),
              ),
            );

        return Success(
          Checkpoint(
            id: id,
            runId: runId,
            sequence: nextSequence,
            completedNodeId: completedNodeId,
            pendingNodeIds: pendingNodeIds,
            attemptsByEdge: attemptsByEdge,
            circuitBreakerCount: circuitBreakerCount,
            nodeOutputs: nodeOutputs,
            createdAt: utcCreatedAt,
          ),
        );
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to append checkpoint "$id" for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<Checkpoint>>> listForRun(String runId) async {
    try {
      final query = _db.select(_db.checkpoints)
        ..where((row) => row.runId.equals(runId))
        ..orderBy([(row) => OrderingTerm.asc(row.sequence)]);
      final rows = await query.get();
      return Success(rows.map(_fromRow).toList());
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list checkpoints for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Checkpoint?>> getLatestForRun(String runId) async {
    try {
      final query = _db.select(_db.checkpoints)
        ..where((row) => row.runId.equals(runId))
        ..orderBy([(row) => OrderingTerm.desc(row.sequence)])
        ..limit(1);
      final row = await query.getSingleOrNull();
      return Success(row == null ? null : _fromRow(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to load latest checkpoint for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  Checkpoint _fromRow(CheckpointRow row) {
    final rawPending = jsonDecode(row.pendingNodeIdsJson) as List<Object?>;
    final rawAttempts = jsonDecode(row.attemptsByEdgeJson) as JsonMap;
    final rawOutputs = jsonDecode(row.nodeOutputsJson) as JsonMap;

    return Checkpoint(
      id: row.id,
      runId: row.runId,
      sequence: row.sequence,
      completedNodeId: row.completedNodeId,
      pendingNodeIds: rawPending.cast<String>(),
      attemptsByEdge: {
        for (final entry in rawAttempts.entries)
          entry.key: (entry.value! as num).toInt(),
      },
      circuitBreakerCount: row.circuitBreakerCount,
      nodeOutputs: {
        for (final entry in rawOutputs.entries)
          entry.key: (entry.value! as Map).cast<String, Object?>(),
      },
      createdAt: DateTime.parse(row.createdAt).toUtc(),
    );
  }
}
