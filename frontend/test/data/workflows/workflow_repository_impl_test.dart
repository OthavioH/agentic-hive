import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_deletion_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_events.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _EmptyDeletionEvents implements WorkflowDeletionEventsSource {
  @override
  Stream<WorkflowDeletionFinished> get finished =>
      const Stream<WorkflowDeletionFinished>.empty();

  @override
  Stream<WorkflowDeletionStatus> get progress =>
      const Stream<WorkflowDeletionStatus>.empty();
}

final class _FakeBackendClient implements BackendClient {
  String? lastMethod;
  String? lastPath;
  JsonMap? lastBody;
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});

  /// Answers keyed by `'<METHOD> <path>'`, consulted before [nextResponse].
  final Map<String, Result<JsonMap>> responses = {};

  /// Every request as `'<METHOD> <path>'`, in order.
  final List<String> calls = [];

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    lastMethod = method;
    lastPath = path;
    lastBody = body;
    calls.add('$method $path');
    return responses['$method $path'] ?? nextResponse;
  }

  @override
  Future<Result<StatusResponse>> checkStatus() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<BackendWebSocketSession>> connectWebSocket() async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<ShutdownResponse>> shutdown({required bool force}) async =>
      const Success(ShutdownResponse());

  @override
  Future<Result<JsonMap>> getJson(String path, {Duration? timeout}) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> postJson(
    String path, {
    JsonMap? body,
    Duration? timeout,
  }) async => const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<JsonMap>> putJson(String path, JsonMap body) async =>
      const FailureResult(NetworkFailure('unused'));

  @override
  Future<Result<void>> delete(String path) async =>
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
          overrides: [
            backendClientProvider.overrideWithValue(client),
            workflowDeletionEventsSourceProvider.overrideWithValue(
              _EmptyDeletionEvents(),
            ),
          ],
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
        overrides: [
          backendClientProvider.overrideWithValue(client),
          workflowDeletionEventsSourceProvider.overrideWithValue(
            _EmptyDeletionEvents(),
          ),
        ],
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

      client.responses
        ..['DELETE /api/v1/workflows/wf-1'] = const Success(<String, Object?>{
          'operationId': 'op-1',
          'workflowId': 'wf-1',
        })
        ..['GET /api/v1/workflow-deletions/op-1'] = Success(
          WorkflowDeletionStatus(
            operationId: 'op-1',
            workflowId: 'wf-1',
            phase: WorkflowDeletionPhase.done,
            outcome: WorkflowDeletionOutcome.deleted,
            startedAt: now,
            finishedAt: now,
          ).toJson(),
        );
      client.calls.clear();
      final delUpdates = await repo.deleteWorkflow('wf-1').toList();
      expect(client.calls, [
        'DELETE /api/v1/workflows/wf-1',
        'GET /api/v1/workflow-deletions/op-1',
      ]);
      expect(delUpdates.last, isA<WorkflowDeletionSucceeded>());

      client.nextResponse = Success(valid.toJson());
      final valRes = await repo.validateWorkflow(sampleWorkflow);
      expect(client.lastMethod, 'POST');
      expect(client.lastPath, '/api/v1/workflows/validate');
      expect(valRes.valueOrNull?.isValid, isTrue);
    });

    test('deleteWorkflow sends scope, revision and force', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const FailureResult(NotFoundFailure('gone'));
      final container = ProviderContainer.test(
        overrides: [
          backendClientProvider.overrideWithValue(client),
          workflowDeletionEventsSourceProvider.overrideWithValue(
            _EmptyDeletionEvents(),
          ),
        ],
      );

      final updates = await container
          .read(workflowRepositoryProvider)
          .deleteWorkflow(
            'wf-1',
            workspaceId: 'ws-1',
            revision: 'r1',
            force: true,
          )
          .toList();

      expect(
        client.calls.first,
        'DELETE /api/v1/workflows/wf-1?workspaceId=ws-1&revision=r1&force=true',
      );
      expect(updates, [isA<WorkflowDeletionSucceeded>()]);
    });

    test(
      'getWorkflowDeletion calls GET /api/v1/workflow-deletions/<encoded id> '
      'and decodes the status',
      () async {
        final client = _FakeBackendClient()
          ..nextResponse = Success(
            WorkflowDeletionStatus(
              operationId: 'op 1',
              workflowId: 'wf-1',
              phase: WorkflowDeletionPhase.deletingRuns,
              startedAt: now,
            ).toJson(),
          );
        final container = ProviderContainer.test(
          overrides: [
            backendClientProvider.overrideWithValue(client),
            workflowDeletionEventsSourceProvider.overrideWithValue(
              _EmptyDeletionEvents(),
            ),
          ],
        );

        final result = await container
            .read(workflowRemoteDataSourceProvider)
            .getWorkflowDeletion('op 1');

        expect(client.lastMethod, 'GET');
        expect(client.lastPath, '/api/v1/workflow-deletions/op%201');
        expect(result.valueOrNull?.phase, WorkflowDeletionPhase.deletingRuns);
      },
    );

    test('returns BackendFailure on malformed payload', () async {
      final client = _FakeBackendClient()
        ..nextResponse = const Success(<String, Object?>{'unexpected': true});
      final container = ProviderContainer.test(
        overrides: [
          backendClientProvider.overrideWithValue(client),
          workflowDeletionEventsSourceProvider.overrideWithValue(
            _EmptyDeletionEvents(),
          ),
        ],
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
        overrides: [
          backendClientProvider.overrideWithValue(client),
          workflowDeletionEventsSourceProvider.overrideWithValue(
            _EmptyDeletionEvents(),
          ),
        ],
      );

      final result = await container
          .read(workflowRepositoryProvider)
          .getWorkflow('missing');
      expect(result.failureOrNull, isA<NotFoundFailure>());
    });
  });
}
