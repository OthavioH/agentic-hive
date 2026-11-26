import 'dart:convert';
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
import 'package:logging/logging.dart';
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
  new(
    this.prompts, {
    this.allowedTools = const <String, List<String>>{},
    this.deniedTools = const <String, List<String>>{},
  });

  final Map<String, String> prompts;
  final Map<String, List<String>> allowedTools;
  final Map<String, List<String>> deniedTools;

  /// Workspace root the last lookup carried.
  String? lastWorkspaceRoot;

  @override
  Future<Result<String>> resolvePrompt(
    String agentId, {
    String? workspaceRoot,
  }) async {
    lastWorkspaceRoot = workspaceRoot;
    final prompt = prompts[agentId];
    if (prompt == null) {
      return FailureResult(NotFoundFailure('Agent "$agentId" not found.'));
    }
    return Success(prompt);
  }

  @override
  Future<Result<ResolvedAgent>> resolveAgent(
    String agentId, {
    String? workspaceRoot,
  }) async {
    lastWorkspaceRoot = workspaceRoot;
    final prompt = prompts[agentId];
    if (prompt == null) {
      return FailureResult(NotFoundFailure('Agent "$agentId" not found.'));
    }
    return Success(
      ResolvedAgent(
        prompt: prompt,
        allowedTools: allowedTools[agentId] ?? const <String>[],
        deniedTools: deniedTools[agentId] ?? const <String>[],
      ),
    );
  }
}

NodeExecutionContext _context({
  String runId = 'run-1',
  JsonMap config = const {'additionalInstructions': 'Implement feature X'},
  String? humanAnswer,
  String? runInput,
  List<RunAttachmentFile> runAttachments = const <RunAttachmentFile>[],
  WorkspaceIsolationMode isolationMode = WorkspaceIsolationMode.direct,
  String? resultJsonPath,
}) => NodeExecutionContext(
  runId: runId,
  nodeId: 'node-1',
  workspacePath: '/tmp/workspace',
  config: config,
  humanAnswer: humanAnswer,
  runInput: runInput,
  runAttachments: runAttachments,
  isolationMode: isolationMode,
  resultJsonPath: resultJsonPath,
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
        containsAllInOrder([
          '-p',
          '--output-format',
          'stream-json',
          '--verbose',
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

    test('ClaudeCodeNode does not duplicate --verbose when extraArgs already '
        'includes it', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {
            'additionalInstructions': 'Fix the bug.',
            'extraArgs': ['--verbose', '--model', 'sonnet'],
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      final args = processRunner.lastInvocation!.arguments;
      expect(args.where((arg) => arg == '--verbose'), hasLength(1));
      expect(
        args,
        containsAllInOrder([
          '-p',
          '--output-format',
          'stream-json',
          '--verbose',
          '--model',
          'sonnet',
        ]),
      );
    });

    test('ClaudeCodeNode handles --verbose stream-json events without '
        'bypassing the result contract', () async {
      const verboseStreamJsonStdout = '''
{"type":"system","subtype":"hook_started","hook_id":"h1","hook_name":"SessionStart:startup"}
{"type":"system","subtype":"hook_response","hook_id":"h1","outcome":"success","exit_code":0}
{"type":"system","subtype":"init","cwd":"/tmp/workspace","mcp_servers":[{"name":"drive","status":"needs-auth"}]}
{"type":"assistant","message":{"role":"assistant","content":[{"type":"text","text":"ok"}]}}
{"type":"rate_limit_event","rate_limit_info":{"status":"allowed"}}
{"type":"result","subtype":"success","is_error":false,"result":"ok"}
''';
      final runnerWithVerboseStdout = _FakeProcessRunner(
        const ProcessExecutionResult(
          exitCode: 0,
          stdout: verboseStreamJsonStdout,
        ),
      );
      final node = ClaudeCodeNode(
        processRunner: runnerWithVerboseStdout,
        resultContract: _FakeResultContract(),
        agentPromptResolver: agentResolver,
      );

      // Even with a "subtype":"success" result event in stdout, exit 0 without
      // a result contract report must still fail (ADR 0003).
      final missingReportResult = await node.execute(_context());
      expect(missingReportResult.isFailure, isTrue);
      expect(
        missingReportResult.failureOrNull,
        isA<NodeExecutionFailure>().having(
          (f) => f.message,
          'message',
          contains('Exited 0 without report.'),
        ),
      );

      // With a non-zero exit code, verbose metadata events like
      // rate_limit_event or mcp_servers needs-auth must not false-positive.
      final analysis = node.parseOutput(
        const ProcessExecutionResult(
          exitCode: 1,
          stdout: verboseStreamJsonStdout,
        ),
      );
      expect(analysis.isAuthenticationError, isFalse);
      expect(analysis.isRateLimitError, isFalse);
      expect(analysis.metadata, isEmpty);
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
      expect(
        processRunner.lastInvocation!.arguments,
        containsAllInOrder(['exec', '--json', '--sandbox', 'workspace-write']),
      );
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

    test(
      'AntigravityNode invokes agy stream-json with NDJSON user event on stdin',
      () async {
        final node = AntigravityNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentResolver,
        );

        final result = await node.execute(
          _context(
            config: const {
              'additionalInstructions': 'Implement feature X',
              'extraArgs': ['--model', 'gemini-3-pro'],
            },
          ),
        );
        expect(result.isSuccess, isTrue);
        final invocation = processRunner.lastInvocation!;
        expect(invocation.executable, 'agy');
        expect(invocation.arguments, [
          '--input-format',
          'stream-json',
          '--output-format',
          'stream-json',
          '--mode',
          'accept-edits',
          '--model',
          'gemini-3-pro',
        ]);
        expect(
          invocation.arguments.join(' '),
          isNot(contains('Implement feature X')),
        );
        expect(invocation.stdinContent, endsWith('\n'));

        final payload =
            jsonDecode(invocation.stdinContent!.trim()) as Map<String, Object?>;
        expect(payload['event'], 'user');
        final message = payload['message']! as Map<String, Object?>;
        expect(message['role'], 'user');
        expect(message['content'], contains('Implement feature X'));
      },
    );

    test('AntigravityNode handles stream-json events without bypassing the '
        'result contract', () async {
      const streamJsonStdout = '''
{"event":"init","conversation_id":"c1","init":{"cwd":"/tmp/ws","tools":["run_command","view_file"],"permission_mode":"request-review"}}
{"event":"step_update","step_update":{"conversation_id":"c1","step_index":0,"state":"DONE","step_type":"user_input"}}
{"event":"step_update","step_update":{"conversation_id":"c1","step_index":1,"state":"DONE","step_type":"agent_response","text_delta":"OK"}}
{"event":"result","result":{"conversation_id":"c1","status":"SUCCESS","response":"OK"}}
''';
      final runner = _FakeProcessRunner(
        const ProcessExecutionResult(exitCode: 0, stdout: streamJsonStdout),
      );
      final node = AntigravityNode(
        processRunner: runner,
        resultContract: _FakeResultContract(),
        agentPromptResolver: agentResolver,
      );

      final missingReportResult = await node.execute(_context());
      expect(missingReportResult.isFailure, isTrue);
      expect(
        missingReportResult.failureOrNull,
        isA<NodeExecutionFailure>().having(
          (f) => f.message,
          'message',
          contains('Exited 0 without report.'),
        ),
      );

      final analysis = node.parseOutput(
        const ProcessExecutionResult(exitCode: 1, stdout: streamJsonStdout),
      );
      expect(analysis.isAuthenticationError, isFalse);
      expect(analysis.isRateLimitError, isFalse);
      expect(analysis.metadata, isEmpty);
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
      resultContract.report = null;
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

  group('Headless harness permission policy', () {
    const resultJsonPath =
        '/tmp/hive-data/runs/run-1/results/node-1-attempt-1.json';
    const resultsDir = '/tmp/hive-data/runs/run-1/results';

    late _FakeAgentPromptResolver policyAgentResolver;

    setUp(() {
      policyAgentResolver = _FakeAgentPromptResolver(
        const {'sweeper': 'Sweep the workspace.'},
        allowedTools: const {
          'sweeper': ['Read', 'Bash(git status)', 'Edit'],
        },
        deniedTools: const {
          'sweeper': ['Bash(git status)', 'WebFetch'],
        },
      );
    });

    test(
      'ClaudeCodeNode applies worktree bypass, Hive MCP tools, results dir, '
      'allowed/denied tools (denied wins), and keeps extraArgs last',
      () async {
        final node = ClaudeCodeNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: policyAgentResolver,
        );

        final result = await node.execute(
          _context(
            isolationMode: WorkspaceIsolationMode.worktree,
            resultJsonPath: resultJsonPath,
            config: const {
              'agentId': 'sweeper',
              'extraArgs': ['--permission-mode', 'plan'],
            },
          ),
        );

        expect(result.isSuccess, isTrue);
        final args = processRunner.lastInvocation!.arguments;
        expect(args, contains('--dangerously-skip-permissions'));
        expect(args, containsAllInOrder(['--add-dir', resultsDir]));
        expect(
          args,
          containsAllInOrder([
            '--allowedTools',
            'mcp__hive__report_result,mcp__hive__ask_human,Read,Edit',
          ]),
        );
        expect(
          args,
          containsAllInOrder([
            '--disallowedTools',
            'Bash(git status),WebFetch',
          ]),
        );
        // extraArgs must stay last so user can override.
        expect(args.sublist(args.length - 2), ['--permission-mode', 'plan']);
      },
    );

    test(
      'ClaudeCodeNode applies direct mode acceptEdits and Hive MCP tools',
      () async {
        final node = ClaudeCodeNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: policyAgentResolver,
        );

        final result = await node.execute(
          _context(
            resultJsonPath: resultJsonPath,
            config: const {'agentId': 'sweeper'},
          ),
        );

        expect(result.isSuccess, isTrue);
        final args = processRunner.lastInvocation!.arguments;
        expect(args, isNot(contains('--dangerously-skip-permissions')));
        expect(args, containsAllInOrder(['--permission-mode', 'acceptEdits']));
        expect(args, containsAllInOrder(['--add-dir', resultsDir]));
        expect(
          args,
          containsAllInOrder([
            '--allowedTools',
            'mcp__hive__report_result,mcp__hive__ask_human,Read,Edit',
          ]),
        );
        expect(
          args,
          containsAllInOrder([
            '--disallowedTools',
            'Bash(git status),WebFetch',
          ]),
        );
      },
    );

    test(
      'CodexNode applies worktree bypass, direct sandbox, results dir, '
      'extraArgs last, and logs unsupported tool lists once per run',
      () async {
        final warnings = <String>[];
        final sub = Logger.root.onRecord.listen((record) {
          if (record.level >= Level.WARNING) {
            warnings.add(record.message);
          }
        });
        addTearDown(sub.cancel);

        final node = CodexNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: policyAgentResolver,
        );

        await node.execute(
          _context(
            runId: 'codex-policy-run-1',
            isolationMode: WorkspaceIsolationMode.worktree,
            resultJsonPath: resultJsonPath,
            config: const {
              'agentId': 'sweeper',
              'extraArgs': ['--model', 'o3'],
            },
          ),
        );

        final worktreeArgs = processRunner.lastInvocation!.arguments;
        expect(
          worktreeArgs,
          contains('--dangerously-bypass-approvals-and-sandbox'),
        );
        expect(worktreeArgs, containsAllInOrder(['--add-dir', resultsDir]));
        expect(worktreeArgs.sublist(worktreeArgs.length - 2), [
          '--model',
          'o3',
        ]);

        // Second call in same run must not duplicate the same gap warning.
        await node.execute(
          _context(
            runId: 'codex-policy-run-1',
            resultJsonPath: resultJsonPath,
            config: const {'agentId': 'sweeper'},
          ),
        );

        final directArgs = processRunner.lastInvocation!.arguments;
        expect(
          directArgs,
          isNot(contains('--dangerously-bypass-approvals-and-sandbox')),
        );
        expect(
          directArgs,
          containsAllInOrder(['--sandbox', 'workspace-write']),
        );
        expect(directArgs, containsAllInOrder(['--add-dir', resultsDir]));
        expect(
          warnings.where((w) => w.contains('allowed_tools')),
          hasLength(1),
        );
        expect(warnings.where((w) => w.contains('denied_tools')), hasLength(1));
      },
    );

    test('GeminiCliNode applies approval-mode, hive MCP server, include-dir, '
        'filtered allowed-tools, logs denied_tools gap once, and keeps '
        'extraArgs last', () async {
      final warnings = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        if (record.level >= Level.WARNING) {
          warnings.add(record.message);
        }
      });
      addTearDown(sub.cancel);

      final node = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: policyAgentResolver,
      );

      await node.execute(
        _context(
          runId: 'gemini-policy-run-1',
          isolationMode: WorkspaceIsolationMode.worktree,
          resultJsonPath: resultJsonPath,
          config: const {
            'agentId': 'sweeper',
            'extraArgs': ['--model', 'gemini-2.5-pro'],
          },
        ),
      );

      final worktreeArgs = processRunner.lastInvocation!.arguments;
      expect(worktreeArgs, containsAllInOrder(['--approval-mode', 'yolo']));
      expect(
        worktreeArgs,
        containsAllInOrder(['--allowed-mcp-server-names', 'hive']),
      );
      expect(
        worktreeArgs,
        containsAllInOrder(['--include-directories', resultsDir]),
      );
      expect(
        worktreeArgs,
        containsAllInOrder(['--allowed-tools', 'Read', 'Edit']),
      );
      expect(worktreeArgs, isNot(contains('Bash(git status)')));
      expect(worktreeArgs.sublist(worktreeArgs.length - 2), [
        '--model',
        'gemini-2.5-pro',
      ]);

      await node.execute(
        _context(
          runId: 'gemini-policy-run-1',
          resultJsonPath: resultJsonPath,
          config: const {'agentId': 'sweeper'},
        ),
      );

      final directArgs = processRunner.lastInvocation!.arguments;
      expect(directArgs, containsAllInOrder(['--approval-mode', 'auto_edit']));
      expect(warnings.where((w) => w.contains('denied_tools')), hasLength(1));
    });

    test('AntigravityNode applies worktree bypass, direct accept-edits mode, '
        'results dir, extraArgs last, and logs unsupported tool lists once '
        'per run', () async {
      final warnings = <String>[];
      final sub = Logger.root.onRecord.listen((record) {
        if (record.level >= Level.WARNING) {
          warnings.add(record.message);
        }
      });
      addTearDown(sub.cancel);

      final node = AntigravityNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: policyAgentResolver,
      );

      await node.execute(
        _context(
          runId: 'agy-policy-run-1',
          isolationMode: WorkspaceIsolationMode.worktree,
          resultJsonPath: resultJsonPath,
          config: const {
            'agentId': 'sweeper',
            'extraArgs': ['--model', 'gemini-3-pro'],
          },
        ),
      );

      final worktreeArgs = processRunner.lastInvocation!.arguments;
      expect(worktreeArgs, contains('--dangerously-skip-permissions'));
      expect(worktreeArgs, containsAllInOrder(['--add-dir', resultsDir]));
      expect(worktreeArgs.sublist(worktreeArgs.length - 2), [
        '--model',
        'gemini-3-pro',
      ]);

      await node.execute(
        _context(
          runId: 'agy-policy-run-1',
          resultJsonPath: resultJsonPath,
          config: const {'agentId': 'sweeper'},
        ),
      );

      final directArgs = processRunner.lastInvocation!.arguments;
      expect(directArgs, isNot(contains('--dangerously-skip-permissions')));
      expect(directArgs, containsAllInOrder(['--mode', 'accept-edits']));
      expect(directArgs, containsAllInOrder(['--add-dir', resultsDir]));
      expect(warnings.where((w) => w.contains('allowed_tools')), hasLength(1));
      expect(warnings.where((w) => w.contains('denied_tools')), hasLength(1));
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
      expect(ptyRunner.lastInvocation!.initialInput, isNull);
      expect(
        ptyRunner.lastInvocation!.environment['HIVE_PROMPT_FILE'],
        isNotNull,
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

    test('includes ## Run input section after agent prompt and before result '
        'contract instructions when runInput is non-empty', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          config: const {'agentId': 'coder'},
          runInput: 'Check all Dart files for unused imports.',
        ),
      );

      expect(result.isSuccess, isTrue);
      final invocation = processRunner.lastInvocation!;
      final prompt = invocation.stdinContent!;
      expect(
        invocation.arguments.join(' '),
        isNot(contains('Check all Dart files')),
      );
      expect(
        prompt,
        contains('## Run input\nCheck all Dart files for unused imports.'),
      );
      final agentIdx = prompt.indexOf('You are a careful Dart engineer.');
      final inputIdx = prompt.indexOf('## Run input');
      final contractIdx = prompt.indexOf('Call report_result when finished.');
      expect(agentIdx, lessThan(inputIdx));
      expect(inputIdx, lessThan(contractIdx));
    });

    test('omits ## Run input section when runInput is null or blank', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      for (final blank in [null, '', '   \n\t  ']) {
        final result = await node.execute(
          _context(config: const {'agentId': 'coder'}, runInput: blank),
        );
        expect(result.isSuccess, isTrue);
        expect(
          processRunner.lastInvocation!.stdinContent,
          isNot(contains('## Run input')),
        );
      }
    });

    test('includes ## Run attachments after ## Run input with absolute paths '
        'and names', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          runInput: 'Fix the layout',
          runAttachments: const [
            RunAttachmentFile(
              path: '/runs/r1/attachments/1.png',
              fileName: 'bug.png',
            ),
            RunAttachmentFile(
              path: '/runs/r1/attachments/2.jpg',
              fileName: 'expected.jpg',
            ),
          ],
        ),
      );

      expect(result.isSuccess, isTrue);
      final invocation = processRunner.lastInvocation!;
      final prompt = invocation.stdinContent!;
      expect(prompt, contains('## Run attachments'));
      expect(prompt, contains('Open them with your file-reading tool:'));
      expect(prompt, contains('- /runs/r1/attachments/1.png (bug.png)'));
      expect(prompt, contains('- /runs/r1/attachments/2.jpg (expected.jpg)'));

      final inputIndex = prompt.indexOf('## Run input');
      final attachmentsIndex = prompt.indexOf('## Run attachments');
      final contextIndex = prompt.indexOf('## Execution Context');
      expect(inputIndex, greaterThanOrEqualTo(0));
      expect(attachmentsIndex, greaterThan(inputIndex));
      expect(contextIndex, greaterThan(attachmentsIndex));

      expect(
        invocation.arguments,
        isNot(contains('/runs/r1/attachments/1.png')),
      );
      expect(
        invocation.arguments,
        isNot(contains('/runs/r1/attachments/2.jpg')),
      );
    });

    test('adds ## Run attachments without a Run input', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(
        _context(
          runAttachments: const [
            RunAttachmentFile(
              path: '/runs/r1/attachments/1.png',
              fileName: 'shot.png',
            ),
          ],
        ),
      );

      expect(result.isSuccess, isTrue);
      final prompt = processRunner.lastInvocation!.stdinContent!;
      expect(prompt, isNot(contains('## Run input')));
      expect(prompt, contains('## Run attachments'));
      expect(prompt, contains('- /runs/r1/attachments/1.png (shot.png)'));
      expect(
        prompt.indexOf('## Run attachments'),
        lessThan(prompt.indexOf('## Execution Context')),
      );
    });

    test('omits ## Run attachments when the run has none', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      final result = await node.execute(_context());
      expect(result.isSuccess, isTrue);
      expect(
        processRunner.lastInvocation!.stdinContent,
        isNot(contains('## Run attachments')),
      );
    });
  });

  group('Headless harness attachments permission policy', () {
    const attachments = [
      RunAttachmentFile(
        path: '/runs/r1/attachments/1.png',
        fileName: 'shot.png',
      ),
    ];
    const attachmentsDir = '/runs/r1/attachments';

    test('ClaudeCodeNode adds --add-dir for attachmentsDir in direct and '
        'worktree modes', () async {
      final node = ClaudeCodeNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      for (final mode in WorkspaceIsolationMode.values) {
        await node.execute(
          _context(isolationMode: mode, runAttachments: attachments),
        );
        final args = processRunner.lastInvocation!.arguments;
        expect(args, containsAllInOrder(['--add-dir', attachmentsDir]));
        expect(args, isNot(contains('/runs/r1')));
      }

      await node.execute(_context());
      expect(
        processRunner.lastInvocation!.arguments,
        isNot(contains(attachmentsDir)),
      );
    });

    test(
      'CodexNode adds --add-dir for attachmentsDir only when present',
      () async {
        final node = CodexNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentResolver,
        );

        await node.execute(_context(runAttachments: attachments));
        var args = processRunner.lastInvocation!.arguments;
        expect(args, containsAllInOrder(['--add-dir', attachmentsDir]));
        expect(args, isNot(contains('/runs/r1')));

        await node.execute(_context());
        args = processRunner.lastInvocation!.arguments;
        expect(args, isNot(contains(attachmentsDir)));
      },
    );

    test('GeminiCliNode adds --include-directories for attachmentsDir '
        'only when present', () async {
      final node = GeminiCliNode(
        processRunner: processRunner,
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      await node.execute(_context(runAttachments: attachments));
      var args = processRunner.lastInvocation!.arguments;
      expect(
        args,
        containsAllInOrder(['--include-directories', attachmentsDir]),
      );
      expect(args, isNot(contains('/runs/r1')));

      await node.execute(_context());
      args = processRunner.lastInvocation!.arguments;
      expect(args, isNot(contains(attachmentsDir)));
    });

    test(
      'AntigravityNode adds --add-dir for attachmentsDir only when present',
      () async {
        final node = AntigravityNode(
          processRunner: processRunner,
          resultContract: resultContract,
          agentPromptResolver: agentResolver,
        );

        await node.execute(_context(runAttachments: attachments));
        var args = processRunner.lastInvocation!.arguments;
        expect(args, containsAllInOrder(['--add-dir', attachmentsDir]));
        expect(args, isNot(contains('/runs/r1')));

        await node.execute(_context());
        args = processRunner.lastInvocation!.arguments;
        expect(args, isNot(contains(attachmentsDir)));
      },
    );
  });

  group('Rate limit after the result contract', () {
    late _FakeProcessRunner processRunner;
    late _FakeResultContract resultContract;
    late _FakeAgentPromptResolver agentResolver;

    setUp(() {
      processRunner = _FakeProcessRunner(
        const ProcessExecutionResult(exitCode: 0),
      );
      resultContract = _FakeResultContract()
        ..report = const ResultContractReport(
          status: ResultContractStatus.success,
          summary: 'Done',
        );
      agentResolver = _FakeAgentPromptResolver(const <String, String>{});
    });

    final headlessCases =
        <
          ({
            String name,
            String typeId,
            Future<Result<Object>> Function(NodeExecutionContext) execute,
            String rateLimitLine,
            String authLine,
          })
        >[
          (
            name: 'ClaudeCodeNode',
            typeId: 'harness.claude_code',
            execute: (ctx) => ClaudeCodeNode(
              processRunner: processRunner,
              resultContract: resultContract,
              agentPromptResolver: agentResolver,
            ).execute(ctx),
            rateLimitLine: 'Error: 429 Too Many Requests',
            authLine: 'Please run `claude login` (401 Unauthorized)',
          ),
          (
            name: 'CodexNode',
            typeId: 'harness.codex',
            execute: (ctx) => CodexNode(
              processRunner: processRunner,
              resultContract: resultContract,
              agentPromptResolver: agentResolver,
            ).execute(ctx),
            rateLimitLine: 'Error: usage limit reached',
            authLine: '401 Unauthorized',
          ),
          (
            name: 'GeminiCliNode',
            typeId: 'harness.gemini_cli',
            execute: (ctx) => GeminiCliNode(
              processRunner: processRunner,
              resultContract: resultContract,
              agentPromptResolver: agentResolver,
            ).execute(ctx),
            rateLimitLine: 'RESOURCE_EXHAUSTED: quota exceeded',
            authLine: '401 Unauthorized',
          ),
          (
            name: 'AntigravityNode',
            typeId: 'harness.antigravity',
            execute: (ctx) => AntigravityNode(
              processRunner: processRunner,
              resultContract: resultContract,
              agentPromptResolver: agentResolver,
            ).execute(ctx),
            rateLimitLine: 'Error: model is at capacity',
            authLine: '401 Unauthorized',
          ),
        ];

    for (final entry in headlessCases) {
      group(entry.name, () {
        test(
          'exit 1 + matching stderr + null report -> HarnessRateLimitFailure',
          () async {
            resultContract.report = null;
            processRunner.result = ProcessExecutionResult(
              exitCode: 1,
              stderr: entry.rateLimitLine,
            );

            final result = await entry.execute(_context());
            final failure = result.failureOrNull;
            expect(failure, isA<HarnessRateLimitFailure>());
            expect(
              (failure! as HarnessRateLimitFailure).harnessType,
              entry.typeId,
            );
          },
        );

        test(
          'exit 0 + matching stdout + null report -> HarnessRateLimitFailure',
          () async {
            resultContract.report = null;
            processRunner.result = ProcessExecutionResult(
              exitCode: 0,
              stdout: entry.rateLimitLine,
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<HarnessRateLimitFailure>());
          },
        );

        test(
          'exit 0 + matching stdout + report set -> NodeOutput.onSuccess',
          () async {
            processRunner.result = ProcessExecutionResult(
              exitCode: 0,
              stdout: entry.rateLimitLine,
            );

            final result = await entry.execute(_context());
            expect(result.isSuccess, isTrue);
          },
        );

        test(
          'exit 1 + matching stderr + report set -> NodeExecutionFailure',
          () async {
            processRunner.result = ProcessExecutionResult(
              exitCode: 1,
              stderr: entry.rateLimitLine,
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<NodeExecutionFailure>());
            expect(result.failureOrNull, isNot(isA<HarnessRateLimitFailure>()));
          },
        );

        test(
          'timedOut + matching text + report set -> NodeExecutionFailure',
          () async {
            processRunner.result = ProcessExecutionResult(
              exitCode: -1,
              timedOut: true,
              stderr: entry.rateLimitLine,
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<NodeExecutionFailure>());
            expect(result.failureOrNull, isNot(isA<HarnessRateLimitFailure>()));
          },
        );

        test(
          'exit 1 + auth and rate limit + null report -> auth wins',
          () async {
            resultContract.report = null;
            processRunner.result = ProcessExecutionResult(
              exitCode: 1,
              stderr: '${entry.authLine}\n${entry.rateLimitLine}',
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<HarnessAuthenticationFailure>());
          },
        );

        test(
          'exit 0 + auth text only + null report -> NodeExecutionFailure',
          () async {
            resultContract.report = null;
            processRunner.result = ProcessExecutionResult(
              exitCode: 0,
              stdout: entry.authLine,
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<NodeExecutionFailure>());
            expect(
              result.failureOrNull,
              isNot(isA<HarnessAuthenticationFailure>()),
            );
          },
        );

        test(
          'timedOut + null report + no match -> NodeExecutionFailure',
          () async {
            resultContract.report = null;
            processRunner.result = const ProcessExecutionResult(
              exitCode: -1,
              timedOut: true,
            );

            final result = await entry.execute(_context());
            expect(result.failureOrNull, isA<NodeExecutionFailure>());
          },
        );

        test('exit 0 + matching text + malformed report -> '
            'HarnessRateLimitFailure', () async {
          resultContract.readFailure = const ValidationFailure(
            'Invalid JSON in fallback result.json.',
          );
          processRunner.result = ProcessExecutionResult(
            exitCode: 0,
            stdout: entry.rateLimitLine,
          );

          final result = await entry.execute(_context());
          expect(result.failureOrNull, isA<HarnessRateLimitFailure>());
        });
      });
    }

    test('TerminalHarnessNode: exit 0 + rate limit + null report stays '
        'NodeExecutionFailure; exit 1 -> HarnessRateLimitFailure', () async {
      resultContract.report = null;
      final ptyRunner = _RateLimitFakePtyRunner();
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _RateLimitFakeShellProvider('/bin/zsh'),
        resultContract: resultContract,
        agentPromptResolver: agentResolver,
      );

      ptyRunner.result = const ProcessExecutionResult(
        exitCode: 0,
        stdout: 'rate limit',
      );
      final cleanResult = await node.execute(
        _context(config: const <String, Object?>{'command': 'my-cli'}),
      );
      expect(cleanResult.failureOrNull, isA<NodeExecutionFailure>());
      expect(cleanResult.failureOrNull, isNot(isA<HarnessRateLimitFailure>()));

      ptyRunner.result = const ProcessExecutionResult(
        exitCode: 1,
        stderr: 'rate limit',
      );
      final failedResult = await node.execute(
        _context(config: const <String, Object?>{'command': 'my-cli'}),
      );
      expect(failedResult.failureOrNull, isA<HarnessRateLimitFailure>());
    });
  });
}

final class _RateLimitFakePtyRunner implements PtyRunner {
  ProcessExecutionResult result = const ProcessExecutionResult(exitCode: 0);

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async => Success(result);
}

final class _RateLimitFakeShellProvider implements DefaultShellProvider {
  const new(this.defaultShell);

  @override
  final String defaultShell;
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
