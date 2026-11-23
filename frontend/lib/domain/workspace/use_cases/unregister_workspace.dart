import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';

/// Unregisters a workspace without deleting any files on disk.
final class UnregisterWorkspace {
  /// Creates an [UnregisterWorkspace] use case.
  const new(this._repository);

  final WorkspaceRepository _repository;

  /// Unregisters workspace [id].
  Future<Result<void>> call(String id) => _repository.unregisterWorkspace(id);
}
