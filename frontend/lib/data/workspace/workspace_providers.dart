import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_selection_store_impl.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_providers.g.dart';

/// Provides the [WorkspaceRemoteDataSource] backed by [backendClientProvider].
@riverpod
WorkspaceRemoteDataSource workspaceRemoteDataSource(Ref ref) {
  return HttpWorkspaceRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [WorkspaceRepository] interface.
@riverpod
WorkspaceRepository workspaceRepository(Ref ref) {
  return WorkspaceRepositoryImpl(ref.watch(workspaceRemoteDataSourceProvider));
}

/// Provides the local [WorkspaceSelectionStore].
@Riverpod(keepAlive: true)
WorkspaceSelectionStore workspaceSelectionStore(Ref ref) {
  return FileWorkspaceSelectionStore(currentPlatformPaths());
}
