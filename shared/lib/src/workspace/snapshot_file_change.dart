import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/snapshot_change_type.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'snapshot_file_change.freezed.dart';
part 'snapshot_file_change.g.dart';

/// A single file changed in a workspace snapshot.
@freezed
sealed class SnapshotFileChange with _$SnapshotFileChange {
  /// Creates a snapshot file change entry.
  const factory({
    required String path,
    required SnapshotChangeType changeType,
  }) = _SnapshotFileChange;

  /// Decodes a file change entry; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$SnapshotFileChangeFromJson);
}
