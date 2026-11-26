import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_slug.dart';
import 'package:agentic_hive_backend/src/domain/agents/workspace_agent_repositories.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Domain operations for managing the agent library.
///
/// Without a `workspaceId` every operation targets the global library. With
/// one, reads see the workspace folder layered over the global library
/// (workspace overrides global by `name`, ADR 0025) and writes only touch the
/// workspace folder.
final class AgentService {
  /// Creates an agent service backed by the global library and, optionally,
  /// workspace libraries.
  ///
  /// `onWorkspaceAgentsChanged` runs after a workspace folder is read or
  /// written so file watchers can pick up a folder that did not exist before.
  new(
    this._global, {
    this._workspaces,
    this._layer,
    this._onWorkspaceAgentsChanged,
  }) : assert(
         _workspaces == null || _layer != null,
         'Workspace-scoped agents need a layering.',
       );

  final AgentRepository _global;
  final WorkspaceAgentRepositories? _workspaces;
  final LayerAgentRepositories? _layer;
  final Future<void> Function()? _onWorkspaceAgentsChanged;

  Future<Result<AgentRepository>> _workspaceRepository(String workspaceId) {
    final workspaces = _workspaces;
    if (workspaces == null) {
      return Future.value(
        const FailureResult(
          ValidationFailure('Workspace-scoped agents are not available.'),
        ),
      );
    }
    return workspaces.forWorkspaceId(workspaceId);
  }

  Future<Result<T>> _inWorkspace<T>(
    String workspaceId,
    Future<Result<T>> Function(AgentRepository workspace) action,
  ) async {
    final repository = await _workspaceRepository(workspaceId);
    if (repository case FailureResult<AgentRepository>(:final failure)) {
      return FailureResult(failure);
    }
    final result = await action(repository.valueOrNull!);
    await _onWorkspaceAgentsChanged?.call();
    return result;
  }

  /// Lists the global agents, or with [WorkspaceScope] the workspace agents
  /// plus the global ones.
  Future<Result<List<AgentSummary>>> list({
    DefinitionScope scope = const GlobalScope(),
  }) => switch (scope) {
    GlobalScope() => _global.list(),
    WorkspaceScope(:final workspaceId) => _inWorkspace(
      workspaceId,
      (workspace) => _layer!(global: _global, workspace: workspace).list(),
    ),
  };

  /// Loads the agent with filename stem [id], resolving the workspace folder
  /// first when [scope] is [WorkspaceScope].
  Future<Result<AgentDetail>> getById(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) {
    final validId = validateAgentLookupId(id);
    if (validId case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    return switch (scope) {
      GlobalScope() => _global.getById(id),
      WorkspaceScope(:final workspaceId) => _inWorkspace(
        workspaceId,
        (workspace) =>
            _layer!(global: _global, workspace: workspace).getById(id),
      ),
    };
  }

  /// Creates a new agent from [request] in [scope].
  Future<Result<AgentDetail>> create(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) {
    final slug = validateAgentSlug(request.id);
    if (slug case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    if (request.name.trim().isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('Agent name must not be empty.')),
      );
    }
    return switch (scope) {
      GlobalScope() => _global.create(request),
      WorkspaceScope(:final workspaceId) => _inWorkspace(
        workspaceId,
        (workspace) => workspace.create(request),
      ),
    };
  }

  /// Updates an existing agent [id] from [request] in [scope].
  Future<Result<AgentDetail>> update(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) {
    final slug = validateAgentSlug(id);
    if (slug case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    if (request.name.trim().isEmpty) {
      return Future.value(
        const FailureResult(ValidationFailure('Agent name must not be empty.')),
      );
    }
    if (request.expectedHash.trim().isEmpty) {
      return Future.value(
        const FailureResult(
          ValidationFailure('expectedHash must not be empty.'),
        ),
      );
    }
    return switch (scope) {
      GlobalScope() => _global.update(id, request),
      WorkspaceScope(:final workspaceId) => _inWorkspace(
        workspaceId,
        (workspace) => workspace.update(id, request),
      ),
    };
  }

  /// Deletes the agent with filename stem [id] from [scope].
  Future<Result<void>> delete(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) {
    final validId = validateAgentLookupId(id);
    if (validId case FailureResult(:final failure)) {
      return Future.value(FailureResult(failure));
    }
    return switch (scope) {
      GlobalScope() => _global.delete(id),
      WorkspaceScope(:final workspaceId) => _inWorkspace(
        workspaceId,
        (workspace) => workspace.delete(id),
      ),
    };
  }
}
