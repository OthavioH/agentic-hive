import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/nodes/windows_pty_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_backend/src/domain/result_contract/result_contract_coordinator.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _FakePtyRunner implements PtyRunner {
  new({this.onRun});

  final Future<Result<ProcessExecutionResult>> Function(
    PtyInvocation invocation,
    NodeOutputCallback? onOutput,
  )?
  onRun;

  PtyInvocation? lastInvocation;
  String? observedPromptFileContent;

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    lastInvocation = invocation;
    final promptPath = invocation.environment['HIVE_PROMPT_FILE'];
    if (promptPath != null && File(promptPath).existsSync()) {
      observedPromptFileContent = await File(promptPath).readAsString();
    }
    if (onRun != null) {
      return await onRun!(invocation, onOutput);
    }
    return const Success(ProcessExecutionResult(exitCode: 0));
  }
}

final class _FakeShellProvider implements DefaultShellProvider {
  const new(this.defaultShell);

  @override
  final String defaultShell;
}

final class _FakeAgentPromptResolver implements AgentPromptResolver {
  @override
  Future<Result<String>> resolvePrompt(
    String agentId, {
    String? workspaceRoot,
  }) => Future<Result<String>>.value(Success('Agent prompt for $agentId'));

  @override
  Future<Result<ResolvedAgent>> resolveAgent(
    String agentId, {
    String? workspaceRoot,
  }) => Future<Result<ResolvedAgent>>.value(
    Success(ResolvedAgent(prompt: 'Agent prompt for $agentId')),
  );
}

final class _FakeProcessTreeKiller implements ProcessTreeKiller {
  final List<(String, String?)> kills = <(String, String?)>[];
  void Function(String runId, String? nodeId)? onKill;
  Result<void> nextResult = const Success(null);

  @override
  Future<Result<void>> killTree({required String runId, String? nodeId}) async {
    kills.add((runId, nodeId));
    onKill?.call(runId, nodeId);
    return nextResult;
  }
}

final class _FakeResultContract implements ResultContract {
  new({this.coordinator});

  final ResultContractCoordinator? coordinator;
  ResultContractReport report = const ResultContractReport(
    status: ResultContractStatus.success,
    summary: 'Done',
  );

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Report via report_result.';

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async {
    final coord = coordinator;
    if (coord != null) {
      coord.registerAttempt(
        runId: context.runId,
        nodeId: context.nodeId,
        attempt: context.attempt,
        workspacePath: context.workspacePath,
        availableOutputs: context.availableOutputs,
      );
    }
    return Success(
      _FakeResultContractSession(
        context: context,
        instructions: instructionsFor(context),
        coordinator: coord,
        fallbackReport: report,
      ),
    );
  }

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async => Success(report);
}

final class _FakeResultContractSession implements ResultContractSession {
  new({
    required NodeExecutionContext context,
    required this.instructions,
    required this.coordinator,
    required this.fallbackReport,
  }) : runId = context.runId,
       nodeId = context.nodeId,
       attempt = context.attempt;

  final ResultContractCoordinator? coordinator;
  final ResultContractReport fallbackReport;

  @override
  final String runId;

  @override
  final String nodeId;

  @override
  final int attempt;

  @override
  final String instructions;

  @override
  String? get mcpConfigPath => '/tmp/fake-mcp.json';

  @override
  Map<String, String> get env => <String, String>{
    'HIVE_RUN_ID': runId,
    'HIVE_NODE_ID': nodeId,
    'HIVE_ATTEMPT': '$attempt',
  };

  @override
  String? get resultFilePath => '/tmp/fake-result.json';

  @override
  Future<ResultContractReport>? get onMcpReportAccepted => coordinator
      ?.watchMcpReport(runId: runId, nodeId: nodeId, attempt: attempt);

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
        NodeExecutionFailure('Exited with $exitCode.', exitCode: exitCode),
      );
    }
    final locked = coordinator?.getLockedMcpReport(
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
    );
    return Success(locked ?? fallbackReport);
  }

  @override
  Future<void> dispose() async {
    coordinator?.unregisterAttempt(
      runId: runId,
      nodeId: nodeId,
      attempt: attempt,
    );
  }
}

final class _FakePtySessionHandle implements PtySessionHandle {
  new(this.key);

  @override
  final PtySessionKey key;

  @override
  bool isActive = true;

  final List<List<int>> inputs = <List<int>>[];
  final List<(int, int)> resizes = <(int, int)>[];
  bool terminated = false;

  @override
  Future<void> writeInput(List<int> bytes) async {
    inputs.add(bytes);
  }

  @override
  Future<void> resize(int cols, int rows) async {
    resizes.add((cols, rows));
  }

  @override
  Future<void> terminate() async {
    terminated = true;
    isActive = false;
  }
}

void main() {
  late Directory workspaceDir;

  setUp(() async {
    workspaceDir = await Directory.systemTemp.createTemp('hive_thn_test_');
  });

  tearDown(() async {
    if (workspaceDir.existsSync()) {
      await workspaceDir.delete(recursive: true);
    }
  });

  NodeExecutionContext makeContext({
    Map<String, Object?> config = const <String, Object?>{},
  }) => NodeExecutionContext(
    runId: 'run-1',
    nodeId: 'term-1',
    workspacePath: workspaceDir.path,
    config: config,
  );

  group('TerminalHarnessNode', () {
    test('creates HIVE_PROMPT_FILE, exposes HIVE_RESULT_PATH, and cleans up '
        'temp prompt file', () async {
      final ptyRunner = _FakePtyRunner();
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/zsh'),
        resultContract: _FakeResultContract(),
        agentPromptResolver: _FakeAgentPromptResolver(),
      );

      final result = await node.execute(
        makeContext(
          config: const <String, Object?>{
            'command': 'my-cli',
            'additionalInstructions': 'Build the widget.',
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      final invocation = ptyRunner.lastInvocation!;
      final promptFile = invocation.environment['HIVE_PROMPT_FILE'];
      expect(promptFile, isNotNull);
      expect(
        ptyRunner.observedPromptFileContent,
        contains('Build the widget.'),
      );
      expect(File(promptFile!).existsSync(), isFalse);
      expect(
        invocation.environment['HIVE_RESULT_PATH'],
        '/tmp/fake-result.json',
      );
      expect(invocation.environment['HIVE_MCP_CONFIG'], '/tmp/fake-mcp.json');
      expect(invocation.initialInput, isNull);
    });

    test(
      'sendPromptToStdin passes prompt to initialInput only when true',
      () async {
        final ptyRunner = _FakePtyRunner();
        final node = TerminalHarnessNode(
          ptyRunner: ptyRunner,
          defaultShellProvider: const _FakeShellProvider('/bin/sh'),
          resultContract: _FakeResultContract(),
          agentPromptResolver: _FakeAgentPromptResolver(),
        );

        final result = await node.execute(
          makeContext(
            config: const <String, Object?>{
              'command': 'my-cli',
              'additionalInstructions': 'Hello stdin',
              'sendPromptToStdin': true,
            },
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(ptyRunner.lastInvocation!.initialInput, contains('Hello stdin'));
      },
    );

    test(
      'falls back to DefaultShellProvider when command is null or blank',
      () async {
        final ptyRunner = _FakePtyRunner();
        final node = TerminalHarnessNode(
          ptyRunner: ptyRunner,
          defaultShellProvider: const _FakeShellProvider('/usr/bin/fish'),
          resultContract: _FakeResultContract(),
          agentPromptResolver: _FakeAgentPromptResolver(),
        );

        final result = await node.execute(
          makeContext(
            config: const <String, Object?>{
              'command': '   ',
              'additionalInstructions': 'Run in default shell',
            },
          ),
        );

        expect(result.isSuccess, isTrue);
        expect(ptyRunner.lastInvocation!.executable, '/usr/bin/fish');
      },
    );

    test('terminates idle PTY after grace period when report_result is '
        'accepted over MCP and resolves with accepted outcome', () async {
      final coordinator = ResultContractCoordinator();
      final killer = _FakeProcessTreeKiller();
      final ptyExitCompleter = Completer<Result<ProcessExecutionResult>>();
      killer.onKill = (runId, nodeId) {
        if (!ptyExitCompleter.isCompleted) {
          ptyExitCompleter.complete(
            const Success(ProcessExecutionResult(exitCode: 1)),
          );
        }
      };

      final ptyRunner = _FakePtyRunner(
        onRun: (invocation, onOutput) {
          final submit = coordinator.submitMcpReport(
            runId: 'run-1',
            nodeId: 'term-1',
            attempt: 1,
            payload: const <String, Object?>{
              'status': 'onSuccess',
              'summary': 'Interactive task finished.',
            },
          );
          expect(submit.isSuccess, isTrue);
          return ptyExitCompleter.future;
        },
      );

      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/sh'),
        resultContract: _FakeResultContract(coordinator: coordinator),
        agentPromptResolver: _FakeAgentPromptResolver(),
        processTreeKiller: killer,
        mcpGracePeriod: const Duration(milliseconds: 30),
      );

      final result = await node.execute(
        makeContext(
          config: const <String, Object?>{
            'command': 'repl-cli',
            'additionalInstructions': 'Stay open after report.',
          },
        ),
      );

      expect(result.isSuccess, isTrue);
      expect(result.valueOrNull!.outputLabel, NodeOutput.onSuccess);
      expect(result.valueOrNull!.data['summary'], 'Interactive task finished.');
      expect(killer.kills, [('run-1', 'term-1')]);
    });

    test('non-zero exit code without MCP report fails per ADR 0003', () async {
      final ptyRunner = _FakePtyRunner(
        onRun: (_, _) async =>
            const Success(ProcessExecutionResult(exitCode: 2, stdout: 'boom')),
      );
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/sh'),
        resultContract: _FakeResultContract(),
        agentPromptResolver: _FakeAgentPromptResolver(),
      );

      final result = await node.execute(
        makeContext(config: const <String, Object?>{'command': 'failing-cli'}),
      );

      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<NodeExecutionFailure>());
    });

    test('sets TERM and COLORTERM defaults and allows env overrides', () async {
      final ptyRunner = _FakePtyRunner();
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/sh'),
        resultContract: _FakeResultContract(),
        agentPromptResolver: _FakeAgentPromptResolver(),
      );

      final result = await node.execute(
        makeContext(config: const <String, Object?>{'command': 'my-cli'}),
      );
      expect(result.isSuccess, isTrue);
      expect(ptyRunner.lastInvocation!.environment['TERM'], 'xterm-256color');
      expect(ptyRunner.lastInvocation!.environment['COLORTERM'], 'truecolor');
    });

    test('sendPromptToStdin appends CR for ConPTY Enter semantics', () async {
      final ptyRunner = _FakePtyRunner();
      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/sh'),
        resultContract: _FakeResultContract(),
        agentPromptResolver: _FakeAgentPromptResolver(),
      );

      final result = await node.execute(
        makeContext(
          config: const <String, Object?>{
            'command': 'my-cli',
            'additionalInstructions': 'Submit me',
            'sendPromptToStdin': true,
          },
        ),
      );
      expect(result.isSuccess, isTrue);
      expect(ptyRunner.lastInvocation!.initialInput, endsWith('\r'));
      expect(ptyRunner.lastInvocation!.initialInput, isNot(endsWith('\n')));
    });

    test('fails when post-grace killTree is unconfirmed', () async {
      final coordinator = ResultContractCoordinator();
      final killer = _FakeProcessTreeKiller()
        ..nextResult = const FailureResult(
          NodeExecutionFailure('killTree failed'),
        );
      final ptyExitCompleter = Completer<Result<ProcessExecutionResult>>();
      killer.onKill = (_, _) {
        if (!ptyExitCompleter.isCompleted) {
          ptyExitCompleter.complete(
            const Success(ProcessExecutionResult(exitCode: 0)),
          );
        }
      };

      final ptyRunner = _FakePtyRunner(
        onRun: (_, _) {
          coordinator.submitMcpReport(
            runId: 'run-1',
            nodeId: 'term-1',
            attempt: 1,
            payload: const <String, Object?>{
              'status': 'onSuccess',
              'summary': 'Done',
            },
          );
          return ptyExitCompleter.future;
        },
      );

      final node = TerminalHarnessNode(
        ptyRunner: ptyRunner,
        defaultShellProvider: const _FakeShellProvider('/bin/sh'),
        resultContract: _FakeResultContract(coordinator: coordinator),
        agentPromptResolver: _FakeAgentPromptResolver(),
        processTreeKiller: killer,
        mcpGracePeriod: const Duration(milliseconds: 20),
      );

      final result = await node.execute(
        makeContext(config: const <String, Object?>{'command': 'repl-cli'}),
      );
      expect(result.isFailure, isTrue);
    });
  });

  group('PtyScrollbackBuffer', () {
    test('retains up to capacityBytes and evicts oldest bytes on wrap', () {
      final buffer = PtyScrollbackBuffer(capacityBytes: 8)
        ..append(<int>[1, 2, 3, 4, 5])
        ..append(<int>[6, 7, 8, 9, 10]);

      expect(buffer.length, 8);
      expect(buffer.snapshot(), <int>[3, 4, 5, 6, 7, 8, 9, 10]);

      buffer.append(<int>[11, 12, 13, 14, 15, 16, 17, 18, 19, 20]);
      expect(buffer.snapshot(), <int>[13, 14, 15, 16, 17, 18, 19, 20]);
    });

    test('trims leading orphaned UTF-8 continuation bytes after eviction', () {
      final emoji = utf8.encode('😀'); // 4 bytes: F0 9F 98 80
      final tail = utf8.encode('ok');
      final buffer = PtyScrollbackBuffer(capacityBytes: 4)
        ..append(emoji)
        ..append(tail);

      // Buffer holds last 4 bytes: [0x98, 0x80, 'o', 'k'].
      expect(utf8.decode(buffer.snapshot()), 'ok');
    });

    test('trims partial CSI fragment after eviction', () {
      final buffer = PtyScrollbackBuffer(capacityBytes: 8)
        ..append(utf8.encode('\x1b[31;1mhi'));

      // Buffer holds last 8 bytes: '[31;1mhi' (ESC evicted).
      expect(utf8.decode(buffer.snapshot()), 'hi');
    });
  });

  group('resolveWindowsExecutable', () {
    test('resolves .cmd shim via PATHEXT and PATH', () async {
      final binDir = Directory(
        '${workspaceDir.path}${Platform.pathSeparator}bin',
      );
      await binDir.create();
      final shim = File('${binDir.path}${Platform.pathSeparator}claude.cmd');
      await shim.writeAsString('@echo off\r\n');

      final resolved = resolveWindowsExecutable(
        'claude',
        workingDirectory: workspaceDir.path,
        env: <String, String>{
          'PATH': binDir.path,
          'PATHEXT': '.COM;.EXE;.BAT;.CMD',
        },
      );
      expect(resolved, shim.path);
    });
  });

  group('PtySessionRegistry', () {
    test(
      'coalesces rapid output chunks and replays scrollback snapshot',
      () async {
        final registry = PtySessionRegistry(
          coalesceWindow: const Duration(milliseconds: 25),
          maxCoalesceBytes: 64,
        );
        addTearDown(registry.dispose);

        const key = (runId: 'run-1', nodeId: 'term-1', attempt: 1);
        final handle = _FakePtySessionHandle(key);
        registry.registerSession(handle);

        final emitted = <PtyOutputPayload>[];
        final sub = registry.outputs.listen(emitted.add);
        addTearDown(sub.cancel);

        registry
          ..appendOutput(key, utf8.encode('hello '))
          ..appendOutput(key, utf8.encode('world'));

        expect(emitted, isEmpty);
        await Future<void>.delayed(const Duration(milliseconds: 60));
        expect(emitted, hasLength(1));
        expect(utf8.decode(base64Decode(emitted.single.data)), 'hello world');
        expect(
          utf8.decode(registry.getScrollbackSnapshot(key)!),
          'hello world',
        );
      },
    );

    test('rejects writeInput and resize when session is not active', () async {
      final registry = PtySessionRegistry();
      addTearDown(registry.dispose);

      const key = (runId: 'run-1', nodeId: 'term-1', attempt: 1);
      expect((await registry.writeInput(key, <int>[65])).isFailure, isTrue);
      expect(
        (await registry.resize(key, cols: 80, rows: 24)).isFailure,
        isTrue,
      );

      final handle = _FakePtySessionHandle(key);
      registry.registerSession(handle);
      expect((await registry.writeInput(key, <int>[65])).isSuccess, isTrue);
      expect(
        (await registry.resize(key, cols: 100, rows: 30)).isSuccess,
        isTrue,
      );
      expect(handle.inputs, [
        <int>[65],
      ]);
      expect(handle.resizes, [(100, 30)]);

      await registry.unregisterSession(key);
      expect((await registry.writeInput(key, <int>[66])).isFailure, isTrue);
    });
  });
}
