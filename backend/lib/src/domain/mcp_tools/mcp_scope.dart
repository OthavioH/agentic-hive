import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// How an [McpScope] was resolved for a tool call.
enum McpScopeSource {
  /// From the `workspace` argument.
  argument,

  /// From the caller's current directory.
  currentDirectory,

  /// From the caller's current worktree.
  worktree,

  /// No workspace matched; the Global scope.
  fallback,
}

/// Resolved scope for an MCP workflow tool call.
sealed class McpScope {
  const new({required this.source});

  /// How this scope was selected.
  final McpScopeSource source;

  /// Workspace id, or `null` for the Global scope.
  String? get workspaceId;

  /// Human-readable scope label for error messages (R9).
  String get label;

  /// First line of every scoped tool response (R6).
  String get header;
}

/// The Global workflow scope.
final class GlobalMcpScope extends McpScope {
  /// Creates a Global scope with [source] (`argument` or `fallback`).
  const new({required super.source});

  @override
  String? get workspaceId => null;

  @override
  String get label => 'the Global scope';

  @override
  String get header => switch (source) {
    McpScopeSource.argument => 'Scope: Global (from the workspace argument)',
    McpScopeSource.fallback ||
    McpScopeSource.currentDirectory ||
    McpScopeSource.worktree =>
      'Scope: Global (default: no workspace contains the current directory)',
  };
}

/// A registered workspace scope.
final class WorkspaceMcpScope extends McpScope {
  /// Creates a workspace scope for [workspace] with [source].
  const new({required this.workspace, required super.source});

  /// The resolved workspace.
  final Workspace workspace;

  @override
  String? get workspaceId => workspace.id;

  @override
  String get label => 'workspace "${workspace.name}"';

  @override
  String get header {
    final sourceText = switch (source) {
      McpScopeSource.argument => 'from the workspace argument',
      McpScopeSource.currentDirectory => 'from the current directory',
      McpScopeSource.worktree => 'from the current worktree',
      McpScopeSource.fallback => 'from the workspace argument',
    };
    return 'Scope: workspace "${workspace.name}" '
        '(id ${workspace.id}, root ${workspace.rootPath}; $sourceText)';
  }
}
