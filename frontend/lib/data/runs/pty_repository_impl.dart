import 'dart:convert';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Callback that sends a [WsEnvelope] over the active backend WebSocket.
typedef WsEnvelopeSender = Future<Result<void>> Function(WsEnvelope envelope);

/// [PtyRepository] implementation backed by the backend WebSocket connection.
final class WsPtyRepository implements PtyRepository {
  /// Creates a [WsPtyRepository] using [_sendEnvelope].
  new(this._sendEnvelope);

  final WsEnvelopeSender _sendEnvelope;
  int _nextId = 0;

  String _generateId(String prefix) => '$prefix-${++_nextId}';

  @override
  Future<Result<void>> subscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) {
    return _sendEnvelope(
      WsEnvelope(
        id: _generateId('pty-sub'),
        type: WsMessageType.ptySubscribe,
        payload: PtySubscribePayload(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
        ).toJson(),
      ),
    );
  }

  @override
  Future<Result<void>> unsubscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) {
    return _sendEnvelope(
      WsEnvelope(
        id: _generateId('pty-unsub'),
        type: WsMessageType.ptyUnsubscribe,
        payload: PtyUnsubscribePayload(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
        ).toJson(),
      ),
    );
  }

  @override
  Future<Result<void>> sendInput({
    required String runId,
    required String nodeId,
    required int attempt,
    required List<int> bytes,
  }) {
    return _sendEnvelope(
      WsEnvelope(
        id: _generateId('pty-in'),
        type: WsMessageType.ptyInput,
        payload: PtyInputPayload(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
          data: base64Encode(bytes),
        ).toJson(),
      ),
    );
  }

  @override
  Future<Result<void>> resize({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  }) {
    return _sendEnvelope(
      WsEnvelope(
        id: _generateId('pty-resize'),
        type: WsMessageType.ptyResize,
        payload: PtyResizePayload(
          runId: runId,
          nodeId: nodeId,
          attempt: attempt,
          cols: cols,
          rows: rows,
        ).toJson(),
      ),
    );
  }
}
