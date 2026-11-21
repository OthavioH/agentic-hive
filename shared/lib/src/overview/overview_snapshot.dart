import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/overview/active_node_summary.dart';
import 'package:agentic_hive_shared/src/overview/active_run_summary.dart';
import 'package:agentic_hive_shared/src/overview/overview_metrics.dart';
import 'package:agentic_hive_shared/src/overview/pending_pause_summary.dart';
import 'package:agentic_hive_shared/src/runs/run_summary.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overview_snapshot.freezed.dart';
part 'overview_snapshot.g.dart';

/// Aggregate operational snapshot returned by `GET /api/v1/overview`.
@freezed
sealed class OverviewSnapshot with _$OverviewSnapshot {
  /// Creates an overview snapshot.
  const factory({
    required OverviewMetrics metrics,
    required List<ActiveRunSummary> activeRuns,
    required List<ActiveNodeSummary> activeNodes,
    required List<PendingPauseSummary> pendingPauses,
    required List<RunSummary> recentRuns,
  }) = _OverviewSnapshot;

  /// Decodes an overview snapshot; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$OverviewSnapshotFromJson);
}
