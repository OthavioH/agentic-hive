import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/command_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/human_approval_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/validator_nodes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _FakeAgentPromptResolver implements AgentPromptResolver {
  const new();

  @override
  Future<Result<String>> resolvePrompt(String agentId) async =>
      FailureResult(NotFoundFailure('Agent "$agentId" not found.'));

  @override
  Future<Result<ResolvedAgent>> resolveAgent(String agentId) async =>
      FailureResult(NotFoundFailure('Agent "$agentId" not found.'));
}

final class _FakeProcessRunner implements NodeProcessRunner {
  new(this.onRun);

  final ProcessExecutionResult Function(ProcessInvocation invocation) onRun;
  ProcessInvocation? lastInvocation;

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    lastInvocation = invocation;
    return Success(onRun(invocation));
  }
}

final class _FakeHumanApprovalPort implements HumanApprovalPort {
  new(this.response);

  HumanApprovalResponse response;
  HumanApprovalRequest? lastRequest;

  @override
  Future<Result<HumanApprovalResponse>> requestApproval(
    HumanApprovalRequest request,
  ) async {
    lastRequest = request;
    return Success(response);
  }
}

final class _FakeResultContract implements ResultContract {
  new(this.report);

  ResultContractReport report;

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async => Success(_FakeResultContractSession(context, this));

  @override
  String instructionsFor(NodeExecutionContext context) => 'Report result.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async => Success(report);
}

final class _FakeResultContractSession implements ResultContractSession {
  new(this._context, this._contract);

  final NodeExecutionContext _context;
  final _FakeResultContract _contract;

  @override
  String get runId => _context.runId;

  @override
  String get nodeId => _context.nodeId;

  @override
  int get attempt => _context.attempt;

  @override
  String get instructions => _contract.instructionsFor(_context);

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
  }) async => Success(_contract.report);

  @override
  Future<void> dispose() async {}
}

void main() {
  late Directory tempDir;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('hive_nodes_test_');
  });

  tearDown(() {
    if (tempDir.existsSync()) {
      tempDir.deleteSync(recursive: true);
    }
  });

  NodeExecutionContext ctx(JsonMap config) => NodeExecutionContext(
    runId: 'run-1',
    nodeId: 'node-1',
    workspacePath: tempDir.path,
    config: config,
  );

  group('CommandNode', () {
    test(
      'returns onSuccess for exit 0 and forwards env/workingDir/timeout',
      () async {
        final runner = _FakeProcessRunner(
          (_) => const ProcessExecutionResult(exitCode: 0, stdout: 'ok'),
        );
        final node = CommandNode(processRunner: runner);

        final result = await node.execute(
          ctx(const {
            'command': 'dart',
            'args': ['--version'],
            'workingDirectory': 'sub',
            'timeoutSeconds': 15,
            'env': {'FOO': 'bar'},
          }),
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.outputLabel, NodeOutput.onSuccess);
        expect(
          runner.lastInvocation!.workingDirectory,
          p.join(tempDir.resolveSymbolicLinksSync(), 'sub'),
        );
        expect(runner.lastInvocation!.environment, {'FOO': 'bar'});
        expect(runner.lastInvocation!.timeout, const Duration(seconds: 15));
      },
    );

    test('returns onFailure on non-zero exit code or timeout', () async {
      final runner = _FakeProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: 2, stderr: 'boom'),
      );
      final node = CommandNode(processRunner: runner);

      final nonZero = await node.execute(ctx(const {'command': 'false'}));
      expect(nonZero.valueOrNull!.outputLabel, NodeOutput.onFailure);

      final timedOutRunner = _FakeProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: -1, timedOut: true),
      );
      final timedOut = await CommandNode(processRunner: timedOutRunner)
          .execute(ctx(const {'command': 'sleep', 'timeoutSeconds': 1}));
      expect(timedOut.valueOrNull!.outputLabel, NodeOutput.onFailure);
      expect(timedOut.valueOrNull!.data['timedOut'], isTrue);
    });
  });

  group('TestsValidatorNode', () {
    test('emits onSuccess on exit 0 and onFailure on non-zero', () async {
      final passNode = TestsValidatorNode(
        processRunner: _FakeProcessRunner(
          (_) =>
              const ProcessExecutionResult(exitCode: 0, stdout: 'All passed'),
        ),
      );
      final pass = await passNode.execute(ctx(const {'command': 'dart test'}));
      expect(pass.valueOrNull!.outputLabel, NodeOutput.onSuccess);

      final failNode = TestsValidatorNode(
        processRunner: _FakeProcessRunner(
          (_) => const ProcessExecutionResult(exitCode: 1, stderr: '1 failed'),
        ),
      );
      final fail = await failNode.execute(ctx(const {'command': 'dart test'}));
      expect(fail.valueOrNull!.outputLabel, NodeOutput.onFailure);
      expect(fail.valueOrNull!.data['exitCode'], 1);
    });
  });

  group('ChecklistValidatorNode', () {
    test(
      'passes when fileExists, commandSucceeds, and outputMatchesRegex pass',
      () async {
        await File(p.join(tempDir.path, 'README.md')).writeAsString('# Hello');

        final runner = _FakeProcessRunner((inv) {
          if (inv.executable == 'dart' && inv.arguments.contains('analyze')) {
            return const ProcessExecutionResult(
              exitCode: 0,
              stdout: 'No issues',
            );
          }
          return const ProcessExecutionResult(
            exitCode: 0,
            stdout: 'Version 1.2.3',
          );
        });

        final node = ChecklistValidatorNode(processRunner: runner);
        final result = await node.execute(
          ctx(const {
            'rules': [
              {
                'label': 'Has README',
                'kind': 'fileExists',
                'path': 'README.md',
              },
              {
                'label': 'Analyzer clean',
                'kind': 'commandSucceeds',
                'command': 'dart analyze',
              },
              {
                'label': 'Semver output',
                'kind': 'outputMatchesRegex',
                'command': 'tool --version',
                'pattern': r'Version \d+\.\d+\.\d+',
              },
            ],
          }),
        );

        expect(result.isSuccess, isTrue);
        expect(result.valueOrNull!.outputLabel, NodeOutput.onSuccess);
        expect(result.valueOrNull!.data['failedRules'], isEmpty);
      },
    );

    test('emits onFailure listing all failed rules', () async {
      final runner = _FakeProcessRunner((inv) {
        if (inv.executable == 'failing') {
          return const ProcessExecutionResult(exitCode: 1);
        }
        return const ProcessExecutionResult(exitCode: 0, stdout: 'nope');
      });

      final node = ChecklistValidatorNode(processRunner: runner);
      final result = await node.execute(
        ctx(const {
          'rules': [
            {
              'label': 'Missing file',
              'kind': 'fileExists',
              'path': 'missing.txt',
            },
            {
              'label': 'Failing cmd',
              'kind': 'commandSucceeds',
              'command': 'failing',
            },
            {
              'label': 'Regex mismatch',
              'kind': 'outputMatchesRegex',
              'command': 'echo',
              'pattern': 'expected-token',
            },
          ],
        }),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onFailure);
      final failed = result.valueOrNull!.data['failedRules']! as List;
      expect(failed, hasLength(3));
    });

    test('fileExists recognizes directories and applies default timeout and '
        'quote-aware command tokenization', () async {
      await Directory(p.join(tempDir.path, 'lib')).create();

      final runner = _FakeProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: 0, stdout: 'matched'),
      );
      final node = ChecklistValidatorNode(processRunner: runner);
      final result = await node.execute(
        ctx(const {
          'rules': [
            {'label': 'Has lib dir', 'kind': 'fileExists', 'path': 'lib'},
            {
              'label': 'Quoted args',
              'kind': 'commandSucceeds',
              'command': 'grep "a b" \'c d\' file.txt',
            },
          ],
        }),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onSuccess);
      expect(runner.lastInvocation!.executable, 'grep');
      expect(runner.lastInvocation!.arguments, ['a b', 'c d', 'file.txt']);
      expect(
        runner.lastInvocation!.timeout,
        ChecklistValidatorNode.defaultCommandTimeout,
      );
    });

    test('records timeout as failed rule', () async {
      final runner = _FakeProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: -1, timedOut: true),
      );
      final node = ChecklistValidatorNode(
        processRunner: runner,
        commandTimeout: const Duration(seconds: 5),
      );
      final result = await node.execute(
        ctx(const {
          'rules': [
            {
              'label': 'Slow command',
              'kind': 'commandSucceeds',
              'command': 'slow_cmd',
            },
          ],
        }),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onFailure);
      expect(runner.lastInvocation!.timeout, const Duration(seconds: 5));
      final failed = result.valueOrNull!.data['failedRules']! as List;
      expect(failed, hasLength(1));
      expect((failed.first as Map)['reason'], 'Command timed out.');
    });
  });

  group('resolveWorkspacePath', () {
    test('rejects absolute, traversal, and symlink escape paths', () async {
      final outsideDir = await Directory.systemTemp.createTemp('hive_outside_');
      addTearDown(() {
        if (outsideDir.existsSync()) {
          outsideDir.deleteSync(recursive: true);
        }
      });

      final node = CommandNode(
        processRunner: _FakeProcessRunner(
          (_) => const ProcessExecutionResult(exitCode: 0),
        ),
      );

      expect(
        node.resolveWorkspacePath(tempDir.path, '../outside').failureOrNull,
        isA<ValidationFailure>(),
      );
      expect(
        node.resolveWorkspacePath(tempDir.path, r'C:\Windows').failureOrNull,
        isA<ValidationFailure>(),
      );

      final linkPath = p.join(tempDir.path, 'escape_link');
      try {
        Link(linkPath).createSync(outsideDir.path);
      } on FileSystemException {
        // Windows without Developer Mode / admin privileges may disallow
        // creating symlinks; skip symlink assertion in that environment.
        return;
      }

      final escaped = node.resolveWorkspacePath(
        tempDir.path,
        p.join('escape_link', 'secret.txt'),
      );
      expect(escaped.failureOrNull, isA<ValidationFailure>());
    });
  });

  group('ReviewValidatorNode', () {
    test('delegates to registered headless harness and maps approved/changesRequested', () async {
      final processRunner = _FakeProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: 0),
      );
      final contract = _FakeResultContract(
        const ResultContractReport(status: ResultContractStatus.approved),
      );
      final registry = NodeRegistry()
        ..register(
          NodeDescriptors.claudeCode,
          () => ClaudeCodeNode(
            processRunner: processRunner,
            resultContract: contract,
            agentPromptResolver: const _FakeAgentPromptResolver(),
          ),
        );

      final reviewNode = ReviewValidatorNode(resolveNode: registry.create);
      final approved = await reviewNode.execute(
        ctx(const {
          'harnessType': NodeTypeId.claudeCode,
          'reviewCriteria': 'Check tests and types.',
        }),
      );
      expect(approved.isSuccess, isTrue);
      expect(approved.valueOrNull!.outputLabel, NodeOutput.approved);

      contract.report = const ResultContractReport(
        status: ResultContractStatus.changesRequested,
        summary: 'Missing edge case test',
      );
      final changes = await reviewNode.execute(
        ctx(const {
          'harnessType': NodeTypeId.claudeCode,
          'reviewCriteria': 'Check tests and types.',
        }),
      );
      expect(changes.isSuccess, isTrue);
      expect(changes.valueOrNull!.outputLabel, NodeOutput.changesRequested);
    });
  });

  group('HumanApprovalNode', () {
    test('maps approved and rejected decisions with feedback', () async {
      final port = _FakeHumanApprovalPort(
        const HumanApprovalResponse(
          decision: HumanApprovalDecision.approved,
          feedback: 'Looks good',
        ),
      );
      final node = HumanApprovalNode(approvalPort: port);

      final approved = await node.execute(
        ctx(const {
          'title': 'Approve release',
          'instructions': 'Verify changelog.',
        }),
      );
      expect(approved.valueOrNull!.outputLabel, NodeOutput.approved);
      expect(approved.valueOrNull!.data['feedback'], 'Looks good');

      port.response = const HumanApprovalResponse(
        decision: HumanApprovalDecision.rejected,
        feedback: 'Needs fixes',
      );
      final rejected = await node.execute(
        ctx(const {'instructions': 'Verify changelog.'}),
      );
      expect(rejected.valueOrNull!.outputLabel, NodeOutput.rejected);
      expect(rejected.valueOrNull!.data['feedback'], 'Needs fixes');
    });
  });
}
