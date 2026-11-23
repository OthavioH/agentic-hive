/// Version of the WebSocket message protocol.
///
/// Increase it on any breaking change to [WsMessageType] payloads.
const wsProtocolVersion = 1;

/// Every message `type` the WebSocket protocol knows.
abstract final class WsMessageType {
  /// Server → client, sent once right after the connection opens.
  static const serverHello = 'server.hello';

  /// Server → client, answers a message the server could not handle.
  static const error = 'error';

  /// Server → client, broadcast when an agent `.md` file changes on disk.
  static const agentsChanged = 'agents.changed';

  /// Server → client, broadcast when a workspace workflow file changes on
  /// disk.
  static const workflowsChanged = 'workflows.changed';

  /// Server → client, broadcast when a harness's detected status changes.
  static const harnessStatusUpdated = 'harness.status_updated';

  /// Server → client, broadcast when runtime settings are updated.
  static const settingsUpdated = 'settings.updated';

  /// Client → server, subscribes the connection to `run.output` frames for a
  /// specific `runId`.
  static const runSubscribe = 'run.subscribe';

  /// Client → server, unsubscribes the connection from `run.output` frames for
  /// a specific `runId`.
  static const runUnsubscribe = 'run.unsubscribe';

  /// Server → client, broadcast globally when a run lifecycle/execution event
  /// is recorded.
  static const runEvent = 'run.event';

  /// Server → client, streamed to connections subscribed to `runId` when a
  /// node emits `stdout` or `stderr` output.
  static const runOutput = 'run.output';

  /// Client → server, subscribes the connection to `pty.output` frames for a
  /// `(runId, nodeId, attempt)` PTY session and requests scrollback replay.
  static const ptySubscribe = 'pty.subscribe';

  /// Client → server, unsubscribes the connection from `pty.output` frames for
  /// a `(runId, nodeId, attempt)` PTY session.
  static const ptyUnsubscribe = 'pty.unsubscribe';

  /// Server → client, streamed to connections subscribed to a PTY session with
  /// base64-encoded raw PTY output bytes.
  static const ptyOutput = 'pty.output';

  /// Client → server, sends base64-encoded keystroke/paste bytes to an active
  /// PTY session.
  static const ptyInput = 'pty.input';

  /// Client → server, resizes an active PTY session (`cols` and `rows`).
  static const ptyResize = 'pty.resize';

  /// Server → client, broadcast globally when a run creates a pending pause.
  static const pauseCreated = 'pause.created';

  /// Server → client, broadcast globally when a pending pause is answered or
  /// cancelled.
  static const pauseResolved = 'pause.resolved';
}
