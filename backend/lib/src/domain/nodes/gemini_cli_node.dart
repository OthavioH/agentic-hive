import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Gemini CLI headless harness (`gemini -p`).
final class GeminiCliNode extends HeadlessHarnessNode {
  /// Creates a Gemini CLI harness node.
  const new({
    required super.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  static final RegExp _authPattern = RegExp(
    r'\b(not signed in|authentication required|'
    r'oauth\s+(?:error|failed|expired|required|invalid)|'
    r'invalid credentials|unauthorized|http\s*401|'
    r'status(?:\s+code)?[:\s]+401|error[:\s]+401|401\s+unauthorized)\b',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    r'\b(resource_exhausted|quota exceeded|rate limit|too many requests|'
    r'http\s*429|status(?:\s+code)?[:\s]+429|error[:\s]+429|'
    r'429\s+too\s+many\s+requests)\b',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.geminiCli;

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
    if (resolved.denied.isNotEmpty) {
      logPolicyGapOnce(
        runId: runId,
        gapKey: 'denied_tools',
        message:
            'Gemini CLI (`gemini`) has no CLI flag for denied_tools without '
            'a policy file; ignoring agent denied_tools: '
            '${resolved.denied.join(', ')} (ADR 0021).',
      );
    }

    return <String>[
      '--approval-mode',
      if (isolationMode == WorkspaceIsolationMode.worktree)
        'yolo'
      else
        'auto_edit',
      '--allowed-mcp-server-names',
      'hive',
      if (resultsDir != null && resultsDir.isNotEmpty) ...<String>[
        '--include-directories',
        resultsDir,
      ],
      if (attachmentsDir != null && attachmentsDir.isNotEmpty) ...<String>[
        '--include-directories',
        attachmentsDir,
      ],
      if (resolved.allowed.isNotEmpty) ...<String>[
        '--allowed-tools',
        ...resolved.allowed,
      ],
    ];
  }

  @override
  List<String> buildModelArgs(String model) => <String>['--model', model];

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
    executable: 'gemini',
    arguments: <String>[
      '-p',
      '',
      '--output-format',
      'stream-json',
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
