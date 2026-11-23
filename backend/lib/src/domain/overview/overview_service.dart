import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/overview/overview_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain service for the operational Overview dashboard.
final class OverviewService {
  /// Creates an overview service backed by [_repository].
  const new(this._repository, {DateTime Function()? now})
    : _now = now ?? _utcNow;

  static DateTime _utcNow() => DateTime.now().toUtc();

  final OverviewRepository _repository;
  final DateTime Function() _now;

  /// Returns the current [OverviewSnapshot].
  Future<Result<OverviewSnapshot>> getOverview() =>
      _repository.getSnapshot(now: _now().toUtc());
}
