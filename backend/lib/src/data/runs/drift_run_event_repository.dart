import 'dart:async';
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
  final StreamController<RunEvent> _eventController =
      StreamController<RunEvent>.broadcast();

  /// Broadcast stream of [RunEvent]s persisted through [append].
  Stream<RunEvent> get events => _eventController.stream;

  /// Closes the [events] stream.
  Future<void> close() async {
    if (!_eventController.isClosed) {
      await _eventController.close();
    }
  }

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
      final result = await _db.transaction(() async {
        final runRow =
            await (_db.selectOnly(_db.runs)
                  ..addColumns([_db.runs.id])
                  ..where(_db.runs.id.equals(runId)))
                .getSingleOrNull();
        if (runRow == null) {
          return FailureResult<RunEvent>(
            NotFoundFailure('Run "$runId" not found.'),
          );
        }

        final maxExpr = _db.runEvents.sequence.max();
        final maxRow =
            await (_db.selectOnly(_db.runEvents)
                  ..addColumns([maxExpr])
                  ..where(_db.runEvents.runId.equals(runId)))
                .getSingle();
        final nextSequence = (maxRow.read(maxExpr) ?? 0) + 1;
        if (sequence != null && sequence != nextSequence) {
          return FailureResult<RunEvent>(
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

        return Success<RunEvent>(
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
      if (result case Success<RunEvent>(:final value)) {
        if (!_eventController.isClosed) {
          _eventController.add(value);
        }
      }
      return result;
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
  static const int _runIdBatchSize = 500;

  @override
  Future<Result<Map<String, Map<String, DateTime>>>> findExecutingNodesForRuns(
    List<String> runIds,
  ) async {
    if (runIds.isEmpty) {
      return const Success(<String, Map<String, DateTime>>{});
    }
    try {
      final result = <String, Map<String, DateTime>>{};
      final newer = _db.alias(_db.runEvents, 'newer');
      for (var i = 0; i < runIds.length; i += _runIdBatchSize) {
        final end = (i + _runIdBatchSize).clamp(0, runIds.length);
        final batch = runIds.sublist(i, end);
        final hasNewerLifecycleEvent = existsQuery(
          _db.selectOnly(newer)
            ..addColumns([const Constant(1)])
            ..where(
              newer.runId.equalsExp(_db.runEvents.runId) &
                  newer.nodeId.equalsExp(_db.runEvents.nodeId) &
                  newer.sequence.isBiggerThan(_db.runEvents.sequence) &
                  newer.type.isIn([
                    RunEventType.nodeStarted.wireName,
                    RunEventType.nodeCompleted.wireName,
                    RunEventType.nodeFailed.wireName,
                  ]),
            ),
        );
        final rows =
            await (_db.selectOnly(_db.runEvents)
                  ..addColumns([
                    _db.runEvents.runId,
                    _db.runEvents.nodeId,
                    _db.runEvents.createdAt,
                  ])
                  ..where(
                    _db.runEvents.runId.isIn(batch) &
                        _db.runEvents.nodeId.isNotNull() &
                        _db.runEvents.nodeId.equals('').not() &
                        _db.runEvents.type.equals(
                          RunEventType.nodeStarted.wireName,
                        ) &
                        hasNewerLifecycleEvent.not(),
                  )
                  ..orderBy([
                    OrderingTerm.asc(_db.runEvents.runId),
                    OrderingTerm.asc(_db.runEvents.sequence),
                  ]))
                .get();
        for (final row in rows) {
          final runId = row.read(_db.runEvents.runId)!;
          final nodeId = row.read(_db.runEvents.nodeId)!;
          final createdAt = DateTime.parse(row.read(_db.runEvents.createdAt)!)
              .toUtc();
          result.putIfAbsent(runId, () => <String, DateTime>{})[nodeId] =
              createdAt;
        }
      }
      return Success(result);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to find executing nodes for runs.',
          cause: error,
        ),
      );
    }
  }

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
