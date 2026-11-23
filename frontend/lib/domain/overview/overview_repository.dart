import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for fetching and observing the Overview dashboard.
abstract interface class OverviewRepository {
  /// Fetches the aggregate operational snapshot (`GET /api/v1/overview`).
  Future<Result<OverviewSnapshot>> getOverview();

  /// Streams live run, node, pause, and reconnect-sync events.
  Stream<OverviewEvent> watchOverviewEvents();
}
