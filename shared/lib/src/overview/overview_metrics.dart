import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'overview_metrics.freezed.dart';
part 'overview_metrics.g.dart';

/// Aggregate operational counts for the Overview dashboard.
@freezed
sealed class OverviewMetrics with _$OverviewMetrics {
  /// Creates overview metrics.
  const factory({
    required int activeRunsCount,
    required int activeNodesCount,
    required int pendingPausesCount,
    required int succeededLast24hCount,
    required int failedLast24hCount,
  }) = _OverviewMetrics;

  /// Decodes overview metrics; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$OverviewMetricsFromJson);
}
