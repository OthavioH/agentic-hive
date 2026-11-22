import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/overview/overview_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_event.dart';
import 'package:agentic_hive_frontend/domain/overview/overview_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [OverviewRepository] backed by [OverviewRemoteDataSource] and a live
/// [OverviewEvent] stream from the backend WebSocket.
final class OverviewRepositoryImpl implements OverviewRepository {
  /// Creates an [OverviewRepositoryImpl].
  const new(this._remoteDataSource, this._eventsStream);

  final OverviewRemoteDataSource _remoteDataSource;
  final Stream<OverviewEvent> _eventsStream;

  @override
  Future<Result<OverviewSnapshot>> getOverview() =>
      _remoteDataSource.getOverview();

  @override
  Stream<OverviewEvent> watchOverviewEvents() => _eventsStream;
}
