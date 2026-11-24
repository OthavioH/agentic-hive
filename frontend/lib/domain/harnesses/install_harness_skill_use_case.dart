import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Installs or updates the Agentic Hive skill inside a single CLI harness.
final class InstallHarnessSkillUseCase {
  /// Creates an [InstallHarnessSkillUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Triggers skill installation or update for [id] on the backend and returns
  /// its updated state.
  Future<Result<HarnessInfo>> call(
    HarnessId id, {
    bool overwriteModified = false,
  }) => _repository.installSkill(id, overwriteModified: overwriteModified);
}
