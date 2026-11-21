import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persists and retrieves [Workflow] definitions.
abstract interface class WorkflowRepository {
  /// Returns all saved workflows ordered by most recently updated first.
  Future<Result<List<Workflow>>> listAll();

  /// Returns the workflow with [id], or `NotFoundFailure` if absent.
  Future<Result<Workflow>> getById(String id);

  /// Persists a new [workflow].
  Future<Result<Workflow>> create(Workflow workflow);

  /// Updates an existing [workflow], or returns `NotFoundFailure` if absent.
  Future<Result<Workflow>> update(Workflow workflow);

  /// Deletes the workflow with [id], or returns `NotFoundFailure` if absent.
  Future<Result<void>> delete(String id);
}
