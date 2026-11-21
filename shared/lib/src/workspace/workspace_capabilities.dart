import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

part 'workspace_capabilities.freezed.dart';
part 'workspace_capabilities.g.dart';

/// Git and workspace capabilities reported by the backend pre-flight check.
@freezed
sealed class WorkspaceCapabilities with _$WorkspaceCapabilities {
  /// Creates workspace capabilities.
  const factory({
    required bool gitAvailable,
    required bool isGitRepo,
    required bool hasCommits,
    String? gitVersion,
  }) = _WorkspaceCapabilities;

  /// Decodes workspace capabilities; throws a [FormatException] on a bad shape.
  factory fromJson(JsonMap json) =>
      parseJson(json, _$WorkspaceCapabilitiesFromJson);
}
