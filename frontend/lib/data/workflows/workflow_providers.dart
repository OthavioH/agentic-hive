import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workflow_providers.g.dart';

/// Provides the [WorkflowRemoteDataSource] backed by [backendClientProvider].
@riverpod
WorkflowRemoteDataSource workflowRemoteDataSource(Ref ref) {
  return HttpWorkflowRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [WorkflowRepository] interface.
@riverpod
WorkflowRepository workflowRepository(Ref ref) {
  return WorkflowRepositoryImpl(ref.watch(workflowRemoteDataSourceProvider));
}
