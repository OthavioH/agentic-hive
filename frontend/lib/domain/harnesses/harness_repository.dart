import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository for querying and refreshing detected CLI harnesses.
abstract interface class HarnessRepository {
  /// Fetches the current list of detected harnesses from the backend.
  Future<Result<List<HarnessInfo>>> getHarnesses();

  /// Re-runs detection for all harnesses and returns the updated list.
  Future<Result<List<HarnessInfo>>> refreshAll();

  /// Re-runs detection for a single harness [id] and returns its updated info.
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id);

  /// Installs or updates the Hive MCP server for [id] and returns its updated
  /// info.
  Future<Result<HarnessInfo>> installMcp(HarnessId id);

  /// Broadcast stream of real-time harness status updates from the backend.
  Stream<HarnessInfo> watchHarnessUpdates();
}
