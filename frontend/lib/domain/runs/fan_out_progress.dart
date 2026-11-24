import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// One item of a fan-out node as the monitor shows it.
final class FanOutItem {
  /// Creates a [FanOutItem].
  const new({
    required this.index,
    required this.name,
    required this.status,
    this.runId,
    this.deleted = false,
    this.error,
  });

  /// Zero-based index of the item within the fan-out list.
  final int index;

  /// Display name of the item, or empty string when using a fallback label.
  final String name;

  /// Current or recorded status of the child run.
  final RunStatus status;

  /// Child run ID when a run was started for this item.
  final String? runId;

  /// Whether the item's child run existed in output but was deleted.
  final bool deleted;

  /// Failure message if the item failed or could not be started.
  final String? error;

  /// Whether the child run reached a final status (interrupted is not final).
  bool get isFinal => deleted || _finalStatuses.contains(status);

  /// Whether the item ended without success.
  bool get isFailure => isFinal && status != RunStatus.succeeded;

  /// Whether the child waits for a human.
  bool get needsHuman => !deleted && status == RunStatus.paused;

  /// Whether the item can be opened in the monitor.
  bool get isOpenable => runId != null && !deleted;
}

const Set<RunStatus> _finalStatuses = <RunStatus>{
  RunStatus.succeeded,
  RunStatus.failed,
  RunStatus.cancelled,
  RunStatus.cancellationUncertain,
};

/// Progress of one fan-out node derived from its child runs and its output.
final class FanOutProgress {
  /// Creates a [FanOutProgress].
  const new({required this.items, this.emptyList = false});

  /// Builds the progress for [nodeId].
  ///
  /// [children]: every loaded child run of the parent (any node); only those
  /// with `parentNodeId == nodeId` are used. [nodeOutputEntry]: the node's
  /// entry of the latest checkpoint's `nodeOutputs` (`{'data': {...}}`) or
  /// null.
  factory of({
    required String nodeId,
    required List<Run> children,
    required Object? nodeOutputEntry,
  }) {
    final latestByIndex = <int, Run>{};
    for (final run in children) {
      if (run.parentNodeId != nodeId) continue;
      final index = run.childIndex ?? 0;
      final existing = latestByIndex[index];
      if (existing == null || !run.startedAt.isBefore(existing.startedAt)) {
        latestByIndex[index] = run;
      }
    }

    final itemsByIndex = <int, FanOutItem>{
      for (final entry in latestByIndex.entries)
        entry.key: FanOutItem(
          index: entry.key,
          name: entry.value.childName ?? '',
          status: entry.value.status,
          runId: entry.value.id,
          error: entry.value.errorMessage,
        ),
    };

    final data = nodeOutputEntry is Map ? nodeOutputEntry['data'] : null;
    final emptyList = data is Map && data['total'] == 0;
    final entries = data is Map ? data['children'] : null;
    if (entries is List) {
      for (final rawEntry in entries) {
        if (rawEntry is! Map) continue;
        final index = rawEntry['index'];
        if (index is! int || itemsByIndex.containsKey(index)) continue;
        final rawRunId = rawEntry['runId'];
        final runId = rawRunId is String ? rawRunId : null;
        final rawName = rawEntry['name'];
        final name = rawName is String ? rawName : '';
        final rawError = rawEntry['error'];
        final error = rawError is String ? rawError : null;
        final rawStatus = rawEntry['status'];
        final status =
            RunStatus.values.where((s) => s.name == rawStatus).firstOrNull ??
            RunStatus.failed;
        itemsByIndex[index] = FanOutItem(
          index: index,
          name: name,
          status: status,
          runId: runId,
          deleted: runId != null,
          error: error,
        );
      }
    }

    final items = itemsByIndex.values.toList()
      ..sort((a, b) => a.index.compareTo(b.index));

    return FanOutProgress(items: items, emptyList: emptyList);
  }

  /// Ordered items of this fan-out node.
  final List<FanOutItem> items;

  /// Whether the node completed with zero input items (`total == 0`).
  final bool emptyList;

  /// Total number of known items.
  int get total => items.length;

  /// Number of items that reached a final state (including deleted runs).
  int get done => items.where((i) => i.isFinal).length;

  /// Number of final items that did not succeed.
  int get failed => items.where((i) => i.isFailure).length;

  /// Number of live child runs currently paused waiting for human input.
  int get needsHuman => items.where((i) => i.needsHuman).length;

  /// Whether no items exist.
  bool get isEmpty => items.isEmpty;
}
