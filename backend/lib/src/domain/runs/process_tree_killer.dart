import 'dart:io';

import 'package:agentic_hive_backend/src/core/result.dart';

/// Port that terminates the OS process tree of a running node and reports
/// only once every process has exited (ADR 0009, ADR 0012).
///
/// Concretely implemented by F10 (job objects on Windows, process groups on
/// Linux/macOS). The engine never reports a cancellation as done before
/// [killTree] succeeds.
abstract interface class ProcessTreeKiller {
  /// Terminates the process trees started for [runId] (only those of [nodeId]
  /// when given) and completes once the exit is confirmed.
  Future<Result<void>> killTree({required String runId, String? nodeId});
}

/// Port for registering and unregistering spawned child [Process]es so
/// [ProcessTreeKiller] can terminate their entire OS process trees.
abstract interface class ProcessTreeTracker {
  /// Registers [process] under [runId] and [nodeId] right after launch.
  void track({
    required String runId,
    required String nodeId,
    required Process process,
  });

  /// Unregisters [process] after it exits normally.
  void untrack(Process process);
}
