import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Reads and writes the per-workspace execution overrides stored in the
/// workspace folder (`<root>/.agentic-hive/settings.json`, ADR 0025).
abstract interface class WorkspaceSettingsStore {
  /// Reads the overrides of the workspace rooted at [rootPath].
  ///
  /// A missing file means no overrides. Keys that are not execution settings
  /// (machine-specific ones such as CLI paths or theme) are ignored. A file
  /// that is not valid JSON, or holds an invalid value for an execution
  /// setting, is a `ValidationFailure`.
  Future<Result<ExecutionSettings>> read(String rootPath);

  /// Replaces the overrides of the workspace rooted at [rootPath].
  ///
  /// Only the keys that are set are written; writing empty overrides removes
  /// the file.
  Future<Result<void>> write(String rootPath, ExecutionSettings settings);
}
