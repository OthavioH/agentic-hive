import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Read view over one workspace agent folder and the global library
/// (ADR 0022).
///
/// A workspace agent overrides a global agent with the same id: [getById]
/// resolves workspace first, then global, and [list] returns both with the
/// shadowed global entry flagged [AgentSummary.overridden].
///
/// Writes are not layered: callers pick the [workspace] or [global]
/// repository explicitly so an edit never silently lands in the wrong scope.
final class LayeredAgentRepository implements AgentRepository {
  /// Creates a layered view of [workspace] over [global].
  const new({required this.global, required this.workspace});

  /// The global library (`~/.agents/agents`).
  final AgentRepository global;

  /// The workspace library (`<root>/.agents/agents`).
  final AgentRepository workspace;

  @override
  Future<Result<List<AgentSummary>>> list() async {
    final globalResult = await global.list();
    if (globalResult case FailureResult<List<AgentSummary>>(:final failure)) {
      return FailureResult(failure);
    }
    final workspaceResult = await workspace.list();
    if (workspaceResult case FailureResult<List<AgentSummary>>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final workspaceItems = workspaceResult.valueOrNull!;
    final workspaceIds = {for (final s in workspaceItems) s.id};
    final merged = <AgentSummary>[
      ...workspaceItems,
      for (final s in globalResult.valueOrNull!)
        s.copyWith(overridden: workspaceIds.contains(s.id)),
    ]..sort((a, b) => a.id.compareTo(b.id));
    return Success(merged);
  }

  @override
  Future<Result<AgentDetail>> getById(String id) async {
    final fromWorkspace = await workspace.getById(id);
    if (fromWorkspace case FailureResult<AgentDetail>(:final failure)
        when failure is NotFoundFailure) {
      return await global.getById(id);
    }
    return fromWorkspace;
  }

  @override
  Future<Result<AgentDetail>> create(CreateAgentRequest request) =>
      workspace.create(request);

  @override
  Future<Result<AgentDetail>> update(String id, UpdateAgentRequest request) =>
      workspace.update(id, request);

  @override
  Future<Result<void>> delete(String id) => workspace.delete(id);
}
