import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [PauseRepository] backed by the drift [AppDatabase].
final class DriftPauseRepository implements PauseRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;
  final StreamController<Pause> _createdController =
      StreamController<Pause>.broadcast();
  final StreamController<Pause> _resolvedController =
      StreamController<Pause>.broadcast();

  /// Broadcast stream of [Pause]s persisted through [create].
  Stream<Pause> get created => _createdController.stream;

  /// Broadcast stream of [Pause]s resolved via [markAnswered] or
  /// [cancelPendingForRun].
  Stream<Pause> get resolved => _resolvedController.stream;

  /// Closes the broadcast streams.
  Future<void> close() async {
    if (!_createdController.isClosed) {
      await _createdController.close();
    }
    if (!_resolvedController.isClosed) {
      await _resolvedController.close();
    }
  }

  @override
  Future<Result<Pause>> create(Pause pause) async {
    try {
      final utcCreatedAt = pause.createdAt.toUtc();
      final normalized = pause.copyWith(
        createdAt: utcCreatedAt,
        answeredAt: pause.answeredAt?.toUtc(),
      );
      await _db
          .into(_db.pauses)
          .insert(
            PausesCompanion.insert(
              id: normalized.id,
              runId: normalized.runId,
              nodeId: normalized.nodeId,
              kind: normalized.kind.name,
              status: normalized.status.name,
              workflowName: normalized.workflowName,
              nodeLabel: normalized.nodeLabel,
              title: Value(normalized.title),
              instructions: Value(normalized.instructions),
              allowFeedback: Value(normalized.allowFeedback),
              question: Value(normalized.question),
              optionsJson: jsonEncode(normalized.options),
              decision: Value(normalized.decision),
              feedback: Value(normalized.feedback),
              answer: Value(normalized.answer),
              createdAt: utcCreatedAt.toIso8601String(),
              answeredAt: Value(normalized.answeredAt?.toIso8601String()),
            ),
          );
      if (normalized.status == PauseStatus.pending &&
          !_createdController.isClosed) {
        _createdController.add(normalized);
      }
      return Success(normalized);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to create pause "${pause.id}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Pause>> getById(String id) async {
    try {
      final row = await (_db.select(
        _db.pauses,
      )..where((p) => p.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return FailureResult(NotFoundFailure('Pause "$id" not found.'));
      }
      return Success(_toDomain(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to load pause "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<({List<Pause> items, int total})>> list({
    PauseStatus? status,
    String? runId,
    int limit = 50,
    int offset = 0,
  }) async {
    try {
      Expression<bool> predicate(Pauses tbl) {
        Expression<bool> expr = const Constant(true);
        if (status != null) {
          expr = expr & tbl.status.equals(status.name);
        }
        if (runId != null) {
          expr = expr & tbl.runId.equals(runId);
        }
        return expr;
      }

      final countExpr = _db.pauses.id.count();
      final totalRow =
          await (_db.selectOnly(_db.pauses)
                ..addColumns([countExpr])
                ..where(predicate(_db.pauses)))
              .getSingle();
      final total = totalRow.read(countExpr) ?? 0;

      final rows =
          await (_db.select(_db.pauses)
                ..where(predicate)
                ..orderBy([(p) => OrderingTerm.asc(p.createdAt)])
                ..limit(limit, offset: offset))
              .get();

      return Success((
        items: rows.map(_toDomain).toList(growable: false),
        total: total,
      ));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to list pauses.', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Pause>>> listPendingForRun(String runId) async {
    try {
      final rows =
          await (_db.select(_db.pauses)
                ..where(
                  (p) =>
                      p.runId.equals(runId) &
                      p.status.equals(PauseStatus.pending.name),
                )
                ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
              .get();
      return Success(rows.map(_toDomain).toList(growable: false));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list pending pauses for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Pause>> markAnswered(
    String id, {
    required DateTime answeredAt,
    String? decision,
    String? feedback,
    String? answer,
  }) async {
    try {
      final result = await _db.transaction(() async {
        final existing = await (_db.select(
          _db.pauses,
        )..where((p) => p.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return FailureResult<Pause>(
            NotFoundFailure('Pause "$id" not found.'),
          );
        }
        if (existing.status != PauseStatus.pending.name) {
          return const FailureResult<Pause>(
            ConflictFailure('This pause was already resolved or cancelled.'),
          );
        }

        final utcAnsweredAt = answeredAt.toUtc();
        await (_db.update(_db.pauses)..where((p) => p.id.equals(id))).write(
          PausesCompanion(
            status: Value(PauseStatus.answered.name),
            decision: Value(decision),
            feedback: Value(feedback),
            answer: Value(answer),
            answeredAt: Value(utcAnsweredAt.toIso8601String()),
          ),
        );

        final updated = await (_db.select(
          _db.pauses,
        )..where((p) => p.id.equals(id))).getSingle();
        return Success<Pause>(_toDomain(updated));
      });

      if (result case Success<Pause>(:final value)) {
        if (!_resolvedController.isClosed) {
          _resolvedController.add(value);
        }
      }
      return result;
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to answer pause "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Pause>>> cancelPendingForRun(
    String runId, {
    required DateTime cancelledAt,
  }) async {
    try {
      final utcCancelledAt = cancelledAt.toUtc();
      final cancelled = await _db.transaction(() async {
        final pendingRows =
            await (_db.select(_db.pauses)
                  ..where(
                    (p) =>
                        p.runId.equals(runId) &
                        p.status.equals(PauseStatus.pending.name),
                  )
                  ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
                .get();
        if (pendingRows.isEmpty) return <Pause>[];

        await (_db.update(_db.pauses)..where(
              (p) =>
                  p.runId.equals(runId) &
                  p.status.equals(PauseStatus.pending.name),
            ))
            .write(
              PausesCompanion(
                status: Value(PauseStatus.cancelled.name),
                answeredAt: Value(utcCancelledAt.toIso8601String()),
              ),
            );

        final ids = pendingRows.map((r) => r.id).toList(growable: false);
        final updatedRows =
            await (_db.select(_db.pauses)
                  ..where((p) => p.id.isIn(ids))
                  ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
                .get();
        return updatedRows.map(_toDomain).toList(growable: false);
      });

      if (!_resolvedController.isClosed) {
        cancelled.forEach(_resolvedController.add);
      }
      return Success(cancelled);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to cancel pending pauses for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<Pause>>> cancelPendingForNode(
    String runId,
    String nodeId, {
    required DateTime cancelledAt,
  }) async {
    try {
      final utcCancelledAt = cancelledAt.toUtc();
      final cancelled = await _db.transaction(() async {
        final pendingRows =
            await (_db.select(_db.pauses)
                  ..where(
                    (p) =>
                        p.runId.equals(runId) &
                        p.nodeId.equals(nodeId) &
                        p.status.equals(PauseStatus.pending.name),
                  )
                  ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
                .get();
        if (pendingRows.isEmpty) return <Pause>[];

        await (_db.update(_db.pauses)..where(
              (p) =>
                  p.runId.equals(runId) &
                  p.nodeId.equals(nodeId) &
                  p.status.equals(PauseStatus.pending.name),
            ))
            .write(
              PausesCompanion(
                status: Value(PauseStatus.cancelled.name),
                answeredAt: Value(utcCancelledAt.toIso8601String()),
              ),
            );

        final ids = pendingRows.map((r) => r.id).toList(growable: false);
        final updatedRows =
            await (_db.select(_db.pauses)
                  ..where((p) => p.id.isIn(ids))
                  ..orderBy([(p) => OrderingTerm.asc(p.createdAt)]))
                .get();
        return updatedRows.map(_toDomain).toList(growable: false);
      });

      if (!_resolvedController.isClosed) {
        cancelled.forEach(_resolvedController.add);
      }
      return Success(cancelled);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to cancel pending pauses for run "$runId" node "$nodeId".',
          cause: error,
        ),
      );
    }
  }

  Pause _toDomain(PauseRow row) {
    final decodedOptions = (jsonDecode(row.optionsJson) as List<Object?>)
        .cast<String>()
        .toList(growable: false);
    return Pause(
      id: row.id,
      runId: row.runId,
      nodeId: row.nodeId,
      kind: PauseKind.fromName(row.kind),
      status: PauseStatus.fromName(row.status),
      workflowName: row.workflowName,
      nodeLabel: row.nodeLabel,
      title: row.title,
      instructions: row.instructions,
      allowFeedback: row.allowFeedback,
      question: row.question,
      options: decodedOptions,
      decision: row.decision,
      feedback: row.feedback,
      answer: row.answer,
      createdAt: DateTime.parse(row.createdAt).toUtc(),
      answeredAt: row.answeredAt == null
          ? null
          : DateTime.parse(row.answeredAt!).toUtc(),
    );
  }
}
