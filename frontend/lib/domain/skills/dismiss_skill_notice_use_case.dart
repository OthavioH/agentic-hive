import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/skills/skill_notice_repository.dart';

/// Dismisses the pending automatic skill install notice on the backend.
final class DismissSkillNoticeUseCase {
  /// Creates a [DismissSkillNoticeUseCase].
  const new(this._repository);

  final SkillNoticeRepository _repository;

  /// Sends the dismiss request to the backend.
  Future<Result<void>> call() => _repository.dismissNotice();
}
