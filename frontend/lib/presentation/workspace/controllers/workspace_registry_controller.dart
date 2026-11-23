import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter/foundation.dart' show immutable;
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_registry_controller.g.dart';

/// Immutable state for registered workspaces and the active selection.
@immutable
final class WorkspaceRegistryState {
  /// Creates a [WorkspaceRegistryState].
  const new({
    required this.workspaces,
    required this.currentWorkspaceId,
    this.isSubmitting = false,
    this.isGlobalSelected = false,
  });

  /// All registered workspaces.
  final List<Workspace> workspaces;

  /// Identifier of the active workspace, or null when none is selected.
  final String? currentWorkspaceId;

  /// Whether a create, rename, or unregister mutation is in flight.
  final bool isSubmitting;

  /// Whether the fixed Global entry is selected: no workspace is current and
  /// pages manage only global items (ADR 0025). Not persisted across restarts.
  final bool isGlobalSelected;

  /// Currently selected [Workspace], or null when [currentWorkspaceId] is
  /// unset or not present in [workspaces].
  Workspace? get currentWorkspace {
    final id = currentWorkspaceId;
    if (id == null) return null;
    for (final workspace in workspaces) {
      if (workspace.id == id) return workspace;
    }
    return null;
  }

  /// Returns a copy with updated fields.
  WorkspaceRegistryState copyWith({
    List<Workspace>? workspaces,
    String? Function()? currentWorkspaceId,
    bool? isSubmitting,
    bool? isGlobalSelected,
  }) => WorkspaceRegistryState(
    workspaces: workspaces ?? this.workspaces,
    currentWorkspaceId: currentWorkspaceId != null
        ? currentWorkspaceId()
        : this.currentWorkspaceId,
    isSubmitting: isSubmitting ?? this.isSubmitting,
    isGlobalSelected: isGlobalSelected ?? this.isGlobalSelected,
  );
}

/// Manages registered workspaces and persists the current workspace across
/// restarts.
@riverpod
class WorkspaceRegistryController extends _$WorkspaceRegistryController {
  @override
  Future<WorkspaceRegistryState> build() async {
    final listWorkspaces = ref.watch(listWorkspacesProvider);
    final loadLastWorkspaceId = ref.watch(loadLastWorkspaceIdProvider);

    final results = await Future.wait<Object?>(<Future<Object?>>[
      listWorkspaces(),
      loadLastWorkspaceId(),
    ]);
    final workspacesResult = results[0]! as Result<List<Workspace>>;
    final savedId = results[1] as String?;

    return switch (workspacesResult) {
      Success<List<Workspace>>(:final value) => WorkspaceRegistryState(
        workspaces: value,
        currentWorkspaceId: _resolveSelectedId(value, savedId),
      ),
      FailureResult<List<Workspace>>(:final failure) => throw StateError(
        failure.message,
      ),
    };
  }

  String? _resolveSelectedId(List<Workspace> workspaces, String? preferredId) {
    if (workspaces.isEmpty) return null;
    if (preferredId != null && workspaces.any((w) => w.id == preferredId)) {
      return preferredId;
    }
    return workspaces.first.id;
  }

  /// Reloads registered workspaces from the backend while preserving the
  /// current selection if it still exists.
  Future<void> refresh() async {
    final currentId = state.asData?.value.currentWorkspaceId;
    final keepGlobal = state.asData?.value.isGlobalSelected ?? false;
    final result = await ref.read(listWorkspacesProvider)();
    if (!ref.mounted) return;
    switch (result) {
      case Success<List<Workspace>>(:final value):
        state = AsyncData<WorkspaceRegistryState>(
          WorkspaceRegistryState(
            workspaces: value,
            currentWorkspaceId: keepGlobal
                ? null
                : _resolveSelectedId(value, currentId),
            isGlobalSelected: keepGlobal,
          ),
        );
      case FailureResult<List<Workspace>>(:final failure):
        state = AsyncError<WorkspaceRegistryState>(failure, StackTrace.current);
    }
  }

  /// Switches the current workspace to [id] and persists the selection.
  Future<void> selectWorkspace(String id) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (!current.workspaces.any((w) => w.id == id)) return;
    state = AsyncData<WorkspaceRegistryState>(
      current.copyWith(currentWorkspaceId: () => id, isGlobalSelected: false),
    );
    await ref.read(saveLastWorkspaceIdProvider)(id);
  }

  /// Selects the fixed Global entry, so pages manage only global items.
  void selectGlobal() {
    final current = state.asData?.value;
    if (current == null) return;
    state = AsyncData<WorkspaceRegistryState>(
      current.copyWith(currentWorkspaceId: () => null, isGlobalSelected: true),
    );
  }

  /// Opens the native folder picker for selecting a workspace root folder.
  Future<String?> pickWorkspaceFolder() => ref.read(pickDirectoryProvider)();

  /// Registers a workspace at [rootPath] with an optional [name], selects it,
  /// and persists the selection.
  Future<Result<Workspace>> addWorkspace({
    required String rootPath,
    String? name,
  }) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<WorkspaceRegistryState>(
        current.copyWith(isSubmitting: true),
      );
    }
    final result = await ref.read(createWorkspaceProvider)(
      rootPath: rootPath,
      name: name,
    );
    if (!ref.mounted) return result;
    final latest = state.asData?.value;
    switch (result) {
      case Success<Workspace>(:final value):
        final existing = latest?.workspaces ?? <Workspace>[];
        final updated = <Workspace>[
          for (final w in existing)
            if (w.id != value.id) w,
          value,
        ];
        state = AsyncData<WorkspaceRegistryState>(
          WorkspaceRegistryState(
            workspaces: updated,
            currentWorkspaceId: value.id,
          ),
        );
        await ref.read(saveLastWorkspaceIdProvider)(value.id);
      case FailureResult<Workspace>():
        if (latest != null) {
          state = AsyncData<WorkspaceRegistryState>(
            latest.copyWith(isSubmitting: false),
          );
        }
    }
    return result;
  }

  /// Renames workspace [id] to [name].
  Future<Result<Workspace>> renameWorkspace(
    String id, {
    required String name,
  }) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<WorkspaceRegistryState>(
        current.copyWith(isSubmitting: true),
      );
    }
    final result = await ref.read(renameWorkspaceProvider)(id, name: name);
    if (!ref.mounted) return result;
    final latest = state.asData?.value;
    if (latest != null) {
      switch (result) {
        case Success<Workspace>(:final value):
          state = AsyncData<WorkspaceRegistryState>(
            latest.copyWith(
              workspaces: <Workspace>[
                for (final w in latest.workspaces)
                  if (w.id == id) value else w,
              ],
              isSubmitting: false,
            ),
          );
        case FailureResult<Workspace>():
          state = AsyncData<WorkspaceRegistryState>(
            latest.copyWith(isSubmitting: false),
          );
      }
    }
    return result;
  }

  /// Unregisters workspace [id] without deleting files on disk.
  Future<Result<void>> removeWorkspace(String id) async {
    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData<WorkspaceRegistryState>(
        current.copyWith(isSubmitting: true),
      );
    }
    final result = await ref.read(unregisterWorkspaceProvider)(id);
    if (!ref.mounted) return result;
    final latest = state.asData?.value;
    if (latest != null) {
      switch (result) {
        case Success<void>():
          final remaining = latest.workspaces.where((w) => w.id != id).toList();
          final nextId = latest.currentWorkspaceId == id
              ? remaining.firstOrNull?.id
              : latest.currentWorkspaceId;
          state = AsyncData<WorkspaceRegistryState>(
            WorkspaceRegistryState(
              workspaces: remaining,
              currentWorkspaceId: nextId,
              isGlobalSelected: latest.isGlobalSelected,
            ),
          );
          if (latest.currentWorkspaceId == id) {
            await ref.read(saveLastWorkspaceIdProvider)(nextId);
          }
        case FailureResult<void>():
          state = AsyncData<WorkspaceRegistryState>(
            latest.copyWith(isSubmitting: false),
          );
      }
    }
    return result;
  }
}
