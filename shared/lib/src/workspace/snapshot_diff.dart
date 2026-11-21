import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/snapshot_file_change.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot_diff.freezed.dart';
part 'snapshot_diff.g.dart';

/// List of files changed in a workspace snapshot.
@freezed
sealed class SnapshotDiff with _$SnapshotDiff {
  /// Creates a snapshot diff.
  const factory({
    required String snapshotId,
    required List<SnapshotFileChange> files,
  }) = _SnapshotDiff;

  /// Decodes a snapshot diff; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$SnapshotDiffFromJson);
}
