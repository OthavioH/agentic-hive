import 'dart:convert';

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
