import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
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
  TranscriptInterpreter createTranscriptInterpreter() =>
      _GeminiTranscriptInterpreter();

  @override
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result) =>
      analyzeCliOutput(
        result,
        authPattern: _authPattern,
        rateLimitPattern: _rateLimitPattern,
        rateLimitOnCleanExit: true,
      );
}

final class _GeminiTranscriptInterpreter extends JsonLineTranscriptInterpreter {
  String? _messageId;
  int _messageFirstOffset = 0;
  final StringBuffer _messageText = StringBuffer();

  @override
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry) {
    final type = event['type'] as String?;
    final isAssistantDelta =
        type == 'message' &&
        event['role'] == 'assistant' &&
        event['delta'] == true;
    if (!isAssistantDelta) {
      _messageId = null;
      _messageText.clear();
    }

    return switch (type) {
      'init' => const [],
      'message' => _interpretMessage(
        event,
        entry,
        isAssistantDelta: isAssistantDelta,
      ),
      'tool_use' => [
        TranscriptEntry.toolCall(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          name: event['tool_name'] as String? ?? '',
          input: event['parameters'] as JsonMap? ?? const <String, Object?>{},
          callId: event['tool_id'] as String?,
        ),
      ],
      'tool_result' => _interpretToolResult(event, entry),
      'error' => [
        TranscriptEntry.error(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          message: event['message'] as String? ?? '',
        ),
      ],
      'result' => _interpretResult(event, entry),
      _ => null,
    };
  }

  List<TranscriptEntry>? _interpretMessage(
    JsonMap event,
    RunLogEntry entry, {
    required bool isAssistantDelta,
  }) {
    final role = event['role'] as String?;
    if (role == 'user') {
      return const [];
    }
    if (role != 'assistant') {
      return null;
    }

    final content = event['content'] as String? ?? '';
    if (isAssistantDelta) {
      if (_messageId == null) {
        _messageId = transcriptEntryId(entry);
        _messageFirstOffset = entry.offset;
      }
      _messageText.write(content);
      return [
        TranscriptEntry.agentMessage(
          id: _messageId!,
          firstOffset: _messageFirstOffset,
          lastOffset: entry.offset,
          text: _messageText.toString(),
        ),
      ];
    }

    return [
      TranscriptEntry.agentMessage(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        text: content,
      ),
    ];
  }

  List<TranscriptEntry> _interpretToolResult(JsonMap event, RunLogEntry entry) {
    final error = event['error'] as JsonMap?;
    return [
      TranscriptEntry.toolResult(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        output:
            event['output'] as String? ?? error?['message'] as String? ?? '',
        callId: event['tool_id'] as String?,
        isError: event['status'] == 'error',
      ),
    ];
  }

  List<TranscriptEntry> _interpretResult(JsonMap event, RunLogEntry entry) {
    final error = event['error'] as JsonMap?;
    final stats = event['stats'] as JsonMap?;
    final status = event['status'] as String?;
    final durationMs = (stats?['duration_ms'] as num?)?.toInt();
    final inputTokens = (stats?['input_tokens'] as num?)?.toInt();
    final outputTokens = (stats?['output_tokens'] as num?)?.toInt();

    if (error != null) {
      return [
        TranscriptEntry.error(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          message: error['message'] as String? ?? '',
        ),
        TranscriptEntry.finalResult(
          id: transcriptEntryId(entry, 1),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          status: status,
          durationMs: durationMs,
          inputTokens: inputTokens,
          outputTokens: outputTokens,
        ),
      ];
    }

    return [
      TranscriptEntry.finalResult(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        status: status,
        durationMs: durationMs,
        inputTokens: inputTokens,
        outputTokens: outputTokens,
      ),
    ];
  }
}
