import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_remote_data_source.dart';
import 'package:agentic_hive_frontend/domain/skills/skill_notice_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'skill_notice_repository_impl.g.dart';

/// [SkillNoticeRepository] backed by [SkillNoticeRemoteDataSource].
final class SkillNoticeRepositoryImpl implements SkillNoticeRepository {
  /// Creates a [SkillNoticeRepositoryImpl].
  const new(this._remoteDataSource);

  final SkillNoticeRemoteDataSource _remoteDataSource;

  @override
  Future<Result<SkillAutoInstallNotice?>> getPendingNotice() =>
      _remoteDataSource.getPendingNotice();

  @override
  Future<Result<void>> dismissNotice() => _remoteDataSource.dismissNotice();

  @override
  Stream<SkillAutoInstallNotice> watchNotices() =>
      _remoteDataSource.watchNotices();
}

/// Provides the [SkillNoticeRepository] implementation.
@riverpod
SkillNoticeRepository skillNoticeRepository(Ref ref) =>
    SkillNoticeRepositoryImpl(ref.watch(skillNoticeRemoteDataSourceProvider));
