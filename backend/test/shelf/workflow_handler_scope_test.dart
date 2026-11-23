import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/workflows/workflow_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workflows/file_workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

final class _MemoryWorkflows implements WorkflowRepository {
  final store = <String, Workflow>{};

  @override
  Future<Result<Workflow>> create(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String id) async => store.remove(id) == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : const Success<void>(null);

  @override
  Future<Result<Workflow>> getById(String id) async => store[id] == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : Success(store[id]!);

  @override
  Future<Result<List<Workflow>>> listAll() async =>
      Success(store.values.toList());

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class _Workspaces implements WorkspaceRepository {
  new(this.workspace);

  final Workspace workspace;

  @override
  Future<Result<Workspace>> getById(String id) async => id == workspace.id
      ? Success(workspace)
      : FailureResult(NotFoundFailure('Workspace "$id" not found.'));

  @override
  Future<Result<Workspace>> create(Workspace workspace) async =>
      Success(workspace);

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);

  @override
  Future<Result<List<Workspace>>> list() async => Success([workspace]);

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => Success(workspace);
}

Request _request(String method, String path, [Object? body]) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: {'content-type': 'application/json'},
  body: body == null ? null : jsonEncode(body),
);

Future<Map<String, Object?>> _json(Response response) async =>
    jsonDecode(await response.readAsString()) as Map<String, Object?>;

void main() {
  late Directory root;
  late WorkflowHandler handler;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hive_wf_handler_');
    handler = WorkflowHandler(
      service: WorkflowService(
        repository: _MemoryWorkflows(),
        validator: const WorkflowValidator(),
        workspaceWorkflows: FileWorkspaceWorkflowRepository(),
        workspaces: _Workspaces(
          Workspace(
            id: 'ws-1',
            name: 'Repo',
            rootPath: root.path,
            isGit: false,
            createdAt: DateTime.utc(2026),
            updatedAt: DateTime.utc(2026),
          ),
        ),
        generateId: () => 'global-1',
      ),
    );
  });

  tearDown(() => root.deleteSync(recursive: true));

  test('create, edit, delete a workspace workflow through the API', () async {
    final created = await handler.call(
      _request('POST', '/', {'name': 'Deploy', 'workspaceId': 'ws-1'}),
    );
    expect(created.statusCode, 201);
    final body = await _json(created);
    expect(body['scope'], 'workspace');
    expect(body['workspaceId'], 'ws-1');
    expect((body['workflow']! as Map)['id'], 'deploy');

    final updated = await handler.call(
      _request('PUT', '/deploy?workspaceId=ws-1', {'name': 'Deploy v2'}),
    );
    expect(updated.statusCode, 200);
    expect(((await _json(updated))['workflow']! as Map)['name'], 'Deploy v2');

    final missingScope = await handler.call(_request('GET', '/deploy'));
    expect(missingScope.statusCode, 404);

    final deleted = await handler.call(
      _request('DELETE', '/deploy?workspaceId=ws-1'),
    );
    expect(deleted.statusCode, 200);
    expect(
      (await handler.call(_request('GET', '/deploy?workspaceId=ws-1')))
          .statusCode,
      404,
    );
  });

  test(
    'list with workspaceId returns both scopes; without, global only',
    () async {
      await handler.call(_request('POST', '/', {'name': 'Deploy'}));
      await handler.call(
        _request('POST', '/', {'name': 'Deploy', 'workspaceId': 'ws-1'}),
      );

      final both = WorkflowListResponse.fromJson(
        await _json(await handler.call(_request('GET', '/?workspaceId=ws-1'))),
      ).workflows;
      expect(both.map((w) => w.scope).toSet(), {
        WorkflowScope.global,
        WorkflowScope.workspace,
      });
      expect(both, hasLength(2));

      final globalOnly = WorkflowListResponse.fromJson(
        await _json(await handler.call(_request('GET', '/'))),
      ).workflows;
      expect(globalOnly.map((w) => w.scope), [WorkflowScope.global]);
    },
  );

  test('duplicate honours the workspaceId query', () async {
    await handler.call(
      _request('POST', '/', {'name': 'Deploy', 'workspaceId': 'ws-1'}),
    );

    final copy = await handler.call(
      _request('POST', '/deploy/duplicate?workspaceId=ws-1'),
    );

    expect(copy.statusCode, 201);
    expect((await _json(copy))['scope'], 'workspace');
  });

  test('an unknown workspaceId answers 404', () async {
    final response = await handler.call(_request('GET', '/?workspaceId=nope'));

    expect(response.statusCode, 404);
  });
}
