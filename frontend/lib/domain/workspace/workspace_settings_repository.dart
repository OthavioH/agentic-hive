import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository contract for the per-workspace execution settings overrides
/// (ADR 0025).
abstract interface class WorkspaceSettingsRepository {
  /// Loads the overrides, inherited global values and effective values of
  /// workspace [workspaceId].
  Future<Result<WorkspaceSettingsResponse>> getSettings(String workspaceId);

  /// Replaces the overrides of workspace [workspaceId]; unset fields are
  /// inherited from the global settings.
  Future<Result<WorkspaceSettingsResponse>> updateSettings(
    String workspaceId,
    ExecutionSettings overrides,
  );
}
