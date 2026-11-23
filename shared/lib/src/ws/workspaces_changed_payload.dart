import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/workspace.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspaces_changed_payload.freezed.dart';
part 'workspaces_changed_payload.g.dart';

/// Kind of change reported in [WorkspacesChangedPayload].
enum WorkspaceChangeKind {
  /// A workspace was registered.
  created,

  /// A workspace was renamed or otherwise updated.
  updated,

  /// A workspace was unregistered.
  deleted,
}

/// Payload of a `workspaces.changed` WebSocket event.
///
/// [id] is the workspace id. [workspace] is absent for a deletion.
@freezed
sealed class WorkspacesChangedPayload with _$WorkspacesChangedPayload {
  /// Creates a workspaces-changed payload.
  const factory({
    required WorkspaceChangeKind kind,
    required String id,
    Workspace? workspace,
  }) = _WorkspacesChangedPayload;

  /// Decodes a workspaces-changed payload; throws a [FormatException] on a
  /// bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkspacesChangedPayloadFromJson);
}
