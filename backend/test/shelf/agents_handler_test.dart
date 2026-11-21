import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/api/agents/agents_handler.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_service.dart';
import 'package:agentic_hive_backend/src/http/api_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/shutdown_handler.dart';
import 'package:agentic_hive_backend/src/http/handlers/status_handler.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:shelf/shelf.dart';
import 'package:test/test.dart';

import 'support.dart';

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
  late Directory tempDir;
  late Handler handler;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_handler_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    final repository = LocalAgentRepository(agentsDir: tempDir.path);
    final service = AgentService(repository);
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

  group('/api/v1/agents', () {
    test('CRUD lifecycle: create, list, get, update, delete', () async {
      final emptyList = await handler(buildRequest('/api/v1/agents'));
      expect(emptyList.statusCode, 200);
      expect(await readJson(emptyList), {'agents': <Object?>[]});

      final createRes = await handler(
        _jsonRequest(
          '/api/v1/agents',
          method: 'POST',
          body: const CreateAgentRequest(
            id: 'reviewer',
            name: 'Code Reviewer',
            description: 'Reviews PRs.',
            tags: ['review'],
            requiredSkills: ['dart-validation'],
            prompt: 'Be thorough.',
          ).toJson(),
        ),
      );
      expect(createRes.statusCode, 201);
      final created = AgentDetail.fromJson(await readJson(createRes));
      expect(created.id, 'reviewer');
      expect(created.name, 'Code Reviewer');

      final listRes = await handler(buildRequest('/api/v1/agents'));
      expect(listRes.statusCode, 200);
      final list = AgentListResponse.fromJson(await readJson(listRes));
      expect(list.agents, hasLength(1));
      expect(list.agents.single.id, 'reviewer');

      final getRes = await handler(buildRequest('/api/v1/agents/reviewer'));
      expect(getRes.statusCode, 200);
      final fetched = AgentDetail.fromJson(await readJson(getRes));
      expect(fetched.contentHash, created.contentHash);

      final updateRes = await handler(
        _jsonRequest(
          '/api/v1/agents/reviewer',
          method: 'PUT',
          body: UpdateAgentRequest(
            name: 'Strict Reviewer',
            description: 'Very strict.',
            tags: const ['review', 'strict'],
            prompt: 'Be very thorough.',
            expectedHash: created.contentHash,
          ).toJson(),
        ),
      );
      expect(updateRes.statusCode, 200);
      final updated = AgentDetail.fromJson(await readJson(updateRes));
      expect(updated.name, 'Strict Reviewer');
      expect(updated.contentHash, isNot(created.contentHash));

      final deleteRes = await handler(
        buildRequest('/api/v1/agents/reviewer', method: 'DELETE'),
      );
      expect(deleteRes.statusCode, 200);
      expect(await readJson(deleteRes), {'id': 'reviewer', 'deleted': true});

      final missingRes = await handler(buildRequest('/api/v1/agents/reviewer'));
      expect(missingRes.statusCode, 404);
    });

    test(
      'POST returns 409 on duplicate slug and 400 on invalid input',
      () async {
        await handler(
          _jsonRequest(
            '/api/v1/agents',
            method: 'POST',
            body: const CreateAgentRequest(id: 'dup', name: 'Dup').toJson(),
          ),
        );

        final dupRes = await handler(
          _jsonRequest(
            '/api/v1/agents',
            method: 'POST',
            body: const CreateAgentRequest(id: 'dup', name: 'Dup 2').toJson(),
          ),
        );
        expect(dupRes.statusCode, 409);
        expect(
          ((await readJson(dupRes))['error']! as JsonMap)['code'],
          ApiErrorCode.conflict,
        );

        final badSlugRes = await handler(
          _jsonRequest(
            '/api/v1/agents',
            method: 'POST',
            body: const CreateAgentRequest(
              id: 'Bad Slug',
              name: 'Bad',
            ).toJson(),
          ),
        );
        expect(badSlugRes.statusCode, 400);

        final badJsonRes = await handler(
          _jsonRequest('/api/v1/agents', method: 'POST', body: '{not json'),
        );
        expect(badJsonRes.statusCode, 400);
      },
    );

    test('PUT returns 409 on stale expectedHash', () async {
      await handler(
        _jsonRequest(
          '/api/v1/agents',
          method: 'POST',
          body: const CreateAgentRequest(
            id: 'conflict-agent',
            name: 'Initial',
          ).toJson(),
        ),
      );

      final conflictRes = await handler(
        _jsonRequest(
          '/api/v1/agents/conflict-agent',
          method: 'PUT',
          body: const UpdateAgentRequest(
            name: 'Overwrite',
            expectedHash: 'stale-hash',
          ).toJson(),
        ),
      );
      expect(conflictRes.statusCode, 409);
      expect(
        ((await readJson(conflictRes))['error']! as JsonMap)['code'],
        ApiErrorCode.conflict,
      );
    });

    test('GET surfaces parseError and rawContent for malformed file', () async {
      const raw = '---\nname: [broken\n---\nBody';
      await File(p.join(tempDir.path, 'broken.md')).writeAsString(raw);

      final getRes = await handler(buildRequest('/api/v1/agents/broken'));
      expect(getRes.statusCode, 200);
      final detail = AgentDetail.fromJson(await readJson(getRes));
      expect(detail.parseError, isNotNull);
      expect(detail.rawContent, raw);

      final updateRes = await handler(
        _jsonRequest(
          '/api/v1/agents/broken',
          method: 'PUT',
          body: UpdateAgentRequest(
            name: 'Fix',
            expectedHash: detail.contentHash,
          ).toJson(),
        ),
      );
      expect(updateRes.statusCode, 400);
    });

    test('GET and DELETE succeed for non-slug .md filename while PUT and path '
        'traversal return 400', () async {
      const raw = '---\nname: [broken\n---\nBody';
      await File(p.join(tempDir.path, 'My Agent.md')).writeAsString(raw);

      final listRes = await handler(buildRequest('/api/v1/agents'));
      expect(listRes.statusCode, 200);
      final list = AgentListResponse.fromJson(await readJson(listRes));
      expect(list.agents.map((a) => a.id), contains('My Agent'));

      final getRes = await handler(buildRequest('/api/v1/agents/My%20Agent'));
      expect(getRes.statusCode, 200);
      final detail = AgentDetail.fromJson(await readJson(getRes));
      expect(detail.id, 'My Agent');
      expect(detail.parseError, isNotNull);

      // Updating a non-slug filename remains forbidden by validateAgentSlug.
      final putRes = await handler(
        _jsonRequest(
          '/api/v1/agents/My%20Agent',
          method: 'PUT',
          body: UpdateAgentRequest(
            name: 'Renamed',
            expectedHash: detail.contentHash,
          ).toJson(),
        ),
      );
      expect(putRes.statusCode, 400);

      // Path traversal or leading-dot filenames are rejected with 400.
      for (final badId in ['.hidden', '..%2Fsecret', 'sub%5Cagent']) {
        final badGet = await handler(buildRequest('/api/v1/agents/$badId'));
        expect(badGet.statusCode, 400);
        final badDel = await handler(
          buildRequest('/api/v1/agents/$badId', method: 'DELETE'),
        );
        expect(badDel.statusCode, 400);
      }

      // Deleting the non-slug file succeeds.
      final deleteRes = await handler(
        buildRequest('/api/v1/agents/My%20Agent', method: 'DELETE'),
      );
      expect(deleteRes.statusCode, 200);
      expect(await readJson(deleteRes), {'id': 'My Agent', 'deleted': true});
      expect(File(p.join(tempDir.path, 'My Agent.md')).existsSync(), isFalse);
    });

    test('rejects Origin header with 403', () async {
      final res = await handler(
        buildRequest(
          '/api/v1/agents',
          headers: {'origin': 'https://evil.example'},
        ),
      );
      expect(res.statusCode, 403);
    });
  });
}
