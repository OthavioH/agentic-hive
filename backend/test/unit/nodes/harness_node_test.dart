import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/nodes/os_shell_provider.dart';
import 'package:agentic_hive_backend/src/data/result_contract/hive_result_contract.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/human_pause_gateway.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/mcp/hive_mcp_locator.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeProcessRunner implements NodeProcessRunner {
  new(this.result);

  ProcessExecutionResult result;
  ProcessInvocation? lastInvocation;

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    lastInvocation = invocation;
    return Success(result);
  }
}

final class _FakePtyRunner implements PtyRunner {
  new(this.result);

  ProcessExecutionResult result;
  PtyInvocation? lastInvocation;

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    lastInvocation = invocation;
    return Success(result);
  }
}

final class _FakeResultContract implements ResultContract {
  new({this.report});

  ResultContractReport? report;

  /// When set, reading the report fails with this failure.
  Failure? readFailure;

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async => Success(
    _FakeResultContractSession(
      context: context,
      instructions: instructionsFor(context),
      readReport: () => readReport(context),
    ),
  );

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Call report_result when finished.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async =>
      readFailure == null ? Success(report) : FailureResult(readFailure!);
}

final class _FakeResultContractSession implements ResultContractSession {
  new({
    required NodeExecutionContext context,
    required this.instructions,
    required this._readReport,
  }) : runId = context.runId,
       nodeId = context.nodeId,
       attempt = context.attempt;

  @override
  final String runId;

  @override
  final String nodeId;

  @override
  final int attempt;

  @override
  final String instructions;

  @override
  String? get mcpConfigPath => null;

  @override
  Map<String, String> get env => const <String, String>{};

  @override
  String? get resultFilePath => null;

  final Future<Result<ResultContractReport?>> Function() _readReport;

  @override
  Future<Result<ResultContractReport>> resolveOutcome({
    required int exitCode,
    bool timedOut = false,
  }) async {
    if (timedOut) {
      return const FailureResult(NodeExecutionFailure('Timed out.'));
    }
    if (exitCode != 0) {
      return FailureResult(
        NodeExecutionFailure('Exited with code $exitCode.', exitCode: exitCode),
      );
    }
    final reportResult = await _readReport();
    if (reportResult case FailureResult<ResultContractReport?>(
      :final failure,
    )) {
      return FailureResult(failure);
    }
    final report = reportResult.valueOrNull;
    if (report == null) {
      return const FailureResult(
        NodeExecutionFailure('Exited 0 without report.', exitCode: 0),
      );
    }
    return Success(report);
  }

  @override
  Future<void> dispose() async {}
}

final class _FakeAgentPromptResolver implements AgentPromptResolver {
  new(this.prompts);

  final Map<String, String> prompts;

  @override
  Future<Result<String>> resolvePrompt(String agentId) async {
    final prompt = prompts[agentId];
    if (prompt == null) {
      return FailureResult(NotFoundFailure('Agent "$agentId" not found.'));
    }
    return Success(prompt);
  }
}

NodeExecutionContext _context({
  JsonMap config = const {'additionalInstructions': 'Implement feature X'},
  String? humanAnswer,
}) => NodeExecutionContext(
  runId: 'run-1',
  nodeId: 'node-1',
  workspacePath: '/tmp/workspace',
  config: config,
  humanAnswer: humanAnswer,
);

void main() {
  late _FakeProcessRunner processRunner;
  late _FakePtyRunner ptyRunner;
  late _FakeResultContract resultContract;
  late _FakeAgentPromptResolver agentResolver;

  setUp(() {
    processRunner = _FakeProcessRunner(
      const ProcessExecutionResult(exitCode: 0),
    );
    ptyRunner = _FakePtyRunner(const ProcessExecutionResult(exitCode: 0));
    resultContract = _FakeResultContract(
      report: const ResultContractReport(
        status: ResultContractStatus.success,
        output: {'summary': 'done'},
        artifacts: ['lib/a.dart'],
      ),
    );
    agentResolver = _FakeAgentPromptResolver({
      'coder': 'You are a careful Dart engineer.',
    });
  });

  group('HeadlessHarnessNode subclasses', () {
    test('ClaudeCodeNode builds prompt, delivers via stdin (never CLI args), '
        'and resolves ResultContract', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {
            'agentId': 'coder',
            'additionalInstructions': 'Fix the bug.',
            'extraArgs': ['--model', 'sonnet'],
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      final outcome = result.valueOrNull!;
      expect(outcome.outputLabel, NodeOutput.onSuccess);
      expect(outcome.artifacts, ['lib/a.dart']);

      final invocation = processRunner.lastInvocation!;
      expect(invocation.executable, 'claude');
      expect(
        invocation.arguments,
        containsAll([
          '-p',
          '--output-format',
          'stream-json',
          '--model',
          'sonnet',
        ]),
      );
      expect(invocation.arguments.join(' '), isNot(contains('Fix the bug.')));
      expect(
        invocation.stdinContent,
        contains('You are a careful Dart engineer.'),
      );
      expect(invocation.stdinContent, contains('Fix the bug.'));
      expect(
        invocation.stdinContent,
        contains('Call report_result when finished.'),
      );
    });

    test('injects the human answer into the prompt on a re-run', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      await node.execute(_context(humanAnswer: 'Use PostgreSQL.'));

      final stdin = processRunner.lastInvocation!.stdinContent!;
      expect(stdin, contains('## Human Answer'));
      expect(stdin, contains('Use PostgreSQL.'));
    });

    test('adds no human answer section without an answer', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      await node.execute(_context());

      expect(
        processRunner.lastInvocation!.stdinContent,
        isNot(contains('Human Answer')),
      );
    });

    test('CodexNode invokes codex exec with prompt via stdin', () async {
      final node = CodexNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.isSuccess, isTrue);
      expect(processRunner.lastInvocation!.executable, 'codex');
      expect(processRunner.lastInvocation!.arguments, ['exec', '--json']);
      expect(
        processRunner.lastInvocation!.stdinContent,
        contains('Implement feature X'),
      );
    });

    test('GeminiCliNode invokes gemini -p with prompt via stdin', () async {
      final node = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.isSuccess, isTrue);
      expect(processRunner.lastInvocation!.executable, 'gemini');
      expect(
        processRunner.lastInvocation!.arguments.join(' '),
        isNot(contains('Implement feature X')),
      );
      expect(
        processRunner.lastInvocation!.stdinContent,
        contains('Implement feature X'),
      );
    });

    test('AntigravityNode invokes agy -p with prompt via stdin', () async {
      final node = AntigravityNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.isSuccess, isTrue);
      expect(processRunner.lastInvocation!.executable, 'agy');
      expect(processRunner.lastInvocation!.arguments, ['-p']);
      expect(
        processRunner.lastInvocation!.stdinContent,
        contains('Implement feature X'),
      );
    });

    test(
      'exit code 0 without ResultContract report is a failure (ADR 0003)',
      () async {
        resultContract.report = null;
        final node = ClaudeCodeNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentResolver,
        );

        final result = await node.execute(_context());
        expect(result.failureOrNull, isA<NodeExecutionFailure>());
      },
    );

    test('ResultContract failure status maps to onFailure outcome', () async {
      resultContract.report = const ResultContractReport(
        status: ResultContractStatus.failure,
        summary: 'Could not compile',
      );
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onFailure);
    });

    test('maps auth errors to HarnessAuthenticationFailure', () async {
      processRunner.result = const ProcessExecutionResult(
        exitCode: 1,
        stderr: 'Error: Not logged in. Please login first.',
      );
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.failureOrNull, isA<HarnessAuthenticationFailure>());
    });

    test('maps rate limit errors to HarnessRateLimitFailure', () async {
      processRunner.result = const ProcessExecutionResult(
        exitCode: 1,
        stderr: 'RESOURCE_EXHAUSTED: Quota exceeded (429)',
      );
      final node = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.failureOrNull, isA<HarnessRateLimitFailure>());
    });

    test('a malformed result report is an infrastructure failure', () async {
      resultContract.readFailure = const ValidationFailure(
        'Invalid JSON in fallback result.json.',
      );
      final node = CodexNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());

      final failure = result.failureOrNull;
      expect(failure, isA<NodeExecutionFailure>());
      expect(failure!.message, contains('Invalid JSON'));
      expect((failure as NodeExecutionFailure).exitCode, 0);
    });

    test('maps timeout to NodeExecutionFailure', () async {
      processRunner.result = const ProcessExecutionResult(
        exitCode: -1,
        timedOut: true,
      );
      final node = CodexNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {
            'additionalInstructions': 'Work',
            'timeoutSeconds': 10,
          },
        ),
      );
      expect(result.failureOrNull, isA<NodeExecutionFailure>());
    });

    test('rejects workingDirectory traversal outside workspace', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {
            'additionalInstructions': 'Work',
            'workingDirectory': '../outside',
          },
        ),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });

    test('successful run with 401, 429, oauth, and capacity in stdout is not '
        'misclassified as auth or rate-limit failure', () async {
      processRunner.result = const ProcessExecutionResult(
        exitCode: 0,
        stdout:
            'Added tests for HTTP 401 and 429 handling, oauth flow, and '
            'channel capacity.',
      );
      final gemini = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );
      final geminiResult = await gemini.execute(_context());
      expect(geminiResult.isSuccess, isTrue);
      expect(geminiResult.valueOrNull!.outputLabel, NodeOutput.onSuccess);

      final agy = AntigravityNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );
      final agyResult = await agy.execute(_context());
      expect(agyResult.isSuccess, isTrue);
      expect(agyResult.valueOrNull!.outputLabel, NodeOutput.onSuccess);
    });
  });

  group('TerminalHarnessNode', () {
    test('delegates to PtyRunner and resolves ResultContract', () async {
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const PosixShellProvider(),
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {
            'command': 'claude',
            'args': ['--chat'],
            'additionalInstructions': 'Interactive task',
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onSuccess);
      expect(ptyRunner.lastInvocation!.executable, 'claude');
      expect(ptyRunner.lastInvocation!.arguments, ['--chat']);
      expect(
        ptyRunner.lastInvocation!.initialInput,
        contains('Interactive task'),
      );
    });
  });

  group('HarnessNode + HiveResultContract session lifecycle', () {
    test('registers attempt, passes MCP config and env, resolves MCP report, '
        'and cleans up temp config and pending pauses on dispose', () async {
      final tempDir = await Directory.systemTemp.createTemp('hive_hn_rc_');
      addTearDown(() async {
        if (tempDir.existsSync()) {
          await tempDir.delete(recursive: true);
        }
      });
      final dataDir = p.join(tempDir.path, 'data');
      final workspaceDir = p.join(tempDir.path, 'ws');
      await Directory(dataDir).create(recursive: true);
      await Directory(workspaceDir).create(recursive: true);

      final coordinator = ResultContractCoordinator();
      final pauseGateway = InMemoryHumanPauseGateway();
      addTearDown(pauseGateway.dispose);
      final contract = HiveResultContract(
        coordinator: coordinator,
        dataDir: dataDir,
        socketPath: p.join(dataDir, 'backend.sock'),
        mcpLocator: HiveMcpLocator(
          overrideCommand: const HiveMcpLaunchCommand(executable: 'hive-mcp'),
        ),
        humanPauseGateway: pauseGateway,
      );

      String? observedMcpConfigPath;
      Map<String, String>? observedEnv;
      late Future<Result<String>> pendingPauseFuture;

      final runner = _CallbackProcessRunner((invocation) {
        final mcpFlagIndex = invocation.arguments.indexOf('--mcp-config');
        expect(mcpFlagIndex, isNot(-1));
        observedMcpConfigPath = invocation.arguments[mcpFlagIndex + 1];
        observedEnv = invocation.environment;
        expect(File(observedMcpConfigPath!).existsSync(), isTrue);
        expect(
          coordinator.isAttemptRegistered(
            runId: 'run-rc',
            nodeId: 'node-rc',
            attempt: 1,
          ),
          isTrue,
        );

        pendingPauseFuture = pauseGateway.requestHumanAnswer(
          runId: 'run-rc',
          nodeId: 'node-rc',
          attempt: 1,
          question: 'Dangling question?',
        );

        final submit = coordinator.submitMcpReport(
          runId: 'run-rc',
          nodeId: 'node-rc',
          attempt: 1,
          payload: const <String, Object?>{
            'status': 'onSuccess',
            'summary': 'Completed via MCP.',
            'data': <String, Object?>{'ok': true},
          },
        );
        expect(submit.isSuccess, isTrue);
        return const ProcessExecutionResult(exitCode: 0);
      });

      final node = ClaudeCodeNode(
        processRunner: runner,
        resultContract: contract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        NodeExecutionContext(
          runId: 'run-rc',
          nodeId: 'node-rc',
          workspacePath: workspaceDir,
          config: const <String, Object?>{'additionalInstructions': 'Do work.'},
        ),
      );

      expect(result.isSuccess, isTrue);
      final outcome = result.valueOrNull!;
      expect(outcome.outputLabel, NodeOutput.onSuccess);
      expect(outcome.data['summary'], 'Completed via MCP.');
      expect(outcome.data['ok'], isTrue);
      expect(observedEnv?['HIVE_RUN_ID'], 'run-rc');
      expect(observedEnv?['HIVE_NODE_ID'], 'node-rc');
      expect(observedEnv?['HIVE_ATTEMPT'], '1');
      expect(File(observedMcpConfigPath!).existsSync(), isFalse);
      expect(
        coordinator.isAttemptRegistered(
          runId: 'run-rc',
          nodeId: 'node-rc',
          attempt: 1,
        ),
        isFalse,
      );
      expect((await pendingPauseFuture).failureOrNull, isA<ConflictFailure>());
    });
  });
}

final class _CallbackProcessRunner implements NodeProcessRunner {
  new(this._onRun);

  final ProcessExecutionResult Function(ProcessInvocation invocation) _onRun;

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async => Success(_onRun(invocation));
}
