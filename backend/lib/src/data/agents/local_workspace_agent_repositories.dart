import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/workspace_agent_repositories.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// [WorkspaceAgentRepositories] backed by LocalAgentRepository folders.
final class LocalWorkspaceAgentRepositories
    implements WorkspaceAgentRepositories {
  /// Creates the factory; `findWorkspace` resolves a registered workspace by
  /// id.
  new({required this._findWorkspace, p.Context? pathContext})
    : _path = pathContext ?? p.context;

  final Future<Result<Workspace>> Function(String workspaceId) _findWorkspace;
  final p.Context _path;

  @override
  AgentRepository forRoot(
    String workspaceRoot, {
    required String workspaceId,
  }) => LocalAgentRepository(
    agentsDir: _path.join(workspaceRoot, '.agents', 'agents'),
    scope: WorkspaceScope(workspaceId),
    pathContext: _path,
  );

  @override
  Future<Result<AgentRepository>> forWorkspaceId(String workspaceId) async {
    final found = await _findWorkspace(workspaceId);
    return switch (found) {
      Success<Workspace>(:final value) => Success(
        forRoot(value.rootPath, workspaceId: value.id),
      ),
      FailureResult<Workspace>(:final failure) => FailureResult(failure),
    };
  }
}
