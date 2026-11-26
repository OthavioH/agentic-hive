import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/nodes/command_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/headless_harness_nodes.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_execution_context.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_registry.dart';
import 'package:agentic_hive_backend/src/domain/nodes/terminal_harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/validator_nodes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'support/engine_harness.dart';

final class _RecordingProcessRunner implements NodeProcessRunner {
  new(this._handler);

  final ProcessExecutionResult Function(ProcessInvocation invocation) _handler;
  final List<ProcessInvocation> invocations = <ProcessInvocation>[];

  @override
  Future<Result<ProcessExecutionResult>> run(
    ProcessInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    invocations.add(invocation);
    return Success(_handler(invocation));
  }
}

final class _RecordingPtyRunner implements PtyRunner {
  new(this._handler);

  final ProcessExecutionResult Function(PtyInvocation invocation) _handler;
  final List<PtyInvocation> invocations = <PtyInvocation>[];

  @override
  Future<Result<ProcessExecutionResult>> run(
    PtyInvocation invocation, {
    NodeOutputCallback? onOutput,
  }) async {
    invocations.add(invocation);
    return Success(_handler(invocation));
  }
}

final class _FakeShellProvider implements DefaultShellProvider {
  const new();

  @override
  String get defaultShell => '/bin/sh';
}

final class _ScriptedResultContract implements ResultContract {
  new(this._reports);

  final Map<String, ResultContractReport> _reports;

  @override
  Future<Result<ResultContractSession>> openSession(
    NodeExecutionContext context,
  ) async => Success(
    _ScriptedResultContractSession(
      context: context,
      report: _reports[context.nodeId]!,
    ),
  );

  @override
  String instructionsFor(NodeExecutionContext context) =>
      'Call report_result when finished.';

  @override
  Future<Result<ResultContractReport?>> readReport(
    NodeExecutionContext context,
  ) async => Success(_reports[context.nodeId]);
}

final class _ScriptedResultContractSession implements ResultContractSession {
  new({required NodeExecutionContext context, required this.report})
    : runId = context.runId,
      nodeId = context.nodeId,
      attempt = context.attempt;

  final ResultContractReport report;

  @override
  final String runId;

  @override
  final String nodeId;

  @override
  final int attempt;

  @override
  String get instructions => 'Call report_result when finished.';

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
  }) async => Success(report);

  @override
  Future<void> dispose() async {}
}

final class _EmptyAgentPromptResolver implements AgentPromptResolver {
  const new();

  @override
  Future<Result<String>> resolvePrompt(
    String agentId, {
    String? workspaceRoot,
  }) async => FailureResult(NotFoundFailure('Agent "$agentId" not found.'));

  @override
  Future<Result<ResolvedAgent>> resolveAgent(
    String agentId, {
    String? workspaceRoot,
  }) async => FailureResult(NotFoundFailure('Agent "$agentId" not found.'));
}

Map<String, Object?> _extractPromptInputsJson(String prompt) {
  final line = prompt
      .split('\n')
      .firstWhere(
        (l) => l.startsWith('- Inputs: '),
        orElse: () => fail('Expected "- Inputs: " line in prompt:\n$prompt'),
      );
  final raw = line.substring('- Inputs: '.length).trim();
  return jsonDecode(raw) as Map<String, Object?>;
}

WorkflowNode _node(
  String id,
  String type, {
  JsonMap config = const <String, Object?>{},
}) => WorkflowNode(
  id: id,
  type: type,
  label: id,
  position: const WorkflowPosition(x: 0, y: 0),
  config: config,
);

void main() {
  late Directory tempWorkspace;

  setUp(() async {
    tempWorkspace = await Directory.systemTemp.createTemp('hive_eng_outputs_');
  });

  tearDown(() {
    if (tempWorkspace.existsSync()) {
      tempWorkspace.deleteSync(recursive: true);
    }
  });

  group('GraphEngine harness outputs and prompt inputs', () {
    test('excludes raw stdout/stderr from checkpoints and downstream prompts '
        'across headless, terminal, and review nodes, and deduplicates '
        'predecessors as valid JSON', () async {
      const rawClaudeTranscript =
          '{"type":"system","subtype":"init",'
          '"secret_marker":"RAW_CLAUDE_STDOUT"}\n'
          '{"type":"user","message":{"content":"huge file dump"}}';
      const rawCodexTranscript =
          '{"type":"thread.started","marker":"RAW_CODEX_STDOUT"}';
      const rawPtyTranscript = '\x1b[32mRAW_PTY_STDOUT\x1b[0m';
      const rawStderr = 'RAW_STDERR_NOISE';

      final processRunner = _RecordingProcessRunner((inv) {
        return switch (inv.nodeId) {
          'analyze' => const ProcessExecutionResult(
            exitCode: 0,
            stdout: rawClaudeTranscript,
            stderr: rawStderr,
          ),
          'spec' => const ProcessExecutionResult(
            exitCode: 0,
            stdout: rawCodexTranscript,
            stderr: rawStderr,
          ),
          'review' => const ProcessExecutionResult(
            exitCode: 0,
            stdout: '{"type":"assistant","marker":"RAW_REVIEW_STDOUT"}',
            stderr: rawStderr,
          ),
          _ => const ProcessExecutionResult(exitCode: 0),
        };
      });
      final ptyRunner = _RecordingPtyRunner(
        (_) => const ProcessExecutionResult(
          exitCode: 0,
          stdout: rawPtyTranscript,
          stderr: rawStderr,
        ),
      );
      final contract = _ScriptedResultContract(<String, ResultContractReport>{
        'analyze': const ResultContractReport(
          status: ResultContractStatus.success,
          summary: 'Analyzed request',
          output: <String, Object?>{'analysis': 'clean structured analysis'},
          artifacts: <String>['docs/analysis.md'],
        ),
        'spec': const ResultContractReport(
          status: ResultContractStatus.success,
          summary: 'Wrote spec',
          output: <String, Object?>{'spec': 166},
        ),
        'terminal_step': const ResultContractReport(
          status: ResultContractStatus.success,
          summary: 'Terminal done',
          output: <String, Object?>{'ticketCount': 3},
        ),
        'review': const ResultContractReport(
          status: ResultContractStatus.approved,
          summary: 'Looks good',
          output: <String, Object?>{'verdict': 'ship'},
        ),
      });
      const agentResolver = _EmptyAgentPromptResolver();

      late NodeRegistry sharedRegistry;
      final h = EngineHarness(
        registerNodes: (registry) {
          sharedRegistry = registry;
          registry
            ..register(
              NodeDescriptors.claudeCode,
              () => ClaudeCodeNode(
                processRunner: processRunner,
                resultContract: contract,
                agentPromptResolver: agentResolver,
              ),
            )
            ..register(
              NodeDescriptors.codex,
              () => CodexNode(
                processRunner: processRunner,
                resultContract: contract,
                agentPromptResolver: agentResolver,
              ),
            )
            ..register(
              NodeDescriptors.terminal,
              () => TerminalHarnessNode(
                ptyRunner: ptyRunner,
                defaultShellProvider: const _FakeShellProvider(),
                resultContract: contract,
                agentPromptResolver: agentResolver,
              ),
            )
            ..register(
              NodeDescriptors.reviewValidator,
              () => ReviewValidatorNode(resolveNode: sharedRegistry.create),
            );
        },
      );

      final at = DateTime.utc(2026);
      final workflow = Workflow(
        id: 'wf-harness-chain',
        name: 'Harness chain',
        nodes: <WorkflowNode>[
          _node(
            'analyze',
            NodeTypeId.claudeCode,
            config: const <String, Object?>{
              'additionalInstructions': 'Analyze task',
            },
          ),
          _node(
            'spec',
            NodeTypeId.codex,
            config: const <String, Object?>{
              'additionalInstructions': 'Write spec',
            },
          ),
          _node(
            'terminal_step',
            NodeTypeId.terminal,
            config: const <String, Object?>{
              'additionalInstructions': 'Run terminal step',
              'sendPromptToStdin': true,
            },
          ),
          _node(
            'review',
            NodeTypeId.reviewValidator,
            config: const <String, Object?>{
              'harnessType': NodeTypeId.claudeCode,
              'reviewCriteria': 'Check everything',
            },
          ),
        ],
        edges: <WorkflowEdge>[
          edge('analyze', NodeOutput.onSuccess, 'spec'),
          edge('spec', NodeOutput.onSuccess, 'terminal_step'),
          edge('terminal_step', NodeOutput.onSuccess, 'review'),
        ],
        createdAt: at,
        updatedAt: at,
        entryNodeId: 'analyze',
      );

      final run = Run(
        id: runId,
        workflowName: workflow.name,
        workflowDefinition: workflow,
        workspaceRoot: tempWorkspace.path,
        status: RunStatus.running,
        startedAt: at,
      );
      await h.runs.create(run);

      final result = await h.engine.start(runId);
      expect(result.valueOrNull?.status, RunStatus.succeeded);

      // Check persisted checkpoints never contain raw stdout/stderr.
      final latestCheckpoint = (await h.checkpoints.listForRun(runId))
          .valueOrNull!
          .last;
      for (final nodeId in ['analyze', 'spec', 'terminal_step', 'review']) {
        final entry = latestCheckpoint.nodeOutputs[nodeId]!;
        final data = entry['data']! as Map<String, Object?>;
        expect(data.containsKey('stdout'), isFalse, reason: nodeId);
        expect(data.containsKey('stderr'), isFalse, reason: nodeId);
        expect(data['contractStatus'], isNotNull, reason: nodeId);
      }
      expect(
        (latestCheckpoint.nodeOutputs['analyze']!['data']!
            as Map<String, Object?>)['analysis'],
        'clean structured analysis',
      );
      expect(latestCheckpoint.nodeOutputs['analyze']!['artifacts'], [
        'docs/analysis.md',
      ]);

      // Downstream prompts must be valid JSON, omit raw transcripts, and
      // list predecessorIds instead of duplicating predecessor payloads.
      final specPrompt = processRunner.invocations
          .firstWhere((i) => i.nodeId == 'spec')
          .stdinContent!;
      expect(specPrompt, isNot(contains('RAW_CLAUDE_STDOUT')));
      expect(specPrompt, isNot(contains('RAW_STDERR_NOISE')));
      final specInputs = _extractPromptInputsJson(specPrompt);
      expect(specInputs['predecessorIds'], ['analyze']);
      expect(specInputs.containsKey('predecessors'), isFalse);
      expect((specInputs['nodeOutputs']! as Map<String, Object?>).keys, [
        'analyze',
      ]);

      // Terminal harness prompt delivered to PTY stdin.
      final ptyPrompt = ptyRunner.invocations.single.initialInput!;
      expect(ptyPrompt, isNot(contains('RAW_CLAUDE_STDOUT')));
      expect(ptyPrompt, isNot(contains('RAW_CODEX_STDOUT')));
      final ptyInputs = _extractPromptInputsJson(ptyPrompt);
      expect(ptyInputs['predecessorIds'], ['spec']);
      expect(ptyInputs.containsKey('predecessors'), isFalse);
      expect(
        (ptyInputs['nodeOutputs']! as Map<String, Object?>).keys,
        containsAll(['analyze', 'spec']),
      );

      // ReviewValidatorNode delegated prompt.
      final reviewPrompt = processRunner.invocations
          .firstWhere((i) => i.nodeId == 'review')
          .stdinContent!;
      expect(reviewPrompt, isNot(contains('RAW_PTY_STDOUT')));
      final reviewInputs = _extractPromptInputsJson(reviewPrompt);
      expect(reviewInputs['predecessorIds'], ['terminal_step']);
      expect(reviewInputs.containsKey('predecessors'), isFalse);
    });

    test('strips legacy harness stdout/stderr when resuming from a pre-fix '
        'checkpoint without mutating the checkpoint map', () async {
      final processRunner = _RecordingProcessRunner(
        (_) => const ProcessExecutionResult(exitCode: 0),
      );
      final contract = _ScriptedResultContract(<String, ResultContractReport>{
        'downstream': const ResultContractReport(
          status: ResultContractStatus.success,
          summary: 'Finished resumed node',
        ),
      });
      final h = EngineHarness(
        registerNodes: (registry) {
          registry.register(
            NodeDescriptors.claudeCode,
            () => ClaudeCodeNode(
              processRunner: processRunner,
              resultContract: contract,
              agentPromptResolver: const _EmptyAgentPromptResolver(),
            ),
          );
        },
      );

      final at = DateTime.utc(2026);
      final workflow = Workflow(
        id: 'wf-legacy-resume',
        name: 'Legacy resume',
        nodes: <WorkflowNode>[
          _node(
            'legacy_harness',
            NodeTypeId.claudeCode,
            config: const <String, Object?>{
              'additionalInstructions': 'Earlier node',
            },
          ),
          _node(
            'downstream',
            NodeTypeId.claudeCode,
            config: const <String, Object?>{
              'additionalInstructions': 'Next node',
            },
          ),
        ],
        edges: <WorkflowEdge>[
          edge('legacy_harness', NodeOutput.onSuccess, 'downstream'),
        ],
        createdAt: at,
        updatedAt: at,
        entryNodeId: 'legacy_harness',
      );

      await h.runs.create(
        Run(
          id: runId,
          workflowName: workflow.name,
          workflowDefinition: workflow,
          workspaceRoot: tempWorkspace.path,
          status: RunStatus.interrupted,
          startedAt: at,
        ),
      );

      final legacyData = <String, Object?>{
        'stdout': 'LEGACY_RAW_STREAM_JSON_DUMP',
        'stderr': 'LEGACY_RAW_STDERR_DUMP',
        'analysis': 'kept structured value',
        'contractStatus': 'success',
        'summary': 'Legacy summary',
      };
      await h.checkpoints.append(
        id: 'cp-legacy',
        runId: runId,
        completedNodeId: 'legacy_harness',
        pendingNodeIds: const <String>['downstream'],
        attemptsByEdge: const <String, int>{},
        circuitBreakerCount: 0,
        nodeOutputs: <String, JsonMap>{
          'legacy_harness': <String, Object?>{
            'outputLabel': NodeOutput.onSuccess,
            'data': legacyData,
            'artifacts': const <String>[],
          },
        },
        createdAt: at,
      );

      final result = await h.engine.resume(runId);
      expect(result.valueOrNull?.status, RunStatus.succeeded);

      final prompt = processRunner.invocations.single.stdinContent!;
      expect(prompt, isNot(contains('LEGACY_RAW_STREAM_JSON_DUMP')));
      expect(prompt, isNot(contains('LEGACY_RAW_STDERR_DUMP')));

      final inputs = _extractPromptInputsJson(prompt);
      expect(inputs['predecessorIds'], ['legacy_harness']);
      final legacyEntry =
          (inputs['nodeOutputs']! as Map<String, Object?>)['legacy_harness']!
              as Map<String, Object?>;
      final forwardedData = legacyEntry['data']! as Map<String, Object?>;
      expect(forwardedData['analysis'], 'kept structured value');
      expect(forwardedData['summary'], 'Legacy summary');
      expect(forwardedData.containsKey('stdout'), isFalse);
      expect(forwardedData.containsKey('stderr'), isFalse);

      // Original checkpoint map must not be mutated.
      expect(legacyData['stdout'], 'LEGACY_RAW_STREAM_JSON_DUMP');
    });

    test(
      'preserves tail-truncated CommandNode and TestsValidatorNode stdout and '
      'stderr into downstream harness prompts',
      () async {
        final oversizedStdout =
            'LEADING_NOISE_${'A' * 20000}_TRAILING_ERROR_SUMMARY';
        final oversizedStderr = 'LEADING_WARN_${'B' * 20000}_FINAL_STACK_FRAME';

        final processRunner = _RecordingProcessRunner((inv) {
          if (inv.executable == 'dart') {
            return ProcessExecutionResult(
              exitCode: 1,
              stdout: oversizedStdout,
              stderr: oversizedStderr,
            );
          }
          if (inv.nodeId == 'run_cmd') {
            return const ProcessExecutionResult(
              exitCode: 0,
              stdout: 'short ok',
            );
          }
          return const ProcessExecutionResult(exitCode: 0);
        });
        final contract = _ScriptedResultContract(<String, ResultContractReport>{
          'fix_tests': const ResultContractReport(
            status: ResultContractStatus.success,
            summary: 'Fixed tests',
          ),
        });

        final h = EngineHarness(
          registerFakeCommand: false,
          registerNodes: (registry) {
            registry
              ..register(
                NodeDescriptors.command,
                () => CommandNode(processRunner: processRunner),
              )
              ..register(
                NodeDescriptors.testsValidator,
                () => TestsValidatorNode(processRunner: processRunner),
              )
              ..register(
                NodeDescriptors.claudeCode,
                () => ClaudeCodeNode(
                  processRunner: processRunner,
                  resultContract: contract,
                  agentPromptResolver: const _EmptyAgentPromptResolver(),
                ),
              );
          },
        );

        final at = DateTime.utc(2026);
        final workflow = Workflow(
          id: 'wf-cmd-to-harness',
          name: 'Command to harness',
          nodes: <WorkflowNode>[
            _node(
              'run_cmd',
              NodeTypeId.command,
              config: const <String, Object?>{'command': 'echo'},
            ),
            _node(
              'run_tests',
              NodeTypeId.testsValidator,
              config: const <String, Object?>{'command': 'dart'},
            ),
            _node(
              'fix_tests',
              NodeTypeId.claudeCode,
              config: const <String, Object?>{
                'additionalInstructions': 'Fix failing tests',
              },
            ),
          ],
          edges: <WorkflowEdge>[
            edge('run_cmd', NodeOutput.onSuccess, 'run_tests'),
            edge('run_tests', NodeOutput.onFailure, 'fix_tests'),
          ],
          createdAt: at,
          updatedAt: at,
          entryNodeId: 'run_cmd',
        );

        await h.runs.create(
          Run(
            id: runId,
            workflowName: workflow.name,
            workflowDefinition: workflow,
            workspaceRoot: tempWorkspace.path,
            status: RunStatus.running,
            startedAt: at,
          ),
        );

        final result = await h.engine.start(runId);
        expect(result.valueOrNull?.status, RunStatus.succeeded);

        final fixPrompt = processRunner.invocations
            .firstWhere((i) => i.nodeId == 'fix_tests')
            .stdinContent!;
        final inputs = _extractPromptInputsJson(fixPrompt);
        expect(inputs['predecessorIds'], ['run_tests']);
        expect(inputs.containsKey('predecessors'), isFalse);

        final nodeOutputs = inputs['nodeOutputs']! as Map<String, Object?>;
        final cmdData =
            (nodeOutputs['run_cmd']! as Map<String, Object?>)['data']!
                as Map<String, Object?>;
        expect(cmdData['stdout'], 'short ok');

        final testData =
            (nodeOutputs['run_tests']! as Map<String, Object?>)['data']!
                as Map<String, Object?>;
        final stdout = testData['stdout']! as String;
        final stderr = testData['stderr']! as String;
        expect(stdout, contains('truncated'));
        expect(stdout, contains('run logs'));
        expect(stdout, endsWith('_TRAILING_ERROR_SUMMARY'));
        expect(stdout, isNot(contains('LEADING_NOISE_')));
        expect(stderr, contains('truncated'));
        expect(stderr, endsWith('_FINAL_STACK_FRAME'));
        expect(stderr, isNot(contains('LEADING_WARN_')));
      },
    );
  });
}
