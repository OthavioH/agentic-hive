@Timeout(Duration(seconds: 90))
library;

import 'dart:convert';

import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../http/support/harness.dart';
import 'support/ws_harness.dart';

void main() {
  late SocketHttpClient http;
  late WsTestClient ws;

  setUp(() async {
    final dataDir = (await createTempDir()).path;
    final backend = await startBackend(dataDir);
    http = SocketHttpClient(backend.socketPath);
    addTearDown(http.close);
    ws = await WsTestClient.connect(backend.socketPath);
    addTearDown(ws.close);
    await ws.next(); // server.hello
  });

  test('deleting a workflow broadcasts a done progress event, then '
      'workflow.deleted with the accepted operation id', () async {
    final created = await http.post(
      '/api/v1/workflows',
      body: jsonEncode(const CreateWorkflowRequest(name: 'Flow').toJson()),
    );
    final workflow = WorkflowResponse.fromJson(created.json).workflow;

    final res = await http.delete('/api/v1/workflows/${workflow.id}');
    expect(res.statusCode, 202);
    final accepted = WorkflowDeletionAccepted.fromJson(res.json);

    final progress = <WorkflowDeletionStatus>[];
    WsEnvelope? deletedEnvelope;
    for (var i = 0; i < 20 && deletedEnvelope == null; i++) {
      final envelope = await ws.next();
      if (envelope.type == WsMessageType.workflowDeleteProgress) {
        progress.add(WorkflowDeletionStatus.fromJson(envelope.payload));
      } else if (envelope.type == WsMessageType.workflowDeleted) {
        deletedEnvelope = envelope;
      }
    }

    expect(deletedEnvelope, isNotNull, reason: 'workflow.deleted never came');
    expect(
      progress.any(
        (status) =>
            status.phase == WorkflowDeletionPhase.done &&
            status.operationId == accepted.operationId,
      ),
      isTrue,
    );
    final deleted = WorkflowDeletedPayload.fromJson(deletedEnvelope!.payload);
    expect(deleted.operationId, accepted.operationId);
    expect(deleted.workflowId, workflow.id);
    expect(deleted.deletedRuns, 0);
  });
}
