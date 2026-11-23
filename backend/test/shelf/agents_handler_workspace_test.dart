import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/layered_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/data/agents/local_workspace_agent_repositories.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

Request _json(String path, {required String method, Object? body}) => Request(
  method,
  Uri.parse('http://localhost$path'),
  headers: {'content-type': 'application/json'},
  body: body == null ? null : jsonEncode(body),
);

void main() {
  late Directory tempDir;
  late Directory globalDir;
  late Directory workspaceRoot;
  late Handler handler;
  var syncCount = 0;

  Directory wsAgents() =>
      Directory(p.join(workspaceRoot.path, '.agents', 'agents'));

  Future<void> writeAgent(Directory dir, String id, String prompt) async {
    await dir.create(recursive: true);
    await File(p.join(dir.path, '$id.md'))
        .writeAsString('---\nname: $id\n---\n$prompt');
  }

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_ws_handler_');
    addTearDown(() => tempDir.delete(recursive: true));
    globalDir = Directory(p.join(tempDir.path, 'global'))..createSync();
    workspaceRoot = Directory(p.join(tempDir.path, 'repo'))..createSync();
    syncCount = 0;
    final service = AgentService(
      LocalAgentRepository(agentsDir: globalDir.path),
      layer: LayeredAgentRepository.new,
      workspaces: LocalWorkspaceAgentRepositories(
        findWorkspace: (id) async => id == 'ws-1'
            ? Success(
                Workspace(
                  id: 'ws-1',
                  name: 'repo',
                  rootPath: workspaceRoot.path,
                  isGit: false,
                  createdAt: DateTime.utc(2026),
                  updatedAt: DateTime.utc(2026),
                ),
              )
            : const FailureResult(NotFoundFailure('Workspace not found.')),
      ),
      onWorkspaceAgentsChanged: () async => syncCount++,
    );
    handler = buildApiHandler(
      statusHandler: StatusHandler(
        databaseHealthCheck: FakeDatabaseHealthCheck(
          const DatabaseStatus(ok: true, schemaVersion: 1),
        ),
        version: '0.1.0',
        dataDir: tempDir.path,
        startedAt: DateTime.utc(2026, 11, 20),
      ),
      shutdownHandler: ShutdownHandler(onShutdown: () async {}),
      webSocketHandler: (_) => Response(418),
      agentsHandler: AgentsHandler(service),
    );
  });

  test('without workspaceId only global agents are listed', () async {
    await writeAgent(globalDir, 'a', 'g');
    await writeAgent(wsAgents(), 'b', 'w');

    final res = await handler(buildRequest('/api/v1/agents'));
    final list = AgentListResponse.fromJson(await readJson(res));

    expect(list.agents.map((s) => s.id), ['a']);
    expect(list.agents.single.scope, AgentScope.global);
  });

  test(
    'workspaceId lists workspace plus global with scope and override',
    () async {
      await writeAgent(globalDir, 'reviewer', 'g');
      await writeAgent(globalDir, 'planner', 'g');
      await writeAgent(wsAgents(), 'reviewer', 'w');

      final res = await handler(
        buildRequest('/api/v1/agents?workspaceId=ws-1'),
      );
      final list = AgentListResponse.fromJson(await readJson(res));

      final summary = [
        for (final s in list.agents) '${s.id}:${s.scope.name}:${s.overridden}',
      ];
      expect(
        summary,
        unorderedEquals([
          'planner:global:false',
          'reviewer:workspace:false',
          'reviewer:global:true',
        ]),
      );
      expect(syncCount, greaterThan(0));
    },
  );

  test('GET with workspaceId resolves workspace first, then global', () async {
    await writeAgent(globalDir, 'reviewer', 'global prompt');
    await writeAgent(globalDir, 'planner', 'plan');
    await writeAgent(wsAgents(), 'reviewer', 'workspace prompt');

    final overridden = AgentDetail.fromJson(
      await readJson(
        await handler(buildRequest('/api/v1/agents/reviewer?workspaceId=ws-1')),
      ),
    );
    expect(overridden.prompt, 'workspace prompt');
    expect(overridden.scope, AgentScope.workspace);

    final fallback = AgentDetail.fromJson(
      await readJson(
        await handler(buildRequest('/api/v1/agents/planner?workspaceId=ws-1')),
      ),
    );
    expect(fallback.scope, AgentScope.global);

    final globalOnly = AgentDetail.fromJson(
      await readJson(await handler(buildRequest('/api/v1/agents/reviewer'))),
    );
    expect(globalOnly.prompt, 'global prompt');
  });

  test('POST with workspaceId writes under <root>/.agents/agents', () async {
    final res = await handler(
      _json(
        '/api/v1/agents?workspaceId=ws-1',
        method: 'POST',
        body: const CreateAgentRequest(id: 'ws-only', name: 'Ws').toJson(),
      ),
    );

    expect(res.statusCode, 201);
    expect(
      AgentDetail.fromJson(await readJson(res)).scope,
      AgentScope.workspace,
    );
    expect(File(p.join(wsAgents().path, 'ws-only.md')).existsSync(), isTrue);
    expect(File(p.join(globalDir.path, 'ws-only.md')).existsSync(), isFalse);
    expect(syncCount, greaterThan(0));
  });

  test(
    'PUT and DELETE with workspaceId only touch the workspace file',
    () async {
      await writeAgent(globalDir, 'reviewer', 'global');
      await writeAgent(wsAgents(), 'reviewer', 'workspace');
      final detail = AgentDetail.fromJson(
        await readJson(
          await handler(
            buildRequest('/api/v1/agents/reviewer?workspaceId=ws-1'),
          ),
        ),
      );

      final put = await handler(
        _json(
          '/api/v1/agents/reviewer?workspaceId=ws-1',
          method: 'PUT',
          body: UpdateAgentRequest(
            name: 'Edited',
            prompt: 'edited',
            expectedHash: detail.contentHash,
          ).toJson(),
        ),
      );
      expect(put.statusCode, 200);
      expect(
        File(p.join(globalDir.path, 'reviewer.md')).readAsStringSync(),
        contains('global'),
      );

      final del = await handler(
        buildRequest(
          '/api/v1/agents/reviewer?workspaceId=ws-1',
          method: 'DELETE',
        ),
      );
      expect(del.statusCode, 200);
      expect(
        File(p.join(wsAgents().path, 'reviewer.md')).existsSync(),
        isFalse,
      );
      expect(File(p.join(globalDir.path, 'reviewer.md')).existsSync(), isTrue);
    },
  );

  test('unknown workspaceId is 404', () async {
    final res = await handler(buildRequest('/api/v1/agents?workspaceId=nope'));
    expect(res.statusCode, 404);
  });
}
