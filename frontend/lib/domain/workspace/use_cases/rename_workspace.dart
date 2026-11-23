import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Renames a registered workspace.
final class RenameWorkspace {
  /// Creates a [RenameWorkspace] use case.
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Renames workspace [id] to [name].
  Future<Result<Workspace>> call(String id, {required String name}) =>
      _repository.renameWorkspace(id, name: name);
}
