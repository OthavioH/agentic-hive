import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope.dart';
import 'package:agentic_hive_backend/src/domain/mcp_tools/mcp_scope_resolver.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Arguments of one tool call plus the caller's current directory.
final class McpToolInput {
  /// Creates an [McpToolInput].
  const new({required this.arguments, this.cwd});

  /// Raw tool arguments from the MCP call.
  final JsonMap arguments;

  /// Optional caller working directory.
  final String? cwd;

  /// Reads an optional string argument; blank strings become `Success(null)`.
  Result<String?> optionalString(String key) {
    final raw = arguments[key];
    if (raw == null) {
      return const Success(null);
    }
    if (raw is! String) {
      return FailureResult(ValidationFailure('"$key" must be a string.'));
    }
    final trimmed = raw.trim();
    return Success(trimmed.isEmpty ? null : trimmed);
  }

  /// Reads a required non-blank string argument.
  Result<String> requiredString(String key, {required String missingMessage}) =>
      optionalString(key).flatMap(
        (value) => value == null
            ? FailureResult(ValidationFailure(missingMessage))
            : Success(value),
      );
}

/// One backend-served MCP tool (ADR 0026). Add a tool = one subclass + one
/// registry entry.
abstract base class McpTool {
  /// Creates an [McpTool].
  const new();

  /// Unique tool name exposed to MCP clients.
  String get name;

  /// Executes the tool for [input].
  Future<Result<String>> call(McpToolInput input);
}

/// Template method: resolves the scope once, then prefixes the header (R6).
abstract base class ScopedMcpTool extends McpTool {
  /// Creates a [ScopedMcpTool] using [_scopes] to resolve each call's scope.
  const new(this._scopes);

  final McpScopeResolver _scopes;

  @override
  Future<Result<String>> call(McpToolInput input) async {
    final workspaceResult = input.optionalString('workspace');
    if (workspaceResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final workspace = (workspaceResult as Success<String?>).value;
    final scopeResult = await _scopes.resolve(
      workspace: workspace,
      cwd: input.cwd,
    );
    if (scopeResult case FailureResult(:final failure)) {
      return FailureResult(failure);
    }
    final scope = (scopeResult as Success<McpScope>).value;
    final bodyResult = await runInScope(scope, input);
    return bodyResult.map((body) => '${scope.header}\n$body');
  }

  /// Executes the tool within the resolved [scope].
  Future<Result<String>> runInScope(McpScope scope, McpToolInput input);
}
