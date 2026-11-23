import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

Matcher _formatErrorNaming(String field) => isA<FormatException>().having(
  (e) => e.message,
  'message',
  contains('"$field"'),
);

void main() {
  final updatedAt = DateTime.utc(2026, 11, 20, 14, 30);

  group('AgentSummary', () {
    test('round-trips through JSON with all fields', () {
      final summary = AgentSummary(
        id: 'code-reviewer',
        name: 'Code Reviewer',
        description: 'Reviews pull requests.',
        tags: const ['review', 'quality'],
        contentHash: 'abc123',
        updatedAt: updatedAt,
      );

      final decoded = AgentSummary.fromJson(_overTheWire(summary.toJson()));

      expect(decoded, summary);
      expect(decoded.parseError, isNull);
    });

    test('round-trips through JSON with parseError and defaults', () {
      final summary = AgentSummary(
        id: 'broken',
        name: 'broken',
        contentHash: 'deadbeef',
        updatedAt: updatedAt,
        parseError: 'Invalid YAML at line 2',
      );

      final decoded = AgentSummary.fromJson(_overTheWire(summary.toJson()));

      expect(decoded, summary);
      expect(decoded.description, isEmpty);
      expect(decoded.tags, isEmpty);
      expect(decoded.parseError, 'Invalid YAML at line 2');
    });

    test('throws a FormatException naming a missing required field', () {
      expect(
        () => AgentSummary.fromJson({
          'id': 'reviewer',
          'name': 'Reviewer',
          'updatedAt': updatedAt.toIso8601String(),
        }),
        throwsA(_formatErrorNaming('contentHash')),
      );
    });
  });

  group('AgentDetail', () {
    test('round-trips through JSON with capabilities and prompt', () {
      final detail = AgentDetail(
        id: 'architect',
        name: 'Architect',
        description: 'Designs systems.',
        tags: const ['design'],
        requiredSkills: const ['architecture'],
        requiredTools: const ['read_file'],
        allowedTools: const ['read_file', 'grep'],
        deniedTools: const ['run_command'],
        prompt: '# Responsibilities\nDesign carefully.',
        contentHash: 'sha256hex',
        updatedAt: updatedAt,
      );

      final decoded = AgentDetail.fromJson(_overTheWire(detail.toJson()));

      expect(decoded, detail);
      expect(decoded.rawContent, isNull);
      expect(decoded.parseError, isNull);
    });

    test('round-trips malformed agent with parseError and rawContent', () {
      final detail = AgentDetail(
        id: 'bad-agent',
        name: 'bad-agent',
        contentHash: 'hash',
        updatedAt: updatedAt,
        parseError: 'Missing closing frontmatter delimiter',
        rawContent: '---\nname: Broken\n',
      );

      final decoded = AgentDetail.fromJson(_overTheWire(detail.toJson()));

      expect(decoded, detail);
      expect(decoded.rawContent, '---\nname: Broken\n');
    });
  });

  group('CreateAgentRequest', () {
    test('round-trips through JSON', () {
      const request = CreateAgentRequest(
        id: 'tester',
        name: 'Tester',
        description: 'Writes tests.',
        tags: ['qa'],
        requiredSkills: ['tdd'],
        requiredTools: ['dart'],
        allowedTools: ['dart'],
        deniedTools: ['rm'],
        prompt: 'Write thorough tests.',
      );

      final decoded = CreateAgentRequest.fromJson(
        _overTheWire(request.toJson()),
      );

      expect(decoded, request);
    });

    test('throws a FormatException naming "id" when missing', () {
      expect(
        () => CreateAgentRequest.fromJson({'name': 'Tester'}),
        throwsA(_formatErrorNaming('id')),
      );
    });
  });

  group('UpdateAgentRequest', () {
    test('round-trips through JSON with expectedHash', () {
      const request = UpdateAgentRequest(
        name: 'Updated Tester',
        expectedHash: 'prevhash',
        description: 'Writes even better tests.',
        tags: ['qa', 'unit'],
        prompt: 'Updated prompt.',
      );

      final decoded = UpdateAgentRequest.fromJson(
        _overTheWire(request.toJson()),
      );

      expect(decoded, request);
    });

    test('throws a FormatException naming "expectedHash" when missing', () {
      expect(
        () => UpdateAgentRequest.fromJson({'name': 'Tester'}),
        throwsA(_formatErrorNaming('expectedHash')),
      );
    });
  });

  group('AgentListResponse', () {
    test('round-trips through JSON', () {
      final response = AgentListResponse(
        agents: [
          AgentSummary(
            id: 'a1',
            name: 'Agent One',
            contentHash: 'h1',
            updatedAt: updatedAt,
          ),
        ],
      );

      final decoded = AgentListResponse.fromJson(
        _overTheWire(response.toJson()),
      );

      expect(decoded, response);
    });
  });

  group('Agent scope (ADR 0022)', () {
    test('summary defaults to global scope and not overridden', () {
      final summary = AgentSummary(
        id: 'a',
        name: 'A',
        contentHash: 'h',
        updatedAt: updatedAt,
      );

      expect(summary.scope, AgentScope.global);
      expect(summary.overridden, isFalse);
      expect(summary.toJson()['scope'], 'global');
    });

    test('summary round-trips workspace scope and overridden flag', () {
      final summary = AgentSummary(
        id: 'a',
        name: 'A',
        contentHash: 'h',
        updatedAt: updatedAt,
        scope: AgentScope.workspace,
        overridden: true,
      );

      final decoded = AgentSummary.fromJson(_overTheWire(summary.toJson()));

      expect(decoded, summary);
      expect(decoded.scope, AgentScope.workspace);
    });

    test('summary without scope decodes as global', () {
      final decoded = AgentSummary.fromJson({
        'id': 'a',
        'name': 'A',
        'contentHash': 'h',
        'updatedAt': updatedAt.toIso8601String(),
      });

      expect(decoded.scope, AgentScope.global);
    });

    test('detail round-trips workspace scope', () {
      final detail = AgentDetail(
        id: 'a',
        name: 'A',
        contentHash: 'h',
        updatedAt: updatedAt,
        scope: AgentScope.workspace,
      );

      final decoded = AgentDetail.fromJson(_overTheWire(detail.toJson()));

      expect(decoded.scope, AgentScope.workspace);
    });

    test('changed payload carries the workspace id, null meaning global', () {
      const global = AgentsChangedPayload(
        kind: AgentChangeKind.updated,
        id: 'a',
      );
      const scoped = AgentsChangedPayload(
        kind: AgentChangeKind.created,
        id: 'a',
        workspaceId: 'ws-1',
      );

      expect(global.workspaceId, isNull);
      expect(
        AgentsChangedPayload.fromJson(_overTheWire(scoped.toJson())),
        scoped,
      );
    });
  });
}
