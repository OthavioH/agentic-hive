import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
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

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Call report_result when finished.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async => Success(report);
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
}) => NodeExecutionContext(
  runId: 'run-1',
  nodeId: 'node-1',
  workspacePath: '/tmp/workspace',
  config: config,
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
  });

  group('TerminalHarnessNode', () {
    test('delegates to PtyRunner and resolves ResultContract', () async {
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
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
}
