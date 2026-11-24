import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Removes the Agentic Hive skill from a single CLI harness.
final class RemoveHarnessSkillUseCase {
  /// Creates a [RemoveHarnessSkillUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Triggers skill removal for [id] on the backend and returns its updated
  /// state.
  Future<Result<HarnessInfo>> call(HarnessId id) => _repository.removeSkill(id);
}
