import 'package:agentic_hive_frontend/core/backend/backend_client.dart';
import 'package:agentic_hive_frontend/core/backend/backend_client_provider.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_reference_providers.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeBackendClient implements BackendClient {
  Result<JsonMap> nextResponse = const Success(<String, Object?>{});
  final List<String> calls = <String>[];

  @override
  Future<Result<JsonMap>> sendJsonRequest(
    String method,
    String path, {
    JsonMap? body,
  }) async {
    calls.add('$method $path');
    return nextResponse;
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
  group(
    'WorkflowReferenceRepositoryImpl & HttpWorkflowReferencesRemoteDataSource',
    () {
      test('GETs /api/v1/workflows/<id>/references without a scope for a global workflow', () async {
        final client = _FakeBackendClient()
          ..nextResponse = const Success(<String, Object?>{
            'references': <Object?>[],
          });
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final result = await container
            .read(workflowReferenceRepositoryProvider)
            .getReferences('wf-1');

        expect(client.calls, <String>['GET /api/v1/workflows/wf-1/references']);
        expect(result.valueOrNull, isEmpty);
      });

      test('adds ?workspaceId= when scoped', () async {
        final client = _FakeBackendClient()
          ..nextResponse = const Success(<String, Object?>{
            'references': <Object?>[],
          });
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        await container
            .read(workflowReferenceRepositoryProvider)
            .getReferences('wf-1', scope: const WorkspaceScope('ws 1'));

        expect(client.calls, <String>[
          'GET /api/v1/workflows/wf-1/references?workspaceId=ws+1',
        ]);
      });

      test('decodes the references list', () async {
        final client = _FakeBackendClient()
          ..nextResponse = const Success(<String, Object?>{
            'references': <Object?>[
              <String, Object?>{
                'workflowId': 'p',
                'workflowName': 'Planner',
                'scope': 'global',
                'nodeIds': <String>['n1'],
              },
            ],
          });
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final result = await container
            .read(workflowReferenceRepositoryProvider)
            .getReferences('wf-1');

        expect(result.valueOrNull, <WorkflowReference>[
          const WorkflowReference(
            workflowId: 'p',
            workflowName: 'Planner',
            nodeIds: <String>['n1'],
          ),
        ]);
      });

      test('maps a malformed payload to a BackendFailure', () async {
        final client = _FakeBackendClient()
          ..nextResponse = const Success(<String, Object?>{
            'references': 'not-a-list',
          });
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final result = await container
            .read(workflowReferenceRepositoryProvider)
            .getReferences('wf-1');

        expect(
          result,
          isA<FailureResult<List<WorkflowReference>>>().having(
            (f) => f.failure,
            'failure',
            isA<BackendFailure>(),
          ),
        );
      });

      test('propagates a backend failure', () async {
        final client = _FakeBackendClient()
          ..nextResponse = const FailureResult<JsonMap>(
            BackendFailure('server down', statusCode: 500),
          );
        final container = ProviderContainer.test(
          overrides: [backendClientProvider.overrideWithValue(client)],
        );

        final result = await container
            .read(workflowReferenceRepositoryProvider)
            .getReferences('wf-1');

        expect(
          result,
          isA<FailureResult<List<WorkflowReference>>>().having(
            (f) => f.failure,
            'failure',
            isA<BackendFailure>()
                .having((b) => b.message, 'message', 'server down')
                .having((b) => b.statusCode, 'statusCode', 500),
          ),
        );
      });
    },
  );
}
