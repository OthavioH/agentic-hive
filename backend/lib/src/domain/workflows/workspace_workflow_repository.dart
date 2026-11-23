import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persists workspace-scoped [Workflow]s as versionable files under a
/// workspace root (ADR 0025).
///
/// Every method takes the workspace `rootPath`; the workflow `id` is the file
/// basename (the slug), so it is stable across external edits.
abstract interface class WorkspaceWorkflowRepository {
  /// Lists the workflows of the workspace at [rootPath], newest first.
  ///
  /// A missing folder yields an empty list. Files that are not valid
  /// workflows are skipped.
  Future<Result<List<Workflow>>> listAll(String rootPath);

  /// Loads workflow [id], or returns `NotFoundFailure`.
  Future<Result<Workflow>> getById(String rootPath, String id);

  /// Writes a new [workflow]; `ConflictFailure` when its file already exists.
  Future<Result<Workflow>> create(String rootPath, Workflow workflow);

  /// Rewrites an existing [workflow], or returns `NotFoundFailure`.
  Future<Result<Workflow>> update(String rootPath, Workflow workflow);

  /// Deletes workflow [id], or returns `NotFoundFailure`.
  Future<Result<void>> delete(String rootPath, String id);
}
