import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_validator.dart';

/// Unique key identifying a single execution attempt of a node in a run.
typedef ResultContractAttemptKey = ({String runId, String nodeId, int attempt});

final class _AttemptState {
  new({required this.targetFolder, required this.availableOutputs});

  final String targetFolder;
  final List<String> availableOutputs;
  final Completer<ResultContractReport> reportCompleter =
      Completer<ResultContractReport>();
  ResultContractReport? lockedReport;
}

/// Coordinates active node attempts and MCP `report_result` submissions.
///
/// Enforces first-valid-report-wins locking per `(runId, nodeId, attempt)`:
/// invalid payloads return [ValidationFailure] so the agent can retry, while a
/// second call after an accepted report returns [ConflictFailure] without
/// overwriting.
final class ResultContractCoordinator {
  /// Creates a coordinator using [validator].
  new({ResultContractValidator? validator})
    : _validator = validator ?? ResultContractValidator();

  final ResultContractValidator _validator;
  final Map<ResultContractAttemptKey, _AttemptState> _attempts =
      <ResultContractAttemptKey, _AttemptState>{};

  /// Registers an active attempt so MCP `report_result` calls can be validated
  /// and locked against its [targetFolder] and [availableOutputs].
  ///
  /// Returns [ConflictFailure] if the attempt already has a locked report.
  Result<void> registerAttempt({
    required String runId,
    required String nodeId,
    required int attempt,
    required String targetFolder,
    required List<String> availableOutputs,
  }) {
    final key = (runId: runId, nodeId: nodeId, attempt: attempt);
    final existing = _attempts[key];
    if (existing?.lockedReport != null) {
      return FailureResult(
        ConflictFailure(
          'Cannot re-register attempt ($runId, $nodeId, $attempt) that already '
          'has a locked report.',
        ),
      );
    }
    _attempts[key] = _AttemptState(
      targetFolder: targetFolder,
      availableOutputs: List<String>.unmodifiable(availableOutputs),
    );
    return const Success(null);
  }

  /// Whether `(runId, nodeId, attempt)` is currently registered as an active
  /// attempt.
  bool isAttemptRegistered({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _attempts.containsKey((runId: runId, nodeId: nodeId, attempt: attempt));

  /// Removes state for the attempt identified by `(runId, nodeId, attempt)`.
  void unregisterAttempt({
    required String runId,
    required String nodeId,
    required int attempt,
  }) {
    _attempts.remove((runId: runId, nodeId: nodeId, attempt: attempt));
  }

  /// Validates and locks an MCP `report_result` [payload] for the given
  /// attempt.
  Result<ResultContractReport> submitMcpReport({
    required String runId,
    required String nodeId,
    required int attempt,
    required Map<String, Object?> payload,
  }) {
    final key = (runId: runId, nodeId: nodeId, attempt: attempt);
    final state = _attempts[key];
    if (state == null) {
      return FailureResult(
        NotFoundFailure(
          'No active node attempt for run "$runId", node "$nodeId", '
          'attempt $attempt.',
        ),
      );
    }

    if (state.lockedReport != null) {
      return const FailureResult(
        ConflictFailure('Result already reported for this node attempt.'),
      );
    }

    final validation = _validator.validate(
      payload,
      targetFolder: state.targetFolder,
      availableOutputs: state.availableOutputs,
    );
    if (validation case FailureResult<ResultContractReport>(:final failure)) {
      return FailureResult(failure);
    }

    final report = validation.valueOrNull!;
    state.lockedReport = report;
    if (!state.reportCompleter.isCompleted) {
      state.reportCompleter.complete(report);
    }
    return Success(report);
  }

  /// Returns a future that completes when an MCP `report_result` is accepted
  /// for `(runId, nodeId, attempt)`, or `null` if the attempt is not active.
  Future<ResultContractReport>? watchMcpReport({
    required String runId,
    required String nodeId,
    required int attempt,
  }) => _attempts[(runId: runId, nodeId: nodeId, attempt: attempt)]
      ?.reportCompleter
      .future;

  /// Returns the locked MCP report for `(runId, nodeId, attempt)`, or `null`
  /// if none was accepted.
  ResultContractReport? getLockedMcpReport({
    required String runId,
    required String nodeId,
    required int attempt,
  }) =>
      _attempts[(runId: runId, nodeId: nodeId, attempt: attempt)]?.lockedReport;
}
