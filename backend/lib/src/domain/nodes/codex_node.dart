import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// OpenAI Codex headless harness (`codex exec`).
final class CodexNode extends HeadlessHarnessNode {
  /// Creates a Codex harness node.
  const new({
    required super.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  static final RegExp _authPattern = RegExp(
    r'\b(not authenticated|login required|authentication error|unauthorized|'
    r'invalid api key|http\s*401|status(?:\s+code)?[:\s]+401|'
    r'error[:\s]+401|401\s+unauthorized)\b',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    r'\b(rate limit|usage limit|quota exceeded|too many requests|'
    r'http\s*429|status(?:\s+code)?[:\s]+429|error[:\s]+429|'
    r'429\s+too\s+many\s+requests)\b',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.codex;

  @override
  List<String> buildPermissionArgs({
    required WorkspaceIsolationMode isolationMode,
    String? resultsDir,
    String? attachmentsDir,
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
    String? runId,
  }) {
    final resolved = HeadlessHarnessNode.resolveToolLists(
      allowedTools: allowedTools,
      deniedTools: deniedTools,
    );
    if (resolved.allowed.isNotEmpty) {
      logPolicyGapOnce(
        runId: runId,
        gapKey: 'allowed_tools',
        message:
            'Codex CLI (`codex exec`) has no per-tool allow flag; ignoring '
            'agent allowed_tools: ${resolved.allowed.join(', ')} (ADR 0021).',
      );
    }
    if (resolved.denied.isNotEmpty) {
      logPolicyGapOnce(
        runId: runId,
        gapKey: 'denied_tools',
        message:
            'Codex CLI (`codex exec`) has no per-tool deny flag; ignoring '
            'agent denied_tools: ${resolved.denied.join(', ')} (ADR 0021).',
      );
    }

    return <String>[
      if (isolationMode == WorkspaceIsolationMode.worktree)
        '--dangerously-bypass-approvals-and-sandbox'
      else ...<String>['--sandbox', 'workspace-write'],
      if (resultsDir != null && resultsDir.isNotEmpty) ...<String>[
        '--add-dir',
        resultsDir,
      ],
      if (attachmentsDir != null && attachmentsDir.isNotEmpty) ...<String>[
        '--add-dir',
        attachmentsDir,
      ],
    ];
  }

  static const Map<HarnessEffort, String> _effortValue = {
    HarnessEffort.low: 'low',
    HarnessEffort.medium: 'medium',
    HarnessEffort.high: 'high',
    HarnessEffort.max: 'xhigh',
  };

  @override
  List<String> buildModelArgs(String model) => <String>['--model', model];

  @override
  List<String> buildEffortArgs(HarnessEffort effort) => <String>[
    '-c',
    'model_reasoning_effort=${_effortValue[effort]}',
  ];

  @override
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
    String? mcpConfigPath,
    Map<String, String> environment = const <String, String>{},
    WorkspaceIsolationMode isolationMode = WorkspaceIsolationMode.direct,
    String? resultsDir,
    String? attachmentsDir,
    List<String> allowedTools = const <String>[],
    List<String> deniedTools = const <String>[],
    String? runId,
  }) => ProcessInvocation(
    executable: 'codex',
    arguments: <String>[
      'exec',
      '--json',
      ...buildPermissionArgs(
        isolationMode: isolationMode,
        resultsDir: resultsDir,
        attachmentsDir: attachmentsDir,
        allowedTools: allowedTools,
        deniedTools: deniedTools,
        runId: runId,
      ),
      ...buildModelAndEffortArgs(config),
      ...config.extraArgs,
    ],
    workingDirectory: workingDirectory,
    environment: environment,
    stdinContent: prompt,
    timeout: config.timeoutSeconds != null
        ? Duration(seconds: config.timeoutSeconds!)
        : null,
  );

  @override
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result) =>
      analyzeCliOutput(
        result,
        authPattern: _authPattern,
        rateLimitPattern: _rateLimitPattern,
        rateLimitOnCleanExit: true,
      );
}
