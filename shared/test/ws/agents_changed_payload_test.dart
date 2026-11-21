import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

JsonMap _overTheWire(JsonMap json) =>
    jsonDecode(jsonEncode(json)) as Map<String, Object?>;

void main() {
  final updatedAt = DateTime.utc(2026, 11, 20, 15);

  group('AgentsChangedPayload', () {
    test('round-trips a created event with AgentSummary', () {
      final payload = AgentsChangedPayload(
        kind: AgentChangeKind.created,
        id: 'reviewer',
        agent: AgentSummary(
          id: 'reviewer',
          name: 'Reviewer',
          contentHash: 'abc',
          updatedAt: updatedAt,
        ),
      );

      final decoded = AgentsChangedPayload.fromJson(
        _overTheWire(payload.toJson()),
      );

      expect(decoded, payload);
      expect(decoded.kind, AgentChangeKind.created);
      expect(decoded.agent?.name, 'Reviewer');
    });

    test('round-trips a deleted event without AgentSummary', () {
      const payload = AgentsChangedPayload(
        kind: AgentChangeKind.deleted,
        id: 'reviewer',
      );

      final decoded = AgentsChangedPayload.fromJson(
        _overTheWire(payload.toJson()),
      );

      expect(decoded, payload);
      expect(decoded.agent, isNull);
    });

    test('throws FormatException on unknown kind', () {
      expect(
        () => AgentsChangedPayload.fromJson({'kind': 'renamed', 'id': 'x'}),
        throwsFormatException,
      );
    });
  });
}
