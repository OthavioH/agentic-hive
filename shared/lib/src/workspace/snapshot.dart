import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/snapshot_kind.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot.freezed.dart';
part 'snapshot.g.dart';

/// A workspace snapshot stored in a run's shadow git repository.
@freezed
sealed class Snapshot with _$Snapshot {
  /// Creates a snapshot record.
  const factory({
    required String id,
    required String runId,
    required String commitHash,
    required SnapshotKind kind,
    required int addedCount,
    required int modifiedCount,
    required int deletedCount,
    required DateTime createdAt,
    String? nodeId,
  }) = _Snapshot;

  /// Decodes a snapshot; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$SnapshotFromJson);
}
