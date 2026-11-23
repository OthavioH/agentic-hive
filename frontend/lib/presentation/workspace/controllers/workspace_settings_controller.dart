import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_settings_controller.g.dart';

/// Immutable state of the workspace settings editor.
@immutable
final class WorkspaceSettingsState {
  /// Creates a [WorkspaceSettingsState].
  const new({required this.response, this.isSaving = false});

  /// Stored overrides, inherited global values and effective values.
  final WorkspaceSettingsResponse response;

  /// Whether a save is in flight.
  final bool isSaving;

  /// Returns a copy with updated fields.
  WorkspaceSettingsState copyWith({
    WorkspaceSettingsResponse? response,
    bool? isSaving,
  }) => WorkspaceSettingsState(
    response: response ?? this.response,
    isSaving: isSaving ?? this.isSaving,
  );
}

/// Loads and saves the execution settings overrides of one workspace.
@riverpod
class WorkspaceSettingsController extends _$WorkspaceSettingsController {
  @override
  Future<WorkspaceSettingsState> build(String workspaceId) async {
    final result = await ref.watch(getWorkspaceSettingsProvider)(workspaceId);
    return switch (result) {
      Success<WorkspaceSettingsResponse>(:final value) =>
        WorkspaceSettingsState(response: value),
      FailureResult<WorkspaceSettingsResponse>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
  }

  /// Stores [overrides] for this workspace; unset fields are inherited.
  Future<Result<WorkspaceSettingsResponse>> save(
    ExecutionSettings overrides,
  ) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<WorkspaceSettingsState>(
        current.copyWith(isSaving: true),
      );
    }
    final result = await ref.read(updateWorkspaceSettingsProvider)(
      workspaceId,
      overrides,
    );
    if (!ref.mounted) return result;
    final latest = state.asData?.value ?? current;
    if (latest != null) {
      state = AsyncData<WorkspaceSettingsState>(switch (result) {
        Success<WorkspaceSettingsResponse>(:final value) =>
          WorkspaceSettingsState(response: value),
        FailureResult<WorkspaceSettingsResponse>() => latest.copyWith(
          isSaving: false,
        ),
      });
    }
    return result;
  }
}
