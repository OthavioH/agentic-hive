import 'package:agentic_hive_frontend/domain/skills/skill_notice_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Watches live automatic skill install notices from the backend.
final class WatchSkillNoticesUseCase {
  /// Creates a [WatchSkillNoticesUseCase].
  const new(this._repository);

  final SkillNoticeRepository _repository;

  /// Returns a stream of automatic install notices.
  Stream<SkillAutoInstallNotice> call() => _repository.watchNotices();
}
