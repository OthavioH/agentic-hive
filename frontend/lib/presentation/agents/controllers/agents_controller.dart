import 'dart:async';

import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_slug.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_state.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/workspace_registry_controller.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'agents_controller.g.dart';

/// Manages the Agent library list, search/tag filters, inline creation,
/// structured draft editing, `expectedHash` conflict resolution, and live
/// WebSocket synchronization.
@riverpod
class AgentsController extends _$AgentsController {
  StreamSubscription<AgentsChangedPayload>? _changesSub;

  /// Workspace whose agents the page shows next to the global ones, or `null`
  /// when none is selected.
  String? get _currentWorkspaceId =>
      ref.read(workspaceRegistryControllerProvider).value?.currentWorkspaceId;

  /// Scope passed to list and create calls: [GlobalScope] in the Global view.
  DefinitionScope get _viewScope => state.globalOnly
      ? const GlobalScope()
      : DefinitionScope.ofWorkspaceId(_currentWorkspaceId);

  /// Scope passed to calls on the open agent: workspace-scoped files are
  /// addressed through their workspace folder.
  DefinitionScope get _openAgentScope => switch (state.detail.value?.scope) {
    final WorkspaceScope scope => scope,
    GlobalScope() || null => const GlobalScope(),
  };

  @override
  AgentsState build() {
    // Switching workspace or Global entry rebuilds the controller and reloads.
    final isGlobalSelected = ref.watch(
      workspaceRegistryControllerProvider.select(
        (value) => value.value?.isGlobalSelected ?? false,
      ),
    );
    ref.watch(
      workspaceRegistryControllerProvider.select(
        (value) => value.value?.currentWorkspaceId,
      ),
    );
    unawaited(_changesSub?.cancel());
    _changesSub = ref
        .read(watchAgentChangesUseCaseProvider)()
        .listen(_handleExternalChange);
    ref.onDispose(() {
      unawaited(_changesSub?.cancel());
      _changesSub = null;
    });

    unawaited(Future.microtask(loadAgents));
    return AgentsState(globalOnly: isGlobalSelected);
  }

  /// Loads or refreshes the list of agents from the backend.
  Future<void> loadAgents() async {
    state = state.copyWith(agents: const AsyncLoading<List<AgentSummary>>());
    final result = await ref.read(listAgentsUseCaseProvider)(scope: _viewScope);
    if (!ref.mounted) return;
    switch (result) {
      case Success<List<AgentSummary>>(:final value):
        state = state.copyWith(agents: AsyncData(_sorted(value)));
      case FailureResult<List<AgentSummary>>(:final failure):
        state = state.copyWith(agents: AsyncError(failure, StackTrace.current));
    }
  }

  /// Switches between the Global view (`true`, only global agents) and the
  /// current workspace plus global agents (`false`), then reloads the list.
  Future<void> setGlobalOnly(bool globalOnly) async {
    if (state.globalOnly == globalOnly) return;
    state = state.copyWith(globalOnly: globalOnly);
    clearSelection();
    if (globalOnly) {
      ref.read(workspaceRegistryControllerProvider.notifier).selectGlobal();
    }
    await loadAgents();
  }

  /// Updates the search query.
  void setSearchQuery(String query) {
    state = state.copyWith(searchQuery: query);
  }

  /// Toggles [tag] in the active tag filter set.
  void toggleTagFilter(String tag) {
    final next = Set<String>.from(state.selectedTags);
    if (!next.add(tag)) {
      next.remove(tag);
    }
    state = state.copyWith(selectedTags: next);
  }

  /// Clears search query and active tag filters.
  void clearFilters() {
    state = state.copyWith(searchQuery: '', selectedTags: const <String>{});
  }

  /// Selects an existing agent by [id] and loads its full detail.
  ///
  /// With [scope] [GlobalScope] the global file is loaded even when a
  /// workspace agent overrides it; otherwise [_viewScope] is searched first.
  Future<void> selectAgent(String id, {DefinitionScope? scope}) async {
    state = state.copyWith(
      selectedAgentId: () => id,
      isCreating: false,
      isPreviewMode: false,
      detail: const AsyncLoading<AgentDetail?>(),
      draft: () => null,
      baselineDraft: () => null,
      saveError: () => null,
      externalNotice: ExternalChangeNotice.none,
    );

    final result = await ref.read(getAgentUseCaseProvider)(
      id,
      scope: switch (scope) {
        GlobalScope() => const GlobalScope(),
        _ => _viewScope,
      },
    );
    if (!ref.mounted || state.selectedAgentId != id) return;
    switch (result) {
      case Success<AgentDetail>(:final value):
        final loadedDraft = AgentDraft.fromDetail(value);
        state = state.copyWith(
          detail: AsyncData(value),
          draft: () => loadedDraft,
          baselineDraft: () => loadedDraft,
        );
      case FailureResult<AgentDetail>(:final failure):
        state = state.copyWith(detail: AsyncError(failure, StackTrace.current));
    }
  }

  /// Clears the current selection or new-agent draft.
  void clearSelection() {
    state = state.copyWith(
      selectedAgentId: () => null,
      isCreating: false,
      detail: const AsyncData<AgentDetail?>(null),
      draft: () => null,
      baselineDraft: () => null,
      saveError: () => null,
      externalNotice: ExternalChangeNotice.none,
    );
  }

  /// Starts creating a new agent inline in the detail pane.
  void startCreate() {
    const emptyDraft = AgentDraft();
    state = state.copyWith(
      selectedAgentId: () => null,
      isCreating: true,
      isPreviewMode: false,
      detail: const AsyncData<AgentDetail?>(null),
      draft: () => emptyDraft,
      baselineDraft: () => emptyDraft,
      saveError: () => null,
      externalNotice: ExternalChangeNotice.none,
    );
  }

  /// Inserts [template] into the new-agent draft prompt.
  void insertTemplate(String template) {
    final current = state.draft;
    if (current == null || !state.isCreating) return;
    state = state.copyWith(draft: () => current.copyWith(prompt: template));
  }

  /// Switches the prompt editor between Raw (`false`) and Preview (`true`).
  void setPreviewMode(bool preview) {
    state = state.copyWith(isPreviewMode: preview);
  }

  /// Dismisses any active external-change banner.
  void dismissExternalNotice() {
    state = state.copyWith(externalNotice: ExternalChangeNotice.none);
  }

  /// Dismisses any active save/delete error banner.
  void dismissSaveError() {
    state = state.copyWith(saveError: () => null);
  }

  /// Updates the draft name, auto-suggesting the slug during creation until
  /// the user edits the slug manually.
  void updateName(String name) {
    final current = state.draft;
    if (current == null) return;
    final nextId = state.isCreating && !current.idManuallyEdited
        ? AgentSlug.suggest(name)
        : current.id;
    state = state.copyWith(
      draft: () => current.copyWith(name: name, id: nextId),
      saveError: () => null,
    );
  }

  /// Updates the draft slug ID (only effective while creating).
  void updateSlug(String slug) {
    final current = state.draft;
    if (current == null || !state.isCreating) return;
    state = state.copyWith(
      draft: () => current.copyWith(id: slug, idManuallyEdited: true),
      saveError: () => null,
    );
  }

  /// Updates the draft description.
  void updateDescription(String description) {
    final current = state.draft;
    if (current == null) return;
    state = state.copyWith(
      draft: () => current.copyWith(description: description),
    );
  }

  /// Updates the draft Markdown prompt.
  void updatePrompt(String prompt) {
    final current = state.draft;
    if (current == null) return;
    state = state.copyWith(draft: () => current.copyWith(prompt: prompt));
  }

  /// Adds [tag] to the draft tags if non-empty and not already present.
  void addTag(String tag) => _updateChipList(
    read: (d) => d.tags,
    write: (d, list) => d.copyWith(tags: list),
    item: tag,
  );

  /// Removes [tag] from the draft tags.
  void removeTag(String tag) => _removeChipItem(
    read: (d) => d.tags,
    write: (d, list) => d.copyWith(tags: list),
    item: tag,
  );

  /// Adds [skill] to `requiredSkills`.
  void addRequiredSkill(String skill) => _updateChipList(
    read: (d) => d.requiredSkills,
    write: (d, list) => d.copyWith(requiredSkills: list),
    item: skill,
  );

  /// Removes [skill] from `requiredSkills`.
  void removeRequiredSkill(String skill) => _removeChipItem(
    read: (d) => d.requiredSkills,
    write: (d, list) => d.copyWith(requiredSkills: list),
    item: skill,
  );

  /// Adds [tool] to `requiredTools`.
  void addRequiredTool(String tool) => _updateChipList(
    read: (d) => d.requiredTools,
    write: (d, list) => d.copyWith(requiredTools: list),
    item: tool,
  );

  /// Removes [tool] from `requiredTools`.
  void removeRequiredTool(String tool) => _removeChipItem(
    read: (d) => d.requiredTools,
    write: (d, list) => d.copyWith(requiredTools: list),
    item: tool,
  );

  /// Adds [tool] to `allowedTools`.
  void addAllowedTool(String tool) => _updateChipList(
    read: (d) => d.allowedTools,
    write: (d, list) => d.copyWith(allowedTools: list),
    item: tool,
  );

  /// Removes [tool] from `allowedTools`.
  void removeAllowedTool(String tool) => _removeChipItem(
    read: (d) => d.allowedTools,
    write: (d, list) => d.copyWith(allowedTools: list),
    item: tool,
  );

  /// Adds [tool] to `deniedTools`.
  void addDeniedTool(String tool) => _updateChipList(
    read: (d) => d.deniedTools,
    write: (d, list) => d.copyWith(deniedTools: list),
    item: tool,
  );

  /// Removes [tool] from `deniedTools`.
  void removeDeniedTool(String tool) => _removeChipItem(
    read: (d) => d.deniedTools,
    write: (d, list) => d.copyWith(deniedTools: list),
    item: tool,
  );

  /// Saves the current draft (creating or updating).
  Future<SaveAgentOutcome> save() async {
    final current = state.draft;
    if (current == null) {
      return const SaveAgentFailure(
        AgentSaveRemoteError('No active draft to save.'),
      );
    }

    final trimmedName = current.name.trim();
    if (trimmedName.isEmpty) {
      const err = AgentSaveNameRequiredError();
      state = state.copyWith(saveError: () => err);
      return const SaveAgentFailure(err);
    }

    if (state.isCreating && !AgentSlug.isValid(current.id)) {
      const err = AgentSaveSlugInvalidError();
      state = state.copyWith(saveError: () => err);
      return const SaveAgentFailure(err);
    }

    state = state.copyWith(isSaving: true, saveError: () => null);

    if (state.isCreating) {
      final result = await ref.read(createAgentUseCaseProvider)(
        CreateAgentRequest(
          id: current.id,
          name: trimmedName,
          description: current.description.trim(),
          tags: current.tags,
          requiredSkills: current.requiredSkills,
          requiredTools: current.requiredTools,
          allowedTools: current.allowedTools,
          deniedTools: current.deniedTools,
          prompt: current.prompt,
        ),
        scope: _viewScope,
      );
      if (!ref.mounted) {
        return const SaveAgentFailure(
          AgentSaveRemoteError('Controller disposed.'),
        );
      }
      return _applySaveResult(result, created: true);
    }

    final result = await ref.read(updateAgentUseCaseProvider)(
      id: current.id,
      request: UpdateAgentRequest(
        name: trimmedName,
        expectedHash: current.baseHash ?? '',
        description: current.description.trim(),
        tags: current.tags,
        requiredSkills: current.requiredSkills,
        requiredTools: current.requiredTools,
        allowedTools: current.allowedTools,
        deniedTools: current.deniedTools,
        prompt: current.prompt,
      ),
      scope: _openAgentScope,
    );
    if (!ref.mounted) {
      return const SaveAgentFailure(
        AgentSaveRemoteError('Controller disposed.'),
      );
    }
    return _applySaveResult(result, created: false);
  }

  /// Overwrites external disk changes with the current draft after a `409`
  /// conflict by fetching the latest `contentHash` and retrying `PUT`.
  Future<SaveAgentOutcome> forceOverwrite() async {
    final current = state.draft;
    if (current == null) {
      return const SaveAgentFailure(
        AgentSaveRemoteError('No active draft to overwrite.'),
      );
    }

    state = state.copyWith(isSaving: true, saveError: () => null);
    final scoped = _openAgentScope;
    final latestResult = await ref.read(getAgentUseCaseProvider)(
      current.id,
      scope: scoped,
    );
    if (!ref.mounted) {
      return const SaveAgentFailure(
        AgentSaveRemoteError('Controller disposed.'),
      );
    }

    switch (latestResult) {
      case Success<AgentDetail>(:final value):
        final updateResult = await ref.read(updateAgentUseCaseProvider)(
          id: current.id,
          request: UpdateAgentRequest(
            name: current.name.trim(),
            expectedHash: value.contentHash,
            description: current.description.trim(),
            tags: current.tags,
            requiredSkills: current.requiredSkills,
            requiredTools: current.requiredTools,
            allowedTools: current.allowedTools,
            deniedTools: current.deniedTools,
            prompt: current.prompt,
          ),
          scope: scoped,
        );
        if (!ref.mounted) {
          return const SaveAgentFailure(
            AgentSaveRemoteError('Controller disposed.'),
          );
        }
        return _applySaveResult(updateResult, created: false);
      case FailureResult<AgentDetail>(:final failure):
        if (failure is NotFoundFailure) {
          final createResult = await ref.read(createAgentUseCaseProvider)(
            CreateAgentRequest(
              id: current.id,
              name: current.name.trim(),
              description: current.description.trim(),
              tags: current.tags,
              requiredSkills: current.requiredSkills,
              requiredTools: current.requiredTools,
              allowedTools: current.allowedTools,
              deniedTools: current.deniedTools,
              prompt: current.prompt,
            ),
            scope: scoped,
          );
          if (!ref.mounted) {
            return const SaveAgentFailure(
              AgentSaveRemoteError('Controller disposed.'),
            );
          }
          return _applySaveResult(createResult, created: true);
        }
        final err = AgentSaveRemoteError(failure.message);
        state = state.copyWith(isSaving: false, saveError: () => err);
        return SaveAgentFailure(err);
    }
  }

  /// Reloads the currently selected agent from disk, discarding local edits.
  Future<void> reloadSelected() async {
    final id = state.selectedAgentId;
    if (id == null) return;
    await selectAgent(id, scope: state.detail.value?.scope);
  }

  /// Deletes the currently selected agent from disk.
  Future<Result<void>> deleteSelected() async {
    final id = state.selectedAgentId;
    if (id == null) {
      return const FailureResult(ValidationFailure('No agent selected.'));
    }
    final deletedScope = state.detail.value?.scope ?? const GlobalScope();
    state = state.copyWith(isDeleting: true, saveError: () => null);
    final result = await ref.read(deleteAgentUseCaseProvider)(
      id,
      scope: _openAgentScope,
    );
    if (!ref.mounted) {
      return const FailureResult(UnexpectedFailure('Controller disposed.'));
    }

    switch (result) {
      case Success<void>():
        final updatedList = _withOverrides(
          (state.agents.value ?? const <AgentSummary>[])
              .where((a) => !(a.id == id && a.scope == deletedScope))
              .toList(),
        );
        state = state.copyWith(
          agents: AsyncData(updatedList),
          selectedAgentId: () => null,
          isCreating: false,
          detail: const AsyncData<AgentDetail?>(null),
          draft: () => null,
          baselineDraft: () => null,
          isDeleting: false,
          externalNotice: ExternalChangeNotice.none,
        );
        return const Success<void>(null);
      case FailureResult<void>(:final failure):
        state = state.copyWith(
          isDeleting: false,
          saveError: () => AgentSaveRemoteError(failure.message),
        );
        return FailureResult<void>(failure);
    }
  }

  SaveAgentOutcome _applySaveResult(
    Result<AgentDetail> result, {
    required bool created,
  }) {
    switch (result) {
      case Success<AgentDetail>(:final value):
        final savedDraft = AgentDraft.fromDetail(value);
        final summary = AgentSummary(
          id: value.id,
          name: value.name,
          description: value.description,
          tags: value.tags,
          contentHash: value.contentHash,
          updatedAt: value.updatedAt,
          scope: value.scope,
          parseError: value.parseError,
        );
        final existing = state.agents.value ?? const <AgentSummary>[];
        final nextList = <AgentSummary>[
          for (final item in existing)
            if (!(item.id == value.id && item.scope == value.scope)) item,
          summary,
        ];
        state = state.copyWith(
          agents: AsyncData(_sorted(nextList)),
          selectedAgentId: () => value.id,
          isCreating: false,
          detail: AsyncData(value),
          draft: () => savedDraft,
          baselineDraft: () => savedDraft,
          isSaving: false,
          saveError: () => null,
          externalNotice: ExternalChangeNotice.none,
        );
        return SaveAgentSuccess(created: created);
      case FailureResult<AgentDetail>(:final failure):
        state = state.copyWith(isSaving: false);
        if (failure is BackendFailure &&
            (failure.statusCode == 409 ||
                failure.code == ApiErrorCode.conflict)) {
          return SaveAgentConflict(failure.message);
        }
        final err = AgentSaveRemoteError(failure.message);
        state = state.copyWith(saveError: () => err);
        return SaveAgentFailure(err);
    }
  }

  void _handleExternalChange(AgentsChangedPayload payload) {
    if (!ref.mounted) return;
    final changedWorkspaceId = payload.workspaceId;
    if (changedWorkspaceId != null &&
        changedWorkspaceId != _viewScope.workspaceIdOrNull) {
      // Another workspace, or a workspace edit while the Global view is open.
      return;
    }
    final changedScope = DefinitionScope.ofWorkspaceId(changedWorkspaceId);
    final currentList = state.agents.value;
    if (currentList != null) {
      switch (payload.kind) {
        case AgentChangeKind.created:
        case AgentChangeKind.updated:
          final summary = payload.agent;
          if (summary != null) {
            final next = <AgentSummary>[
              for (final item in currentList)
                if (!(item.id == payload.id && item.scope == summary.scope))
                  item,
              summary,
            ];
            state = state.copyWith(agents: AsyncData(_sorted(next)));
          } else {
            unawaited(loadAgents());
          }
        case AgentChangeKind.deleted:
          final next = currentList
              .where(
                (item) =>
                    !(item.id == payload.id && item.scope == changedScope),
              )
              .toList();
          state = state.copyWith(agents: AsyncData(_withOverrides(next)));
      }
    }

    if (state.selectedAgentId != payload.id || state.isCreating) return;
    if (state.detail.value?.scope != changedScope) return;

    switch (payload.kind) {
      case AgentChangeKind.deleted:
        state = state.copyWith(
          externalNotice: ExternalChangeNotice.deletedExternally,
        );
      case AgentChangeKind.created:
      case AgentChangeKind.updated:
        final newHash = payload.agent?.contentHash;
        if (newHash != null && newHash == state.draft?.baseHash) {
          return;
        }
        if (!state.isDirty) {
          unawaited(selectAgent(payload.id, scope: changedScope));
        } else {
          state = state.copyWith(
            externalNotice: ExternalChangeNotice.modifiedExternally,
          );
        }
    }
  }

  void _updateChipList({
    required List<String> Function(AgentDraft) read,
    required AgentDraft Function(AgentDraft, List<String>) write,
    required String item,
  }) {
    final current = state.draft;
    if (current == null) return;
    final trimmed = item.trim();
    if (trimmed.isEmpty) return;
    final list = read(current);
    if (list.contains(trimmed)) return;
    state = state.copyWith(
      draft: () =>
          write(current, List<String>.unmodifiable(<String>[...list, trimmed])),
    );
  }

  void _removeChipItem({
    required List<String> Function(AgentDraft) read,
    required AgentDraft Function(AgentDraft, List<String>) write,
    required String item,
  }) {
    final current = state.draft;
    if (current == null) return;
    final list = read(current).where((entry) => entry != item).toList();
    state = state.copyWith(
      draft: () => write(current, List<String>.unmodifiable(list)),
    );
  }

  /// Flags every global agent shadowed by a workspace agent with the same
  /// `name` (trimmed, as the backend does): the file ids may differ (ADR 0025).
  /// Malformed files never override nor get overridden.
  List<AgentSummary> _withOverrides(List<AgentSummary> items) {
    final workspaceNames = <String>{
      for (final item in items)
        if (item.scope is WorkspaceScope && item.parseError == null)
          item.name.trim(),
    };
    return <AgentSummary>[
      for (final item in items)
        if (item.scope is GlobalScope)
          item.copyWith(
            overridden:
                item.parseError == null &&
                workspaceNames.contains(item.name.trim()),
          )
        else
          item,
    ];
  }

  List<AgentSummary> _sorted(List<AgentSummary> items) {
    return _withOverrides(items)..sort((a, b) {
      final byName = a.name.toLowerCase().compareTo(b.name.toLowerCase());
      if (byName != 0) return byName;
      final byId = a.id.compareTo(b.id);
      if (byId != 0) return byId;
      return _scopeRank(a.scope).compareTo(_scopeRank(b.scope));
    });
  }

  static int _scopeRank(DefinitionScope scope) => switch (scope) {
    GlobalScope() => 0,
    WorkspaceScope() => 1,
  };
}
