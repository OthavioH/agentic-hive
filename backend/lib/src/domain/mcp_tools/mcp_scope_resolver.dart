import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_backend/src/util/canonical_folder.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// Resolves the [McpScope] for a workflow tool call from an optional
/// `workspace` argument and the caller's `cwd` (R4, R5).
final class McpScopeResolver {
  /// Creates a scope resolver.
  new({
    required this._workspaces,
    required this._worktreesDir,
    required this._path,
  });

  final WorkspaceRepository _workspaces;
  final String _worktreesDir;
  final p.Context _path;

  /// The reserved workspace argument that selects the Global scope.
  static const globalToken = 'global';

  /// Resolves the scope according to R4.
  Future<Result<McpScope>> resolve({String? workspace, String? cwd}) async {
    final listed = await _workspaces.list();
    return switch (listed) {
      FailureResult(:final failure) => FailureResult(failure),
      Success(value: final items) => _resolveWithList(
        items,
        workspace: workspace,
        cwd: cwd,
      ),
    };
  }

  Result<McpScope> _resolveWithList(
    List<Workspace> items, {
    String? workspace,
    String? cwd,
  }) {
    final trimmedArg = workspace?.trim();
    if (trimmedArg != null && trimmedArg.isNotEmpty) {
      if (trimmedArg.toLowerCase() == globalToken) {
        return const Success(GlobalMcpScope(source: McpScopeSource.argument));
      }
      for (final ws in items) {
        if (ws.id == trimmedArg) {
          return Success(
            WorkspaceMcpScope(workspace: ws, source: McpScopeSource.argument),
          );
        }
      }
      if (_path.isAbsolute(trimmedArg)) {
        final canonicalArg = canonicalFolder(trimmedArg, _path);
        for (final ws in items) {
          if (_path.equals(canonicalArg, canonicalFolder(ws.rootPath, _path))) {
            return Success(
              WorkspaceMcpScope(workspace: ws, source: McpScopeSource.argument),
            );
          }
        }
      }
      return FailureResult(
        NotFoundFailure(
          'Unknown workspace "$trimmedArg": pass the workspace root path or '
          'id (see list_workspaces).',
        ),
      );
    }

    final trimmedCwd = cwd?.trim();
    if (trimmedCwd != null &&
        trimmedCwd.isNotEmpty &&
        _path.isAbsolute(trimmedCwd)) {
      final canonicalCwd = canonicalFolder(trimmedCwd, _path);
      Workspace? deepest;
      var deepestLen = -1;
      for (final ws in items) {
        final canonicalRoot = canonicalFolder(ws.rootPath, _path);
        if (_path.equals(canonicalCwd, canonicalRoot) ||
            _path.isWithin(canonicalRoot, canonicalCwd)) {
          if (canonicalRoot.length > deepestLen) {
            deepest = ws;
            deepestLen = canonicalRoot.length;
          }
        }
      }
      if (deepest != null) {
        return Success(
          WorkspaceMcpScope(
            workspace: deepest,
            source: McpScopeSource.currentDirectory,
          ),
        );
      }

      final canonicalWorktrees = canonicalFolder(_worktreesDir, _path);
      if (_path.equals(canonicalCwd, canonicalWorktrees) ||
          _path.isWithin(canonicalWorktrees, canonicalCwd)) {
        final rel = _path.relative(canonicalCwd, from: canonicalWorktrees);
        if (rel != '.' && rel.isNotEmpty) {
          final firstSeg = _path.split(rel).first;
          for (final ws in items) {
            if (ws.id == firstSeg) {
              return Success(
                WorkspaceMcpScope(
                  workspace: ws,
                  source: McpScopeSource.worktree,
                ),
              );
            }
          }
        }
      }
    }

    return const Success(GlobalMcpScope(source: McpScopeSource.fallback));
  }
}
