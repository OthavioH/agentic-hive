import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/domain/nodes/antigravity_node.dart';
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

AntigravityNode _buildNode() => const AntigravityNode(
  processRunner: _StubProcessRunner(),
  resultContract: _StubResultContract(),
  agentPromptResolver: _StubAgentPromptResolver(),
);

List<RunLogEntry> _loadFixture() =>
    File(p.join('test', 'fixtures', 'transcripts', 'antigravity.jsonl'))
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
  group('AntigravityNode.createTranscriptInterpreter', () {
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
        TranscriptEntry.agentMessage(
          id: '3',
          firstOffset: 3,
          lastOffset: 6,
          text: 'Hello world from agy.',
        ),
        TranscriptEntry.toolCall(
          id: '8',
          firstOffset: 8,
          lastOffset: 9,
          name: 'read_file',
          input: <String, Object?>{'Path': '/workspace/project/a.txt'},
          callId: 'conv-1:3',
        ),
        TranscriptEntry.toolResult(
          id: '8.1',
          firstOffset: 8,
          lastOffset: 9,
          output: 'file contents',
          callId: 'conv-1:3',
        ),
        TranscriptEntry.toolCall(
          id: '10',
          firstOffset: 10,
          lastOffset: 11,
          name: 'read_file',
          input: <String, Object?>{'Path': '/workspace/project/missing.txt'},
          callId: 'conv-1:4',
        ),
        TranscriptEntry.toolResult(
          id: '10.1',
          firstOffset: 10,
          lastOffset: 11,
          output: 'file does not exist',
          callId: 'conv-1:4',
          isError: true,
        ),
        TranscriptEntry.toolCall(
          id: '12',
          firstOffset: 12,
          lastOffset: 13,
          name: 'write_file',
          input: <String, Object?>{'Path': '/workspace/project/out.txt'},
          callId: 'conv-1:5',
        ),
        TranscriptEntry.toolCall(
          id: '15',
          firstOffset: 15,
          lastOffset: 16,
          name: 'subagent',
          input: <String, Object?>{'role': 'Researcher'},
          callId: 'conv-1:7',
        ),
        TranscriptEntry.agentMessage(
          id: '17',
          firstOffset: 17,
          lastOffset: 18,
          text: 'Subagent done.',
        ),
        TranscriptEntry.plainText(
          id: '19',
          firstOffset: 19,
          lastOffset: 19,
          stream: RunOutputStream.stdout,
          text: '{"event":"mystery"}',
        ),
        TranscriptEntry.plainText(
          id: '20',
          firstOffset: 20,
          lastOffset: 20,
          stream: RunOutputStream.stdout,
          text: '{bad',
        ),
        TranscriptEntry.plainText(
          id: '21',
          firstOffset: 21,
          lastOffset: 21,
          stream: RunOutputStream.stderr,
          text: 'Warning: stderr line',
        ),
        TranscriptEntry.finalResult(
          id: '22',
          firstOffset: 22,
          lastOffset: 22,
          status: 'SUCCESS',
          durationMs: 4568,
          inputTokens: 200,
          outputTokens: 50,
        ),
      ]);
    });

    test('merges agent_response deltas incrementally with stable id', () {
      final interpreter = _buildNode().createTranscriptInterpreter();
      final deltaEntries = _loadFixture()
          .where((e) => e.offset >= 3 && e.offset <= 6)
          .toList(growable: false);

      final expectedTexts = <String>[
        'Hello ',
        'Hello world',
        'Hello world from ',
        'Hello world from agy.',
      ];

      for (var i = 0; i < deltaEntries.length; i++) {
        final result = interpreter.interpret(deltaEntries[i]);
        expect(result, hasLength(1));
        expect(
          result.single,
          TranscriptEntry.agentMessage(
            id: '3',
            firstOffset: 3,
            lastOffset: deltaEntries[i].offset,
            text: expectedTexts[i],
          ),
        );
      }
    });

    test('hides init, user_input, system_message, and usage-only DONE', () {
      final node = _buildNode();
      final entries = _loadFixture();

      final transcript = buildTranscript(
        node.createTranscriptInterpreter(),
        entries,
      );
      final offsets = transcript.map((e) => e.firstOffset).toSet();

      for (final hiddenOffset in const <int>[1, 2, 7, 14]) {
        expect(offsets, isNot(contains(hiddenOffset)));
      }
    });

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

    test('preserves unknown/invalid step input without colliding with later valid steps', () {
      final node = _buildNode();
      final entries = <RunLogEntry>[
        _entry(
          offset: 1,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 1,
              'step_type': 'agent_response',
              'state': 'ERROR',
              'text_delta': 'oops',
            },
          }),
        ),
        _entry(
          offset: 2,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 1,
              'step_type': 'agent_response',
              'state': 'UNKNOWN_STATE',
              'text_delta': 'mystery',
            },
          }),
        ),
        _entry(
          offset: 3,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 1,
              'step_type': 'agent_response',
              'state': 'ACTIVE',
              'text_delta': 42,
            },
          }),
        ),
        _entry(
          offset: 4,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 1,
              'step_type': 'agent_response',
              'state': 'ACTIVE',
              'text_delta': 'Recovered',
            },
          }),
        ),
        _entry(
          offset: 5,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 2,
              'step_type': 'tool',
              'state': 'WEIRD',
              'tool_info': <String, Object?>{'name': 'read_file'},
            },
          }),
        ),
        _entry(
          offset: 6,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 2,
              'step_type': 'tool',
              'state': 'ACTIVE',
              'tool_info': <String, Object?>{'name': 'read_file'},
            },
          }),
        ),
      ];

      final transcript = buildTranscript(
        node.createTranscriptInterpreter(),
        entries,
      );

      expect(transcript, <TranscriptEntry>[
        TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: entries[0].chunk,
        ),
        TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: entries[1].chunk,
        ),
        TranscriptEntry.plainText(
          id: '3',
          firstOffset: 3,
          lastOffset: 3,
          stream: RunOutputStream.stdout,
          text: entries[2].chunk,
        ),
        const TranscriptEntry.agentMessage(
          id: '4',
          firstOffset: 4,
          lastOffset: 4,
          text: 'Recovered',
        ),
        TranscriptEntry.plainText(
          id: '5',
          firstOffset: 5,
          lastOffset: 5,
          stream: RunOutputStream.stdout,
          text: entries[4].chunk,
        ),
        const TranscriptEntry.toolCall(
          id: '6',
          firstOffset: 6,
          lastOffset: 6,
          name: 'read_file',
          callId: 'c1:2',
        ),
      ]);
    });

    test('encodes non-String tool DONE output, falls back to output on ERROR, '
        'and emits result error', () {
      final interpreter = _buildNode().createTranscriptInterpreter();

      final nonStringDone = interpreter.interpret(
        _entry(
          offset: 1,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 1,
              'step_type': 'tool',
              'state': 'DONE',
              'tool_info': <String, Object?>{
                'name': 'list_dir',
                'output': <String, Object?>{'count': 2},
              },
            },
          }),
        ),
      );
      expect(nonStringDone, const <TranscriptEntry>[
        TranscriptEntry.toolCall(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          name: 'list_dir',
          callId: 'c1:1',
        ),
        TranscriptEntry.toolResult(
          id: '1.1',
          firstOffset: 1,
          lastOffset: 1,
          output: '{"count":2}',
          callId: 'c1:1',
        ),
      ]);

      final errorFallback = interpreter.interpret(
        _entry(
          offset: 2,
          chunk: jsonEncode(<String, Object?>{
            'event': 'step_update',
            'step_update': <String, Object?>{
              'conversation_id': 'c1',
              'step_index': 2,
              'step_type': 'tool',
              'state': 'ERROR',
              'tool_info': <String, Object?>{
                'name': 'run_cmd',
                'output': 'command failed',
              },
            },
          }),
        ),
      );
      expect(errorFallback, const <TranscriptEntry>[
        TranscriptEntry.toolCall(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          name: 'run_cmd',
          callId: 'c1:2',
        ),
        TranscriptEntry.toolResult(
          id: '2.1',
          firstOffset: 2,
          lastOffset: 2,
          output: 'command failed',
          callId: 'c1:2',
          isError: true,
        ),
      ]);

      final failedResult = interpreter.interpret(
        _entry(
          offset: 3,
          chunk: jsonEncode(<String, Object?>{
            'event': 'result',
            'result': <String, Object?>{
              'status': 'ERROR',
              'error': 'Quota exceeded',
              'duration_seconds': 1.2,
            },
          }),
        ),
      );
      expect(failedResult, const <TranscriptEntry>[
        TranscriptEntry.finalResult(
          id: '3',
          firstOffset: 3,
          lastOffset: 3,
          status: 'ERROR',
          durationMs: 1200,
        ),
        TranscriptEntry.error(
          id: '3.1',
          firstOffset: 3,
          lastOffset: 3,
          message: 'Quota exceeded',
        ),
      ]);
    });
  });
}
