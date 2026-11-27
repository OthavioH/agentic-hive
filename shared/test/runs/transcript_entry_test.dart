import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('TranscriptEntry', () {
    test('round-trips every variant through JSON', () {
      final variants = <TranscriptEntry>[
        const TranscriptEntry.agentMessage(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          text: 'hello from agent',
        ),
        const TranscriptEntry.thinking(
          id: '2',
          firstOffset: 2,
          lastOffset: 3,
          text: 'pondering',
        ),
        const TranscriptEntry.toolCall(
          id: '3',
          firstOffset: 4,
          lastOffset: 4,
          name: 'read_file',
          input: <String, Object?>{'path': 'lib/main.dart', 'line': 10},
          callId: 'call-1',
        ),
        const TranscriptEntry.toolResult(
          id: '4',
          firstOffset: 5,
          lastOffset: 5,
          callId: 'call-1',
          output: 'file contents',
          isError: true,
        ),
        const TranscriptEntry.error(
          id: '5',
          firstOffset: 6,
          lastOffset: 6,
          message: 'something broke',
        ),
        const TranscriptEntry.finalResult(
          id: '6',
          firstOffset: 7,
          lastOffset: 7,
          status: 'success',
          durationMs: 1234,
          costUsd: 0.0125,
          inputTokens: 100,
          outputTokens: 50,
        ),
        const TranscriptEntry.finalResult(
          id: '7',
          firstOffset: 8,
          lastOffset: 8,
        ),
        const TranscriptEntry.plainText(
          id: '8',
          firstOffset: 9,
          lastOffset: 9,
          stream: RunOutputStream.stderr,
          text: 'raw stderr line',
        ),
      ];

      for (final entry in variants) {
        final json = entry.toJson();
        expect(json['kind'], isA<String>());
        expect(TranscriptEntry.fromJson(json), entry);
      }
    });
  });
}
