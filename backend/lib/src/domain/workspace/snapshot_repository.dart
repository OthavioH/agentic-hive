import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Persistence port for workspace [Snapshot]s belonging to runs.
abstract interface class SnapshotRepository {
  /// Persists a newly captured [snapshot].
  Future<Result<Snapshot>> create(Snapshot snapshot);

  /// Lists all snapshots for [runId] ordered chronologically (`createdAt ASC`).
  Future<Result<List<Snapshot>>> listForRun(String runId);

  /// Fetches a single snapshot [snapshotId] belonging to [runId].
  Future<Result<Snapshot>> getById(String runId, String snapshotId);

  /// Returns the most recent snapshot for [runId], or `null` when none exist.
  Future<Result<Snapshot?>> getLatestForRun(String runId);
}
