import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
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
  TranscriptInterpreter createTranscriptInterpreter() =>
      _CodexTranscriptInterpreter();

  @override
  HarnessOutputAnalysis parseOutput(ProcessExecutionResult result) =>
      analyzeCliOutput(
        result,
        authPattern: _authPattern,
        rateLimitPattern: _rateLimitPattern,
        rateLimitOnCleanExit: true,
      );
}

final class _CodexTranscriptInterpreter extends JsonLineTranscriptInterpreter {
  final Map<String, ({String id, int firstOffset})> _items = {};

  @override
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry) {
    final type = event['type'] as String?;
    return switch (type) {
      'thread.started' || 'turn.started' => const [],
      'turn.completed' => _interpretTurnCompleted(event, entry),
      'turn.failed' => _interpretTurnFailed(event, entry),
      'error' => [
        TranscriptEntry.error(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          message: event['message'] as String? ?? '',
        ),
      ],
      'item.started' ||
      'item.updated' ||
      'item.completed' => _interpretItemEvent(type!, event, entry),
      _ => null,
    };
  }

  List<TranscriptEntry> _interpretTurnCompleted(
    JsonMap event,
    RunLogEntry entry,
  ) {
    final usage = event['usage'] as JsonMap?;
    return [
      TranscriptEntry.finalResult(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        status: 'success',
        inputTokens: (usage?['input_tokens'] as num?)?.toInt(),
        outputTokens: (usage?['output_tokens'] as num?)?.toInt(),
      ),
    ];
  }

  List<TranscriptEntry> _interpretTurnFailed(JsonMap event, RunLogEntry entry) {
    final error = event['error'] as JsonMap?;
    return [
      TranscriptEntry.error(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        message: error?['message'] as String? ?? '',
      ),
      TranscriptEntry.finalResult(
        id: transcriptEntryId(entry, 1),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        status: 'error',
      ),
    ];
  }

  List<TranscriptEntry>? _interpretItemEvent(
    String eventType,
    JsonMap event,
    RunLogEntry entry,
  ) {
    final item = event['item'];
    if (item is! JsonMap) {
      return null;
    }
    final itemId = item['id'];
    if (itemId is! String) {
      return null;
    }

    return switch (item['type']) {
      'agent_message' => _upsertTextItem(
        itemId,
        entry,
        item['text'] as String? ?? '',
        (id, firstOffset, lastOffset, text) => TranscriptEntry.agentMessage(
          id: id,
          firstOffset: firstOffset,
          lastOffset: lastOffset,
          text: text,
        ),
      ),
      'reasoning' => _upsertTextItem(
        itemId,
        entry,
        item['text'] as String? ?? '',
        (id, firstOffset, lastOffset, text) => TranscriptEntry.thinking(
          id: id,
          firstOffset: firstOffset,
          lastOffset: lastOffset,
          text: text,
        ),
      ),
      'todo_list' => _upsertTextItem(
        itemId,
        entry,
        _formatTodoList(item),
        (id, firstOffset, lastOffset, text) => TranscriptEntry.agentMessage(
          id: id,
          firstOffset: firstOffset,
          lastOffset: lastOffset,
          text: text,
        ),
      ),
      'error' => _upsertTextItem(
        itemId,
        entry,
        item['message'] as String? ?? '',
        (id, firstOffset, lastOffset, message) => TranscriptEntry.error(
          id: id,
          firstOffset: firstOffset,
          lastOffset: lastOffset,
          message: message,
        ),
      ),
      'command_execution' ||
      'mcp_tool_call' ||
      'file_change' ||
      'web_search' => _interpretToolItem(eventType, itemId, item, entry),
      _ => null,
    };
  }

  List<TranscriptEntry> _upsertTextItem(
    String itemId,
    RunLogEntry entry,
    String text,
    TranscriptEntry Function(
      String id,
      int firstOffset,
      int lastOffset,
      String text,
    )
    build,
  ) {
    final existing = _items[itemId];
    if (existing == null) {
      if (text.isEmpty) {
        return const [];
      }
      final id = transcriptEntryId(entry);
      _items[itemId] = (id: id, firstOffset: entry.offset);
      return [build(id, entry.offset, entry.offset, text)];
    }
    return [build(existing.id, existing.firstOffset, entry.offset, text)];
  }

  List<TranscriptEntry> _interpretToolItem(
    String eventType,
    String itemId,
    JsonMap item,
    RunLogEntry entry,
  ) {
    if (eventType == 'item.updated') {
      return const [];
    }

    final tool = _decodeToolItem(item);
    if (eventType == 'item.started') {
      final id = transcriptEntryId(entry);
      _items[itemId] = (id: id, firstOffset: entry.offset);
      return [
        TranscriptEntry.toolCall(
          id: id,
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          name: tool.name,
          input: tool.input,
          callId: itemId,
        ),
      ];
    }

    // item.completed
    final wasStarted = _items.containsKey(itemId);
    if (wasStarted) {
      return [
        TranscriptEntry.toolResult(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          output: tool.output,
          callId: itemId,
          isError: tool.isError,
        ),
      ];
    }

    return [
      TranscriptEntry.toolCall(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        name: tool.name,
        input: tool.input,
        callId: itemId,
      ),
      TranscriptEntry.toolResult(
        id: transcriptEntryId(entry, 1),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        output: tool.output,
        callId: itemId,
        isError: tool.isError,
      ),
    ];
  }

  ({String name, JsonMap input, String output, bool isError}) _decodeToolItem(
    JsonMap item,
  ) {
    final status = item['status'] as String?;
    return switch (item['type']) {
      'command_execution' => (
        name: 'shell',
        input: <String, Object?>{'command': item['command']},
        output: item['aggregated_output'] as String? ?? '',
        isError:
            status == 'failed' ||
            status == 'declined' ||
            ((item['exit_code'] as num?)?.toInt() ?? 0) != 0,
      ),
      'mcp_tool_call' => _decodeMcpToolCall(item, status),
      'file_change' => (
        name: 'apply_patch',
        input: <String, Object?>{'changes': item['changes']},
        output: _formatFileChanges(item['changes']),
        isError: status == 'failed',
      ),
      'web_search' => (
        name: 'web_search',
        input: <String, Object?>{'query': item['query']},
        output: item['results'] != null ? jsonEncode(item['results']) : '',
        isError: false,
      ),
      _ => throw StateError('Unreachable tool item type: ${item['type']}'),
    };
  }

  ({String name, JsonMap input, String output, bool isError})
  _decodeMcpToolCall(JsonMap item, String? status) {
    final error = item['error'] as JsonMap?;
    final result = item['result'] as JsonMap?;
    final String output;
    if (error != null) {
      output = error['message'] as String? ?? '';
    } else if (result != null) {
      final content = result['content'];
      if (content is List<Object?>) {
        final textBlocks = [
          for (final block in content)
            if (block is JsonMap &&
                block['type'] == 'text' &&
                block['text'] is String)
              block['text']! as String,
        ];
        output = textBlocks.isNotEmpty
            ? textBlocks.join('\n')
            : jsonEncode(content);
      } else {
        output = '';
      }
    } else {
      output = '';
    }

    return (
      name: '${item['server']}.${item['tool']}',
      input: item['arguments'] is JsonMap
          ? item['arguments']! as JsonMap
          : const <String, Object?>{},
      output: output,
      isError: status == 'failed' || error != null,
    );
  }

  String _formatTodoList(JsonMap item) {
    final items = item['items'];
    if (items is! List<Object?>) {
      return '';
    }
    final lines = <String>[];
    for (final todo in items) {
      if (todo is JsonMap) {
        final mark = todo['completed'] == true ? 'x' : ' ';
        final text = todo['text'] as String? ?? '';
        lines.add('- [$mark] $text');
      }
    }
    return lines.join('\n');
  }

  String _formatFileChanges(Object? changes) {
    if (changes is! List<Object?>) {
      return '';
    }
    return [
      for (final change in changes)
        if (change is JsonMap) '${change['kind']} ${change['path']}',
    ].join('\n');
  }
}
