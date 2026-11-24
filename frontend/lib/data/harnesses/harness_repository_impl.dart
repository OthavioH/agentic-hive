import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harnesses_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'harness_repository_impl.g.dart';

/// [HarnessRepository] backed by [HarnessesRemoteDataSource].
final class HarnessRepositoryImpl implements HarnessRepository {
  /// Creates a [HarnessRepositoryImpl].
  const new(this._remoteDataSource);

  final HarnessesRemoteDataSource _remoteDataSource;

  @override
  Future<Result<List<HarnessInfo>>> getHarnesses() async {
    final result = await _remoteDataSource.getHarnesses();
    return result.map((response) => response.harnesses);
  }

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() async {
    final result = await _remoteDataSource.refreshAll();
    return result.map((response) => response.harnesses);
  }

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) =>
      _remoteDataSource.refreshHarness(id);

  @override
  Future<Result<HarnessInfo>> installMcp(HarnessId id) =>
      _remoteDataSource.installMcp(id);

  @override
  Future<Result<HarnessInfo>> installSkill(
    HarnessId id, {
    required bool overwriteModified,
  }) =>
      _remoteDataSource.installSkill(id, overwriteModified: overwriteModified);

  @override
  Future<Result<HarnessInfo>> removeSkill(HarnessId id) =>
      _remoteDataSource.removeSkill(id);

  @override
  Stream<HarnessInfo> watchHarnessUpdates() =>
      _remoteDataSource.watchHarnessUpdates();
}

/// Provides the [HarnessRepository] implementation.
@riverpod
HarnessRepository harnessRepository(Ref ref) =>
    HarnessRepositoryImpl(ref.watch(harnessesRemoteDataSourceProvider));
