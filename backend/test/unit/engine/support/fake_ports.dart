import 'dart:async';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';
import 'package:agentic_hive_backend/src/domain/workspace/snapshot_service.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Scripted behavior of a fake node execution.
typedef NodeBehavior = Future<Result<NodeOutcome>> Function(
  NodeExecutionContext context,
);

/// Behavior returning [label] with optional [data].
NodeBehavior outcome(String label, {Map<String, Object?> data = const {}}) =>
    (_) async => Success(NodeOutcome(outputLabel: label, data: data));

/// Behavior failing with an infrastructure [NodeExecutionFailure].
NodeBehavior infraFailure([String message = 'process crashed']) =>
    (_) async => FailureResult(NodeExecutionFailure(message));

/// Behavior that waits for [gate] before returning [label].
NodeBehavior outcomeAfter(Future<void> gate, String label) => (_) async {
  await gate;
  return Success(NodeOutcome(outputLabel: label));
};

/// Shared script and recorder for [FakeNode]s, keyed by node id.
final class NodeScript {
  /// Creates an empty script.
  new();

  final Map<String, List<NodeBehavior>> _behaviors =
      <String, List<NodeBehavior>>{};

  /// Contexts of every execution in start order.
  final List<NodeExecutionContext> executions = <NodeExecutionContext>[];

  /// Number of nodes executing right now.
  int active = 0;

  /// The highest number of nodes that executed at once.
  int maxActive = 0;

  /// Scripts the successive executions of [nodeId]; the last behavior repeats.
  void on(String nodeId, List<NodeBehavior> behaviors) =>
      _behaviors[nodeId] = behaviors;

  /// How many times [nodeId] ran.
  int runsOf(String nodeId) =>
      executions.where((c) => c.nodeId == nodeId).length;

  /// Node ids in start order.
  List<String> get startOrder => executions.map((c) => c.nodeId).toList();

  /// Executes the scripted behavior for [context].
  Future<Result<NodeOutcome>> run(NodeExecutionContext context) async {
    executions.add(context);
    final count = runsOf(context.nodeId);
    final behaviors = _behaviors[context.nodeId];
    final behavior = behaviors == null
        ? outcome(NodeOutput.onSuccess)
        : behaviors[(count - 1).clamp(0, behaviors.length - 1)];
    active++;
    if (active > maxActive) maxActive = active;
    try {
      return await behavior(context);
    } finally {
      active--;
    }
  }
}

/// A [Node] whose execution is scripted through a [NodeScript].
final class FakeNode extends Node {
  /// Creates a fake node.
  const new(this.script);

  /// The shared script.
  final NodeScript script;

  @override
  String get typeId => NodeTypeId.command;

  @override
  NodeDescriptor get descriptor => NodeDescriptors.command;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) =>
      script.run(context);
}

/// [SnapshotService] recording calls and detecting concurrent captures.
final class FakeSnapshotService implements SnapshotService {
  /// Creates a fake snapshot service.
  new();

  /// Nodes snapshotted, in order.
  final List<String?> captured = <String?>[];

  /// Snapshot ids restored, in order.
  final List<String> restored = <String>[];

  /// Snapshots known to the service, in creation order.
  final List<Snapshot> snapshots = <Snapshot>[];

  /// Highest number of captures in flight at once.
  int maxInFlight = 0;

  /// When set, every capture fails with this failure.
  Failure? captureFailure;

  /// When set, every restore fails with this failure.
  Failure? restoreFailure;

  /// Clock stamped on new snapshots.
  DateTime Function() clock = () => DateTime.now().toUtc();

  int _inFlight = 0;
  int _next = 1;

  @override
  Future<Result<Snapshot>> captureSnapshot({
    required String runId,
    required String workspaceDir,
    String? nodeId,
    SnapshotKind kind = SnapshotKind.preNode,
  }) async {
    _inFlight++;
    if (_inFlight > maxInFlight) maxInFlight = _inFlight;
    await Future<void>.delayed(Duration.zero);
    _inFlight--;
    if (captureFailure case final failure?) return FailureResult(failure);
    captured.add(nodeId);
    final snapshot = Snapshot(
      id: 'snap-${_next++}',
      runId: runId,
      commitHash: 'hash',
      kind: kind,
      addedCount: 0,
      modifiedCount: 0,
      deletedCount: 0,
      createdAt: clock(),
      nodeId: nodeId,
    );
    snapshots.add(snapshot);
    return Success(snapshot);
  }

  @override
  Future<Result<RunSnapshotsResponse>> listSnapshots(String runId) async =>
      Success(RunSnapshotsResponse(items: List<Snapshot>.of(snapshots)));

  @override
  Future<Result<RestoreSnapshotResponse>> restoreSnapshot(
    String runId,
    String snapshotId,
  ) async {
    if (restoreFailure case final failure?) return FailureResult(failure);
    restored.add(snapshotId);
    return Success(
      RestoreSnapshotResponse(
        restoredSnapshotId: snapshotId,
        safetySnapshot: snapshots.first,
      ),
    );
  }
}

/// [ProcessTreeKiller] recording kills; confirmation can be held back.
final class FakeProcessTreeKiller implements ProcessTreeKiller {
  /// Creates a fake killer.
  new();

  /// Kill requests as `(runId, nodeId)`.
  final List<(String, String?)> kills = <(String, String?)>[];

  /// Called when a kill is requested, before confirmation (typically to make
  /// the killed node's execution return).
  void Function(String runId, String? nodeId)? onKill;

  /// When set, a kill is confirmed only once this future completes.
  Future<void>? confirmation;

  /// When set, kills fail with this failure.
  Failure? failure;

  /// Whether a kill has been confirmed.
  bool confirmed = false;

  @override
  Future<Result<void>> killTree({required String runId, String? nodeId}) async {
    kills.add((runId, nodeId));
    onKill?.call(runId, nodeId);
    if (confirmation != null) await confirmation;
    if (failure case final f?) return FailureResult(f);
    confirmed = true;
    return const Success(null);
  }
}

/// In-memory [RunAttachmentStore] for engine and recovery unit tests.
final class FakeRunAttachmentStore implements RunAttachmentStore {
  /// Creates a fake attachment store.
  new();

  /// Run ids that currently have an attachments folder.
  final Set<String> folders = <String>{};

  /// Run ids passed to [deleteRun], in call order.
  final List<String> deleteCalls = <String>[];

  /// When `true`, [deleteRun] returns a [PersistenceFailure] without removing.
  bool failDeletes = false;

  /// When `true`, [listRunIds] returns a [PersistenceFailure].
  bool failListRunIds = false;

  @override
  String attachmentsDir(String runId) => '/runs/$runId/attachments';

  @override
  String filePath(String runId, int index, RunAttachment attachment) {
    final extension = runAttachmentExtensions[attachment.mimeType] ?? 'bin';
    return p.posix.join(attachmentsDir(runId), '${index + 1}.$extension');
  }

  @override
  Future<Result<void>> write(
    String runId,
    List<DecodedRunAttachment> files,
  ) async {
    folders.add(runId);
    return const Success(null);
  }

  @override
  Future<Result<void>> deleteRun(String runId) async {
    deleteCalls.add(runId);
    if (failDeletes) {
      return const FailureResult(PersistenceFailure('disk error'));
    }
    folders.remove(runId);
    return const Success(null);
  }

  @override
  Future<Result<List<String>>> listRunIds() async {
    if (failListRunIds) {
      return const FailureResult(PersistenceFailure('list error'));
    }
    return Success(folders.toList());
  }
}
