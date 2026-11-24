import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
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

final class _FakeResultContract implements ResultContract {
  new({this.report});

  ResultContractReport? report;

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
  ) async => Success(report);
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

  @override
  Future<ResultContractReport>? get onMcpReportAccepted => null;

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
  new();

  @override
  Future<Result<String>> resolvePrompt(
    String agentId, {
    String? workspaceRoot,
  }) async => const Success('prompt');

  @override
  Future<Result<ResolvedAgent>> resolveAgent(
    String agentId, {
    String? workspaceRoot,
  }) async => const Success(ResolvedAgent(prompt: 'prompt'));
}

NodeExecutionContext _context({
  JsonMap config = const {'additionalInstructions': 'Implement feature X'},
}) => NodeExecutionContext(
  runId: 'run-1',
  nodeId: 'node-1',
  workspacePath: '/tmp/workspace',
  config: config,
);

const ProcessExecutionResult _okProcessResult = ProcessExecutionResult(
  exitCode: 0,
);

void main() {
  late _FakeProcessRunner processRunner;
  late _FakeResultContract resultContract;
  late _FakeAgentPromptResolver agentPromptResolver;

  setUp(() {
    processRunner = _FakeProcessRunner(_okProcessResult);
    resultContract = _FakeResultContract(
      report: const ResultContractReport(
        status: ResultContractStatus.success,
        summary: 'Done',
      ),
    );
    agentPromptResolver = _FakeAgentPromptResolver();
  });

  test('claude: model and effort flags', () {
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final invocation = node.buildInvocation(
      config: const HarnessNodeConfig(
        additionalInstructions: 'x',
        model: 'opus',
        effort: 'high',
        extraArgs: ['--model', 'sonnet'],
      ),
      workingDirectory: '/tmp/w',
      prompt: 'p',
    );
    final args = invocation.arguments;
    expect(args, containsAllInOrder(['--model', 'opus', '--effort', 'high']));
    expect(args.lastIndexOf('--model'), greaterThan(args.indexOf('--model')));
    expect(args.lastIndexOf('--model'), args.length - 2);
  });

  test('claude: unset adds no flag', () {
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final unsetArgs = node
        .buildInvocation(
          config: const HarnessNodeConfig(additionalInstructions: 'x'),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(unsetArgs, isNot(contains('--model')));
    expect(unsetArgs, isNot(contains('--effort')));

    final blankArgs = node
        .buildInvocation(
          config: const HarnessNodeConfig(
            additionalInstructions: 'x',
            model: '  ',
            effort: '',
          ),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(blankArgs, isNot(contains('--model')));
    expect(blankArgs, isNot(contains('--effort')));
  });

  test('claude: max passes through', () {
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final args = node
        .buildInvocation(
          config: const HarnessNodeConfig(
            additionalInstructions: 'x',
            effort: 'max',
          ),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(args, containsAllInOrder(['--effort', 'max']));
  });

  test('codex: model -> --model; effort -> -c model_reasoning_effort=<v>', () {
    final node = CodexNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    for (final level in ['low', 'medium', 'high']) {
      final args = node
          .buildInvocation(
            config: HarnessNodeConfig(
              additionalInstructions: 'x',
              model: 'o3',
              effort: level,
            ),
            workingDirectory: '/tmp/w',
            prompt: 'p',
          )
          .arguments;
      expect(
        args,
        containsAllInOrder([
          '--model',
          'o3',
          '-c',
          'model_reasoning_effort=$level',
        ]),
      );
      expect(args.any((a) => a.contains('"')), isFalse);
    }

    final maxArgs = node
        .buildInvocation(
          config: const HarnessNodeConfig(
            additionalInstructions: 'x',
            effort: 'max',
          ),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(maxArgs, containsAllInOrder(['-c', 'model_reasoning_effort=xhigh']));
    expect(maxArgs.any((a) => a.contains('"')), isFalse);
  });

  test('gemini: model -> --model; effort produces no flag', () {
    final node = GeminiCliNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final args = node
        .buildInvocation(
          config: const HarnessNodeConfig(
            additionalInstructions: 'x',
            model: 'gemini-2.5-pro',
            effort: 'high',
          ),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(args, containsAllInOrder(['--model', 'gemini-2.5-pro']));
    expect(args, isNot(contains('--effort')));
    expect(args, isNot(contains('high')));
  });

  test('antigravity: --model and --effort', () {
    final node = AntigravityNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final args = node
        .buildInvocation(
          config: const HarnessNodeConfig(
            additionalInstructions: 'x',
            model: 'agy-model',
            effort: 'medium',
          ),
          workingDirectory: '/tmp/w',
          prompt: 'p',
        )
        .arguments;
    expect(
      args,
      containsAllInOrder(['--model', 'agy-model', '--effort', 'medium']),
    );
  });

  test(
    'T-B1 each subclass translates exactly the fields its descriptor declares',
    () {
      final nodes = [
        ClaudeCodeNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
        CodexNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
        GeminiCliNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
        AntigravityNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentPromptResolver,
        ),
      ];

      for (final node in nodes) {
        final args = node
            .buildInvocation(
              config: const HarnessNodeConfig(
                additionalInstructions: 'x',
                model: 'm',
                effort: 'high',
              ),
              workingDirectory: '/tmp/w',
              prompt: 'p',
            )
            .arguments;
        final hasModelFlag = args.contains('--model');
        final hasEffortFlag =
            args.contains('--effort') ||
            args.any((a) => a.startsWith('model_reasoning_effort='));
        expect(
          hasModelFlag,
          node.descriptor.configFields.any((f) => f.name == 'model'),
          reason: '${node.descriptor.typeId} model flag mismatch',
        );
        expect(
          hasEffortFlag,
          node.descriptor.configFields.any((f) => f.name == 'effort'),
          reason: '${node.descriptor.typeId} effort flag mismatch',
        );
      }
    },
  );

  test(
    'T-B2 unsupported field fails the node before any process starts',
    () async {
      final node = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentPromptResolver,
      );
      final result = await node.execute(
        _context(
          config: const {'additionalInstructions': 'x', 'effort': 'high'},
        ),
      );
      expect(result, isA<FailureResult<dynamic>>());
      final failure = (result as FailureResult<dynamic>).failure;
      expect(failure, isA<ValidationFailure>());
      expect(
        failure.message,
        contains(
          'effort: harness.gemini_cli does not support choosing an effort.',
        ),
      );
      expect(processRunner.lastInvocation, isNull);
    },
  );

  test('T-B3 model value starting with "-" fails the node', () async {
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final result = await node.execute(
      _context(config: const {'additionalInstructions': 'x', 'model': '--bad'}),
    );
    expect(result, isA<FailureResult<dynamic>>());
    expect(
      (result as FailureResult<dynamic>).failure,
      isA<ValidationFailure>(),
    );
    expect(processRunner.lastInvocation, isNull);
  });

  test('T-B4 execute passes model/effort end to end', () async {
    final node = ClaudeCodeNode(
      processRunner: processRunner,
      resultContract: resultContract,
      agentPromptResolver: agentPromptResolver,
    );
    final result = await node.execute(
      _context(
        config: const {
          'additionalInstructions': 'x',
          'model': 'opus',
          'effort': 'low',
        },
      ),
    );
    expect(result.isSuccess, isTrue);
    expect(
      processRunner.lastInvocation!.arguments,
      containsAllInOrder(['--model', 'opus', '--effort', 'low']),
    );
  });
}
