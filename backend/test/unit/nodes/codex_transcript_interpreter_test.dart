import 'package:agentic_hive_backend/src/domain/nodes/codex_node.dart';
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

CodexNode _createNode() => const CodexNode(
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
    line: '{"type":"thread.started","thread_id":"th_1"}',
  ),
  (stream: RunOutputStream.stdout, line: '{"type":"turn.started"}'),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"rs_1","type":"reasoning", '
        '"text":"Checking files"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.started","item":{"id":"cmd_1", '
        '"type":"command_execution","command":"ls -la", '
        '"aggregated_output":"","status":"in_progress"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.updated","item":{"id":"cmd_1", '
        '"type":"command_execution","command":"ls -la", '
        '"aggregated_output":"partial","status":"in_progress"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"cmd_1", '
        '"type":"command_execution","command":"ls -la", '
        '"aggregated_output":"missing file","exit_code":1, '
        '"status":"failed"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"fc_1","type":"file_change", '
        '"changes":[{"path":"lib/a.dart","kind":"update"}, '
        '{"path":"lib/b.dart","kind":"add"}],"status":"completed"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.started","item":{"id":"mcp_1","type":"mcp_tool_call", '
        '"server":"hive","tool":"report_result", '
        '"arguments":{"status":"success"},"status":"in_progress"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"mcp_1", '
        '"type":"mcp_tool_call","server":"hive","tool":"report_result", '
        '"arguments":{"status":"success"}, '
        '"result":{"content":[{"type":"text","text":"Recorded"}]}, '
        '"status":"completed"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.started","item":{"id":"todo_1","type":"todo_list", '
        '"items":[{"text":"Read code","completed":false}, '
        '{"text":"Write tests","completed":false}]}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.updated","item":{"id":"todo_1","type":"todo_list", '
        '"items":[{"text":"Read code","completed":true}, '
        '{"text":"Write tests","completed":false}]}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"msg_1", '
        '"type":"agent_message","text":"All done"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"err_1","type":"error", '
        '"message":"Minor warning"}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.started","item":{"id":"ws_1","type":"web_search", '
        '"query":""}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"item.completed","item":{"id":"ws_1","type":"web_search", '
        '"query":"dart transcript interpreter", '
        '"results":[{"title":"Dart docs"}]}}',
  ),
  (
    stream: RunOutputStream.stdout,
    line:
        '{"type":"turn.completed","usage":{"input_tokens":120, '
        '"cached_input_tokens":30,"output_tokens":45}}',
  ),
];

List<RunLogEntry> _fixtureEntries() => [
  for (var i = 0; i < _fixture.length; i++)
    _entry(offset: i + 1, chunk: _fixture[i].line, stream: _fixture[i].stream),
];

const List<TranscriptEntry> _expectedEntries = [
  TranscriptEntry.thinking(
    id: '3',
    firstOffset: 3,
    lastOffset: 3,
    text: 'Checking files',
  ),
  TranscriptEntry.toolCall(
    id: '4',
    firstOffset: 4,
    lastOffset: 6,
    name: 'shell',
    input: {'command': 'ls -la'},
    callId: 'cmd_1',
  ),
  TranscriptEntry.toolResult(
    id: '6',
    firstOffset: 6,
    lastOffset: 6,
    output: 'missing file',
    callId: 'cmd_1',
    isError: true,
  ),
  TranscriptEntry.toolCall(
    id: '7',
    firstOffset: 7,
    lastOffset: 7,
    name: 'apply_patch',
    input: {
      'changes': [
        {'path': 'lib/a.dart', 'kind': 'update'},
        {'path': 'lib/b.dart', 'kind': 'add'},
      ],
    },
    callId: 'fc_1',
  ),
  TranscriptEntry.toolResult(
    id: '7.1',
    firstOffset: 7,
    lastOffset: 7,
    output: 'update lib/a.dart\nadd lib/b.dart',
    callId: 'fc_1',
  ),
  TranscriptEntry.toolCall(
    id: '8',
    firstOffset: 8,
    lastOffset: 9,
    name: 'hive.report_result',
    input: {'status': 'success'},
    callId: 'mcp_1',
  ),
  TranscriptEntry.toolResult(
    id: '9',
    firstOffset: 9,
    lastOffset: 9,
    output: 'Recorded',
    callId: 'mcp_1',
  ),
  TranscriptEntry.agentMessage(
    id: '10',
    firstOffset: 10,
    lastOffset: 11,
    text: '- [x] Read code\n- [ ] Write tests',
  ),
  TranscriptEntry.agentMessage(
    id: '12',
    firstOffset: 12,
    lastOffset: 12,
    text: 'All done',
  ),
  TranscriptEntry.error(
    id: '13',
    firstOffset: 13,
    lastOffset: 13,
    message: 'Minor warning',
  ),
  TranscriptEntry.toolCall(
    id: '14',
    firstOffset: 14,
    lastOffset: 15,
    name: 'web_search',
    input: {'query': 'dart transcript interpreter'},
    callId: 'ws_1',
  ),
  TranscriptEntry.toolResult(
    id: '15',
    firstOffset: 15,
    lastOffset: 15,
    output: '[{"title":"Dart docs"}]',
    callId: 'ws_1',
  ),
  TranscriptEntry.finalResult(
    id: '16',
    firstOffset: 16,
    lastOffset: 16,
    status: 'success',
    inputTokens: 120,
    outputTokens: 45,
  ),
];

void main() {
  group('CodexNode transcript interpreter', () {
    test('buildTranscript produces expected entries for Codex events', () {
      final node = _createNode();
      final actual = buildTranscript(
        node.createTranscriptInterpreter(),
        _fixtureEntries(),
      );

      expect(actual, _expectedEntries);
    });

    test('hides thread.started, turn.started, and item.updated command', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      expect(
        interpreter.interpret(
          _entry(
            offset: 1,
            chunk: '{"type":"thread.started","thread_id":"th_1"}',
          ),
        ),
        isEmpty,
      );
      expect(
        interpreter.interpret(
          _entry(offset: 2, chunk: '{"type":"turn.started"}'),
        ),
        isEmpty,
      );
      expect(
        interpreter.interpret(
          _entry(
            offset: 3,
            chunk:
                '{"type":"item.updated","item":{"id":"cmd_1",'
                '"type":"command_execution","command":"ls",'
                '"aggregated_output":"a","status":"in_progress"}}',
          ),
        ),
        isEmpty,
      );
    });

    test('never drops unknown types, invalid JSON, or stderr lines', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      const unknownType = '{"type":"future.event","x":1}';
      const collabItem =
          '{"type":"item.completed","item":{"id":"c_1",'
          '"type":"collab_tool_call","tool":"wait"}}';
      const badJson = '{bad json';
      const stderrLine = 'codex: warning';

      expect(interpreter.interpret(_entry(offset: 1, chunk: unknownType)), [
        const TranscriptEntry.plainText(
          id: '1',
          firstOffset: 1,
          lastOffset: 1,
          stream: RunOutputStream.stdout,
          text: unknownType,
        ),
      ]);
      expect(interpreter.interpret(_entry(offset: 2, chunk: collabItem)), [
        const TranscriptEntry.plainText(
          id: '2',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: collabItem,
        ),
      ]);
      expect(interpreter.interpret(_entry(offset: 3, chunk: badJson)), [
        const TranscriptEntry.plainText(
          id: '3',
          firstOffset: 3,
          lastOffset: 3,
          stream: RunOutputStream.stdout,
          text: badJson,
        ),
      ]);
      expect(
        interpreter.interpret(
          _entry(offset: 4, chunk: stderrLine, stream: RunOutputStream.stderr),
        ),
        [
          const TranscriptEntry.plainText(
            id: '4',
            firstOffset: 4,
            lastOffset: 4,
            stream: RunOutputStream.stderr,
            text: stderrLine,
          ),
        ],
      );
    });

    test('maps turn.failed to error and error finalResult', () {
      final interpreter = _createNode().createTranscriptInterpreter();

      final result = interpreter.interpret(
        _entry(
          offset: 9,
          chunk: '{"type":"turn.failed","error":{"message":"Quota exceeded"}}',
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

    test(
      'maps MCP error, MCP non-text content, and declined command status',
      () {
        final interpreter = _createNode().createTranscriptInterpreter();

        const mcpError =
            '{"type":"item.completed","item":{"id":"mcp_err", '
            '"type":"mcp_tool_call","server":"hive","tool":"report_result", '
            '"arguments":{},"error":{"message":"Tool failed"}, '
            '"status":"failed"}}';
        expect(
          interpreter.interpret(_entry(offset: 1, chunk: mcpError)),
          const [
            TranscriptEntry.toolCall(
              id: '1',
              firstOffset: 1,
              lastOffset: 1,
              name: 'hive.report_result',
              callId: 'mcp_err',
            ),
            TranscriptEntry.toolResult(
              id: '1.1',
              firstOffset: 1,
              lastOffset: 1,
              output: 'Tool failed',
              callId: 'mcp_err',
              isError: true,
            ),
          ],
        );

        const mcpJsonFallback =
            '{"type":"item.completed","item":{"id":"mcp_img", '
            '"type":"mcp_tool_call","server":"fs","tool":"read", '
            '"arguments":{},"result":{"content":[{"type":"image", '
            '"data":"abc"}]},"status":"completed"}}';
        expect(
          interpreter.interpret(_entry(offset: 2, chunk: mcpJsonFallback)),
          const [
            TranscriptEntry.toolCall(
              id: '2',
              firstOffset: 2,
              lastOffset: 2,
              name: 'fs.read',
              callId: 'mcp_img',
            ),
            TranscriptEntry.toolResult(
              id: '2.1',
              firstOffset: 2,
              lastOffset: 2,
              output: '[{"type":"image","data":"abc"}]',
              callId: 'mcp_img',
            ),
          ],
        );

        const declinedCmd =
            '{"type":"item.completed","item":{"id":"cmd_dec", '
            '"type":"command_execution","command":"rm -rf /", '
            '"aggregated_output":"User declined","status":"declined"}}';
        expect(
          interpreter.interpret(_entry(offset: 3, chunk: declinedCmd)),
          const [
            TranscriptEntry.toolCall(
              id: '3',
              firstOffset: 3,
              lastOffset: 3,
              name: 'shell',
              input: {'command': 'rm -rf /'},
              callId: 'cmd_dec',
            ),
            TranscriptEntry.toolResult(
              id: '3.1',
              firstOffset: 3,
              lastOffset: 3,
              output: 'User declined',
              callId: 'cmd_dec',
              isError: true,
            ),
          ],
        );
      },
    );

    test('falls back to plainText when text item misses text or message', () {
      final interpreter = _createNode().createTranscriptInterpreter();
      const missingText =
          '{"type":"item.completed","item":{"id":"m_1", '
          '"type":"agent_message"}}';
      const missingErr =
          '{"type":"item.completed","item":{"id":"e_1","type":"error"}}';

      expect(
        interpreter.interpret(_entry(offset: 1, chunk: missingText)),
        const [
          TranscriptEntry.plainText(
            id: '1',
            firstOffset: 1,
            lastOffset: 1,
            stream: RunOutputStream.stdout,
            text: missingText,
          ),
        ],
      );
      expect(
        interpreter.interpret(_entry(offset: 2, chunk: missingErr)),
        const [
          TranscriptEntry.plainText(
            id: '2',
            firstOffset: 2,
            lastOffset: 2,
            stream: RunOutputStream.stdout,
            text: missingErr,
          ),
        ],
      );
    });
  });
}
