import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  test('a global change round-trips without workspaceId', () {
    const payload = WorkflowsChangedPayload(
      kind: WorkflowChangeKind.created,
      id: 'x',
    );
    final json =
        jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>;

    expect(WorkflowsChangedPayload.fromJson(json), payload);
    expect(json['workspaceId'], isNull);
    expect(
      WorkflowsChangedPayload.fromJson({'kind': 'created', 'id': 'x'})
          .workspaceId,
      isNull,
    );
  });

  test('a workspace change still carries workspaceId', () {
    const payload = WorkflowsChangedPayload(
      kind: WorkflowChangeKind.created,
      id: 'x',
      workspaceId: 'ws-1',
    );
    final decoded = WorkflowsChangedPayload.fromJson(
      jsonDecode(jsonEncode(payload.toJson())) as Map<String, dynamic>,
    );

    expect(decoded, payload);
  });
}
