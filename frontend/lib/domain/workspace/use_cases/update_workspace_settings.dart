import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Replaces the execution settings overrides of a workspace.
final class UpdateWorkspaceSettings {
  /// Creates an [UpdateWorkspaceSettings] use case.
  const new(this._repository);

  final WorkspaceSettingsRepository _repository;

  /// Stores [overrides] for workspace [workspaceId].
  Future<Result<WorkspaceSettingsResponse>> call(
    String workspaceId,
    ExecutionSettings overrides,
  ) => _repository.updateSettings(workspaceId, overrides);
}
