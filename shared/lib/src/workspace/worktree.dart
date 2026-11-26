import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'worktree.freezed.dart';
part 'worktree.g.dart';

/// [Worktree.id] of the primary checkout of a workspace (ADR 0025). Worktree
/// names cannot use it, so it never collides with a real worktree.
const primaryWorktreeId = 'primary';

/// A checkout of a git workspace: its primary checkout or one of its
/// worktrees (ADR 0025).
///
/// [id] is the worktree [name] (the last segment of its directory); the
/// primary checkout uses the fixed id [primaryWorktreeId]. [branch] is null
/// when the checkout has a detached `HEAD`. [hasUncommittedChanges] is true
/// when the checkout has staged, unstaged or untracked changes. [isBroken] is
/// true for a broken worktree: its folder exists but git can no longer read it.
/// Its changes can't be inspected, so [hasUncommittedChanges] is then reported
/// as true.
@freezed
sealed class Worktree with _$Worktree {
  /// Creates a worktree.
  const factory({
    required String id,
    required String name,
    required String path,
    required bool isPrimary,
    required bool hasUncommittedChanges,
    @Default(false) bool isBroken,
    String? branch,
  }) = _Worktree;

  /// Decodes a worktree; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorktreeFromJson);
}

/// Request body for `POST /api/v1/workspaces/:id/worktrees`.
///
/// [name] becomes the directory name. [branch] is the new branch to create
/// and defaults to [name]. [baseBranch] defaults to the branch checked out in
/// the primary checkout.
@freezed
sealed class CreateWorktreeRequest with _$CreateWorktreeRequest {
  /// Creates a create-worktree request.
  const factory({required String name, String? branch, String? baseBranch}) =
      _CreateWorktreeRequest;

  /// Decodes a create-worktree request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$CreateWorktreeRequestFromJson);
}

/// Response body for `GET /api/v1/workspaces/:id/worktrees`.
///
/// The primary checkout comes first. A non-git workspace has no worktrees, so
/// its list is empty.
@freezed
sealed class WorktreeListResponse with _$WorktreeListResponse {
  /// Creates a worktree list response.
  const factory({required List<Worktree> items}) = _WorktreeListResponse;

  /// Decodes a worktree list response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorktreeListResponseFromJson);
}

/// Response body for `DELETE /api/v1/workspaces/:id/worktrees/:worktreeId`.
///
/// [branchDeleted] is false when the branch was kept because it is not merged
/// (or there was none); [notice] then explains why.
@freezed
sealed class RemoveWorktreeResponse with _$RemoveWorktreeResponse {
  /// Creates a remove-worktree response.
  const factory({
    required String id,
    required bool deleted,
    required bool branchDeleted,
    String? notice,
  }) = _RemoveWorktreeResponse;

  /// Decodes a remove-worktree response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$RemoveWorktreeResponseFromJson);
}
