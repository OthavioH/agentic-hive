import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/data/runs/run_repository_impl.dart';
import 'package:agentic_hive_frontend/data/runs/runs_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_providers.g.dart';

/// Provides the [RunsRemoteDataSource] backed by [backendClientProvider].
@riverpod
RunsRemoteDataSource runsRemoteDataSource(Ref ref) {
  return HttpRunsRemoteDataSource(ref.watch(backendClientProvider));
}

/// Provides the [RunRepository] interface.
@riverpod
RunRepository runRepository(Ref ref) {
  return RunRepositoryImpl(ref.watch(runsRemoteDataSourceProvider));
}
