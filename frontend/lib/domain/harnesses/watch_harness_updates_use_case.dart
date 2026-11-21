import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Subscribes to real-time harness status updates from the backend.
final class WatchHarnessUpdatesUseCase {
  /// Creates a [WatchHarnessUpdatesUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Returns a stream of updated [HarnessInfo] records.
  Stream<HarnessInfo> call() => _repository.watchHarnessUpdates();
}
