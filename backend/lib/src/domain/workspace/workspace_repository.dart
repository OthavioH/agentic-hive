import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for registered [Workspace]s (ADR 0025).
abstract interface class WorkspaceRepository {
  /// Persists a new [workspace].
  ///
  /// Returns `ConflictFailure` when another workspace already has the same
  /// `rootPath`.
  Future<Result<Workspace>> create(Workspace workspace);

  /// Loads a workspace by [id], or returns `NotFoundFailure`.
  ///
  /// The result carries the current `activeRunCount`.
  Future<Result<Workspace>> getById(String id);

  /// Lists every workspace ordered by creation time, then name, each with its
  /// current `activeRunCount`.
  Future<Result<List<Workspace>>> list();

  /// Renames workspace [id] to [name] and stamps [updatedAt].
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  });

  /// Unregisters workspace [id] and deletes the history of its runs.
  ///
  /// Never touches files on disk. Returns `ConflictFailure` while any run of
  /// the workspace is active (`running`, `paused` or `cancelling`), or
  /// `NotFoundFailure` when [id] does not exist.
  Future<Result<void>> delete(String id);
}
