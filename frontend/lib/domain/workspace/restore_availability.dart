import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Whether a snapshot restore may be started for a run right now.
enum RestoreAvailability {
  /// Restore is allowed.
  available,

  /// The run is active; restore is rejected until it stops.
  runActive,

  /// `git` is missing, so the shadow repository cannot be used.
  gitUnavailable,

  /// The capability check itself failed, so restore is not offered.
  checkFailed;

  /// Whether the restore action is enabled.
  bool get isAvailable => this == available;

  /// Resolves the availability from the run [status] and the backend
  /// [capabilities] result (`null` while it has not been loaded).
  static RestoreAvailability resolve({
    required RunStatus status,
    required Result<WorkspaceCapabilities>? capabilities,
  }) {
    if (status.isExecutingProcesses) return runActive;
    return switch (capabilities) {
      null || FailureResult<WorkspaceCapabilities>() => checkFailed,
      Success<WorkspaceCapabilities>(:final value) =>
        value.gitAvailable ? available : gitUnavailable,
    };
  }
}
