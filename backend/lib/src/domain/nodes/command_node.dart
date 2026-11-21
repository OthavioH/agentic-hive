import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_outcome.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Executes a configured shell/process command in the run workspace.
final class CommandNode extends Node {
  /// Creates a command node.
  const new({required this.processRunner});

  /// Process runner port.
  final NodeProcessRunner processRunner;

  @override
  String get typeId => NodeTypeId.command;

  @override
  Future<Result<NodeOutcome>> execute(NodeExecutionContext context) async {
    final issues = validateConfig(context.config);
    if (issues.isNotEmpty) {
      return FailureResult(
        ValidationFailure(
          issues.map((i) => '${i.field}: ${i.message}').join('; '),
        ),
      );
    }

    final config = CommandNodeConfig.fromJson(context.config);
    final workingDirResult = resolveWorkspacePath(
      context.workspacePath,
      config.workingDirectory,
    );
    if (workingDirResult case FailureResult<String>(:final failure)) {
      return FailureResult(failure);
    }
    final workingDirectory = workingDirResult.valueOrNull!;

    final runResult = await processRunner.run(
      ProcessInvocation(
        executable: config.command,
        arguments: config.args,
        workingDirectory: workingDirectory,
        environment: config.env,
        timeout: config.timeoutSeconds != null
            ? Duration(seconds: config.timeoutSeconds!)
            : null,
        runId: context.runId,
        nodeId: context.nodeId,
      ),
      onOutput: context.onOutput,
    );
    if (runResult case FailureResult<ProcessExecutionResult>(:final failure)) {
      return FailureResult(failure);
    }
    final result = runResult.valueOrNull!;

    final succeeded = !result.timedOut && result.exitCode == 0;
    return Success(
      NodeOutcome(
        outputLabel: succeeded ? NodeOutput.onSuccess : NodeOutput.onFailure,
        data: <String, Object?>{
          'exitCode': result.exitCode,
          'timedOut': result.timedOut,
          'stdout': result.stdout,
          'stderr': result.stderr,
        },
      ),
    );
  }
}
