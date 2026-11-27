import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/domain/nodes/claude_code_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

final class _StubProcessRunner implements NodeProcessRunner {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StubResultContract implements ResultContract {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _StubAgentPromptResolver implements AgentPromptResolver {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

ClaudeCodeNode _buildNode() => const ClaudeCodeNode(
  processRunner: _StubProcessRunner(),
  resultContract: _StubResultContract(),
  agentPromptResolver: _StubAgentPromptResolver(),
);

List<RunLogEntry> _loadFixture() =>
    File(p.join('test', 'fixtures', 'transcripts', 'claude_code.jsonl'))
        .readAsLinesSync()
        .map((line) => RunLogEntry.fromJson(jsonDecode(line) as JsonMap))
        .toList(growable: false);

RunLogEntry _entry({
  required int offset,
  required String chunk,
  RunOutputStream stream = RunOutputStream.stdout,
}) => RunLogEntry(
  stream: stream,
  chunk: chunk,
  timestamp: DateTime.utc(2026, 11, 20, 12),
  offset: offset,
);

void main() {
  group('ClaudeCodeNode.createTranscriptInterpreter', () {
    test('returns a distinct non-PlainTextTranscriptInterpreter each call', () {
      final node = _buildNode();
      final first = node.createTranscriptInterpreter();
      final second = node.createTranscriptInterpreter();

      expect(first, isNot(isA<PlainTextTranscriptInterpreter>()));
      expect(second, isNot(same(first)));
    });

    test('interprets full fixture into exact expected entries', () {
      final node = _buildNode();
      final entries = _loadFixture();

      final transcript = buildTranscript(
        node.createTranscriptInterpreter(),
        entries,
      );

      expect(transcript, const <TranscriptEntry>[
        TranscriptEntry.thinking(
          id: '11',
          firstOffset: 11,
          lastOffset: 11,
          text: 'Let me inspect the file first.',
        ),
        TranscriptEntry.agentMessage(
          id: '12',
          firstOffset: 12,
          lastOffset: 12,
          text: 'I will read the config.',
        ),
        TranscriptEntry.toolCall(
          id: '12.1',
          firstOffset: 12,
          lastOffset: 12,
          name: 'Read',
          input: <String, Object?>{'path': '/workspace/project/config.yaml'},
          callId: 'call-1',
        ),
        TranscriptEntry.toolResult(
          id: '13',
          firstOffset: 13,
          lastOffset: 13,
          output: 'port: 8080',
          callId: 'call-1',
        ),
        TranscriptEntry.toolResult(
          id: '14',
          firstOffset: 14,
          lastOffset: 14,
          output: 'line one\nline two',
          callId: 'call-2',
        ),
        TranscriptEntry.toolResult(
          id: '15',
          firstOffset: 15,
          lastOffset: 15,
          output: 'File not found',
          callId: 'call-3',
          isError: true,
        ),
        TranscriptEntry.plainText(
          id: '16',
          firstOffset: 16,
          lastOffset: 16,
          stream: RunOutputStream.stdout,
          text: 'Injected skill instructions',
        ),
        TranscriptEntry.plainText(
          id: '17',
          firstOffset: 17,
          lastOffset: 17,
          stream: RunOutputStream.stdout,
          text:
              '{"type":"system","subtype":"vcs_state_changed",'
              '"branch":"main"}',
        ),
        TranscriptEntry.plainText(
          id: '18',
          firstOffset: 18,
          lastOffset: 18,
          stream: RunOutputStream.stdout,
          text: '{bad',
        ),
        TranscriptEntry.plainText(
          id: '19',
          firstOffset: 19,
          lastOffset: 19,
          stream: RunOutputStream.stderr,
          text: 'Warning: deprecated flag',
        ),
        TranscriptEntry.finalResult(
          id: '20',
          firstOffset: 20,
          lastOffset: 20,
          status: 'success',
          durationMs: 1234,
          costUsd: 0.05,
          inputTokens: 60,
          outputTokens: 40,
        ),
      ]);
    });

    test('hides init, hooks, thinking_tokens, rate limits, progress, tasks, '
        'and empty thinking', () {
      final node = _buildNode();
      final entries = _loadFixture();

      final transcript = buildTranscript(
        node.createTranscriptInterpreter(),
        entries,
      );
      final offsets = transcript.map((e) => e.firstOffset).toSet();

      for (final hiddenOffset in const <int>[1, 2, 3, 4, 5, 6, 7, 8, 9, 10]) {
        expect(offsets, isNot(contains(hiddenOffset)));
      }
    });

    test(
      'handles error_max_turns without cost/usage and assistant API error',
      () {
        final interpreter = _buildNode().createTranscriptInterpreter();

        final errorResult = interpreter.interpret(
          _entry(
            offset: 1,
            chunk: jsonEncode(<String, Object?>{
              'type': 'result',
              'subtype': 'error_max_turns',
              'is_error': true,
              'duration_ms': 500,
              'errors': <String>['Reached max turns'],
            }),
          ),
        );
        expect(errorResult, const <TranscriptEntry>[
          TranscriptEntry.finalResult(
            id: '1',
            firstOffset: 1,
            lastOffset: 1,
            status: 'error_max_turns',
            durationMs: 500,
          ),
          TranscriptEntry.error(
            id: '1.1',
            firstOffset: 1,
            lastOffset: 1,
            message: 'Reached max turns',
          ),
        ]);

        final apiError = interpreter.interpret(
          _entry(
            offset: 2,
            chunk: jsonEncode(<String, Object?>{
              'type': 'assistant',
              'error': 'authentication_failed',
              'message': <String, Object?>{
                'role': 'assistant',
                'content': <Object?>[
                  <String, Object?>{'type': 'text', 'text': 'Invalid API key'},
                ],
              },
            }),
          ),
        );
        expect(apiError, const <TranscriptEntry>[
          TranscriptEntry.error(
            id: '2',
            firstOffset: 2,
            lastOffset: 2,
            message: 'Invalid API key',
          ),
        ]);
      },
    );

    test('full buildTranscript matches incremental entry-by-entry folding', () {
      final node = _buildNode();
      final entries = _loadFixture();

      final full = buildTranscript(node.createTranscriptInterpreter(), entries);

      final incrementalInterpreter = node.createTranscriptInterpreter();
      final byId = <String, TranscriptEntry>{};
      for (final entry in entries) {
        for (final item in incrementalInterpreter.interpret(entry)) {
          byId[item.id] = item;
        }
      }

      expect(byId.values.toList(growable: false), full);
    });

    test('preserves non-String text/thinking blocks as plain text and '
        'handles error result fallback to result text', () {
      final interpreter = _buildNode().createTranscriptInterpreter();

      final nonStringBlocks = interpreter.interpret(
        _entry(
          offset: 1,
          chunk: jsonEncode(<String, Object?>{
            'type': 'assistant',
            'message': <String, Object?>{
              'role': 'assistant',
              'content': <Object?>[
                <String, Object?>{'type': 'text', 'text': 123},
                <String, Object?>{'type': 'thinking', 'thinking': null},
              ],
            },
          }),
        ),
      );
      expect(nonStringBlocks, const <TranscriptEntry>[
        TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: '{"type":"text","text":123}',
        ),
        TranscriptEntry.plainText(
          id: '1.1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: '{"type":"thinking","thinking":null}',
        ),
      ]);

      final resultTextError = interpreter.interpret(
        _entry(
          offset: 2,
          chunk: jsonEncode(<String, Object?>{
            'type': 'result',
            'subtype': 'error_during_execution',
            'is_error': true,
            'result': 'Execution crashed',
          }),
        ),
      );
      expect(resultTextError, const <TranscriptEntry>[
        TranscriptEntry.finalResult(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          status: 'error_during_execution',
        ),
        TranscriptEntry.error(
          id: '2.1',
          firstOffset: 2,
          lastOffset: 2,
          message: 'Execution crashed',
        ),
      ]);
    });
  });
}
