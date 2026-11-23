import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/db/app_database.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:drift/drift.dart';

/// [WorkspaceRepository] backed by the drift [AppDatabase].
final class DriftWorkspaceRepository implements WorkspaceRepository {
  /// Creates a repository over [_db].
  new(this._db);

  final AppDatabase _db;

  static const List<RunStatus> _activeStatuses = [
    RunStatus.running,
    RunStatus.paused,
    RunStatus.cancelling,
  ];

  @override
  Future<Result<Workspace>> create(Workspace workspace) async {
    try {
      final duplicate =
          await (_db.select(_db.workspaces)
                ..where((row) => row.rootPath.equals(workspace.rootPath)))
              .getSingleOrNull();
      if (duplicate != null) {
        return FailureResult(
          ConflictFailure(
            'A workspace is already registered for folder '
            '"${workspace.rootPath}".',
          ),
        );
      }
      await _db
          .into(_db.workspaces)
          .insert(
            WorkspacesCompanion.insert(
              id: workspace.id,
              name: workspace.name,
              rootPath: workspace.rootPath,
              isGit: workspace.isGit,
              createdAt: workspace.createdAt.toUtc().toIso8601String(),
              updatedAt: workspace.updatedAt.toUtc().toIso8601String(),
            ),
          );
      return Success(workspace.copyWith(activeRunCount: 0));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to create workspace "${workspace.id}".',
          cause: error,
        ),
      );
    }
  }

  @override
  Future<Result<Workspace>> getById(String id) async {
    try {
      final row = await (_db.select(
        _db.workspaces,
      )..where((r) => r.id.equals(id))).getSingleOrNull();
      if (row == null) {
        return FailureResult(NotFoundFailure('Workspace "$id" not found.'));
      }
      final counts = await _activeRunCounts(workspaceId: id);
      return Success(_fromRow(row, counts[id] ?? 0));
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to load workspace "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<List<Workspace>>> list() async {
    try {
      final rows =
          await (_db.select(_db.workspaces)..orderBy([
                (r) => OrderingTerm.asc(r.createdAt),
                (r) => OrderingTerm.asc(r.name),
              ]))
              .get();
      final counts = await _activeRunCounts();
      return Success([
        for (final row in rows) _fromRow(row, counts[row.id] ?? 0),
      ]);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to list workspaces.', cause: error),
      );
    }
  }

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async {
    try {
      final updated =
          await (_db.update(
            _db.workspaces,
          )..where((r) => r.id.equals(id))).write(
            WorkspacesCompanion(
              name: Value(name),
              updatedAt: Value(updatedAt.toUtc().toIso8601String()),
            ),
          );
      if (updated == 0) {
        return FailureResult(NotFoundFailure('Workspace "$id" not found.'));
      }
      return await getById(id);
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to rename workspace "$id".', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> delete(String id) async {
    try {
      return await _db.transaction(() async {
        final existing = await (_db.select(
          _db.workspaces,
        )..where((r) => r.id.equals(id))).getSingleOrNull();
        if (existing == null) {
          return FailureResult(NotFoundFailure('Workspace "$id" not found.'));
        }
        final active = (await _activeRunCounts(workspaceId: id))[id] ?? 0;
        if (active > 0) {
          return FailureResult(
            ConflictFailure(
              'Workspace "$id" has $active active run(s); '
              'wait for them to finish or cancel them first.',
            ),
          );
        }
        await (_db.delete(_db.workspaces)..where((r) => r.id.equals(id))).go();
        return const Success<void>(null);
      });
    } on Object catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to delete workspace "$id".', cause: error),
      );
    }
  }

  Future<Map<String, int>> _activeRunCounts({String? workspaceId}) async {
    final countExpr = _db.runs.id.count();
    final query = _db.selectOnly(_db.runs)
      ..addColumns([_db.runs.workspaceId, countExpr])
      ..where(
        _db.runs.status.isIn([for (final s in _activeStatuses) s.name]) &
            _db.runs.workspaceId.isNotNull(),
      )
      ..groupBy([_db.runs.workspaceId]);
    if (workspaceId != null) {
      query.where(_db.runs.workspaceId.equals(workspaceId));
    }
    final rows = await query.get();
    return {
      for (final row in rows)
        row.read(_db.runs.workspaceId)!: row.read(countExpr) ?? 0,
    };
  }

  Workspace _fromRow(WorkspaceRow row, int activeRunCount) => Workspace(
    id: row.id,
    name: row.name,
    rootPath: row.rootPath,
    isGit: row.isGit,
    createdAt: DateTime.parse(row.createdAt).toUtc(),
    updatedAt: DateTime.parse(row.updatedAt).toUtc(),
    activeRunCount: activeRunCount,
  );
}
