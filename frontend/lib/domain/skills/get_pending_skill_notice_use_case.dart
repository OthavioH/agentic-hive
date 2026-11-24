import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/skills/skill_notice_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Fetches the pending automatic skill install notice from the backend.
final class GetPendingSkillNoticeUseCase {
  /// Creates a [GetPendingSkillNoticeUseCase].
  const new(this._repository);

  final SkillNoticeRepository _repository;

  /// Requests the pending notice, or `null` when none is waiting.
  Future<Result<SkillAutoInstallNotice?>> call() =>
      _repository.getPendingNotice();
}
