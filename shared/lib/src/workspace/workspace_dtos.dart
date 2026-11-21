import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/snapshot.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_dtos.freezed.dart';
part 'workspace_dtos.g.dart';

/// Response body for `GET /api/v1/runs/:id/snapshots`.
@freezed
sealed class RunSnapshotsResponse with _$RunSnapshotsResponse {
  /// Creates a run-snapshots response.
  const factory({required List<Snapshot> items}) = _RunSnapshotsResponse;

  /// Decodes a run-snapshots response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RunSnapshotsResponseFromJson);
}

/// Response body for `POST /api/v1/runs/:id/snapshots/:snapshotId/restore`.
@freezed
sealed class RestoreSnapshotResponse with _$RestoreSnapshotResponse {
  /// Creates a restore-snapshot response.
  const factory({
    required String restoredSnapshotId,
    required Snapshot safetySnapshot,
  }) = _RestoreSnapshotResponse;

  /// Decodes a restore-snapshot response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RestoreSnapshotResponseFromJson);
}
