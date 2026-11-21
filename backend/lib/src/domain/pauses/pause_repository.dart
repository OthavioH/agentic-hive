import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence contract for durable human-in-the-loop [Pause] records.
abstract interface class PauseRepository {
  /// Persists a new [pause].
  Future<Result<Pause>> create(Pause pause);

  /// Loads a pause by [id], or returns `NotFoundFailure`.
  Future<Result<Pause>> getById(String id);

  /// Lists pauses ordered by `createdAt ASC`, with optional [status] and
  /// [runId] filters and pagination.
  Future<Result<({List<Pause> items, int total})>> list({
    PauseStatus? status,
    String? runId,
    int limit = 50,
    int offset = 0,
  });

  /// Lists all pending pauses for [runId], ordered by `createdAt ASC`.
  Future<Result<List<Pause>>> listPendingForRun(String runId);

  /// Atomically transitions a `pending` pause [id] to [PauseStatus.answered].
  ///
  /// Returns `NotFoundFailure` when [id] does not exist, or `ConflictFailure`
  /// when the pause is no longer `pending`.
  Future<Result<Pause>> markAnswered(
    String id, {
    required DateTime answeredAt,
    String? decision,
    String? feedback,
    String? answer,
  });

  /// Atomically transitions all `pending` pauses for [runId] to
  /// [PauseStatus.cancelled] and returns the newly cancelled pauses.
  Future<Result<List<Pause>>> cancelPendingForRun(
    String runId, {
    required DateTime cancelledAt,
  });
}
