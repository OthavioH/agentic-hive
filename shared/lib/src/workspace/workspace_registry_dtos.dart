import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:agentic_hive_shared/src/workspace/workspace.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_registry_dtos.freezed.dart';
part 'workspace_registry_dtos.g.dart';

/// Request body for `POST /api/v1/workspaces`.
///
/// [rootPath] must be an absolute path to an existing folder. [name] defaults
/// to the folder name.
@freezed
sealed class CreateWorkspaceRequest with _$CreateWorkspaceRequest {
  /// Creates a create-workspace request.
  const factory({required String rootPath, String? name}) =
      _CreateWorkspaceRequest;

  /// Decodes a create-workspace request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$CreateWorkspaceRequestFromJson);
}

/// Request body for `PATCH /api/v1/workspaces/:id` (rename).
@freezed
sealed class UpdateWorkspaceRequest with _$UpdateWorkspaceRequest {
  /// Creates an update-workspace request.
  const factory({required String name}) = _UpdateWorkspaceRequest;

  /// Decodes an update-workspace request; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$UpdateWorkspaceRequestFromJson);
}

/// Response body for `GET /api/v1/workspaces`.
@freezed
sealed class WorkspaceListResponse with _$WorkspaceListResponse {
  /// Creates a workspace list response.
  const factory({required List<Workspace> items}) = _WorkspaceListResponse;

  /// Decodes a workspace list response; throws a [FormatException] on a bad
  /// shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkspaceListResponseFromJson);
}
