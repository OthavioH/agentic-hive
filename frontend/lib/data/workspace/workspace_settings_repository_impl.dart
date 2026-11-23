import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkspaceSettingsRepository] backed by
/// [WorkspaceSettingsRemoteDataSource].
final class WorkspaceSettingsRepositoryImpl
    implements WorkspaceSettingsRepository {
  /// Creates the repository delegating to [_remote].
  const new(this._remote);

  final WorkspaceSettingsRemoteDataSource _remote;

  @override
  Future<Result<WorkspaceSettingsResponse>> getSettings(String workspaceId) =>
      _remote.getSettings(workspaceId);

  @override
  Future<Result<WorkspaceSettingsResponse>> updateSettings(
    String workspaceId,
    ExecutionSettings overrides,
  ) => _remote.updateSettings(workspaceId, overrides);
}
