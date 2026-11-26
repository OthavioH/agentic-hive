import 'package:freezed_annotation/freezed_annotation.dart';

/// Structured lifecycle and execution event types in a run's event log.
enum RunEventType {
  /// The run started.
  @JsonValue('run.started')
  runStarted('run.started'),

  /// The run paused for human input.
  @JsonValue('run.paused')
  runPaused('run.paused'),

  /// A paused or interrupted run resumed.
  @JsonValue('run.resumed')
  runResumed('run.resumed'),

  /// The run was interrupted by a backend restart.
  @JsonValue('run.interrupted')
  runInterrupted('run.interrupted'),

  /// The run completed successfully.
  @JsonValue('run.succeeded')
  runSucceeded('run.succeeded'),

  /// The run failed.
  @JsonValue('run.failed')
  runFailed('run.failed'),

  /// The run is cancelling and terminating active process trees.
  @JsonValue('run.cancelling')
  runCancelling('run.cancelling'),

  /// Cancellation was requested, but process tree exit could not be confirmed.
  @JsonValue('run.cancellation_uncertain')
  runCancellationUncertain('run.cancellation_uncertain'),

  /// The run was cancelled.
  @JsonValue('run.cancelled')
  runCancelled('run.cancelled'),

  /// A node began executing.
  @JsonValue('node.started')
  nodeStarted('node.started'),

  /// A node finished executing.
  @JsonValue('node.completed')
  nodeCompleted('node.completed'),

  /// A node failed.
  @JsonValue('node.failed')
  nodeFailed('node.failed'),

  /// A node was retried along an edge.
  @JsonValue('node.retried')
  nodeRetried('node.retried'),

  /// A node switched to a fallback entry after a rate limit.
  ///
  /// Payload contract:
  /// `{"from": {"harness": id, "model"?: s},`
  /// `"to": {"harness": id, "model"?: s}, "reason": <rate-limit message>}`.
  @JsonValue('node.fallback')
  nodeFallback('node.fallback'),

  /// A checkpoint was persisted.
  @JsonValue('checkpoint.saved')
  checkpointSaved('checkpoint.saved'),

  /// A workspace snapshot was captured.
  @JsonValue('snapshot.captured')
  snapshotCaptured('snapshot.captured'),

  /// A workspace snapshot was restored.
  @JsonValue('snapshot.restored')
  snapshotRestored('snapshot.restored'),

  /// A non-fatal workspace snapshot or worktree warning occurred.
  @JsonValue('snapshot.warning')
  snapshotWarning('snapshot.warning'),

  /// A non-fatal warning occurred during run execution.
  @JsonValue('run.warning')
  warning('run.warning');

  new(this.wireName);

  /// Dot-notation wire representation (for example `run.started`).
  final String wireName;

  /// Parses a [RunEventType] from its dot-notation [wireName], throwing a
  /// [FormatException] when unknown.
  static RunEventType fromWireName(String wireName) {
    for (final value in values) {
      if (value.wireName == wireName) return value;
    }
    throw FormatException('Unknown RunEventType "$wireName".');
  }
}
