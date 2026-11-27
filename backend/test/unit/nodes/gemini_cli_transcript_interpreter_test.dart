import 'package:agentic_hive_backend/src/domain/nodes/gemini_cli_node.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/transcript_interpreter.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
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

GeminiCliNode _createNode() => const GeminiCliNode(
  processRunner: _StubProcessRunner(),
  resultContract: _StubResultContract(),
  agentPromptResolver: _StubAgentPromptResolver(),
);

RunLogEntry _entry({
  required int offset,
  required String chunk,
  RunOutputStream stream = RunOutputStream.stdout,
}) => RunLogEntry(
  stream: stream,
  chunk: chunk,
  timestamp: DateTime.utc(2026, 11, 27, 9),
  offset: offset,
);

const List<({RunOutputStream stream, String line})> _fixture = [
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"init","timestamp":"2026-11-27T09:00:00Z",'
        '"session_id":"s_1","model":"gemini-2.5-pro"}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:01Z",'
        '"role":"user","content":"Fix the bug"}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:02Z",'
        '"role":"assistant","content":"Let me ","delta":true}',
  ),
  (stream: RunOutputStream.stderr, line: 'Loaded cached credentials.'),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:03Z",'
        '"role":"assistant","content":"check ","delta":true}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:04Z",'
        '"role":"assistant","content":"that.","delta":true}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"tool_use","timestamp":"2026-11-27T09:00:05Z",'
        '"tool_name":"read_file","tool_id":"call_1",'
        '"parameters":{"path":"lib/a.dart"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"tool_result","timestamp":"2026-11-27T09:00:06Z",'
        '"tool_id":"call_1","status":"success","output":"void main() {}"}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"tool_result","timestamp":"2026-11-27T09:00:07Z",'
        '"tool_id":"call_2","status":"error",'
        '"error":{"type":"not_found","message":"File missing"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"error","timestamp":"2026-11-27T09:00:08Z",'
        '"severity":"warning","message":"Retrying request"}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:09Z",'
        '"role":"assistant","content":"Standalone note"}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:10Z",'
        '"role":"assistant","content":"Part A ","delta":true}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"message","timestamp":"2026-11-27T09:00:11Z",'
        '"role":"assistant","content":"Part B","delta":true}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"result","timestamp":"2026-11-27T09:00:12Z",'
        '"status":"success","stats":{"duration_ms":1500,'
        '"input_tokens":200,"output_tokens":80}}',
  ),
];

List<RunLogEntry> _fixtureEntries() => [
  for (var i = 0; i < _fixture.length; i++)
    _entry(offset: i + 1, chunk: _fixture[i].line, stream: _fixture[i].stream),
];

const List<TranscriptEntry> _expectedEntries = [
  TranscriptEntry.agentMessage(
    id: '3',
    firstOffset: 3,
    lastOffset: 6,
    text: 'Let me check that.',
  ),
  TranscriptEntry.plainText(
    id: '4',
    firstOffset: 4,
    lastOffset: 4,
    stream: RunOutputStream.stderr,
    text: 'Loaded cached credentials.',
  ),
  TranscriptEntry.toolCall(
    id: '7',
    firstOffset: 7,
    lastOffset: 7,
    name: 'read_file',
    input: {'path': 'lib/a.dart'},
    callId: 'call_1',
  ),
  TranscriptEntry.toolResult(
    id: '8',
    firstOffset: 8,
    lastOffset: 8,
    output: 'void main() {}',
    callId: 'call_1',
  ),
  TranscriptEntry.toolResult(
    id: '9',
    firstOffset: 9,
    lastOffset: 9,
    output: 'File missing',
    callId: 'call_2',
    isError: true,
  ),
  TranscriptEntry.error(
    id: '10',
    firstOffset: 10,
    lastOffset: 10,
    message: 'Retrying request',
  ),
  TranscriptEntry.agentMessage(
    id: '11',
    firstOffset: 11,
    lastOffset: 11,
    text: 'Standalone note',
  ),
  TranscriptEntry.agentMessage(
    id: '12',
    firstOffset: 12,
    lastOffset: 13,
    text: 'Part A Part B',
  ),
  TranscriptEntry.finalResult(
    id: '14',
    firstOffset: 14,
    lastOffset: 14,
    status: 'success',
    durationMs: 1500,
    inputTokens: 200,
    outputTokens: 80,
  ),
];

void main() {
  group('GeminiCliNode transcript interpreter', () {
    test('buildTranscript produces expected entries for Gemini events', () {
      final node = _createNode();
      final actual = buildTranscript(
        node.createTranscriptInterpreter(),
        _fixtureEntries(),
      );

      expect(actual, _expectedEntries);
    });

    test('hides init and user message events', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      expect(
        interpreter.interpret(
          _entry(
            offset: 1,
            chunk: '{"type":"init","session_id":"s_1","model":"gemini"}',
          ),
        ),
        isEmpty,
      );
      expect(
        interpreter.interpret(
          _entry(
            offset: 2,
            chunk: '{"type":"message","role":"user","content":"Prompt"}',
          ),
        ),
        isEmpty,
      );
    });

    test('never drops unknown types, invalid JSON, or stderr lines', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      const unknownType = '{"type":"future.event","x":1}';
      const badJson = '{bad json';
      const stderrLine = 'gemini: warning';

      expect(interpreter.interpret(_entry(offset: 1, chunk: unknownType)), [
        const TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: unknownType,
        ),
      ]);
      expect(interpreter.interpret(_entry(offset: 2, chunk: badJson)), [
        const TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: badJson,
        ),
      ]);
      expect(
        interpreter.interpret(
          _entry(offset: 3, chunk: stderrLine, stream: RunOutputStream.stderr),
        ),
        [
          const TranscriptEntry.plainText(
            id: '3',
            firstOffset: 3,
            lastOffset: 3,
            stream: RunOutputStream.stderr,
            text: stderrLine,
          ),
        ],
      );
    });

    test('maps result with error to error and error finalResult', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      final result = interpreter.interpret(
        _entry(
          offset: 9,
          chunk:
              '{"type":"result","status":"error", '
              '"error":{"type":"fatal","message":"Quota exceeded"}, '
              '"stats":{"duration_ms":300,"input_tokens":10, '
              '"output_tokens":0}}',
        ),
      );

      expect(result, const [
        TranscriptEntry.error(
          id: '9',
          firstOffset: 9,
          lastOffset: 9,
          message: 'Quota exceeded',
        ),
        TranscriptEntry.finalResult(
          id: '9.1',
          firstOffset: 9,
          lastOffset: 9,
          status: 'error',
          durationMs: 300,
          inputTokens: 10,
          outputTokens: 0,
        ),
      ]);
    });

    test('full and incremental interpretation produce identical ids', () {
      final node = _createNode();
      final entries = _fixtureEntries();

      final full = buildTranscript(node.createTranscriptInterpreter(), entries);

      final incrementalInterpreter = node.createTranscriptInterpreter();
      final byId = <String, TranscriptEntry>{};
      for (final entry in entries) {
        for (final item in incrementalInterpreter.interpret(entry)) {
          byId[item.id] = item;
        }
      }

      expect(byId.values.toList(), full);
      expect(
        byId.keys.toList(),
        _expectedEntries.map((entry) => entry.id).toList(),
      );
    });

    test('createTranscriptInterpreter returns a new instance per call', () {
      final node = _createNode();
      final first = node.createTranscriptInterpreter();
      final second = node.createTranscriptInterpreter();

      expect(first, isNot(same(second)));
    });
  });
}
