import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_tool.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeWorkspaces implements WorkspaceRepository {
  new({this.failure});

  final Failure? failure;

  @override
  Future<Result<List<Workspace>>> list() async =>
      failure != null ? FailureResult(failure!) : const Success(<Workspace>[]);

  @override
  Future<Result<Workspace>> getById(String id) async =>
      throw UnimplementedError();

  @override
  Future<Result<Workspace>> create(Workspace workspace) async =>
      throw UnimplementedError();

  @override
  Future<Result<void>> delete(String id) async => throw UnimplementedError();

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => throw UnimplementedError();
}

final class _EchoScopeTool extends ScopedMcpTool {
  new(super._scopes);

  bool ran = false;

  @override
  String get name => 'echo_scope';

  @override
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input) async {
    ran = true;
    return const Success('body line');
  }
}

void main() {
  test('McpToolInput.optionalString rejects non-strings', () {
    const input = McpToolInput(arguments: <String, Object?>{'workspace': 42});
    final result = input.optionalString('workspace');
    expect(result, isA<FailureResult<String?>>());
    final failure = (result as FailureResult<String?>).failure;
    expect(failure, isA<ValidationFailure>());
    expect(failure.message, '"workspace" must be a string.');
  });

  test('requiredString uses the missing message', () {
    const input = McpToolInput(arguments: <String, Object?>{'id': '   '});
    final result = input.requiredString(
      'id',
      missingMessage: 'Missing "id": pass a workflow id from list_workflows.',
    );
    expect(result, isA<FailureResult<String>>());
    final failure = (result as FailureResult<String>).failure;
    expect(failure, isA<ValidationFailure>());
    expect(
      failure.message,
      'Missing "id": pass a workflow id from list_workflows.',
    );
  });

  test('ScopedMcpTool prefixes the scope header', () async {
    final resolver = McpScopeResolver(
      workspaces: _FakeWorkspaces(),
      worktreesDir: '/tmp/wt',
      path: p.context,
    );
    final tool = _EchoScopeTool(resolver);
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{}),
    );
    expect(
      (result as Success<String>).value,
      'Scope: Global (default: no workspace contains the current directory)\n'
      'body line',
    );
    expect(tool.ran, isTrue);
  });

  test('ScopedMcpTool returns the resolver failure without running', () async {
    final resolver = McpScopeResolver(
      workspaces: _FakeWorkspaces(
        failure: const UnexpectedFailure('repo failed'),
      ),
      worktreesDir: '/tmp/wt',
      path: p.context,
    );
    final tool = _EchoScopeTool(resolver);
    final result = await tool.call(
      const McpToolInput(arguments: <String, Object?>{}),
    );
    expect(result, isA<FailureResult<String>>());
    expect((result as FailureResult<String>).failure.message, 'repo failed');
    expect(tool.ran, isFalse);
  });
}
