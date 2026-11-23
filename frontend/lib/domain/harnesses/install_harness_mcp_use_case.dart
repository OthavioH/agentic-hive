import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Installs or updates the Hive MCP server inside a single CLI harness.
final class InstallHarnessMcpUseCase {
  /// Creates an [InstallHarnessMcpUseCase].
  const new(this._repository);

  final HarnessRepository _repository;

  /// Triggers MCP installation for [id] on the backend and returns its updated
  /// state.
  Future<Result<HarnessInfo>> call(HarnessId id) => _repository.installMcp(id);
}
