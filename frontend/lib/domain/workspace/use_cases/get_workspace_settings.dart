import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Loads the execution settings of a workspace.
final class GetWorkspaceSettings {
  /// Creates a [GetWorkspaceSettings] use case.
  const new(this._repository);

  final WorkspaceSettingsRepository _repository;

  /// Loads the settings of workspace [workspaceId].
  Future<Result<WorkspaceSettingsResponse>> call(String workspaceId) =>
      _repository.getSettings(workspaceId);
}
