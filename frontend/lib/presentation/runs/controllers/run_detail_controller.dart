import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'run_detail_controller.g.dart';

/// View state for the Live Run Monitor (`/runs/:id`).
@immutable
final class RunDetailState {
  /// Creates a [RunDetailState].
  const new({
    required this.run,
    required this.events,
    required this.checkpoints,
    this.nodeStatuses = const <String, HiveNodeStatus>{},
    this.activeNodeId,
    this.inspectedNodeId,
    this.followActiveNode = true,
    this.availableAttempts = const <int>[],
    this.selectedAttempt,
    this.isLoadingLogs = false,
    this.logsTruncated = false,
    this.selectedCheckpointId,
    this.expandedEventIds = const <String>{},
    this.isRefreshing = false,
    this.isActionInFlight = false,
    this.actionFailure,
  });

  /// Loaded run metadata and workflow definition.
  final Run run;

  /// Chronological event log entries for [run].
  final List<RunEvent> events;

  /// Saved checkpoints for [run].
  final List<Checkpoint> checkpoints;

  /// Live status per workflow node ID, derived from [events] and `run.status`.
  final Map<String, HiveNodeStatus> nodeStatuses;

  /// Currently active node ID, or the last executed node if none is active.
  final String? activeNodeId;

  /// Node ID currently inspected in the Output tab.
  final String? inspectedNodeId;

  /// Whether [inspectedNodeId] automatically follows [activeNodeId].
  final bool followActiveNode;

  /// Available attempt numbers for [inspectedNodeId].
  final List<int> availableAttempts;

  /// Currently selected attempt number for [inspectedNodeId].
  final int? selectedAttempt;

  /// Whether initial logs for [inspectedNodeId] are currently loading.
  final bool isLoadingLogs;

  /// Whether the loaded logs for [inspectedNodeId] were truncated.
  final bool logsTruncated;

  /// ID of the currently inspected checkpoint, or `null` when none exist.
  final String? selectedCheckpointId;

  /// Event IDs whose JSON payload is currently expanded.
  final Set<String> expandedEventIds;

  /// Whether a background refresh is in progress while keeping existing data.
  final bool isRefreshing;

  /// Whether a cancel or resume action is currently in flight.
  final bool isActionInFlight;

  /// Transient failure from cancel, resume, or log fetching.
  final Failure? actionFailure;

  /// The currently selected [Checkpoint], or `null` if [checkpoints] is empty.
  Checkpoint? get selectedCheckpoint {
    if (checkpoints.isEmpty) return null;
    final id = selectedCheckpointId;
    if (id != null) {
      for (final checkpoint in checkpoints) {
        if (checkpoint.id == id) return checkpoint;
      }
    }
    return checkpoints.last;
  }

  /// Returns a copy with updated fields.
  RunDetailState copyWith({
    Run? run,
    List<RunEvent>? events,
    List<Checkpoint>? checkpoints,
    Map<String, HiveNodeStatus>? nodeStatuses,
    String? Function()? activeNodeId,
    String? Function()? inspectedNodeId,
    bool? followActiveNode,
    List<int>? availableAttempts,
    int? Function()? selectedAttempt,
    bool? isLoadingLogs,
    bool? logsTruncated,
    String? Function()? selectedCheckpointId,
    Set<String>? expandedEventIds,
    bool? isRefreshing,
    bool? isActionInFlight,
    Failure? Function()? actionFailure,
  }) {
    return RunDetailState(
      run: run ?? this.run,
      events: events ?? this.events,
      checkpoints: checkpoints ?? this.checkpoints,
      nodeStatuses: nodeStatuses ?? this.nodeStatuses,
      activeNodeId: activeNodeId != null ? activeNodeId() : this.activeNodeId,
      inspectedNodeId: inspectedNodeId != null
          ? inspectedNodeId()
          : this.inspectedNodeId,
      followActiveNode: followActiveNode ?? this.followActiveNode,
      availableAttempts: availableAttempts ?? this.availableAttempts,
      selectedAttempt: selectedAttempt != null
          ? selectedAttempt()
          : this.selectedAttempt,
      isLoadingLogs: isLoadingLogs ?? this.isLoadingLogs,
      logsTruncated: logsTruncated ?? this.logsTruncated,
      selectedCheckpointId: selectedCheckpointId != null
          ? selectedCheckpointId()
          : this.selectedCheckpointId,
      expandedEventIds: expandedEventIds ?? this.expandedEventIds,
      isRefreshing: isRefreshing ?? this.isRefreshing,
      isActionInFlight: isActionInFlight ?? this.isActionInFlight,
      actionFailure: actionFailure != null
          ? actionFailure()
          : this.actionFailure,
    );
  }
}

/// Manages loading, WebSocket live updates, node log streaming, and
/// cancel/resume actions for a single run (`runId`).
@riverpod
class RunDetailController extends _$RunDetailController {
  /// Stream controller feeding the `HiveLogStreamViewer` in the Output tab.
  final HiveLogStreamController logController = HiveLogStreamController();

  int _logsRequestToken = 0;
  BackendWebSocketSession? _subscribedSession;

  @override
  Future<RunDetailState> build(String runId) {
    ref.onDispose(() {
      _sendUnsubscribe(runId);
      logController.dispose();
    });

    ref.listen<BackendWebSocketSession?>(backendWebSocketSessionProvider, (
      previous,
      next,
    ) {
      if (next != null && !identical(previous, next)) {
        _sendSubscribe(runId, next);
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
      _sendSubscribe(runId, activeSession);
    }

    return _load(runId);
  }

  void _sendSubscribe(String id, BackendWebSocketSession session) {
    if (session.isClosed) return;
    _subscribedSession = session;
    unawaited(
      session.send(
        WsEnvelope(
          id: 'sub-$id',
          type: WsMessageType.runSubscribe,
          payload: RunSubscribePayload(runId: id).toJson(),
        ),
      ),
    );
  }

  void _sendUnsubscribe(String id) {
    final session = _subscribedSession;
    _subscribedSession = null;
    if (session == null || session.isClosed) return;
    unawaited(
      session.send(
        WsEnvelope(
          id: 'unsub-$id',
          type: WsMessageType.runUnsubscribe,
          payload: RunUnsubscribePayload(runId: id).toJson(),
        ),
      ),
    );
  }

  /// Reloads run details, events, checkpoints, and current node logs.
  Future<void> refresh() async {
    final previous = state.asData?.value;
    if (previous != null) {
      state = AsyncData(
        previous.copyWith(isRefreshing: true, actionFailure: () => null),
      );
    } else {
      state = const AsyncLoading<RunDetailState>();
    }
    try {
      final loaded = await _load(
        runId,
        preferredCheckpointId: previous?.selectedCheckpointId,
        expandedEventIds: previous?.expandedEventIds ?? const <String>{},
        followActiveNode: previous?.followActiveNode ?? true,
        preferredInspectedNodeId: previous?.inspectedNodeId,
        preferredAttempt: previous?.selectedAttempt,
      );
      if (!ref.mounted) return;
      state = AsyncData(loaded);
    } on Failure catch (failure, stackTrace) {
      if (!ref.mounted) return;
      if (previous != null) {
        state = AsyncData(
          previous.copyWith(isRefreshing: false, actionFailure: () => failure),
        );
      } else {
        state = AsyncError(failure, stackTrace);
      }
    }
  }

  /// Requests cancellation of the run (or retries cancellation when
  /// `cancellationUncertain`).
  Future<void> cancelRun() async {
    final current = state.asData?.value;
    if (current == null || current.isActionInFlight) return;
    state = AsyncData(
      current.copyWith(isActionInFlight: true, actionFailure: () => null),
    );

    final result = await ref.read(cancelRunProvider).call(runId);
    if (!ref.mounted) return;
    final latest = state.asData?.value ?? current;

    switch (result) {
      case Success<Run>(:final value):
        state = AsyncData(
          latest.copyWith(
            run: value,
            isActionInFlight: false,
            actionFailure: () => null,
          ),
        );
      case FailureResult<Run>(:final failure):
        state = AsyncData(
          latest.copyWith(
            isActionInFlight: false,
            actionFailure: () => failure,
          ),
        );
    }
  }

  /// Resumes an interrupted run from its latest checkpoint.
  Future<void> resumeRun() async {
    final current = state.asData?.value;
    if (current == null || current.isActionInFlight) return;
    state = AsyncData(
      current.copyWith(isActionInFlight: true, actionFailure: () => null),
    );

    final result = await ref.read(resumeRunProvider).call(runId);
    if (!ref.mounted) return;
    final latest = state.asData?.value ?? current;

    switch (result) {
      case Success<Run>(:final value):
        state = AsyncData(
          latest.copyWith(
            run: value,
            isActionInFlight: false,
            actionFailure: () => null,
          ),
        );
      case FailureResult<Run>(:final failure):
        state = AsyncData(
          latest.copyWith(
            isActionInFlight: false,
            actionFailure: () => failure,
          ),
        );
    }
  }

  /// Selects [nodeId] for log inspection and pauses auto-following the active
  /// node.
  Future<void> selectNode(String nodeId) async {
    final current = state.asData?.value;
    if (current == null) return;
    if (current.inspectedNodeId == nodeId && !current.followActiveNode) return;

    final nodeChanged = current.inspectedNodeId != nodeId;
    state = AsyncData(
      current.copyWith(
        followActiveNode: false,
        inspectedNodeId: () => nodeId,
        availableAttempts: nodeChanged
            ? const <int>[]
            : current.availableAttempts,
        selectedAttempt: nodeChanged
            ? () => null
            : () => current.selectedAttempt,
      ),
    );
    if (nodeChanged) {
      await _loadNodeLogs(nodeId);
    }
  }

  /// Re-enables auto-following the active node and switches to it if one is
  /// active.
  Future<void> enableFollowActive() async {
    final current = state.asData?.value;
    if (current == null || current.followActiveNode) return;

    final targetNodeId = current.activeNodeId;
    final nodeChanged =
        targetNodeId != null && targetNodeId != current.inspectedNodeId;
    state = AsyncData(
      current.copyWith(
        followActiveNode: true,
        inspectedNodeId: () => targetNodeId ?? current.inspectedNodeId,
        availableAttempts: nodeChanged
            ? const <int>[]
            : current.availableAttempts,
        selectedAttempt: nodeChanged
            ? () => null
            : () => current.selectedAttempt,
      ),
    );
    if (nodeChanged) {
      await _loadNodeLogs(targetNodeId);
    }
  }

  /// Selects [attempt] for the currently inspected node and fetches its logs.
  Future<void> selectAttempt(int attempt) async {
    final current = state.asData?.value;
    final nodeId = current?.inspectedNodeId;
    if (current == null ||
        nodeId == null ||
        current.selectedAttempt == attempt) {
      return;
    }
    state = AsyncData(current.copyWith(selectedAttempt: () => attempt));
    await _loadNodeLogs(nodeId, attempt: attempt);
  }

  /// Selects [checkpointId] in the checkpoint inspector.
  void selectCheckpoint(String checkpointId) {
    final current = state.asData?.value;
    if (current == null || current.selectedCheckpointId == checkpointId) return;
    state = AsyncData(
      current.copyWith(selectedCheckpointId: () => checkpointId),
    );
  }

  /// Toggles whether the JSON payload for [eventId] is expanded.
  void toggleEventExpanded(String eventId) {
    final current = state.asData?.value;
    if (current == null) return;
    final next = Set<String>.from(current.expandedEventIds);
    if (!next.add(eventId)) {
      next.remove(eventId);
    }
    state = AsyncData(current.copyWith(expandedEventIds: next));
  }

  /// Clears any transient [RunDetailState.actionFailure].
  void dismissActionFailure() {
    final current = state.asData?.value;
    if (current == null || current.actionFailure == null) return;
    state = AsyncData(current.copyWith(actionFailure: () => null));
  }

  void _handleWsEnvelope(WsEnvelope envelope) {
    if (!ref.mounted) return;
    switch (envelope.type) {
      case WsMessageType.runEvent:
        try {
          final payload = RunEventPayload.fromJson(envelope.payload);
          _onRunEvent(payload.event);
        } on FormatException {
          // Ignore malformed frames.
        }
      case WsMessageType.runOutput:
        try {
          final payload = RunOutputPayload.fromJson(envelope.payload);
          _onRunOutput(payload);
        } on FormatException {
          // Ignore malformed frames.
        }
    }
  }

  void _onRunEvent(RunEvent event) {
    if (event.runId != runId) return;
    final current = state.asData?.value;
    if (current == null) return;

    if (current.events.any((e) => e.id == event.id)) return;

    final updatedEvents = <RunEvent>[...current.events, event]
      ..sort((a, b) => a.sequence.compareTo(b.sequence));

    final updatedStatus = _statusFromEvent(event.type, current.run.status);
    final updatedRun = current.run.copyWith(
      status: updatedStatus,
      finishedAt: _isTerminalOrInterrupted(updatedStatus)
          ? (current.run.finishedAt ?? event.createdAt)
          : null,
    );

    final derived = _deriveGraphState(updatedRun, updatedEvents);
    final previousInspected = current.inspectedNodeId;
    final nextInspected = current.followActiveNode
        ? (derived.activeNodeId ?? previousInspected)
        : previousInspected;

    final nodeChanged =
        nextInspected != null && nextInspected != previousInspected;

    state = AsyncData(
      current.copyWith(
        run: updatedRun,
        events: updatedEvents,
        nodeStatuses: derived.nodeStatuses,
        activeNodeId: () => derived.activeNodeId,
        inspectedNodeId: () => nextInspected,
        availableAttempts: nodeChanged
            ? const <int>[]
            : current.availableAttempts,
        selectedAttempt: nodeChanged
            ? () => null
            : () => current.selectedAttempt,
      ),
    );

    if (nodeChanged) {
      unawaited(_loadNodeLogs(nextInspected));
    }

    if (event.type == RunEventType.checkpointSaved) {
      unawaited(_refreshCheckpointsOnly());
    }
  }

  void _onRunOutput(RunOutputPayload payload) {
    if (payload.runId != runId) return;
    final current = state.asData?.value;
    if (current == null) return;

    if (payload.nodeId != current.inspectedNodeId) return;

    var nextAttempts = current.availableAttempts;
    if (!nextAttempts.contains(payload.attempt)) {
      nextAttempts = <int>[...nextAttempts, payload.attempt]..sort();
    }

    final targetAttempt = current.selectedAttempt ?? payload.attempt;
    if (targetAttempt != payload.attempt) {
      if (nextAttempts != current.availableAttempts) {
        state = AsyncData(current.copyWith(availableAttempts: nextAttempts));
      }
      return;
    }

    if (current.selectedAttempt == null ||
        nextAttempts != current.availableAttempts) {
      state = AsyncData(
        current.copyWith(
          availableAttempts: nextAttempts,
          selectedAttempt: () => targetAttempt,
        ),
      );
    }

    logController.append(
      payload.chunk,
      stream: payload.stream == RunOutputStream.stderr
          ? HiveLogStream.stderr
          : HiveLogStream.stdout,
    );
  }

  Future<void> _refreshCheckpointsOnly() async {
    final result = await ref.read(getRunCheckpointsProvider).call(runId);
    if (!ref.mounted) return;
    if (result case Success<List<Checkpoint>>(:final value)) {
      final current = state.asData?.value;
      if (current == null) return;
      state = AsyncData(current.copyWith(checkpoints: value));
    }
  }

  Future<void> _loadNodeLogs(String nodeId, {int? attempt}) async {
    final token = ++_logsRequestToken;
    logController.clear();

    final current = state.asData?.value;
    if (current != null) {
      state = AsyncData(
        current.copyWith(isLoadingLogs: true, logsTruncated: false),
      );
    }

    final result = await ref
        .read(getNodeLogsProvider)
        .call(runId, nodeId, attempt: attempt);
    if (!ref.mounted || token != _logsRequestToken) return;

    final latest = state.asData?.value;
    switch (result) {
      case Success<RunNodeLogsResponse>(:final value):
        for (final entry in value.entries) {
          logController.append(
            entry.chunk,
            stream: entry.stream == RunOutputStream.stderr
                ? HiveLogStream.stderr
                : HiveLogStream.stdout,
          );
        }
        if (latest != null && latest.inspectedNodeId == nodeId) {
          state = AsyncData(
            latest.copyWith(
              availableAttempts: value.availableAttempts,
              selectedAttempt: () => value.attempt,
              isLoadingLogs: false,
              logsTruncated: value.truncated,
            ),
          );
        }
      case FailureResult<RunNodeLogsResponse>(:final failure):
        if (latest != null && latest.inspectedNodeId == nodeId) {
          state = AsyncData(
            latest.copyWith(
              isLoadingLogs: false,
              actionFailure: failure is NotFoundFailure ? null : () => failure,
            ),
          );
        }
    }
  }

  Future<RunDetailState> _load(
    String id, {
    String? preferredCheckpointId,
    Set<String> expandedEventIds = const <String>{},
    bool followActiveNode = true,
    String? preferredInspectedNodeId,
    int? preferredAttempt,
  }) async {
    final runFuture = ref.read(getRunProvider).call(id);
    final eventsFuture = ref.read(getRunEventsProvider).call(id);
    final checkpointsFuture = ref.read(getRunCheckpointsProvider).call(id);

    final runResult = await runFuture;
    final eventsResult = await eventsFuture;
    final checkpointsResult = await checkpointsFuture;

    final run = switch (runResult) {
      Success<Run>(:final value) => value,
      FailureResult<Run>(:final failure) => Error.throwWithStackTrace(
        failure,
        StackTrace.current,
      ),
    };
    final events = switch (eventsResult) {
      Success<RunEventsResponse>(:final value) => value.items,
      FailureResult<RunEventsResponse>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };
    final checkpoints = switch (checkpointsResult) {
      Success<List<Checkpoint>>(:final value) => value,
      FailureResult<List<Checkpoint>>(:final failure) =>
        Error.throwWithStackTrace(failure, StackTrace.current),
    };

    String? selectedId;
    if (checkpoints.isNotEmpty) {
      if (preferredCheckpointId != null &&
          checkpoints.any((c) => c.id == preferredCheckpointId)) {
        selectedId = preferredCheckpointId;
      } else {
        selectedId = checkpoints
            .reduce((a, b) => a.sequence >= b.sequence ? a : b)
            .id;
      }
    }

    final derived = _deriveGraphState(run, events);
    final inspectedNodeId = followActiveNode
        ? derived.activeNodeId
        : (preferredInspectedNodeId ?? derived.activeNodeId);

    var availableAttempts = const <int>[];
    var selectedAttempt = preferredAttempt;
    var logsTruncated = false;

    logController.clear();
    if (inspectedNodeId != null) {
      final logsResult = await ref
          .read(getNodeLogsProvider)
          .call(id, inspectedNodeId, attempt: preferredAttempt);
      if (logsResult case Success<RunNodeLogsResponse>(:final value)) {
        availableAttempts = value.availableAttempts;
        selectedAttempt = value.attempt;
        logsTruncated = value.truncated;
        for (final entry in value.entries) {
          logController.append(
            entry.chunk,
            stream: entry.stream == RunOutputStream.stderr
                ? HiveLogStream.stderr
                : HiveLogStream.stdout,
          );
        }
      }
    }

    return RunDetailState(
      run: run,
      events: events,
      checkpoints: checkpoints,
      nodeStatuses: derived.nodeStatuses,
      activeNodeId: derived.activeNodeId,
      inspectedNodeId: inspectedNodeId,
      followActiveNode: followActiveNode,
      availableAttempts: availableAttempts,
      selectedAttempt: selectedAttempt,
      logsTruncated: logsTruncated,
      selectedCheckpointId: selectedId,
      expandedEventIds: expandedEventIds,
    );
  }

  static RunStatus _statusFromEvent(RunEventType type, RunStatus fallback) {
    return switch (type) {
      RunEventType.runStarted || RunEventType.runResumed => RunStatus.running,
      RunEventType.runPaused => RunStatus.paused,
      RunEventType.runCancelling => RunStatus.cancelling,
      RunEventType.runCancellationUncertain => RunStatus.cancellationUncertain,
      RunEventType.runCancelled => RunStatus.cancelled,
      RunEventType.runInterrupted => RunStatus.interrupted,
      RunEventType.runSucceeded => RunStatus.succeeded,
      RunEventType.runFailed => RunStatus.failed,
      RunEventType.nodeStarted ||
      RunEventType.nodeCompleted ||
      RunEventType.nodeFailed ||
      RunEventType.nodeRetried ||
      RunEventType.checkpointSaved ||
      RunEventType.snapshotCaptured ||
      RunEventType.snapshotRestored ||
      RunEventType.snapshotWarning => fallback,
    };
  }

  static bool _isTerminalOrInterrupted(RunStatus status) => !status.isActive;

  static ({Map<String, HiveNodeStatus> nodeStatuses, String? activeNodeId})
  _deriveGraphState(Run run, List<RunEvent> events) {
    final statuses = <String, HiveNodeStatus>{
      for (final node in run.workflowDefinition.nodes)
        node.id: HiveNodeStatus.idle,
    };
    String? runningNodeId;
    String? lastTouchedNodeId;

    for (final event in events) {
      final nodeId = event.nodeId;
      switch (event.type) {
        case RunEventType.nodeStarted:
          if (nodeId != null) {
            statuses[nodeId] = HiveNodeStatus.running;
            runningNodeId = nodeId;
            lastTouchedNodeId = nodeId;
          }
        case RunEventType.nodeCompleted:
          if (nodeId != null) {
            statuses[nodeId] = HiveNodeStatus.succeeded;
            if (runningNodeId == nodeId) runningNodeId = null;
            lastTouchedNodeId = nodeId;
          }
        case RunEventType.nodeFailed:
          if (nodeId != null) {
            statuses[nodeId] = HiveNodeStatus.failed;
            if (runningNodeId == nodeId) runningNodeId = null;
            lastTouchedNodeId = nodeId;
          }
        case RunEventType.nodeRetried:
          if (nodeId != null) {
            statuses[nodeId] = HiveNodeStatus.idle;
            if (runningNodeId == nodeId) runningNodeId = null;
            lastTouchedNodeId = nodeId;
          }
        case RunEventType.runPaused:
          final target = nodeId ?? runningNodeId;
          if (target != null) {
            statuses[target] = HiveNodeStatus.paused;
            runningNodeId = target;
            lastTouchedNodeId = target;
          }
        case RunEventType.runResumed:
          if (runningNodeId != null) {
            statuses[runningNodeId] = HiveNodeStatus.running;
          }
        case RunEventType.runCancelling:
          for (final entry in statuses.entries.toList()) {
            if (entry.value == HiveNodeStatus.running ||
                entry.value == HiveNodeStatus.paused) {
              statuses[entry.key] = HiveNodeStatus.cancelling;
            }
          }
        case RunEventType.runCancellationUncertain:
          for (final entry in statuses.entries.toList()) {
            if (entry.value == HiveNodeStatus.running ||
                entry.value == HiveNodeStatus.paused ||
                entry.value == HiveNodeStatus.cancelling) {
              statuses[entry.key] = HiveNodeStatus.cancellationUncertain;
            }
          }
        case RunEventType.runCancelled:
          for (final entry in statuses.entries.toList()) {
            if (entry.value == HiveNodeStatus.running ||
                entry.value == HiveNodeStatus.paused ||
                entry.value == HiveNodeStatus.cancelling) {
              statuses[entry.key] = HiveNodeStatus.cancelled;
            }
          }
          runningNodeId = null;
        case RunEventType.runInterrupted:
          for (final entry in statuses.entries.toList()) {
            if (entry.value == HiveNodeStatus.running ||
                entry.value == HiveNodeStatus.paused ||
                entry.value == HiveNodeStatus.cancelling) {
              statuses[entry.key] = HiveNodeStatus.interrupted;
            }
          }
          runningNodeId = null;
        case RunEventType.runStarted:
        case RunEventType.runSucceeded:
        case RunEventType.runFailed:
        case RunEventType.checkpointSaved:
        case RunEventType.snapshotCaptured:
        case RunEventType.snapshotRestored:
        case RunEventType.snapshotWarning:
          break;
      }
    }

    return (
      nodeStatuses: Map<String, HiveNodeStatus>.unmodifiable(statuses),
      activeNodeId: runningNodeId ?? lastTouchedNodeId,
    );
  }
}
