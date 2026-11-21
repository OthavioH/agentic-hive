import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_slug.dart';
import 'package:agentic_hive_frontend/domain/agents/create_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/delete_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/get_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/list_agents_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/update_agent_use_case.dart';
import 'package:agentic_hive_frontend/domain/agents/watch_agent_changes_use_case.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeAgentRepository implements AgentRepository {
  final StreamController<AgentsChangedPayload> changes =
      StreamController<AgentsChangedPayload>.broadcast();

  AgentDetail sampleDetail = AgentDetail(
    id: 'reviewer',
    name: 'Reviewer',
    description: 'Reviews diffs',
    tags: const <String>['qa'],
    contentHash: 'hash-1',
    updatedAt: DateTime.utc(2026, 11, 20),
    prompt: '# Reviewer',
  );

  @override
  Future<Result<List<AgentSummary>>> listAgents() async =>
      Success(<AgentSummary>[
        AgentSummary(
          id: sampleDetail.id,
          name: sampleDetail.name,
          description: sampleDetail.description,
          tags: sampleDetail.tags,
          contentHash: sampleDetail.contentHash,
          updatedAt: sampleDetail.updatedAt,
        ),
      ]);

  @override
  Future<Result<AgentDetail>> getAgent(String id) async =>
      Success(sampleDetail);

  @override
  Future<Result<AgentDetail>> createAgent(CreateAgentRequest request) async =>
      Success(sampleDetail.copyWith(id: request.id, name: request.name));

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request,
  ) async => Success(sampleDetail.copyWith(name: request.name));

  @override
  Future<Result<void>> deleteAgent(String id) async => const Success(null);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => changes.stream;
}

void main() {
  group('AgentSlug', () {
    test(
      'suggests lowercase hyphenated slugs and avoids reserved OS names',
      () {
        expect(AgentSlug.suggest('Code Reviewer'), 'code-reviewer');
        expect(AgentSlug.suggest('  PR_Helper!! 2  '), 'pr_helper-2');
        expect(AgentSlug.suggest('CON'), 'con-agent');
        expect(AgentSlug.suggest('...'), '');
      },
    );

    test('validates cross-platform safe lowercase slugs', () {
      expect(AgentSlug.isValid('code-reviewer'), isTrue);
      expect(AgentSlug.isValid('agent_1'), isTrue);
      expect(AgentSlug.isValid('a' * 128), isTrue);
      expect(AgentSlug.isValid('a' * 129), isFalse);
      expect(AgentSlug.isValid(''), isFalse);
      expect(AgentSlug.isValid('CodeReviewer'), isFalse);
      expect(AgentSlug.isValid('../escape'), isFalse);
      expect(AgentSlug.isValid('nul'), isFalse);
      expect(AgentSlug.isValid('com1'), isFalse);
    });
  });

  group('Agent use cases', () {
    test('delegate to AgentRepository and return Results', () async {
      final repo = _FakeAgentRepository();
      addTearDown(repo.changes.close);

      final listResult = await ListAgentsUseCase(repo)();
      expect(listResult.valueOrNull, hasLength(1));

      final getResult = await GetAgentUseCase(repo)('reviewer');
      expect(getResult.valueOrNull?.id, 'reviewer');

      final createResult = await CreateAgentUseCase(repo)(
        const CreateAgentRequest(id: 'writer', name: 'Writer'),
      );
      expect(createResult.valueOrNull?.id, 'writer');

      final updateResult = await UpdateAgentUseCase(repo)(
        id: 'reviewer',
        request: const UpdateAgentRequest(
          name: 'Senior Reviewer',
          expectedHash: 'hash-1',
        ),
      );
      expect(updateResult.valueOrNull?.name, 'Senior Reviewer');

      final deleteResult = await DeleteAgentUseCase(repo)('reviewer');
      expect(deleteResult.isSuccess, isTrue);

      final events = <AgentsChangedPayload>[];
      final sub = WatchAgentChangesUseCase(repo)().listen(events.add);
      repo.changes.add(
        const AgentsChangedPayload(
          kind: AgentChangeKind.deleted,
          id: 'reviewer',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(events, hasLength(1));
      expect(events.single.kind, AgentChangeKind.deleted);
      await sub.cancel();
    });
  });
}
