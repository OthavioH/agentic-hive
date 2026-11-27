import 'package:agentic_hive_backend/src/domain/nodes/command_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _StubProcessRunner implements NodeProcessRunner {
  const new();

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

final class _TestJsonInterpreter extends JsonLineTranscriptInterpreter {
  @override
  List<TranscriptEntry>? interpretEvent(JsonMap event, RunLogEntry entry) {
    return switch (event['type']) {
      'message' => [
        TranscriptEntry.agentMessage(
          id: transcriptEntryId(entry),
          firstOffset: entry.offset,
          lastOffset: entry.offset,
          text: event['text'] as String? ?? '',
        ),
      ],
      'ignore' => const [],
      'throw' => throw StateError('boom'),
      _ => null,
    };
  }
}

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
  group('PlainTextTranscriptInterpreter', () {
    test('maps stdout and stderr entries to plainText with offset id', () {
      const interpreter = PlainTextTranscriptInterpreter();

      final out = interpreter.interpret(_entry(offset: 1, chunk: 'hello'));
      final err = interpreter.interpret(
        _entry(offset: 2, chunk: 'warn', stream: RunOutputStream.stderr),
      );

      expect(out, [
        const TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: 'hello',
        ),
      ]);
      expect(err, [
        const TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stderr,
          text: 'warn',
        ),
      ]);
    });
  });

  group('JsonLineTranscriptInterpreter', () {
    test('falls back to plain text for invalid JSON and non-object JSON', () {
      final interpreter = _TestJsonInterpreter();

      expect(interpreter.interpret(_entry(offset: 1, chunk: '{bad json')), [
        const TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: '{bad json',
        ),
      ]);
      expect(interpreter.interpret(_entry(offset: 2, chunk: '42')), [
        const TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: '42',
        ),
      ]);
      expect(interpreter.interpret(_entry(offset: 3, chunk: '[1]')), [
        const TranscriptEntry.plainText(
          id: '3',
          firstOffset: 3,
          lastOffset: 3,
          stream: RunOutputStream.stdout,
          text: '[1]',
        ),
      ]);
    });

    test('falls back to plain text when interpretEvent returns null', () {
      final interpreter = _TestJsonInterpreter();

      expect(
        interpreter.interpret(_entry(offset: 4, chunk: '{"type":"unknown"}')),
        [
          const TranscriptEntry.plainText(
            id: '4',
            firstOffset: 4,
            lastOffset: 4,
            stream: RunOutputStream.stdout,
            text: '{"type":"unknown"}',
          ),
        ],
      );
    });

    test('hides event when interpretEvent returns empty list', () {
      final interpreter = _TestJsonInterpreter();

      expect(
        interpreter.interpret(_entry(offset: 5, chunk: '{"type":"ignore"}')),
        isEmpty,
      );
    });

    test('maps stderr containing valid JSON to plain text', () {
      final interpreter = _TestJsonInterpreter();

      expect(
        interpreter.interpret(
          _entry(
            offset: 6,
            chunk: '{"type":"message","text":"hi"}',
            stream: RunOutputStream.stderr,
          ),
        ),
        [
          const TranscriptEntry.plainText(
            id: '6',
            firstOffset: 6,
            lastOffset: 6,
            stream: RunOutputStream.stderr,
            text: '{"type":"message","text":"hi"}',
          ),
        ],
      );
    });

    test('maps known stdout JSON event', () {
      final interpreter = _TestJsonInterpreter();

      expect(
        interpreter.interpret(
          _entry(offset: 7, chunk: '{"type":"message","text":"hi"}'),
        ),
        [
          const TranscriptEntry.agentMessage(
            id: '7',
            firstOffset: 7,
            lastOffset: 7,
            text: 'hi',
          ),
        ],
      );
    });
    test('falls back to plain text when interpretEvent throws', () {
      final interpreter = _TestJsonInterpreter();

      expect(
        interpreter.interpret(_entry(offset: 8, chunk: '{"type":"throw"}')),
        [
          const TranscriptEntry.plainText(
            id: '8',
            firstOffset: 8,
            lastOffset: 8,
            stream: RunOutputStream.stdout,
            text: '{"type":"throw"}',
          ),
        ],
      );
    });
  });

  group('buildTranscript', () {
    test('replaces same-id entry in its original position', () {
      final transcript = buildTranscript(_DeltaTestInterpreter(), [
        _entry(offset: 1, chunk: 'delta:hel'),
        _entry(offset: 2, chunk: 'other'),
        _entry(offset: 3, chunk: 'delta:lo'),
      ]);

      expect(transcript, [
        const TranscriptEntry.agentMessage(
          id: '1',
          firstOffset: 1,
          lastOffset: 3,
          text: 'hello',
        ),
        const TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: 'other',
        ),
      ]);
    });
  });

  group('Node.createTranscriptInterpreter', () {
    test('defaults to PlainTextTranscriptInterpreter on CommandNode', () {
      const node = CommandNode(processRunner: _StubProcessRunner());
      expect(
        node.createTranscriptInterpreter(),
        isA<PlainTextTranscriptInterpreter>(),
      );
    });
  });
}

final class _DeltaTestInterpreter implements TranscriptInterpreter {
  String? _id;
  int? _firstOffset;
  final _buffer = StringBuffer();

  @override
  List<TranscriptEntry> interpret(RunLogEntry entry) {
    if (entry.chunk.startsWith('delta:')) {
      _id ??= transcriptEntryId(entry);
      _firstOffset ??= entry.offset;
      _buffer.write(entry.chunk.substring('delta:'.length));
      return [
        TranscriptEntry.agentMessage(
          id: _id!,
          firstOffset: _firstOffset!,
          lastOffset: entry.offset,
          text: _buffer.toString(),
        ),
      ];
    }
    return [plainTextEntry(entry)];
  }
}
