import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_references_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// [WorkflowReferenceRepository] backed by
/// [WorkflowReferencesRemoteDataSource].
final class WorkflowReferenceRepositoryImpl
    implements WorkflowReferenceRepository {
  /// Creates a repository delegating to [_remoteDataSource].
  const new(this._remoteDataSource);

  final WorkflowReferencesRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final result = await _remoteDataSource.getReferences(
      workflowId,
      scope: scope,
    );
    return result.map((response) => response.references);
  }
}
