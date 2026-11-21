import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'pty_terminal_controller.g.dart';

/// View state for an embedded PTY terminal session in the Run Monitor.
@immutable
final class PtyTerminalState {
  /// Creates a [PtyTerminalState].
  const new({required this.mode, required this.terminalController});

  /// Current interaction mode (`watch`, `interactive`, or `ended`).
  final HiveTerminalMode mode;

  /// Terminal emulator controller holding screen buffer and scrollback.
  final HiveTerminalController terminalController;

  /// Returns a copy with updated fields.
  PtyTerminalState copyWith({
    HiveTerminalMode? mode,
    HiveTerminalController? terminalController,
  }) {
    return PtyTerminalState(
      mode: mode ?? this.mode,
      terminalController: terminalController ?? this.terminalController,
    );
  }
}

/// Manages WebSocket subscription, output decoding, input gating, debounced
/// resize, and reconnect scrollback replay for a single `(runId, nodeId,
/// attempt)` PTY session.
@riverpod
class PtyTerminalController extends _$PtyTerminalController {
  static const int _resizeDebounceMs = 80;

  /// Debounce duration applied to viewport cell size changes before sending
  /// `pty.resize`.
  static const Duration resizeDebounceDuration = Duration(
    milliseconds: _resizeDebounceMs,
  );

  late HiveTerminalController _terminalController;
  BackendWebSocketSession? _subscribedSession;
  bool _hasSubscribedOnce = false;
  bool _hasReceivedOutput = false;
  Timer? _resizeTimer;
  (int, int)? _pendingResize;
  (int, int)? _lastSentResize;

  @override
  PtyTerminalState build(String runId, String nodeId, int attempt) {
    _terminalController = HiveTerminalController();
    _subscribedSession = null;
    _hasSubscribedOnce = false;
    _hasReceivedOutput = false;
    _resizeTimer = null;
    _pendingResize = null;
    _lastSentResize = null;

    final unsubscribe = ref.read(unsubscribePtyProvider);

    ref.onDispose(() {
      _resizeTimer?.cancel();
      _resizeTimer = null;
      final session = _subscribedSession;
      _subscribedSession = null;
      if (session != null && !session.isClosed) {
        unawaited(unsubscribe(runId: runId, nodeId: nodeId, attempt: attempt));
      }
      _terminalController.dispose();
    });

    ref.listen<BackendWebSocketSession?>(backendWebSocketSessionProvider, (
      previous,
      next,
    ) {
      if (next != null &&
          !next.isClosed &&
          !identical(_subscribedSession, next)) {
        final isReconnect = _hasSubscribedOnce;
        _subscribe(next, resetBeforeReplay: isReconnect);
      }
    });

    ref.listen<AsyncValue<WsEnvelope>>(backendWsMessagesProvider, (_, next) {
      final envelope = next.asData?.value;
      if (envelope != null) {
        _handleWsEnvelope(envelope);
      }
    });

    final activeSession = ref.read(backendWebSocketSessionProvider);
    if (activeSession != null && !activeSession.isClosed) {
      _subscribe(activeSession, resetBeforeReplay: false);
    }

    return PtyTerminalState(
      mode: HiveTerminalMode.watch,
      terminalController: _terminalController,
    );
  }

  /// Switches from [HiveTerminalMode.watch] to [HiveTerminalMode.interactive].
  void takeOver() {
    if (!ref.mounted || state.mode != HiveTerminalMode.watch) return;
    state = state.copyWith(mode: HiveTerminalMode.interactive);
  }

  /// Returns from [HiveTerminalMode.interactive] to [HiveTerminalMode.watch].
  void release() {
    if (!ref.mounted || state.mode != HiveTerminalMode.interactive) return;
    state = state.copyWith(mode: HiveTerminalMode.watch);
  }

  /// Toggles between [HiveTerminalMode.watch] and
  /// [HiveTerminalMode.interactive].
  void toggleTakeOver() {
    switch (state.mode) {
      case HiveTerminalMode.watch:
        takeOver();
      case HiveTerminalMode.interactive:
        release();
      case HiveTerminalMode.ended:
        break;
    }
  }

  /// Locks the terminal permanently to [HiveTerminalMode.ended] while
  /// preserving the final screen and scrollback output.
  void markEnded() {
    if (!ref.mounted || state.mode == HiveTerminalMode.ended) return;
    _resizeTimer?.cancel();
    _resizeTimer = null;
    _pendingResize = null;
    state = state.copyWith(mode: HiveTerminalMode.ended);
  }

  /// Sends raw terminal input [bytes] to the backend PTY, only when in
  /// [HiveTerminalMode.interactive].
  void sendInput(Uint8List bytes) {
    if (!ref.mounted || !state.mode.acceptsInput || bytes.isEmpty) return;
    unawaited(
      ref
          .read(sendPtyInputProvider)
          .call(runId: runId, nodeId: nodeId, attempt: attempt, bytes: bytes),
    );
  }

  /// Debounces viewport cell dimension changes before sending `pty.resize`.
  void onResize(int cols, int rows) {
    if (!ref.mounted || state.mode == HiveTerminalMode.ended) return;
    if (cols <= 0 || rows <= 0) return;

    final nextSize = (cols, rows);
    if (nextSize == _lastSentResize && _resizeTimer == null) return;

    _pendingResize = nextSize;
    _resizeTimer?.cancel();
    _resizeTimer = Timer(resizeDebounceDuration, () {
      _resizeTimer = null;
      if (!ref.mounted || state.mode == HiveTerminalMode.ended) return;
      final size = _pendingResize;
      _pendingResize = null;
      if (size == null || size == _lastSentResize) return;
      _lastSentResize = size;
      unawaited(
        ref
            .read(resizePtyProvider)
            .call(
              runId: runId,
              nodeId: nodeId,
              attempt: attempt,
              cols: size.$1,
              rows: size.$2,
            ),
      );
    });
  }

  void _subscribe(
    BackendWebSocketSession session, {
    required bool resetBeforeReplay,
  }) {
    if (session.isClosed) return;
    _subscribedSession = session;
    _hasSubscribedOnce = true;

    if (resetBeforeReplay) {
      _resetTerminalController();
    }

    unawaited(
      ref
          .read(subscribePtyProvider)
          .call(runId: runId, nodeId: nodeId, attempt: attempt),
    );
  }

  void _resetTerminalController() {
    final previous = _terminalController;
    final replacement = HiveTerminalController();
    _terminalController = replacement;
    _hasReceivedOutput = false;
    previous.dispose();
    if (ref.mounted) {
      state = state.copyWith(terminalController: replacement);
    }
  }

  void _handleWsEnvelope(WsEnvelope envelope) {
    if (!ref.mounted || envelope.type != WsMessageType.ptyOutput) return;
    final PtyOutputPayload payload;
    try {
      payload = PtyOutputPayload.fromJson(envelope.payload);
    } on FormatException {
      return;
    }

    if (payload.runId != runId ||
        payload.nodeId != nodeId ||
        payload.attempt != attempt) {
      return;
    }

    final List<int> bytes;
    try {
      bytes = base64Decode(payload.data);
    } on FormatException {
      return;
    }

    if (payload.isSnapshot && _hasReceivedOutput) {
      _resetTerminalController();
    }
    _hasReceivedOutput = true;
    _terminalController.appendBytes(bytes);
  }
}
