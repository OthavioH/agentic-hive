import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_reference_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_references_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_reference_providers.g.dart';

/// Provides [WorkflowReferencesRemoteDataSource] backed by
/// [backendClientProvider].
@riverpod
WorkflowReferencesRemoteDataSource workflowReferencesRemoteDataSource(Ref ref) {
  return HttpWorkflowReferencesRemoteDataSource(
    ref.watch(backendClientProvider),
  );
}

/// Provides the [WorkflowReferenceRepository] interface.
@riverpod
WorkflowReferenceRepository workflowReferenceRepository(Ref ref) {
  return WorkflowReferenceRepositoryImpl(
    ref.watch(workflowReferencesRemoteDataSourceProvider),
  );
}
