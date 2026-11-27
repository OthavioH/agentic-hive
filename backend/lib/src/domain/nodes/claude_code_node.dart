import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Claude Code headless harness (`claude -p`).
final class ClaudeCodeNode extends HeadlessHarnessNode {
  /// Creates a Claude Code harness node.
  const new({
    required super.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  static final RegExp _authPattern = RegExp(
    r'\b(not logged in|please login|authentication failed|invalid api key|'
    r'unauthorized|http\s*401|status(?:\s+code)?[:\s]+401|'
    r'error[:\s]+401|401\s+unauthorized)\b',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    r'\b(rate limit|too many requests|quota exceeded|credit balance|'
    r'http\s*429|status(?:\s+code)?[:\s]+429|error[:\s]+429|'
    r'429\s+too\s+many\s+requests)\b',
    caseSensitive: false,
  );

  static const List<String> _hiveMcpTools = <String>[
    'mcp__hive__report_result',
    'mcp__hive__ask_human',
  ];

  @override
  String get typeId => NodeTypeId.claudeCode;

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
    final allowed = <String>[
      ..._hiveMcpTools,
      for (final tool in resolved.allowed)
        if (!_hiveMcpTools.contains(tool)) tool,
    ];

    return <String>[
      if (isolationMode == WorkspaceIsolationMode.worktree)
        '--dangerously-skip-permissions'
      else ...<String>['--permission-mode', 'acceptEdits'],
      if (resultsDir != null && resultsDir.isNotEmpty) ...<String>[
        '--add-dir',
        resultsDir,
      ],
      if (attachmentsDir != null && attachmentsDir.isNotEmpty) ...<String>[
        '--add-dir',
        attachmentsDir,
      ],
      '--allowedTools',
      allowed.join(','),
      if (resolved.denied.isNotEmpty) ...<String>[
        '--disallowedTools',
        resolved.denied.join(','),
      ],
    ];
  }

  @override
  List<String> buildModelArgs(String model) => <String>['--model', model];

  @override
  List<String> buildEffortArgs(HarnessEffort effort) => <String>[
    '--effort',
    effort.name,
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
    executable: 'claude',
    arguments: <String>[
      '-p',
      '--output-format',
      'stream-json',
      if (!config.extraArgs.contains('--verbose')) '--verbose',
      if (mcpConfigPath != null) ...<String>['--mcp-config', mcpConfigPath],
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
