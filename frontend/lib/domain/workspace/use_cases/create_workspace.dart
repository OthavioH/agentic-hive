import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Registers a folder as a workspace.
final class CreateWorkspace {
  /// Creates a [CreateWorkspace] use case.
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Registers [rootPath] with an optional display [name].
  Future<Result<Workspace>> call({required String rootPath, String? name}) =>
      _repository.createWorkspace(rootPath: rootPath, name: name);
}
