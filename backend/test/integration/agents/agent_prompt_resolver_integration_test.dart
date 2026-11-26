import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/repository_agent_prompt_resolver.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _CapturingProcessRunner implements NodeProcessRunner {
  ProcessInvocation? lastInvocation;

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    lastInvocation = invocation;
    return const Success(ProcessExecutionResult(exitCode: 0));
  }
}

final class _FakeSession implements ResultContractSession {
  @override
  String get runId => 'run-1';

  @override
  String get nodeId => 'node-1';

  @override
  int get attempt => 1;

  @override
  String get instructions => 'Submit via report_result.';

  @override
  String? get mcpConfigPath => null;

  @override
  Map<String, String> get env => const <String, String>{};

  @override
  String? get resultFilePath => null;

  @override
  Future<ResultContractReport>? get onMcpReportAccepted => null;

  @override
  Future<Result<ResultContractReport>> resolveOutcome({
    required int exitCode,
    bool timedOut = false,
  }) async =>
      const Success(ResultContractReport(status: ResultContractStatus.success));

  @override
  Future<void> dispose() async {}
}

final class _FakeResultContract implements ResultContract {
  const new();

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async => Success(_FakeSession());

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Submit via report_result.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async =>
      const Success(ResultContractReport(status: ResultContractStatus.success));
}

void main() {
  late Directory tempDir;
  late LocalAgentRepository repository;
  late RepositoryAgentPromptResolver resolver;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agent_prompt_int_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    repository = LocalAgentRepository(agentsDir: tempDir.path);
    resolver = RepositoryAgentPromptResolver(repository);
  });

  test(
    'harness node with agentId resolves prompt from LocalAgentRepository and '
    'picks up edits on disk',
    () async {
      final agentFile = File(p.join(tempDir.path, 'codebase-sweeper.md'));
      await agentFile.writeAsString(
        '---\n'
        'name: Codebase Sweeper\n'
        '---\n'
        'Initial sweep instructions.\n',
      );

      final processRunner = _CapturingProcessRunner();
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: const _FakeResultContract(),
        agentPromptResolver: resolver,
      );

      final context = NodeExecutionContext(
        runId: 'run-1',
        nodeId: 'node-1',
        targetFolder: tempDir.path,
        config: const <String, Object?>{'agentId': 'codebase-sweeper'},
      );

      final firstResult = await node.execute(context);
      expect(firstResult.isSuccess, isTrue);
      expect(firstResult.valueOrNull!.outputLabel, NodeOutput.onSuccess);
      expect(
        processRunner.lastInvocation?.stdinContent,
        contains('Initial sweep instructions.'),
      );

      // Update the file on disk; next run must observe the new content.
      await agentFile.writeAsString(
        '---\n'
        'name: Codebase Sweeper\n'
        '---\n'
        'Updated sweep instructions.\n',
      );

      final secondResult = await node.execute(context);
      expect(secondResult.isSuccess, isTrue);
      expect(
        processRunner.lastInvocation?.stdinContent,
        contains('Updated sweep instructions.'),
      );
    },
  );

  test('harness node fails cleanly when agent file has parseError', () async {
    await File(p.join(tempDir.path, 'broken.md'))
        .writeAsString('no frontmatter here');

    final processRunner = _CapturingProcessRunner();
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: const _FakeResultContract(),
      agentPromptResolver: resolver,
    );

    final result = await node.execute(
      NodeExecutionContext(
        runId: 'run-1',
        nodeId: 'node-1',
        targetFolder: tempDir.path,
        config: const <String, Object?>{'agentId': 'broken'},
      ),
    );

    expect(result.isFailure, isTrue);
    expect(result.failureOrNull, isA<ValidationFailure>());
    expect(result.failureOrNull!.message, contains('broken'));
    expect(processRunner.lastInvocation, isNull);
  });
}
