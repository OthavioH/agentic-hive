import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agents_migration_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/agents/agents_migration_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [AgentsMigrationRepository] backed by [AgentsMigrationRemoteDataSource].
final class AgentsMigrationRepositoryImpl implements AgentsMigrationRepository {
  /// Creates an [AgentsMigrationRepositoryImpl].
  const new(this._remoteDataSource);

  final AgentsMigrationRemoteDataSource _remoteDataSource;

  @override
  Future<Result<AgentsMigrationStatus>> getStatus() =>
      _remoteDataSource.getStatus();

  @override
  Future<Result<AgentsMigrationStatus>> dismiss() =>
      _remoteDataSource.dismiss();
}
