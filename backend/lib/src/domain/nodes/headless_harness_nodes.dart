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
