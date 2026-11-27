import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
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

  @override
  TranscriptInterpreter createTranscriptInterpreter() =>
      _ClaudeCodeTranscriptInterpreter();
}

final class _ClaudeCodeTranscriptInterpreter
    extends JsonLineTranscriptInterpreter {
  static const Set<String> _hiddenSystemSubtypes = <String>{
    'init',
    'thinking_tokens',
    'hook_started',
    'hook_progress',
    'hook_response',
    'task_started',
    'task_updated',
    'task_progress',
    'task_notification',
    'background_tasks_changed',
  };

  @override
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry) {
    return switch (event['type']) {
      'system' =>
        _hiddenSystemSubtypes.contains(event['subtype']) ? const [] : null,
      'rate_limit_event' || 'tool_progress' => const [],
      'assistant' => _interpretAssistant(event, entry),
      'user' => _interpretUser(event, entry),
      'result' => _interpretResult(event, entry),
      _ => null,
    };
  }

  List<TranscriptEntry>? _interpretAssistant(JsonMap event, RunLogEntry entry) {
    final content = _messageContent(event);
    if (content == null) {
      return null;
    }

    final isApiError = event['error'] != null;
    final entries = <TranscriptEntry>[];
    for (var i = 0; i < content.length; i++) {
      final block = content[i];
      final id = transcriptEntryId(entry, i);
      if (block is! JsonMap) {
        entries.add(_plainBlock(id, entry, block));
        continue;
      }

      switch (block['type']) {
        case 'text':
          final text = block['text'];
          if (text is String && text.isNotEmpty) {
            entries.add(
              isApiError
                  ? TranscriptEntry.error(
                      id: id,
                      firstOffset: entry.offset,
                      lastOffset: entry.offset,
                      message: text,
                    )
                  : TranscriptEntry.agentMessage(
                      id: id,
                      firstOffset: entry.offset,
                      lastOffset: entry.offset,
                      text: text,
                    ),
            );
          }
        case 'thinking':
          final thinking = block['thinking'];
          if (thinking is String && thinking.trim().isNotEmpty) {
            entries.add(
              TranscriptEntry.thinking(
                id: id,
                firstOffset: entry.offset,
                lastOffset: entry.offset,
                text: thinking,
              ),
            );
          }
        case 'redacted_thinking':
          break;
        case 'tool_use':
          final name = block['name'];
          if (name is! String) {
            entries.add(_plainBlock(id, entry, block));
            break;
          }
          final input = block['input'];
          entries.add(
            TranscriptEntry.toolCall(
              id: id,
              firstOffset: entry.offset,
              lastOffset: entry.offset,
              name: name,
              input: input is JsonMap ? input : const <String, Object?>{},
              callId: block['id'] as String?,
            ),
          );
        default:
          entries.add(_plainBlock(id, entry, block));
      }
    }
    return entries;
  }

  List<TranscriptEntry>? _interpretUser(JsonMap event, RunLogEntry entry) {
    final content = _messageContent(event);
    if (content == null) {
      return null;
    }

    final entries = <TranscriptEntry>[];
    for (var i = 0; i < content.length; i++) {
      final block = content[i];
      final id = transcriptEntryId(entry, i);
      if (block is! JsonMap) {
        entries.add(_plainBlock(id, entry, block));
        continue;
      }

      switch (block['type']) {
        case 'tool_result':
          entries.add(
            TranscriptEntry.toolResult(
              id: id,
              firstOffset: entry.offset,
              lastOffset: entry.offset,
              output: _toolResultOutput(block['content']),
              callId: block['tool_use_id'] as String?,
              isError: block['is_error'] == true,
            ),
          );
        case 'text':
          final text = block['text'];
          entries.add(
            text is String
                ? TranscriptEntry.plainText(
                    id: id,
                    firstOffset: entry.offset,
                    lastOffset: entry.offset,
                    stream: RunOutputStream.stdout,
                    text: text,
                  )
                : _plainBlock(id, entry, block),
          );
        default:
          entries.add(_plainBlock(id, entry, block));
      }
    }
    return entries;
  }

  List<TranscriptEntry> _interpretResult(JsonMap event, RunLogEntry entry) {
    final rawUsage = event['usage'];
    final usage = rawUsage is JsonMap ? rawUsage : null;
    final costUsd = event['total_cost_usd'];
    final rawDurationMs = event['duration_ms'];
    final rawOutputTokens = usage?['output_tokens'];
    final entries = <TranscriptEntry>[
      TranscriptEntry.finalResult(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        status: event['subtype'] as String?,
        durationMs: rawDurationMs is int ? rawDurationMs : null,
        costUsd: costUsd is num ? costUsd.toDouble() : null,
        inputTokens: _sumInputTokens(usage),
        outputTokens: rawOutputTokens is int ? rawOutputTokens : null,
      ),
    ];

    if (event['is_error'] == true) {
      var errorIndex = 1;
      final errors = event['errors'];
      if (errors is List<Object?>) {
        for (final message in errors) {
          if (message is String && message.isNotEmpty) {
            entries.add(
              TranscriptEntry.error(
                id: transcriptEntryId(entry, errorIndex++),
                firstOffset: entry.offset,
                lastOffset: entry.offset,
                message: message,
              ),
            );
          }
        }
      }
      if (errorIndex == 1) {
        final resultText = event['result'];
        if (resultText is String && resultText.isNotEmpty) {
          entries.add(
            TranscriptEntry.error(
              id: transcriptEntryId(entry, 1),
              firstOffset: entry.offset,
              lastOffset: entry.offset,
              message: resultText,
            ),
          );
        }
      }
    }

    return entries;
  }

  static List<Object?>? _messageContent(JsonMap event) {
    final message = event['message'];
    if (message is! JsonMap) {
      return null;
    }
    final content = message['content'];
    return content is List<Object?> ? content : null;
  }

  static TranscriptEntry _plainBlock(
    String id,
    RunLogEntry entry,
    Object? block,
  ) => TranscriptEntry.plainText(
    id: id,
    firstOffset: entry.offset,
    lastOffset: entry.offset,
    stream: RunOutputStream.stdout,
    text: jsonEncode(block),
  );

  static String _toolResultOutput(Object? content) {
    if (content is String) {
      return content;
    }
    if (content is List<Object?>) {
      final parts = <String>[];
      for (final part in content) {
        if (part is JsonMap && part['type'] == 'text') {
          final text = part['text'];
          if (text is String) {
            parts.add(text);
          }
        }
      }
      if (parts.isNotEmpty) {
        return parts.join('\n');
      }
    }
    return content == null ? '' : jsonEncode(content);
  }

  static int? _sumInputTokens(JsonMap? usage) {
    if (usage == null) {
      return null;
    }
    const keys = <String>[
      'input_tokens',
      'cache_creation_input_tokens',
      'cache_read_input_tokens',
    ];
    var sum = 0;
    var hasAny = false;
    for (final key in keys) {
      final value = usage[key];
      if (value is int) {
        sum += value;
        hasAny = true;
      }
    }
    return hasAny ? sum : null;
  }
}
