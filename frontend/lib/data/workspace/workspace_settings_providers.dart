import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_remote_data_source.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_settings_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'workspace_settings_providers.g.dart';

/// Provides the [WorkspaceSettingsRemoteDataSource].
@riverpod
WorkspaceSettingsRemoteDataSource workspaceSettingsRemoteDataSource(Ref ref) =>
    HttpWorkspaceSettingsRemoteDataSource(ref.watch(backendClientProvider));

/// Provides the [WorkspaceSettingsRepository] interface.
@riverpod
WorkspaceSettingsRepository workspaceSettingsRepository(Ref ref) =>
    WorkspaceSettingsRepositoryImpl(
      ref.watch(workspaceSettingsRemoteDataSourceProvider),
    );
