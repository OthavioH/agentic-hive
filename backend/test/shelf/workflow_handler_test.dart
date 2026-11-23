import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
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
  late WorkflowService service;
  late Handler handler;
  late int idCounter;

  setUp(() {
    repository = _FakeWorkflowRepository();
    idCounter = 0;
    service = WorkflowService(
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
    expect(delResp.statusCode, 202);
    final deletion = WorkflowDeletionAccepted.fromJson(await readJson(delResp));
    await service.whenDeletionFinished(deletion.operationId);

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

  test('GET list and GET by id expose revision', () async {
    final created = WorkflowResponse.fromJson(
      await readJson(
        await handler(
          _jsonRequest(
            '/api/v1/workflows',
            method: 'POST',
            body: const CreateWorkflowRequest(name: 'One').toJson(),
          ),
        ),
      ),
    );

    final list = WorkflowListResponse.fromJson(
      await readJson(await handler(buildRequest('/api/v1/workflows'))),
    );
    expect(list.workflows.single.revision, matches(RegExp(r'^[0-9a-f]{16}$')));

    final fetched = WorkflowResponse.fromJson(
      await readJson(
        await handler(buildRequest('/api/v1/workflows/${created.workflow.id}')),
      ),
    );
    expect(fetched.revision, list.workflows.single.revision);
  });

  test('PUT with a stale revision answers 409 revision_conflict and changes '
      'nothing', () async {
    final created = WorkflowResponse.fromJson(
      await readJson(
        await handler(
          _jsonRequest(
            '/api/v1/workflows',
            method: 'POST',
            body: const CreateWorkflowRequest(name: 'Init').toJson(),
          ),
        ),
      ),
    );
    final r0 = created.revision!;

    final okResp = await handler(
      _jsonRequest(
        '/api/v1/workflows/${created.workflow.id}',
        method: 'PUT',
        body: UpdateWorkflowRequest(name: 'A', revision: r0).toJson(),
      ),
    );
    expect(okResp.statusCode, 200);
    final r1 = WorkflowResponse.fromJson(await readJson(okResp)).revision!;
    expect(r1, isNot(r0));

    final staleResp = await handler(
      _jsonRequest(
        '/api/v1/workflows/${created.workflow.id}',
        method: 'PUT',
        body: UpdateWorkflowRequest(name: 'B', revision: r0).toJson(),
      ),
    );
    expect(staleResp.statusCode, 409);
    final error = ApiError.fromJson(await readJson(staleResp));
    expect(error.code, ApiErrorCode.revisionConflict);
    expect(error.details?['currentRevision'], r1);

    final fetched = WorkflowResponse.fromJson(
      await readJson(
        await handler(buildRequest('/api/v1/workflows/${created.workflow.id}')),
      ),
    );
    expect(fetched.workflow.name, 'A');
  });

  test('PUT without revision still succeeds', () async {
    final created = WorkflowResponse.fromJson(
      await readJson(
        await handler(
          _jsonRequest(
            '/api/v1/workflows',
            method: 'POST',
            body: const CreateWorkflowRequest(name: 'Init').toJson(),
          ),
        ),
      ),
    );

    final resp = await handler(
      _jsonRequest(
        '/api/v1/workflows/${created.workflow.id}',
        method: 'PUT',
        body: const UpdateWorkflowRequest(name: 'Updated').toJson(),
      ),
    );
    expect(resp.statusCode, 200);
  });

  test('DELETE with a stale revision answers 409 and keeps the '
      'workflow', () async {
    final created = WorkflowResponse.fromJson(
      await readJson(
        await handler(
          _jsonRequest(
            '/api/v1/workflows',
            method: 'POST',
            body: const CreateWorkflowRequest(name: 'Init').toJson(),
          ),
        ),
      ),
    );

    final staleDel = await handler(
      buildRequest(
        '/api/v1/workflows/${created.workflow.id}'
        '?revision=0000000000000000',
        method: 'DELETE',
      ),
    );
    expect(staleDel.statusCode, 409);
    expect(
      ApiError.fromJson(await readJson(staleDel)).code,
      ApiErrorCode.revisionConflict,
    );

    final okDel = await handler(
      buildRequest(
        '/api/v1/workflows/${created.workflow.id}?revision=${created.revision}',
        method: 'DELETE',
      ),
    );
    expect(okDel.statusCode, 202);
  });

  group('DELETE /api/v1/workflows/:id force', () {
    late _RecordingRunsDeleter deleter;
    late WorkflowService forceService;
    late Handler forceHandler;

    setUp(() async {
      deleter = _RecordingRunsDeleter();
      var counter = 0;
      forceService = WorkflowService(
        repository: _FakeWorkflowRepository(),
        validator: const WorkflowValidator(),
        runsDeleter: deleter,
        generateId: () => 'wf-${++counter}',
        now: () => DateTime.utc(2026, 11, 20, 10),
      );
      forceHandler = buildApiHandler(
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
        workflowHandler: WorkflowHandler(service: forceService),
      );
      final createResp = await forceHandler(
        _jsonRequest(
          '/api/v1/workflows',
          method: 'POST',
          body: const CreateWorkflowRequest(name: 'Flow').toJson(),
        ),
      );
      expect(createResp.statusCode, 201);
    });

    test('force=true forwards force and returns orphanedRuns', () async {
      deleter.result = const Success(
        WorkflowRunsDeletion(deletedRuns: 1, orphanedRuns: ['r2']),
      );

      final resp = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
      );

      expect(resp.statusCode, 202);
      expect(
        WorkflowDeletionAccepted.fromJson(await readJson(resp)).workflowId,
        'wf-1',
      );
      await Future<void>.delayed(Duration.zero);
      expect(deleter.calls.single.$3, isTrue);
    });

    test('no force parameter means force false', () async {
      final resp = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1', method: 'DELETE'),
      );

      expect(resp.statusCode, 202);
      expect(deleter.calls.single.$3, isFalse);
    });

    test('force=false means force false', () async {
      final resp = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1?force=false', method: 'DELETE'),
      );

      expect(resp.statusCode, 202);
      expect(deleter.calls.single.$3, isFalse);
    });

    test('DELETE answers 202 before the background work finishes', () async {
      final gate = Completer<void>();
      deleter.gate = gate;

      final resp = await Future<Response>.value(
        forceHandler(
          buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
        ),
      ).timeout(const Duration(seconds: 1));

      expect(resp.statusCode, 202);
      final accepted = WorkflowDeletionAccepted.fromJson(await readJson(resp));
      expect(accepted.workflowId, 'wf-1');
      expect(
        (await forceHandler(buildRequest('/api/v1/workflows/wf-1'))).statusCode,
        200,
      );

      gate.complete();
      await forceService.whenDeletionFinished(accepted.operationId);
      expect(
        (await forceHandler(buildRequest('/api/v1/workflows/wf-1'))).statusCode,
        404,
      );
    });

    test('DELETE with active runs and no force answers 409 '
        'workflow_has_active_runs with the runs in details', () async {
      deleter.activeRuns = {'r1': RunStatus.running};

      final resp = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1', method: 'DELETE'),
      );

      expect(resp.statusCode, 409);
      final error = ApiError.fromJson(await readJson(resp));
      expect(error.code, ApiErrorCode.workflowHasActiveRuns);
      expect(error.details, {'r1': 'running'});
      expect(deleter.calls, isEmpty);
    });

    test('DELETE twice answers the same operationId', () async {
      deleter.gate = Completer<void>();

      final first = WorkflowDeletionAccepted.fromJson(
        await readJson(
          await forceHandler(
            buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
          ),
        ),
      );
      final second = WorkflowDeletionAccepted.fromJson(
        await readJson(
          await forceHandler(
            buildRequest('/api/v1/workflows/wf-1', method: 'DELETE'),
          ),
        ),
      );

      expect(second.operationId, first.operationId);
      deleter.gate!.complete();
      await forceService.whenDeletionFinished(first.operationId);
    });

    test('PUT while deleting answers 409 workflow_deleting with the '
        'operation id', () async {
      deleter.gate = Completer<void>();
      final accepted = WorkflowDeletionAccepted.fromJson(
        await readJson(
          await forceHandler(
            buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
          ),
        ),
      );

      final resp = await forceHandler(
        _jsonRequest(
          '/api/v1/workflows/wf-1',
          method: 'PUT',
          body: const UpdateWorkflowRequest(name: 'Renamed').toJson(),
        ),
      );

      expect(resp.statusCode, 409);
      final error = ApiError.fromJson(await readJson(resp));
      expect(error.code, ApiErrorCode.workflowDeleting);
      expect(error.details, {'operationId': accepted.operationId});
      deleter.gate!.complete();
      await forceService.whenDeletionFinished(accepted.operationId);
    });

    test(
      'POST duplicate while deleting answers 409 workflow_deleting',
      () async {
        deleter.gate = Completer<void>();
        await forceHandler(
          buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
        );

        final resp = await forceHandler(
          _jsonRequest('/api/v1/workflows/wf-1/duplicate', method: 'POST'),
        );

        expect(resp.statusCode, 409);
        expect(
          ApiError.fromJson(await readJson(resp)).code,
          ApiErrorCode.workflowDeleting,
        );
        deleter.gate!.complete();
      },
    );

    test('GET by id while deleting answers 200 and the list marks the '
        'workflow as deleting', () async {
      deleter.gate = Completer<void>();
      final accepted = WorkflowDeletionAccepted.fromJson(
        await readJson(
          await forceHandler(
            buildRequest('/api/v1/workflows/wf-1?force=true', method: 'DELETE'),
          ),
        ),
      );

      expect(
        (await forceHandler(buildRequest('/api/v1/workflows/wf-1'))).statusCode,
        200,
      );
      final list = WorkflowListResponse.fromJson(
        await readJson(await forceHandler(buildRequest('/api/v1/workflows'))),
      );
      expect(list.workflows.single.deleting, isTrue);

      deleter.gate!.complete();
      await forceService.whenDeletionFinished(accepted.operationId);
    });

    test('an invalid force value is 400 and deletes nothing', () async {
      final resp = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1?force=yes', method: 'DELETE'),
      );

      expect(resp.statusCode, 400);
      final error = ApiError.fromJson(await readJson(resp));
      expect(error.code, ApiErrorCode.badRequest);
      expect(
        error.message,
        'Query parameter "force" must be "true" or "false".',
      );
      expect(deleter.calls, isEmpty);

      final stillThere = await forceHandler(
        buildRequest('/api/v1/workflows/wf-1'),
      );
      expect(stillThere.statusCode, 200);
    });
  });
}

final class _RecordingRunsDeleter implements WorkflowRunsDeleter {
  Result<WorkflowRunsDeletion> result = const Success(
    WorkflowRunsDeletion(deletedRuns: 0),
  );
  final List<(String, String?, bool)> calls = <(String, String?, bool)>[];

  /// Active runs reported for the workflow (run id to status).
  Map<String, RunStatus> activeRuns = const {};

  /// When set, the deletion waits on this gate before answering.
  Completer<void>? gate;

  @override
  Future<Result<Map<String, RunStatus>>> activeRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
  }) async => Success(activeRuns);

  @override
  Future<Result<WorkflowRunsDeletion>> deleteRunsOfWorkflow(
    String workflowId, {
    String? workspaceId,
    bool force = false,
    WorkflowRunsProgressListener? onProgress,
  }) async {
    calls.add((workflowId, workspaceId, force));
    await gate?.future;
    return result;
  }
}
