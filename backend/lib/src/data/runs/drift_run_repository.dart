import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [RunRepository] backed by the drift [AppDatabase].
final class DriftRunRepository implements RunRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<Run>> create(Run run) async {
    try {
      await _db
          .into(_db.runs)
          .insert(
            RunsCompanion.insert(
              id: run.id,
              workflowId: Value(run.workflowId),
              workflowName: run.workflowName,
              workflowDefinitionJson: jsonEncode(
                run.workflowDefinition.toJson(),
              ),
              workspacePath: run.workspacePath,
              workspaceId: Value(run.workspaceId),
              status: run.status.name,
              startedAt: run.startedAt.toUtc().toIso8601String(),
              finishedAt: Value(run.finishedAt?.toUtc().toIso8601String()),
              errorMessage: Value(run.errorMessage),
              isolationMode: Value(run.isolationMode.name),
              worktreePath: Value(run.worktreePath),
              worktreeBranch: Value(run.worktreeBranch),
              input: Value(run.input),
              parentRunId: Value(run.parentRunId),
              parentNodeId: Value(run.parentNodeId),
              childIndex: Value(run.childIndex),
              childName: Value(run.childName),
            ),
          );
      return Success(run);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to create run "${run.id}".', cause: error),
      );
    }
  }

  @override
  Future<Result<Run>> getById(String id) async {
    try {
      final query = _db.select(_db.runs)..where((row) => row.id.equals(id));
      final row = await query.getSingleOrNull();
      if (row == null) {
        return FailureResult(NotFoundFailure('Run "$id" not found.'));
      }
      return Success(_fromRow(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to load run "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<({List<RunSummary> items, int total})>> list({
    RunStatus? status,
    String? workflowId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      Expression<bool> filter(Runs tbl) {
        var expr = const Constant(true) as Expression<bool>;
        if (status != null) {
          expr = expr & tbl.status.equals(status.name);
        }
        if (workflowId != null) {
          expr = expr & tbl.workflowId.equals(workflowId);
        }
        return expr;
      }

      final countExpr = _db.runs.id.count();
      final totalRow =
          await (_db.selectOnly(_db.runs)
                ..addColumns([countExpr])
                ..where(filter(_db.runs)))
              .getSingle();
      final total = totalRow.read(countExpr) ?? 0;

      final rowsQuery = _db.select(_db.runs)
        ..where(filter)
        ..orderBy([(row) => OrderingTerm.desc(row.startedAt)])
        ..limit(limit, offset: offset);
      final rows = await rowsQuery.get();

      final checkpointCounts = <String, int>{};
      if (rows.isNotEmpty) {
        final runIds = rows.map((r) => r.id).toList();
        final cpCountExpr = _db.checkpoints.id.count();
        final countRows =
            await (_db.selectOnly(_db.checkpoints)
                  ..addColumns([_db.checkpoints.runId, cpCountExpr])
                  ..where(_db.checkpoints.runId.isIn(runIds))
                  ..groupBy([_db.checkpoints.runId]))
                .get();
        for (final countRow in countRows) {
          final id = countRow.read(_db.checkpoints.runId);
          final cnt = countRow.read(cpCountExpr);
          if (id != null && cnt != null) {
            checkpointCounts[id] = cnt;
          }
        }
      }

      final items = rows
          .map(
            (row) => RunSummary(
              id: row.id,
              workflowId: row.workflowId,
              workflowName: row.workflowName,
              workspaceId: row.workspaceId,
              status: RunStatus.fromName(row.status),
              startedAt: DateTime.parse(row.startedAt).toUtc(),
              finishedAt: row.finishedAt == null
                  ? null
                  : DateTime.parse(row.finishedAt!).toUtc(),
              checkpointCount: checkpointCounts[row.id] ?? 0,
              isolationMode: WorkspaceIsolationMode.fromName(row.isolationMode),
              worktreePath: row.worktreePath,
              worktreeBranch: row.worktreeBranch,
              parentRunId: row.parentRunId,
              parentNodeId: row.parentNodeId,
            ),
          )
          .toList();

      return Success((items: items, total: total));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to list runs.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Run>>> listByStatus(RunStatus status) async {
    try {
      final query = _db.select(_db.runs)
        ..where((row) => row.status.equals(status.name))
        ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]);
      final rows = await query.get();
      return Success(rows.map(_fromRow).toList());
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list runs with status "${status.name}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<int>> countByStatusFinishedSince(
    RunStatus status, {
    required DateTime finishedSince,
  }) async {
    try {
      // Strip trailing 'Z' so 3-digit (.000Z) and 6-digit (.000000Z) UTC
      // ISO-8601 timestamps compare accurately in SQLite.
      final cutoffBare = finishedSince.toUtc().toIso8601String().replaceFirst(
        RegExp(r'Z$'),
        '',
      );
      final trimmedFinishedAt = FunctionCallExpression<String>('rtrim', [
        _db.runs.finishedAt,
        const Variable('Z'),
      ]);
      final countExpr = _db.runs.id.count();
      final row =
          await (_db.selectOnly(_db.runs)
                ..addColumns([countExpr])
                ..where(
                  _db.runs.status.equals(status.name) &
                      _db.runs.finishedAt.isNotNull() &
                      trimmedFinishedAt.isBiggerOrEqualValue(cutoffBare),
                ))
              .getSingle();
      return Success(row.read(countExpr) ?? 0);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to count runs with status "${status.name}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Run>> updateStatus(
    String id, {
    required RunStatus status,
    DateTime? finishedAt,
    String? errorMessage,
    bool clearFinishedAt = false,
    bool clearErrorMessage = false,
  }) async {
    try {
      return await _db.transaction(() async {
        final updated =
            await (_db.update(
              _db.runs,
            )..where((row) => row.id.equals(id))).write(
              RunsCompanion(
                status: Value(status.name),
                finishedAt: clearFinishedAt
                    ? const Value(null)
                    : (finishedAt == null
                          ? const Value.absent()
                          : Value(finishedAt.toUtc().toIso8601String())),
                errorMessage: clearErrorMessage
                    ? const Value(null)
                    : (errorMessage == null
                          ? const Value.absent()
                          : Value(errorMessage)),
              ),
            );
        if (updated == 0) {
          return FailureResult(NotFoundFailure('Run "$id" not found.'));
        }
        final row = await (_db.select(
          _db.runs,
        )..where((r) => r.id.equals(id))).getSingle();
        return Success(_fromRow(row));
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to update run "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<Run>> markInterruptedWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => _transitionWithEvent(
    runId,
    fromStatus: RunStatus.running,
    toStatus: RunStatus.interrupted,
    eventType: RunEventType.runInterrupted,
    eventId: eventId,
    createdAt: createdAt,
    payload: payload,
  );

  @override
  Future<Result<Run>> markCancellationUncertainWithEvent(
    String runId, {
    required String eventId,
    required DateTime createdAt,
    JsonMap payload = const {},
  }) => _transitionWithEvent(
    runId,
    fromStatus: RunStatus.cancelling,
    toStatus: RunStatus.cancellationUncertain,
    eventType: RunEventType.runCancellationUncertain,
    eventId: eventId,
    createdAt: createdAt,
    payload: payload,
  );

  Future<Result<Run>> _transitionWithEvent(
    String runId, {
    required RunStatus fromStatus,
    required RunStatus toStatus,
    required RunEventType eventType,
    required String eventId,
    required DateTime createdAt,
    required JsonMap payload,
  }) async {
    try {
      return await _db.transaction(() async {
        final updated =
            await (_db.update(_db.runs)..where(
                  (row) =>
                      row.id.equals(runId) & row.status.equals(fromStatus.name),
                ))
                .write(RunsCompanion(status: Value(toStatus.name)));
        if (updated == 0) {
          return FailureResult(
            NotFoundFailure(
              'Run "$runId" with status "${fromStatus.name}" not found.',
            ),
          );
        }

        final maxExpr = _db.runEvents.sequence.max();
        final maxRow =
            await (_db.selectOnly(_db.runEvents)
                  ..addColumns([maxExpr])
                  ..where(_db.runEvents.runId.equals(runId)))
                .getSingle();
        final nextSequence = (maxRow.read(maxExpr) ?? 0) + 1;
        final utcCreatedAt = createdAt.toUtc();

        await _db
            .into(_db.runEvents)
            .insert(
              RunEventsCompanion.insert(
                id: eventId,
                runId: runId,
                sequence: nextSequence,
                type: eventType.wireName,
                payloadJson: jsonEncode(payload),
                createdAt: utcCreatedAt.toIso8601String(),
              ),
            );

        final row = await (_db.select(
          _db.runs,
        )..where((r) => r.id.equals(runId))).getSingle();
        return Success(_fromRow(row));
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to transition run "$runId" to "${toStatus.name}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      return await _db.transaction(() async {
        final deleted =
            await (_db.delete(_db.runs)..where(
                  (row) =>
                      row.id.equals(id) &
                      row.status.isNotIn([
                        RunStatus.running.name,
                        RunStatus.paused.name,
                        RunStatus.cancelling.name,
                      ]),
                ))
                .go();
        if (deleted > 0) {
          return const Success<void>(null);
        }

        final existing = await (_db.select(
          _db.runs,
        )..where((row) => row.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return FailureResult(NotFoundFailure('Run "$id" not found.'));
        }
        return FailureResult(
          ConflictFailure(
            'Cannot delete active run "$id" with status "${existing.status}".',
          ),
        );
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to delete run "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<List<String>>> deleteAllOfWorkflow(
    String workflowId, {
    String? workspaceId,
    Set<String> orphanIds = const {},
  }) async {
    try {
      return await _db.transaction(() async {
        final query = _db.select(_db.runs)
          ..where(
            (row) =>
                row.workflowId.equals(workflowId) &
                (workspaceId == null
                    ? const Constant(true)
                    : row.workspaceId.equals(workspaceId)),
          )
          ..orderBy([(row) => OrderingTerm.asc(row.startedAt)]);
        final rows = await query.get();
        final kept = {
          for (final row in rows)
            if (orphanIds.contains(row.id)) row.id,
        };
        final active = <String, RunStatus>{
          for (final row in rows)
            if (!kept.contains(row.id) &&
                RunStatus.fromName(row.status).isActive)
              row.id: RunStatus.fromName(row.status),
        };
        if (active.isNotEmpty) {
          return FailureResult(
            WorkflowHasActiveRunsFailure(
              'Workflow "$workflowId" has ${active.length} active run(s). '
              'Stop them, then delete it again.',
              activeRuns: active,
            ),
          );
        }
        final ids = [
          for (final row in rows)
            if (!kept.contains(row.id)) row.id,
        ];
        if (ids.isNotEmpty) {
          await (_db.delete(_db.runs)..where((row) => row.id.isIn(ids))).go();
        }
        if (kept.isNotEmpty) {
          await (_db.update(_db.runs)..where((row) => row.id.isIn(kept))).write(
            const RunsCompanion(workflowId: Value(null)),
          );
        }
        return Success(ids);
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to delete runs of workflow "$workflowId".',
          cause: error,
        ),
      );
    }
  }

  Run _fromRow(RunRow row) {
    final decodedWorkflow = jsonDecode(row.workflowDefinitionJson) as JsonMap;
    return Run(
      id: row.id,
      workflowId: row.workflowId,
      workflowName: row.workflowName,
      workflowDefinition: Workflow.fromJson(decodedWorkflow),
      workspacePath: row.workspacePath,
      workspaceId: row.workspaceId,
      status: RunStatus.fromName(row.status),
      startedAt: DateTime.parse(row.startedAt).toUtc(),
      finishedAt: row.finishedAt == null
          ? null
          : DateTime.parse(row.finishedAt!).toUtc(),
      errorMessage: row.errorMessage,
      isolationMode: WorkspaceIsolationMode.fromName(row.isolationMode),
      worktreePath: row.worktreePath,
      worktreeBranch: row.worktreeBranch,
      input: row.input,
      parentRunId: row.parentRunId,
      parentNodeId: row.parentNodeId,
      childIndex: row.childIndex,
      childName: row.childName,
    );
  }
}
