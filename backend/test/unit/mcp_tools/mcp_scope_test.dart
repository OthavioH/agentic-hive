import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  final workspace = Workspace(
    id: 'ws-1',
    name: 'My App',
    rootPath: r'C:\repos\my-app',
    isGit: true,
    createdAt: DateTime.utc(2026),
    updatedAt: DateTime.utc(2026),
  );

  group('McpScope', () {
    test('headers match the exact texts', () {
      expect(
        const GlobalMcpScope(source: McpScopeSource.argument).header,
        'Scope: Global (from the workspace argument)',
      );
      expect(
        const GlobalMcpScope(source: McpScopeSource.fallback).header,
        'Scope: Global (default: no workspace contains the current directory)',
      );
      expect(
        WorkspaceMcpScope(
          workspace: workspace,
          source: McpScopeSource.argument,
        ).header,
        r'Scope: workspace "My App" (id ws-1, root C:\repos\my-app; from the workspace argument)',
      );
      expect(
        WorkspaceMcpScope(
          workspace: workspace,
          source: McpScopeSource.currentDirectory,
        ).header,
        r'Scope: workspace "My App" (id ws-1, root C:\repos\my-app; from the current directory)',
      );
      expect(
        WorkspaceMcpScope(
          workspace: workspace,
          source: McpScopeSource.worktree,
        ).header,
        r'Scope: workspace "My App" (id ws-1, root C:\repos\my-app; from the current worktree)',
      );
    });

    test('labels', () {
      expect(
        const GlobalMcpScope(source: McpScopeSource.fallback).label,
        'the Global scope',
      );
      expect(
        WorkspaceMcpScope(
          workspace: workspace,
          source: McpScopeSource.argument,
        ).label,
        'workspace "My App"',
      );
    });
  });
}
