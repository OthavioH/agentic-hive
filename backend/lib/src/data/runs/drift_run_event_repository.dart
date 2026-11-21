import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_event_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [RunEventRepository] backed by the drift [AppDatabase].
final class DriftRunEventRepository implements RunEventRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<RunEvent>> append({
    required String id,
    required String runId,
    required RunEventType type,
    required DateTime createdAt,
    String? nodeId,
    String? edgeId,
    JsonMap payload = const {},
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

        final maxExpr = _db.runEvents.sequence.max();
        final maxRow =
            await (_db.selectOnly(_db.runEvents)
                  ..addColumns([maxExpr])
                  ..where(_db.runEvents.runId.equals(runId)))
                .getSingle();
        final nextSequence = (maxRow.read(maxExpr) ?? 0) + 1;
        if (sequence != null && sequence != nextSequence) {
          return FailureResult(
            ValidationFailure(
              'Expected event sequence $nextSequence for run "$runId", '
              'got $sequence.',
            ),
          );
        }

        final utcCreatedAt = createdAt.toUtc();
        await _db
            .into(_db.runEvents)
            .insert(
              RunEventsCompanion.insert(
                id: id,
                runId: runId,
                sequence: nextSequence,
                type: type.wireName,
                nodeId: Value(nodeId),
                edgeId: Value(edgeId),
                payloadJson: jsonEncode(payload),
                createdAt: utcCreatedAt.toIso8601String(),
              ),
            );

        return Success(
          RunEvent(
            id: id,
            runId: runId,
            sequence: nextSequence,
            type: type,
            nodeId: nodeId,
            edgeId: edgeId,
            payload: payload,
            createdAt: utcCreatedAt,
          ),
        );
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to append event "$id" for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  static const int _defaultLimit = 200;
  static const int _maxLimit = 1000;

  @override
  Future<Result<({List<RunEvent> items, int lastSequence})>> listForRun(
    String runId, {
    int? afterSequence,
    int? limit,
  }) async {
    try {
      final effectiveLimit = (limit ?? _defaultLimit).clamp(1, _maxLimit);
      final query = _db.select(_db.runEvents)
        ..where((row) {
          final matchRun = row.runId.equals(runId);
          if (afterSequence != null) {
            return matchRun & row.sequence.isBiggerThanValue(afterSequence);
          }
          return matchRun;
        })
        ..orderBy([(row) => OrderingTerm.asc(row.sequence)])
        ..limit(effectiveLimit);
      final rows = await query.get();
      final items = rows.map(_fromRow).toList();
      final lastSequence = items.isNotEmpty
          ? items.last.sequence
          : (afterSequence ?? 0);
      return Success((items: items, lastSequence: lastSequence));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list events for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  RunEvent _fromRow(RunEventRow row) {
    final rawPayload = jsonDecode(row.payloadJson) as JsonMap;
    return RunEvent(
      id: row.id,
      runId: row.runId,
      sequence: row.sequence,
      type: RunEventType.fromWireName(row.type),
      nodeId: row.nodeId,
      edgeId: row.edgeId,
      payload: rawPayload,
      createdAt: DateTime.parse(row.createdAt).toUtc(),
    );
  }
}
