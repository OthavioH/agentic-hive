import 'package:agentic_hive_backend/src/core/result.dart';

/// Port that terminates the OS process tree of a running node and reports
/// only once every process has exited (ADR 0009).
///
/// Concretely implemented by F10 (job objects / process groups). The engine
/// never reports a cancellation as done before [killTree] succeeds.
abstract interface class ProcessTreeKiller {
  /// Terminates the process trees started for [runId] (only those of [nodeId]
  /// when given) and completes once the exit is confirmed.
  Future<Result<void>> killTree({required String runId, String? nodeId});
}
