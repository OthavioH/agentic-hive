import 'dart:convert';

import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final _store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    _store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async {
    if (_store.remove(id) == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return const Success<void>(null);
  }

  @override
  Future<Result<Workflow>> getById(String id) async {
    final wf = _store[id];
    if (wf == null) {
      return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
    }
    return Success(wf);
  }

  @override
  Future<Result<List<Workflow>>> listAll() async {
    final items = _store.values.toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
    return Success(items);
  }

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    if (!_store.containsKey(workflow.id)) {
      return FailureResult(
        NotFoundFailure('Workflow "${workflow.id}" not found.'),
      );
    }
    _store[workflow.id] = workflow;
    return Success(workflow);
  }
}

Request _jsonRequest(
  String path, {
  required String method,
  Object? body,
  Map<String, String> headers = const {},
}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: {'content-type': 'application/json', ...headers},
  body: body == null ? null : (body is String ? body : jsonEncode(body)),
);

void main() {
  late _FakeWorkflowRepository repository;
  late Handler handler;
  late int idCounter;

  setUp(() {
    repository = _FakeWorkflowRepository();
    idCounter = 0;
    final service = WorkflowService(
      repository: repository,
      validator: const WorkflowValidator(),
      generateId: () => 'wf-${++idCounter}',
      now: () => DateTime.utc(2026, 11, 20, 12),
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 2),
        ),
        version: '0.1.0',
        dataDir: '/tmp',
        startedAt: DateTime.utc(2026, 11, 20, 11),
      ),
      webSocketHandler: (_) => Response(418),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      workflowHandler: WorkflowHandler(service: service),
    );
  });

  test('CRUD + duplicate lifecycle under /api/v1/workflows', () async {
    // List initially empty.
    final emptyResp = await handler(buildRequest('/api/v1/workflows'));
    expect(emptyResp.statusCode, 200);
    expect(
      WorkflowListResponse.fromJson(await readJson(emptyResp)).workflows,
      isEmpty,
    );

    // Create draft workflow.
    final createResp = await handler(
      _jsonRequest(
        '/api/v1/workflows',
        method: 'POST',
        body: const CreateWorkflowRequest(
          name: 'My Flow',
          nodes: [
            WorkflowNode(
              id: 'n1',
              type: NodeTypeId.command,
              label: 'Start',
              position: WorkflowPosition(x: 0, y: 0),
              config: {'command': 'echo start'},
            ),
          ],
          entryNodeId: 'n1',
        ).toJson(),
      ),
    );
    expect(createResp.statusCode, 201);
    final created = WorkflowResponse.fromJson(await readJson(createResp));
    expect(created.workflow.id, 'wf-1');
    expect(created.validation.isValid, isTrue);

    // Get by id.
    final getResp = await handler(buildRequest('/api/v1/workflows/wf-1'));
    expect(getResp.statusCode, 200);
    expect(
      WorkflowResponse.fromJson(await readJson(getResp)).workflow.name,
      'My Flow',
    );

    // Update.
    final putResp = await handler(
      _jsonRequest(
        '/api/v1/workflows/wf-1',
        method: 'PUT',
        body: const UpdateWorkflowRequest(name: 'Renamed Flow').toJson(),
      ),
    );
    expect(putResp.statusCode, 200);
    final updated = WorkflowResponse.fromJson(await readJson(putResp));
    expect(updated.workflow.name, 'Renamed Flow');
    expect(updated.validation.isValid, isFalse);

    // Duplicate without body.
    final dupResp = await handler(
      _jsonRequest('/api/v1/workflows/wf-1/duplicate', method: 'POST'),
    );
    expect(dupResp.statusCode, 201);
    final duplicated = WorkflowResponse.fromJson(await readJson(dupResp));
    expect(duplicated.workflow.id, 'wf-2');
    expect(duplicated.workflow.name, 'Renamed Flow (Copy)');

    // Delete.
    final delResp = await handler(
      buildRequest('/api/v1/workflows/wf-1', method: 'DELETE'),
    );
    expect(delResp.statusCode, 200);
    expect(await readJson(delResp), {'id': 'wf-1', 'deleted': true});

    // Get deleted returns 404 ApiError.
    final missingResp = await handler(buildRequest('/api/v1/workflows/wf-1'));
    expect(missingResp.statusCode, 404);
    final error = ApiError.fromJson(await readJson(missingResp));
    expect(error.code, ApiErrorCode.notFound);
  });

  test(
    'POST /api/v1/workflows/validate validates without persisting',
    () async {
      final resp = await handler(
        _jsonRequest(
          '/api/v1/workflows/validate',
          method: 'POST',
          body: ValidateWorkflowRequest(
            workflow: Workflow(
              id: 'temp',
              name: '',
              nodes: const [],
              edges: const [],
              createdAt: DateTime.utc(2026, 11, 20),
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ).toJson(),
        ),
      );

      expect(resp.statusCode, 200);
      final result = WorkflowValidationResult.fromJson(await readJson(resp));
      expect(result.isValid, isFalse);
      expect(result.issues, isNotEmpty);

      final list = WorkflowListResponse.fromJson(
        await readJson(await handler(buildRequest('/api/v1/workflows'))),
      );
      expect(list.workflows, isEmpty);
    },
  );

  test('returns 400 bad_request on malformed JSON body', () async {
    final resp = await handler(
      _jsonRequest('/api/v1/workflows', method: 'POST', body: '{bad json'),
    );

    expect(resp.statusCode, 400);
    final error = ApiError.fromJson(await readJson(resp));
    expect(error.code, ApiErrorCode.badRequest);
  });

  test('rejects Origin header with 403 origin_not_allowed', () async {
    final resp = await handler(
      buildRequest(
        '/api/v1/workflows',
        headers: {'origin': 'https://evil.example'},
      ),
    );

    expect(resp.statusCode, 403);
    final error = ApiError.fromJson(await readJson(resp));
    expect(error.code, ApiErrorCode.originNotAllowed);
  });
}
