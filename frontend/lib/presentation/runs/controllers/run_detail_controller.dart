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

  /// Parses a `{harness, model?}` map from a `node.fallback` event payload.
  static FallbackEntry? parseFallbackEndpoint(Object? raw) {
    if (raw is! Map<Object?, Object?>) return null;
    final harness = raw['harness'];
    if (harness is! String || harness.isEmpty) return null;
    final rawModel = raw['model'];
    final trimmedModel = rawModel is String ? rawModel.trim() : '';
    return FallbackEntry(
      harness: harness,
      model: trimmedModel.isEmpty ? null : trimmedModel,
    );
  }

  /// Effective `{harness, model}` each node ran on after a `node.fallback`
  /// event, omitting entries that match the node's own configured target.
  Map<String, FallbackEntry> get ranOnByNodeId {
    final latestByNodeId = <String, FallbackEntry>{};
    for (final event in events) {
      if (event.type != RunEventType.nodeFallback) continue;
      final nodeId = event.nodeId;
      if (nodeId == null) continue;
      final entry = parseFallbackEndpoint(event.payload['to']);
      if (entry == null) continue;
      latestByNodeId[nodeId] = entry;
    }
    if (latestByNodeId.isEmpty) return const <String, FallbackEntry>{};

    final nodesById = <String, WorkflowNode>{
      for (final node in run.workflowDefinition.nodes) node.id: node,
    };
    final result = <String, FallbackEntry>{};
    for (final entry in latestByNodeId.entries) {
      final node = nodesById[entry.key];
      if (node == null) continue;
      final rawNodeModel = node.config['model'];
      final trimmedNodeModel = rawNodeModel is String
          ? rawNodeModel.trim()
          : '';
      final nodeModel = trimmedNodeModel.isEmpty ? null : trimmedNodeModel;
      if (node.type == entry.value.harness && nodeModel == entry.value.model) {
        continue;
      }
      result[entry.key] = entry.value;
    }
    return result;
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

/// Owns the [HiveLogStreamController] for a single run's live log viewer so
/// its disposal is tied to the provider lifecycle and happens exactly once.
@riverpod
HiveLogStreamController runLogStreamController(Ref ref, String runId) {
  final controller = HiveLogStreamController(
    maxLines: RunDetailController.maxLogLines,
  );
  ref.onDispose(controller.dispose);
  return controller;
}

/// Manages loading, WebSocket live updates, node log streaming, and
/// cancel/resume actions for a single run (`runId`).
@riverpod
class RunDetailController extends _$RunDetailController {
  /// Maximum number of lines retained in [logController].
  static const int maxLogLines = 5000;

  /// Stream controller feeding the `HiveLogStreamViewer` in the Output tab.
  late final HiveLogStreamController logController = ref.read(
    runLogStreamControllerProvider(runId),
  );

  int _logsRequestToken = 0;
  bool _logsLoadInFlight = false;
  final List<RunOutputPayload> _pendingWsOutput = <RunOutputPayload>[];
  int _lastLoadedLogOffset = 0;
  bool _initialLoadCompleted = false;
  String? _runningNodeId;
  String? _lastTouchedNodeId;
  BackendWebSocketSession? _subscribedSession;

  @override
  Future<RunDetailState> build(String runId) {
    // Keep the log stream controller alive across retries/rebuilds of this
    // controller until the run detail provider itself is disposed.
    ref.watch(runLogStreamControllerProvider(runId));
    _initialLoadCompleted = false;
    _logsLoadInFlight = false;
    _pendingWsOutput.clear();
    _lastLoadedLogOffset = 0;
    _runningNodeId = null;
    _lastTouchedNodeId = null;

    ref.onDispose(() {
      _sendUnsubscribe(runId);
    });

    ref.listen<BackendWebSocketSession?>(backendWebSocketSessionProvider, (
      previous,
      next,
    ) {
      if (next != null &&
          !next.isClosed &&
          !identical(_subscribedSession, next)) {
        _sendSubscribe(runId, next);
        if (_initialLoadCompleted) {
          unawaited(_resyncAfterReconnect());
        }
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

  void _clearLogController() {
    if (!ref.mounted) return;
    logController.clear();
  }

  /// Appends one raw log entry; the backend sends each entry as one whole line.
  void _appendLogChunk(String chunk, {required RunOutputStream stream}) {
    if (!ref.mounted) return;
    logController.appendLines(<HiveLogLine>[
      HiveLogLine(
        chunk,
        stream: stream == RunOutputStream.stderr
            ? HiveLogStream.stderr
            : HiveLogStream.stdout,
      ),
    ]);
  }

  void _appendLogPayload(RunOutputPayload payload) {
    if (payload.offset > 0 && payload.offset <= _lastLoadedLogOffset) {
      return;
    }
    _appendLogChunk(payload.chunk, stream: payload.stream);
    if (payload.offset > _lastLoadedLogOffset) {
      _lastLoadedLogOffset = payload.offset;
    }
  }

  static int _maxEntryOffset(RunNodeLogsResponse response) {
    var maxOffset = response.offset;
    for (final entry in response.entries) {
      if (entry.offset > maxOffset) maxOffset = entry.offset;
    }
    return maxOffset;
  }

  static List<RunOutputPayload> _sortedPendingOutput(
    List<RunOutputPayload> pending,
  ) {
    if (pending.length <= 1) return List<RunOutputPayload>.of(pending);
    final indexed = pending.indexed.toList()
      ..sort((a, b) {
        final oa = a.$2.offset;
        final ob = b.$2.offset;
        if (oa > 0 && ob > 0 && oa != ob) {
          return oa.compareTo(ob);
        }
        return a.$1.compareTo(b.$1);
      });
    return <RunOutputPayload>[for (final item in indexed) item.$2];
  }

  void _onRunEvent(RunEvent event) {
    if (event.runId != runId) return;
    final current = state.asData?.value;
    if (current == null) return;

    if (current.events.any((e) => e.id == event.id)) return;

    final inOrder =
        current.events.isEmpty ||
        event.sequence >= current.events.last.sequence;
    final updatedEvents = <RunEvent>[...current.events, event];
    if (!inOrder) {
      updatedEvents.sort((a, b) => a.sequence.compareTo(b.sequence));
    }

    final updatedStatus = _statusFromEvent(event.type, current.run.status);
    final updatedRun = current.run.copyWith(
      status: updatedStatus,
      finishedAt: _isTerminalOrInterrupted(updatedStatus)
          ? (current.run.finishedAt ?? event.createdAt)
          : null,
    );

    final ({Map<String, HiveNodeStatus> nodeStatuses, String? activeNodeId})
    derived;
    if (inOrder) {
      final mutableStatuses = Map<String, HiveNodeStatus>.of(
        current.nodeStatuses,
      );
      final nextGraph = _applyEventToGraphState(
        mutableStatuses,
        event,
        runningNodeId: _runningNodeId,
        lastTouchedNodeId: _lastTouchedNodeId,
      );
      _runningNodeId = nextGraph.runningNodeId;
      _lastTouchedNodeId = nextGraph.lastTouchedNodeId;
      derived = (
        nodeStatuses: Map<String, HiveNodeStatus>.unmodifiable(mutableStatuses),
        activeNodeId: _runningNodeId ?? _lastTouchedNodeId,
      );
    } else {
      final full = _deriveGraphState(updatedRun, updatedEvents);
      _runningNodeId = full.runningNodeId;
      _lastTouchedNodeId = full.lastTouchedNodeId;
      derived = (
        nodeStatuses: full.nodeStatuses,
        activeNodeId: full.activeNodeId,
      );
    }

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
    if (_logsLoadInFlight) {
      _pendingWsOutput.add(payload);
      return;
    }

    final current = state.asData?.value;
    if (current == null) return;

    if (payload.nodeId != current.inspectedNodeId) return;

    var nextAttempts = current.availableAttempts;
    if (!nextAttempts.contains(payload.attempt)) {
      nextAttempts = <int>[...nextAttempts, payload.attempt]..sort();
    }

    final currentAttempt = current.selectedAttempt;
    if (currentAttempt != null &&
        payload.attempt > currentAttempt &&
        current.followActiveNode) {
      _lastLoadedLogOffset = 0;
      _clearLogController();
      state = AsyncData(
        current.copyWith(
          availableAttempts: nextAttempts,
          selectedAttempt: () => payload.attempt,
          logsTruncated: false,
        ),
      );
      _appendLogPayload(payload);
      return;
    }

    final targetAttempt = currentAttempt ?? payload.attempt;
    if (targetAttempt != payload.attempt) {
      if (!identical(nextAttempts, current.availableAttempts)) {
        state = AsyncData(current.copyWith(availableAttempts: nextAttempts));
      }
      return;
    }

    if (current.selectedAttempt == null ||
        !identical(nextAttempts, current.availableAttempts)) {
      state = AsyncData(
        current.copyWith(
          availableAttempts: nextAttempts,
          selectedAttempt: () => targetAttempt,
        ),
      );
    }

    _appendLogPayload(payload);
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

  Future<void> _resyncAfterReconnect() async {
    final current = state.asData?.value;
    if (current == null || !ref.mounted) return;

    final afterSequence = current.events.isEmpty
        ? null
        : current.events.last.sequence;
    final inspectedNodeId = current.inspectedNodeId;
    final selectedAttempt = current.selectedAttempt;

    final runFuture = ref.read(getRunProvider).call(runId);
    final eventsFuture = ref
        .read(getRunEventsProvider)
        .call(runId, afterSequence: afterSequence);
    final logsFuture = inspectedNodeId != null
        ? ref
              .read(getNodeLogsProvider)
              .call(runId, inspectedNodeId, attempt: selectedAttempt)
        : null;

    final runResult = await runFuture;
    final eventsResult = await eventsFuture;
    final logsResult = logsFuture != null ? await logsFuture : null;
    if (!ref.mounted) return;

    final latest = state.asData?.value;
    if (latest == null) return;

    final updatedRun = switch (runResult) {
      Success<Run>(:final value) => value,
      FailureResult<Run>() => latest.run,
    };

    var updatedEvents = latest.events;
    if (eventsResult case Success<RunEventsResponse>(:final value)) {
      if (value.items.isNotEmpty) {
        final seenIds = <String>{for (final e in latest.events) e.id};
        final additions = <RunEvent>[
          for (final e in value.items)
            if (seenIds.add(e.id)) e,
        ];
        if (additions.isNotEmpty) {
          updatedEvents = <RunEvent>[...latest.events, ...additions]
            ..sort((a, b) => a.sequence.compareTo(b.sequence));
        }
      }
    }

    final derived = _deriveGraphState(updatedRun, updatedEvents);
    _runningNodeId = derived.runningNodeId;
    _lastTouchedNodeId = derived.lastTouchedNodeId;

    var nextAvailableAttempts = latest.availableAttempts;
    var nextSelectedAttempt = latest.selectedAttempt;
    var nextLogsTruncated = latest.logsTruncated;

    if (logsResult case Success<RunNodeLogsResponse>(:final value)
        when inspectedNodeId != null &&
            latest.inspectedNodeId == inspectedNodeId &&
            (latest.selectedAttempt == null ||
                latest.selectedAttempt == value.attempt)) {
      nextAvailableAttempts = value.availableAttempts;
      nextSelectedAttempt = value.attempt;
      nextLogsTruncated = value.truncated;

      for (final entry in value.entries) {
        if (entry.offset > 0) {
          if (entry.offset <= _lastLoadedLogOffset) continue;
          _appendLogChunk(entry.chunk, stream: entry.stream);
          _lastLoadedLogOffset = entry.offset;
        } else if (_lastLoadedLogOffset == 0 && logController.isEmpty) {
          _appendLogChunk(entry.chunk, stream: entry.stream);
        }
      }
      final maxOffset = _maxEntryOffset(value);
      if (maxOffset > _lastLoadedLogOffset) {
        _lastLoadedLogOffset = maxOffset;
      }
    }

    state = AsyncData(
      latest.copyWith(
        run: updatedRun,
        events: updatedEvents,
        nodeStatuses: derived.nodeStatuses,
        activeNodeId: () => derived.activeNodeId,
        availableAttempts: nextAvailableAttempts,
        selectedAttempt: () => nextSelectedAttempt,
        logsTruncated: nextLogsTruncated,
      ),
    );
  }

  Future<void> _loadNodeLogs(String nodeId, {int? attempt}) async {
    final token = ++_logsRequestToken;
    _logsLoadInFlight = true;
    _pendingWsOutput.clear();
    _lastLoadedLogOffset = 0;
    _clearLogController();

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
    _logsLoadInFlight = false;

    final latest = state.asData?.value;
    switch (result) {
      case Success<RunNodeLogsResponse>(:final value):
        for (final entry in value.entries) {
          _appendLogChunk(entry.chunk, stream: entry.stream);
        }
        _lastLoadedLogOffset = _maxEntryOffset(value);
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
        final pending = _sortedPendingOutput(_pendingWsOutput);
        _pendingWsOutput.clear();
        pending.forEach(_onRunOutput);
      case FailureResult<RunNodeLogsResponse>(:final failure):
        _pendingWsOutput.clear();
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
    _logsLoadInFlight = true;
    _pendingWsOutput.clear();
    _lastLoadedLogOffset = 0;

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
    _runningNodeId = derived.runningNodeId;
    _lastTouchedNodeId = derived.lastTouchedNodeId;

    final inspectedNodeId = followActiveNode
        ? derived.activeNodeId
        : (preferredInspectedNodeId ?? derived.activeNodeId);

    var availableAttempts = const <int>[];
    var selectedAttempt = preferredAttempt;
    var logsTruncated = false;

    if (!ref.mounted) {
      _logsLoadInFlight = false;
      _pendingWsOutput.clear();
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

    _clearLogController();
    if (inspectedNodeId != null) {
      final logsResult = await ref
          .read(getNodeLogsProvider)
          .call(id, inspectedNodeId, attempt: preferredAttempt);
      if (!ref.mounted) {
        _logsLoadInFlight = false;
        _pendingWsOutput.clear();
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
      if (logsResult case Success<RunNodeLogsResponse>(:final value)) {
        availableAttempts = List<int>.of(value.availableAttempts);
        selectedAttempt = value.attempt;
        logsTruncated = value.truncated;
        for (final entry in value.entries) {
          _appendLogChunk(entry.chunk, stream: entry.stream);
        }
        _lastLoadedLogOffset = _maxEntryOffset(value);
      }
    }

    _logsLoadInFlight = false;
    final pending = _sortedPendingOutput(_pendingWsOutput);
    _pendingWsOutput.clear();
    if (inspectedNodeId != null && pending.isNotEmpty) {
      for (final payload in pending) {
        if (payload.nodeId != inspectedNodeId) continue;
        if (!availableAttempts.contains(payload.attempt)) {
          availableAttempts = <int>[...availableAttempts, payload.attempt]
            ..sort();
        }
        if (selectedAttempt != null &&
            payload.attempt > selectedAttempt &&
            followActiveNode) {
          selectedAttempt = payload.attempt;
          logsTruncated = false;
          _lastLoadedLogOffset = 0;
          _clearLogController();
          _appendLogPayload(payload);
          continue;
        }
        selectedAttempt ??= payload.attempt;
        if (payload.attempt == selectedAttempt) {
          _appendLogPayload(payload);
        }
      }
    }

    _initialLoadCompleted = true;

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
      RunEventType.nodeFallback ||
      RunEventType.checkpointSaved ||
      RunEventType.snapshotCaptured ||
      RunEventType.snapshotRestored ||
      RunEventType.snapshotWarning ||
      RunEventType.warning => fallback,
    };
  }

  static bool _isTerminalOrInterrupted(RunStatus status) => !status.isActive;

  static ({
    Map<String, HiveNodeStatus> nodeStatuses,
    String? activeNodeId,
    String? runningNodeId,
    String? lastTouchedNodeId,
  })
  _deriveGraphState(Run run, List<RunEvent> events) {
    final statuses = <String, HiveNodeStatus>{
      for (final node in run.workflowDefinition.nodes)
        node.id: HiveNodeStatus.idle,
    };
    String? runningNodeId;
    String? lastTouchedNodeId;

    for (final event in events) {
      final next = _applyEventToGraphState(
        statuses,
        event,
        runningNodeId: runningNodeId,
        lastTouchedNodeId: lastTouchedNodeId,
      );
      runningNodeId = next.runningNodeId;
      lastTouchedNodeId = next.lastTouchedNodeId;
    }

    return (
      nodeStatuses: Map<String, HiveNodeStatus>.unmodifiable(statuses),
      activeNodeId: runningNodeId ?? lastTouchedNodeId,
      runningNodeId: runningNodeId,
      lastTouchedNodeId: lastTouchedNodeId,
    );
  }

  static ({String? runningNodeId, String? lastTouchedNodeId})
  _applyEventToGraphState(
    Map<String, HiveNodeStatus> statuses,
    RunEvent event, {
    required String? runningNodeId,
    required String? lastTouchedNodeId,
  }) {
    var nextRunning = runningNodeId;
    var nextLastTouched = lastTouchedNodeId;
    final nodeId = event.nodeId;
    switch (event.type) {
      case RunEventType.nodeStarted:
        if (nodeId != null) {
          statuses[nodeId] = HiveNodeStatus.running;
          nextRunning = nodeId;
          nextLastTouched = nodeId;
        }
      case RunEventType.nodeCompleted:
        if (nodeId != null) {
          statuses[nodeId] = HiveNodeStatus.succeeded;
          if (nextRunning == nodeId) nextRunning = null;
          nextLastTouched = nodeId;
        }
      case RunEventType.nodeFailed:
        if (nodeId != null) {
          statuses[nodeId] = HiveNodeStatus.failed;
          if (nextRunning == nodeId) nextRunning = null;
          nextLastTouched = nodeId;
        }
      case RunEventType.nodeRetried:
        if (nodeId != null) {
          statuses[nodeId] = HiveNodeStatus.idle;
          if (nextRunning == nodeId) nextRunning = null;
          nextLastTouched = nodeId;
        }
      case RunEventType.runPaused:
        final target = nodeId ?? nextRunning;
        if (target != null) {
          statuses[target] = HiveNodeStatus.paused;
          nextRunning = target;
          nextLastTouched = target;
        }
      case RunEventType.runResumed:
        if (nextRunning != null) {
          statuses[nextRunning] = HiveNodeStatus.running;
        }
      case RunEventType.runCancelling:
        for (final entry in statuses.entries.toList()) {
          if (entry.value == HiveNodeStatus.running ||
              entry.value == HiveNodeStatus.paused ||
              entry.value == HiveNodeStatus.cancellationUncertain) {
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
              entry.value == HiveNodeStatus.cancelling ||
              entry.value == HiveNodeStatus.cancellationUncertain) {
            statuses[entry.key] = HiveNodeStatus.cancelled;
          }
        }
        nextRunning = null;
      case RunEventType.runInterrupted:
        for (final entry in statuses.entries.toList()) {
          if (entry.value == HiveNodeStatus.running ||
              entry.value == HiveNodeStatus.paused ||
              entry.value == HiveNodeStatus.cancelling ||
              entry.value == HiveNodeStatus.cancellationUncertain) {
            statuses[entry.key] = HiveNodeStatus.interrupted;
          }
        }
        nextRunning = null;
      case RunEventType.runStarted:
      case RunEventType.runSucceeded:
      case RunEventType.runFailed:
      case RunEventType.nodeFallback:
      case RunEventType.checkpointSaved:
      case RunEventType.snapshotCaptured:
      case RunEventType.snapshotRestored:
      case RunEventType.snapshotWarning:
      case RunEventType.warning:
        break;
    }

    return (runningNodeId: nextRunning, lastTouchedNodeId: nextLastTouched);
  }
}
