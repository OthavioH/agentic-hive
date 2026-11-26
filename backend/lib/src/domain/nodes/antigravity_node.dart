import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Antigravity CLI headless harness (`agy --input-format stream-json`).
final class AntigravityNode extends HeadlessHarnessNode {
  /// Creates an Antigravity CLI harness node.
  const new({
    required super.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  static final RegExp _authPattern = RegExp(
    r'\b(not authenticated|sign in required|authentication failed|'
    r'unauthorized|http\s*401|status(?:\s+code)?[:\s]+401|'
    r'error[:\s]+401|401\s+unauthorized)\b',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    r'\b(rate limit|quota exceeded|(?:no|at|over|out of)\s+capacity|'
    r'capacity\s+(?:exhausted|exceeded|limit)|too many requests|http\s*429|'
    r'status(?:\s+code)?[:\s]+429|error[:\s]+429|'
    r'429\s+too\s+many\s+requests)\b',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.antigravity;

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
            'Antigravity CLI (`agy`) has no per-tool allow flag; ignoring '
            'agent allowed_tools: ${resolved.allowed.join(', ')} (ADR 0021).',
      );
    }
    if (resolved.denied.isNotEmpty) {
      logPolicyGapOnce(
        runId: runId,
        gapKey: 'denied_tools',
        message:
            'Antigravity CLI (`agy`) has no per-tool deny flag; ignoring '
            'agent denied_tools: ${resolved.denied.join(', ')} (ADR 0021).',
      );
    }

    return <String>[
      if (isolationMode == WorkspaceIsolationMode.worktree)
        '--dangerously-skip-permissions'
      else ...<String>['--mode', 'accept-edits'],
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
    executable: 'agy',
    arguments: <String>[
      '--input-format',
      'stream-json',
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
    stdinContent:
        '${jsonEncode(<String, Object?>{
          'event': 'user',
          'message': <String, Object?>{'role': 'user', 'content': prompt},
        })}\n',
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
