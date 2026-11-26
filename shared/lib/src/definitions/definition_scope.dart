import 'package:agentic_hive_shared/src/json_fields.dart';
import 'package:freezed_annotation/freezed_annotation.dart';

/// Reads the entire JSON map so [DefinitionScope.fromJson] can inspect both
/// `scope` and `workspaceId`.
JsonMap readWholeJson(Map<dynamic, dynamic> json, String _) =>
    json is JsonMap ? json : json.cast<String, Object?>();

/// The scope a definition (workflow, agent) belongs to (GLOSSARY: Scope).
@immutable
sealed class DefinitionScope {
  /// Creates a definition scope.
  const new();

  /// Decodes `scope` and `workspaceId` from [json].
  ///
  /// A missing or `null` `scope` decodes as [GlobalScope]. An unknown `scope`
  /// or `'workspace'` without a non-blank `workspaceId` throws
  /// [FormatException].
  factory fromJson(JsonMap json) {
    final raw = json['scope'];
    if (raw == null || raw == 'global') {
      return const GlobalScope();
    }
    if (raw == 'workspace') {
      final workspaceId = json['workspaceId'];
      if (workspaceId is String && workspaceId.trim().isNotEmpty) {
        return WorkspaceScope(workspaceId);
      }
      throw const FormatException(
        'Workspace scope requires a non-blank "workspaceId".',
      );
    }
    throw FormatException('Unknown DefinitionScope "$raw".');
  }

  /// Converts a bare nullable [workspaceId] at a wire boundary.
  ///
  /// `null` maps to [GlobalScope]; any non-null string maps to
  /// [WorkspaceScope].
  static DefinitionScope ofWorkspaceId(String? workspaceId) =>
      workspaceId == null ? const GlobalScope() : WorkspaceScope(workspaceId);

  /// Wire value of the `scope` key: `'global'` or `'workspace'`.
  String get wireName;

  /// Returns `workspaceId` for [WorkspaceScope], or `null` for [GlobalScope].
  ///
  /// Use only at wire boundaries that carry a bare nullable `workspaceId`.
  String? get workspaceIdOrNull => switch (this) {
    GlobalScope() => null,
    WorkspaceScope(:final workspaceId) => workspaceId,
  };

  /// Encodes this scope as `{'scope': wireName}` plus `{'workspaceId': id}`
  /// for [WorkspaceScope].
  JsonMap toJson();
}

/// Definition available in every workspace (GLOSSARY: Global scope).
@immutable
final class GlobalScope extends DefinitionScope {
  /// Creates a global scope.
  const new();

  @override
  String get wireName => 'global';

  @override
  JsonMap toJson() => {'scope': wireName};

  @override
  bool operator ==(Object other) => other is GlobalScope;

  @override
  int get hashCode => (GlobalScope).hashCode;

  @override
  String toString() => 'GlobalScope()';
}

/// Definition belonging to one workspace (GLOSSARY: Workspace scope).
@immutable
final class WorkspaceScope extends DefinitionScope {
  /// Creates a workspace scope for [workspaceId].
  const new(this.workspaceId);

  /// Identifier of the owning workspace.
  final String workspaceId;

  @override
  String get wireName => 'workspace';

  @override
  JsonMap toJson() => {'scope': wireName, 'workspaceId': workspaceId};

  @override
  bool operator ==(Object other) =>
      other is WorkspaceScope && other.workspaceId == workspaceId;

  @override
  int get hashCode => Object.hash(WorkspaceScope, workspaceId);

  @override
  String toString() => 'WorkspaceScope($workspaceId)';
}
