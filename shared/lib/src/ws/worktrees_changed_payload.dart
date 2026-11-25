import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/worktree.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'worktrees_changed_payload.freezed.dart';
part 'worktrees_changed_payload.g.dart';

/// Kind of change reported in [WorktreesChangedPayload].
enum WorktreeChangeKind {
  /// A worktree was created in a git workspace.
  created,

  /// A worktree was removed from a git workspace.
  removed,
}

/// Payload of a `worktrees.changed` WebSocket event.
///
/// [workspaceId] names the workspace the worktree belongs to. [worktree] is
/// absent for a removal.
@freezed
sealed class WorktreesChangedPayload with _$WorktreesChangedPayload {
  /// Creates a worktrees-changed payload.
  const factory({
    required WorktreeChangeKind kind,
    required String workspaceId,
    required String worktreeId,
    Worktree? worktree,
  }) = _WorktreesChangedPayload;

  /// Decodes a worktrees-changed payload; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorktreesChangedPayloadFromJson);
}
