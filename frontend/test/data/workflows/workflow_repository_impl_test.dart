import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  JsonMap? lastBody;
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    return nextResponse;
  }

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<void> close() async {}
}

void main() {
  final now = DateTime.utc(2026, 11, 20, 12);
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Build & Test',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: now,
    updatedAt: now,
  );
  const valid = WorkflowValidationResult(isValid: true);

  group('WorkflowRepositoryImpl & HttpWorkflowRemoteDataSource', () {
    test(
      'listWorkflows calls GET /api/v1/workflows and decodes list',
      () async {
        final client = _FakeBackendClient()
          ..nextResponse = Success(
            WorkflowListResponse(
              workflows: <WorkflowSummary>[
                WorkflowSummary(
                  id: 'wf-1',
                  name: 'Build & Test',
                  nodeCount: 2,
                  edgeCount: 1,
                  hasValidationErrors: false,
                  updatedAt: now,
                ),
              ],
            ).toJson(),
          );
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final result = await container
            .read(workflowRepositoryProvider)
            .listWorkflows();
        expect(client.lastMethod, 'GET');
        expect(client.lastPath, '/api/v1/workflows');
        expect(result.valueOrNull, hasLength(1));
        expect(result.valueOrNull!.first.name, 'Build & Test');
      },
    );

    test('getWorkflow, create, update, duplicate, delete, validate', () async {
      final client = _FakeBackendClient();
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );
      final repo = container.read(workflowRepositoryProvider);

      client.nextResponse = Success(
        WorkflowResponse(workflow: sampleWorkflow, validation: valid).toJson(),
      );

      final getRes = await repo.getWorkflow('wf-1');
      expect(client.lastMethod, 'GET');
      expect(client.lastPath, '/api/v1/workflows/wf-1');
      expect(getRes.valueOrNull?.workflow.id, 'wf-1');

      await repo.createWorkflow(const CreateWorkflowRequest(name: 'New'));
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/v1/workflows');
      expect(client.lastBody?['name'], 'New');

      await repo.updateWorkflow(
        'wf-1',
        const UpdateWorkflowRequest(name: 'Edited'),
      );
      expect(client.lastMethod, 'PUT');
      expect(client.lastPath, '/api/v1/workflows/wf-1');
      expect(client.lastBody?['name'], 'Edited');

      await repo.duplicateWorkflow('wf-1', name: 'Copy');
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/v1/workflows/wf-1/duplicate');
      expect(client.lastBody?['name'], 'Copy');

      client.nextResponse = const Success(<String, Object?>{
        'id': 'wf-1',
        'deleted': true,
      });
      final delRes = await repo.deleteWorkflow('wf-1');
      expect(client.lastMethod, 'DELETE');
      expect(client.lastPath, '/api/v1/workflows/wf-1');
      expect(delRes.isSuccess, isTrue);

      client.nextResponse = Success(valid.toJson());
      final valRes = await repo.validateWorkflow(sampleWorkflow);
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/v1/workflows/validate');
      expect(valRes.valueOrNull?.isValid, isTrue);
    });

    test('returns BackendFailure on malformed payload', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const Success(<String, Object?>{'unexpected': true});
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );

      final result = await container
          .read(workflowRepositoryProvider)
          .listWorkflows();
      expect(result.isFailure, isTrue);
      expect(result.failureOrNull, isA<BackendFailure>());
    });

    test('propagates NotFoundFailure from BackendClient', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const FailureResult(NotFoundFailure('missing'));
      final container = ProviderContainer.test(
        overrides: [backendClientProvider.overrideWithValue(client)],
      );

      final result = await container
          .read(workflowRepositoryProvider)
          .getWorkflow('missing');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
