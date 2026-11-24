import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/ws/connection_registry.dart';
import 'package:agentic_hive_backend/src/ws/ws_workflow_events.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import 'fake_web_socket_channel.dart';

void main() {
  late FakeWebSocketChannel channel;
  late List<WsEnvelope> envelopes;
  late StreamSubscription<Object?> subscription;
  late WsWorkflowEvents events;

  setUp(() {
    final registry = ConnectionRegistry();
    channel = FakeWebSocketChannel();
    registry.add(WsConnection(id: 'conn-1', channel: channel));
    envelopes = [];
    subscription = channel.outgoing.listen((frame) {
      envelopes.add(WsEnvelope.decode(frame! as String));
    });
    events = WsWorkflowEvents(registry, generateId: () => 'evt-1');
  });

  tearDown(() => subscription.cancel());

  test('broadcasts workflows.changed with the summary', () async {
    final summary = WorkflowSummary(
      id: 'wf-1',
      name: 'Review',
      nodeCount: 2,
      edgeCount: 1,
      hasValidationErrors: false,
      scope: WorkflowScope.workspace,
      workspaceId: 'ws-1',
      revision: 'abc123',
      updatedAt: DateTime.utc(2026),
    );
    events.workflowChanged(
      WorkflowChangeKind.created,
      'wf-1',
      workspaceId: 'ws-1',
      workflow: summary,
    );
    await Future<void>.delayed(Duration.zero);
    expect(envelopes, hasLength(1));
    expect(envelopes.single.type, WsMessageType.workflowsChanged);
    expect(envelopes.single.id, 'evt-1');
    final payload = WorkflowsChangedPayload.fromJson(
      jsonDecode(jsonEncode(envelopes.single.payload)) as Map<String, dynamic>,
    );
    expect(payload.kind, WorkflowChangeKind.created);
    expect(payload.id, 'wf-1');
    expect(payload.workspaceId, 'ws-1');
    expect(payload.workflow, summary);
  });

  test('a global change has no workspaceId', () async {
    events.workflowChanged(WorkflowChangeKind.created, 'global-1');
    await Future<void>.delayed(Duration.zero);
    final payload = WorkflowsChangedPayload.fromJson(envelopes.single.payload);
    expect(payload.workspaceId, isNull);
  });
}
