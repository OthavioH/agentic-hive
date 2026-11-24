import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Cancels a run and completes only once the cancellation settled: the run's
/// process trees exited (`cancelled`) or exit could not be confirmed
/// (`cancellationUncertain`).
abstract interface class RunCanceller {
  /// Cancels [runId], or retries the cancel of a `cancellationUncertain` run.
  Future<Result<Run>> cancel(String runId);
}
