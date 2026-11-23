import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Lists all registered workspaces.
final class ListWorkspaces {
  /// Creates a [ListWorkspaces] use case.
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Fetches registered workspaces from the backend.
  Future<Result<List<Workspace>>> call() => _repository.listWorkspaces();
}
