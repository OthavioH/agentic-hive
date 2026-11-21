import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [SnapshotRepository] backed by the drift [AppDatabase].
final class DriftSnapshotRepository implements SnapshotRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  @override
  Future<Result<Snapshot>> create(Snapshot snapshot) async {
    try {
      await _db
          .into(_db.snapshots)
          .insert(
            SnapshotsCompanion.insert(
              id: snapshot.id,
              runId: snapshot.runId,
              nodeId: Value(snapshot.nodeId),
              commitHash: snapshot.commitHash,
              kind: snapshot.kind.wireName,
              addedCount: snapshot.addedCount,
              modifiedCount: snapshot.modifiedCount,
              deletedCount: snapshot.deletedCount,
              createdAt: snapshot.createdAt.toUtc().toIso8601String(),
            ),
          );
      return Success(snapshot);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to create snapshot "${snapshot.id}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<List<Snapshot>>> listForRun(String runId) async {
    try {
      final query = _db.select(_db.snapshots)
        ..where((row) => row.runId.equals(runId))
        ..orderBy([
          (row) => OrderingTerm.asc(row.createdAt),
          (row) => OrderingTerm.asc(row.id),
        ]);
      final rows = await query.get();
      return Success(rows.map(_fromRow).toList());
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list snapshots for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Snapshot>> getById(String runId, String snapshotId) async {
    try {
      final query = _db.select(_db.snapshots)
        ..where((row) => row.runId.equals(runId) & row.id.equals(snapshotId));
      final row = await query.getSingleOrNull();
      if (row == null) {
        return FailureResult(
          NotFoundFailure('Snapshot "$snapshotId" not found for run "$runId".'),
        );
      }
      return Success(_fromRow(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to load snapshot "$snapshotId" for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Snapshot?>> getLatestForRun(String runId) async {
    try {
      final query = _db.select(_db.snapshots)
        ..where((row) => row.runId.equals(runId))
        ..orderBy([
          (row) => OrderingTerm.desc(row.createdAt),
          (row) => OrderingTerm.desc(row.id),
        ])
        ..limit(1);
      final row = await query.getSingleOrNull();
      return Success(row == null ? null : _fromRow(row));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to load latest snapshot for run "$runId".',
          cause: error,
        ),
      );
    }
  }

  Snapshot _fromRow(SnapshotRow row) => Snapshot(
    id: row.id,
    runId: row.runId,
    nodeId: row.nodeId,
    commitHash: row.commitHash,
    kind: SnapshotKind.fromWireName(row.kind),
    addedCount: row.addedCount,
    modifiedCount: row.modifiedCount,
    deletedCount: row.deletedCount,
    createdAt: DateTime.parse(row.createdAt).toUtc(),
  );
}
