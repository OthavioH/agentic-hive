import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Checks git availability and workspace status for an optional path.
final class GetWorkspaceCapabilities {
  /// Creates a [GetWorkspaceCapabilities] use case backed by [_repository].
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Executes the use case, optionally inspecting [path].
  Future<Result<WorkspaceCapabilities>> call({String? path}) =>
      _repository.getCapabilities(path: path);
}
