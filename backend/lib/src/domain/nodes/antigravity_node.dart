import 'dart:convert';

import 'package:agentic_hive_backend/src/domain/nodes/harness_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
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

  @override
  TranscriptInterpreter createTranscriptInterpreter() =>
      _AntigravityTranscriptInterpreter();
}

final class _AntigravityTranscriptInterpreter
    extends JsonLineTranscriptInterpreter {
  final Map<String, RunLogEntry> _stepFirst = <String, RunLogEntry>{};
  final Map<String, StringBuffer> _stepText = <String, StringBuffer>{};

  @override
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry) {
    return switch (event['event']) {
      'init' => const [],
      'step_update' => _interpretStepUpdate(event['step_update'], entry),
      'result' => _interpretResult(event['result'], entry),
      _ => null,
    };
  }

  List<TranscriptEntry>? _interpretStepUpdate(
    Object? rawStep,
    RunLogEntry entry,
  ) {
    if (rawStep is! JsonMap) {
      return null;
    }
    final stepType = rawStep['step_type'];
    if (stepType == 'user_input' || stepType == 'system_message') {
      return const [];
    }

    final conversationId = rawStep['conversation_id'];
    final stepIndex = rawStep['step_index'];
    if (conversationId is! String || stepIndex is! int) {
      return null;
    }

    final stepKey = '$conversationId:$stepIndex';
    final first = _stepFirst.putIfAbsent(stepKey, () => entry);

    if (stepType == 'agent_response') {
      final delta = rawStep['text_delta'];
      if (delta is! String) {
        return const [];
      }
      final buffer = _stepText.putIfAbsent(stepKey, StringBuffer.new)
        ..write(delta);
      final text = buffer.toString();
      if (text.isEmpty) {
        return const [];
      }
      return <TranscriptEntry>[
        TranscriptEntry.agentMessage(
          id: transcriptEntryId(first),
          firstOffset: first.offset,
          lastOffset: entry.offset,
          text: text,
        ),
      ];
    }

    if (stepType == 'tool' || stepType == 'subagent') {
      return _interpretToolStep(
        rawStep,
        stepType! as String,
        stepKey,
        first,
        entry,
      );
    }

    return null;
  }

  List<TranscriptEntry>? _interpretToolStep(
    JsonMap step,
    String stepType,
    String stepKey,
    RunLogEntry first,
    RunLogEntry entry,
  ) {
    final rawToolInfo = step['tool_info'];
    final toolInfo = rawToolInfo is JsonMap ? rawToolInfo : null;
    final rawSubagentInfo = step['subagent_info'];
    final subagentInfo = rawSubagentInfo is JsonMap ? rawSubagentInfo : null;
    final name =
        (toolInfo?['name'] as String?) ??
        (step['tool_name'] as String?) ??
        stepType;
    final rawParameters = toolInfo?['parameters'];
    final input = rawParameters is JsonMap
        ? rawParameters
        : (subagentInfo ?? const <String, Object?>{});

    final callEntry = TranscriptEntry.toolCall(
      id: transcriptEntryId(first),
      firstOffset: first.offset,
      lastOffset: entry.offset,
      name: name,
      input: input,
      callId: stepKey,
    );

    switch (step['state']) {
      case 'ACTIVE':
        return <TranscriptEntry>[callEntry];
      case 'DONE':
        final output = toolInfo?['output'];
        return <TranscriptEntry>[
          callEntry,
          if (output is String)
            TranscriptEntry.toolResult(
              id: transcriptEntryId(first, 1),
              firstOffset: first.offset,
              lastOffset: entry.offset,
              output: output,
              callId: stepKey,
            ),
        ];
      case 'ERROR':
        final rawError = toolInfo?['error'];
        final errorInfo = rawError is JsonMap ? rawError : null;
        final message =
            (errorInfo?['message'] as String?) ??
            (toolInfo?['output'] as String?) ??
            '';
        return <TranscriptEntry>[
          callEntry,
          TranscriptEntry.toolResult(
            id: transcriptEntryId(first, 1),
            firstOffset: first.offset,
            lastOffset: entry.offset,
            output: message,
            callId: stepKey,
            isError: true,
          ),
        ];
      default:
        return null;
    }
  }

  List<TranscriptEntry>? _interpretResult(
    Object? rawResult,
    RunLogEntry entry,
  ) {
    if (rawResult is! JsonMap) {
      return null;
    }
    final durationSeconds = rawResult['duration_seconds'];
    final rawUsage = rawResult['usage'];
    final usage = rawUsage is JsonMap ? rawUsage : null;
    final rawInputTokens = usage?['input_tokens'];
    final rawOutputTokens = usage?['output_tokens'];
    return <TranscriptEntry>[
      TranscriptEntry.finalResult(
        id: transcriptEntryId(entry),
        firstOffset: entry.offset,
        lastOffset: entry.offset,
        status: rawResult['status'] as String?,
        durationMs: durationSeconds is num
            ? (durationSeconds * 1000).round()
            : null,
        inputTokens: rawInputTokens is int ? rawInputTokens : null,
        outputTokens: rawOutputTokens is int ? rawOutputTokens : null,
      ),
    ];
  }
}
