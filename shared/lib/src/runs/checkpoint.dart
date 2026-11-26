import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'checkpoint.freezed.dart';
part 'checkpoint.g.dart';

/// Saved graph execution state at the end of a node.
@freezed
sealed class Checkpoint with _$Checkpoint {
  /// Creates a checkpoint.
  const factory({
    required String id,
    required String runId,
    required int sequence,
    required List<String> pendingNodeIds,
    required Map<String, int> attemptsByEdge,
    required int circuitBreakerCount,
    required Map<String, JsonMap> nodeOutputs,
    required DateTime createdAt,
    String? completedNodeId,

    /// Per-node fallback index: absent means the node runs on its own harness;
    /// value `i` means the node runs on `fallback[i]` (0-based). Old JSON
    /// without this key decodes to `{}` (ADR 0007).
    @Default(<String, int>{}) Map<String, int> fallbackIndexByNodeId,
  }) = _Checkpoint;

  /// Decodes a checkpoint; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$CheckpointFromJson);
}
