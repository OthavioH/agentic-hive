import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_settings_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// In-memory [WorkspaceSettingsRepository] that resolves overrides over a
/// fixed global like the backend does.
final class FakeWorkspaceSettingsRepository
    implements WorkspaceSettingsRepository {
  new({
    this.global = const EffectiveExecutionSettings(
      defaultIsolationMode: WorkspaceIsolationMode.worktree,
      ignorePatterns: <String>['build/'],
      defaultShell: 'cmd.exe',
    ),
    this.overrides = const ExecutionSettings(),
  });

  EffectiveExecutionSettings global;
  ExecutionSettings overrides;
  Failure? getFailure;
  Failure? updateFailure;

  /// When set, `getSettings` waits for it, keeping the dialog loading.
  Completer<void>? getGate;

  final List<String> getCalls = <String>[];
  final List<({String workspaceId, ExecutionSettings overrides})> updateCalls =
      <({String workspaceId, ExecutionSettings overrides})>[];

  WorkspaceSettingsResponse get _response => WorkspaceSettingsResponse(
    overrides: overrides,
    global: global,
    effective: EffectiveExecutionSettings(
      defaultIsolationMode:
          overrides.defaultIsolationMode ?? global.defaultIsolationMode,
      ignorePatterns: overrides.ignorePatterns ?? global.ignorePatterns,
      defaultShell: overrides.defaultShell ?? global.defaultShell,
    ),
  );

  @override
  Future<Result<WorkspaceSettingsResponse>> getSettings(
    String workspaceId,
  ) async {
    getCalls.add(workspaceId);
    await getGate?.future;
    final failure = getFailure;
    if (failure != null) {
      return FailureResult<WorkspaceSettingsResponse>(failure);
    }
    return Success<WorkspaceSettingsResponse>(_response);
  }

  @override
  Future<Result<WorkspaceSettingsResponse>> updateSettings(
    String workspaceId,
    ExecutionSettings overrides,
  ) async {
    updateCalls.add((workspaceId: workspaceId, overrides: overrides));
    final failure = updateFailure;
    if (failure != null) {
      return FailureResult<WorkspaceSettingsResponse>(failure);
    }
    this.overrides = overrides;
    return Success<WorkspaceSettingsResponse>(_response);
  }
}
