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
    '(not logged in|please login|authentication failed|invalid api key|'
    'unauthorized|401)',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    '(rate limit|too many requests|quota exceeded|credit balance|429)',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.claudeCode;

  @override
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
  }) => ProcessInvocation(
    executable: 'claude',
    arguments: <String>[
      '-p',
      '--output-format',
      'stream-json',
      ...config.extraArgs,
    ],
    workingDirectory: workingDirectory,
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
    '(not authenticated|login required|authentication error|unauthorized|'
    'invalid api key|401)',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    '(rate limit|usage limit|quota exceeded|too many requests|429)',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.codex;

  @override
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
  }) => ProcessInvocation(
    executable: 'codex',
    arguments: <String>['exec', '--json', ...config.extraArgs],
    workingDirectory: workingDirectory,
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
    '(not signed in|authentication required|oauth|invalid credentials|'
    'unauthorized|401)',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    '(resource_exhausted|quota exceeded|rate limit|too many requests|429)',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.geminiCli;

  @override
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
  }) => ProcessInvocation(
    executable: 'gemini',
    arguments: <String>[
      '-p',
      '',
      '--output-format',
      'stream-json',
      ...config.extraArgs,
    ],
    workingDirectory: workingDirectory,
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
      );
}

/// Antigravity CLI headless harness (`agy -p`).
final class AntigravityNode extends HeadlessHarnessNode {
  /// Creates an Antigravity CLI harness node.
  const new({
    required super.processRunner,
    required super.resultContract,
    required super.agentPromptResolver,
  });

  static final RegExp _authPattern = RegExp(
    '(not authenticated|sign in required|authentication failed|unauthorized|'
    '401)',
    caseSensitive: false,
  );

  static final RegExp _rateLimitPattern = RegExp(
    '(rate limit|quota exceeded|capacity|too many requests|429)',
    caseSensitive: false,
  );

  @override
  String get typeId => NodeTypeId.antigravity;

  @override
  ProcessInvocation buildInvocation({
    required HarnessNodeConfig config,
    required String workingDirectory,
    required String prompt,
  }) => ProcessInvocation(
    executable: 'agy',
    arguments: <String>['-p', ...config.extraArgs],
    workingDirectory: workingDirectory,
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
      );
}
