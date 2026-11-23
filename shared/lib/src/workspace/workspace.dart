import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace.freezed.dart';
part 'workspace.g.dart';

/// A registered workspace: a named entity with exactly one root folder
/// (ADR 0025).
///
/// [rootPath] is unique per workspace. [isGit] is detected when the workspace
/// is registered; non-git folders are valid workspaces. [activeRunCount] is the
/// number of runs in `running`, `paused` or `cancelling` status, so a client
/// can warn before unregistering.
@freezed
sealed class Workspace with _$Workspace {
  /// Creates a workspace.
  const factory({
    required String id,
    required String name,
    required String rootPath,
    required bool isGit,
    required DateTime createdAt,
    required DateTime updatedAt,
    @Default(0) int activeRunCount,
  }) = _Workspace;

  /// Decodes a workspace; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) => parseJson(json, _$WorkspaceFromJson);
}
