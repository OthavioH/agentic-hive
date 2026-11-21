import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Read-model repository that aggregates the [OverviewSnapshot] from runs,
/// run events, pauses, and agents.
abstract interface class OverviewRepository {
  /// Computes the current [OverviewSnapshot] as of [now] (UTC).
  Future<Result<OverviewSnapshot>> getSnapshot({required DateTime now});
}
