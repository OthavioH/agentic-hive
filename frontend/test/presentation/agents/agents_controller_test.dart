import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_controller.dart';
import 'package:agentic_hive_frontend/presentation/agents/controllers/agents_state.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _InMemoryAgentRepository implements AgentRepository {
  new({List<AgentDetail>? initial}) {
    for (final item in initial ?? const <AgentDetail>[]) {
      _store[item.id] = item;
    }
  }

  final Map<String, AgentDetail> _store = <String, AgentDetail>{};
  final StreamController<AgentsChangedPayload> _changes =
      StreamController<AgentsChangedPayload>.broadcast();
  bool simulateConflictOnNextPut = false;
  String? diskOverrideHash;

  void emitChange(AgentsChangedPayload payload) => _changes.add(payload);

  void putOnDisk(AgentDetail detail) {
    _store[detail.id] = detail;
    diskOverrideHash = detail.contentHash;
  }

  void clearStore() => _store.clear();

  @override
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) async => Success(
    _store.values
        .map(
          (d) => AgentSummary(
            id: d.id,
            name: d.name,
            description: d.description,
            tags: d.tags,
            contentHash: d.contentHash,
            updatedAt: d.updatedAt,
            parseError: d.parseError,
          ),
        )
        .toList(),
  );

  @override
  Future<Result<AgentDetail>> getAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final found = _store[id];
    if (found == null) {
      return const FailureResult(NotFoundFailure('Agent not found'));
    }
    return Success(found);
  }

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final created = AgentDetail(
      id: request.id,
      name: request.name,
      description: request.description,
      tags: request.tags,
      requiredSkills: request.requiredSkills,
      requiredTools: request.requiredTools,
      allowedTools: request.allowedTools,
      deniedTools: request.deniedTools,
      prompt: request.prompt,
      contentHash: 'hash-${request.id}-1',
      updatedAt: DateTime.utc(2026, 11, 20),
    );
    _store[created.id] = created;
    return Success(created);
  }

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    final existing = _store[id];
    if (existing == null) {
      return const FailureResult(NotFoundFailure('Agent not found'));
    }
    if (simulateConflictOnNextPut ||
        (diskOverrideHash != null &&
            request.expectedHash != diskOverrideHash)) {
      simulateConflictOnNextPut = false;
      return const FailureResult(
        BackendFailure(
          'File modified on disk',
          code: ApiErrorCode.conflict,
          statusCode: 409,
        ),
      );
    }
    final updated = existing.copyWith(
      name: request.name,
      description: request.description,
      tags: request.tags,
      requiredSkills: request.requiredSkills,
      requiredTools: request.requiredTools,
      allowedTools: request.allowedTools,
      deniedTools: request.deniedTools,
      prompt: request.prompt,
      contentHash: '${existing.contentHash}-next',
    );
    _store[id] = updated;
    diskOverrideHash = null;
    return Success(updated);
  }

  @override
  Future<Result<void>> deleteAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    _store.remove(id);
    return const Success(null);
  }

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => _changes.stream;

  Future<void> dispose() => _changes.close();
}

void main() {
  final sampleReviewer = AgentDetail(
    id: 'reviewer',
    name: 'Code Reviewer',
    description: 'Reviews pull requests',
    tags: const <String>['qa', 'git'],
    contentHash: 'hash-1',
    updatedAt: DateTime.utc(2026, 11, 20),
    prompt: 'Review carefully.',
  );

  final sampleWriter = AgentDetail(
    id: 'writer',
    name: 'Doc Writer',
    description: 'Writes technical docs',
    tags: const <String>['docs'],
    contentHash: 'hash-2',
    updatedAt: DateTime.utc(2026, 11, 20),
    prompt: 'Write clearly.',
  );

  group('AgentsController', () {
    test('loads, searches, and filters agents by tag', () async {
      final repo = _InMemoryAgentRepository(
        initial: <AgentDetail>[sampleReviewer, sampleWriter],
      );
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      )..listen(agentsControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final state = container.read(agentsControllerProvider);
      expect(state.agents.value, hasLength(2));
      expect(state.availableTags, <String>['docs', 'git', 'qa']);

      final notifier = container.read(agentsControllerProvider.notifier)
        ..setSearchQuery('pull');
      expect(
        container
            .read(agentsControllerProvider)
            .filteredAgents
            .map((a) => a.id),
        <String>['reviewer'],
      );

      notifier
        ..clearFilters()
        ..toggleTagFilter('docs');
      expect(
        container
            .read(agentsControllerProvider)
            .filteredAgents
            .map((a) => a.id),
        <String>['writer'],
      );
    });

    test(
      'inline creation auto-slugs name until manually edited and saves',
      () async {
        final repo = _InMemoryAgentRepository();
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [agentRepositoryProvider.overrideWithValue(repo)],
        )..listen(agentsControllerProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(agentsControllerProvider.notifier)
          ..startCreate()
          ..updateName('Security Auditor');

        expect(
          container.read(agentsControllerProvider).draft?.id,
          'security-auditor',
        );

        notifier
          ..updateSlug('sec-audit')
          ..updateName('Security Auditor Pro');
        expect(container.read(agentsControllerProvider).draft?.id, 'sec-audit');

        notifier.insertTemplate('## Responsibilities');
        final outcome = await notifier.save();
        expect(outcome, isA<SaveAgentSuccess>());
        expect((outcome as SaveAgentSuccess).created, isTrue);

        final updatedState = container.read(agentsControllerProvider);
        expect(updatedState.isCreating, isFalse);
        expect(updatedState.selectedAgentId, 'sec-audit');
        expect(updatedState.agents.value?.map((a) => a.id), <String>[
          'sec-audit',
        ]);
      },
    );

    test(
      'handles 409 conflict with forceOverwrite and reloadSelected',
      () async {
        final repo = _InMemoryAgentRepository(
          initial: <AgentDetail>[sampleReviewer],
        );
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [agentRepositoryProvider.overrideWithValue(repo)],
        )..listen(agentsControllerProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(agentsControllerProvider.notifier);
        await notifier.selectAgent('reviewer');

        notifier.updateDescription('Updated locally');
        expect(container.read(agentsControllerProvider).isDirty, isTrue);

        // Simulate external edit on disk.
        repo.putOnDisk(
          sampleReviewer.copyWith(
            contentHash: 'hash-disk-2',
            description: 'Updated on disk',
          ),
        );

        final conflictOutcome = await notifier.save();
        expect(conflictOutcome, isA<SaveAgentConflict>());

        final overwriteOutcome = await notifier.forceOverwrite();
        expect(overwriteOutcome, isA<SaveAgentSuccess>());
        expect(
          container.read(agentsControllerProvider).draft?.description,
          'Updated locally',
        );
      },
    );

    test('reacts to live WS agents.changed events for open clean/dirty/deleted agents', () async {
      final repo = _InMemoryAgentRepository(
        initial: <AgentDetail>[sampleReviewer],
      );
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      )..listen(agentsControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      final notifier = container.read(agentsControllerProvider.notifier);
      await notifier.selectAgent('reviewer');

      // Clean open agent auto-reloads on external update.
      repo
        ..putOnDisk(
          sampleReviewer.copyWith(
            contentHash: 'hash-ext-1',
            description: 'External edit',
          ),
        )
        ..emitChange(
          AgentsChangedPayload(
            kind: AgentChangeKind.updated,
            id: 'reviewer',
            agent: AgentSummary(
              id: 'reviewer',
              name: 'Code Reviewer',
              description: 'External edit',
              contentHash: 'hash-ext-1',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ),
        );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(agentsControllerProvider).draft?.description,
        'External edit',
      );
      expect(
        container.read(agentsControllerProvider).externalNotice,
        ExternalChangeNotice.none,
      );

      // Dirty open agent flags modifiedExternally instead of clobbering edits.
      notifier.updateDescription('Local unsaved edit');
      repo
        ..putOnDisk(
          sampleReviewer.copyWith(
            contentHash: 'hash-ext-2',
            description: 'Another external edit',
          ),
        )
        ..emitChange(
          AgentsChangedPayload(
            kind: AgentChangeKind.updated,
            id: 'reviewer',
            agent: AgentSummary(
              id: 'reviewer',
              name: 'Code Reviewer',
              description: 'Another external edit',
              contentHash: 'hash-ext-2',
              updatedAt: DateTime.utc(2026, 11, 20),
            ),
          ),
        );
      await Future<void>.delayed(Duration.zero);
      expect(
        container.read(agentsControllerProvider).externalNotice,
        ExternalChangeNotice.modifiedExternally,
      );

      // External deletion flags deletedExternally and removes from list.
      repo.emitChange(
        const AgentsChangedPayload(
          kind: AgentChangeKind.deleted,
          id: 'reviewer',
        ),
      );
      await Future<void>.delayed(Duration.zero);
      expect(container.read(agentsControllerProvider).agents.value, isEmpty);
      expect(
        container.read(agentsControllerProvider).externalNotice,
        ExternalChangeNotice.deletedExternally,
      );
    });

    test(
      'reports typed AgentSaveError for missing name and invalid slug',
      () async {
        final repo = _InMemoryAgentRepository();
        addTearDown(repo.dispose);

        final container = ProviderContainer.test(
          overrides: [agentRepositoryProvider.overrideWithValue(repo)],
        )..listen(agentsControllerProvider, (_, _) {});
        await Future<void>.delayed(Duration.zero);

        final notifier = container.read(agentsControllerProvider.notifier)
          ..startCreate();

        final emptyNameOutcome = await notifier.save();
        expect(emptyNameOutcome, isA<SaveAgentFailure>());
        expect(
          (emptyNameOutcome as SaveAgentFailure).error,
          isA<AgentSaveNameRequiredError>(),
        );
        expect(
          container.read(agentsControllerProvider).saveError,
          isA<AgentSaveNameRequiredError>(),
        );

        notifier
          ..updateName('Valid Name')
          ..updateSlug('Invalid Slug!');
        final badSlugOutcome = await notifier.save();
        expect(badSlugOutcome, isA<SaveAgentFailure>());
        expect(
          (badSlugOutcome as SaveAgentFailure).error,
          isA<AgentSaveSlugInvalidError>(),
        );
        expect(
          container.read(agentsControllerProvider).saveError,
          isA<AgentSaveSlugInvalidError>(),
        );
      },
    );

    test('reloads agents list when folder switch emits agents.changed without '
        'summary', () async {
      final repo = _InMemoryAgentRepository()..putOnDisk(sampleReviewer);
      addTearDown(repo.dispose);

      final container = ProviderContainer.test(
        overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      )..listen(agentsControllerProvider, (_, _) {});
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(agentsControllerProvider).agents.value?.map((a) => a.id),
        <String>['reviewer'],
      );

      // Simulate backend switching to a new agents directory.
      final switchedAgent = sampleReviewer.copyWith(
        id: 'architect',
        name: 'Architect',
      );
      repo
        ..clearStore()
        ..putOnDisk(switchedAgent)
        ..emitChange(
          const AgentsChangedPayload(kind: AgentChangeKind.updated, id: '*'),
        );
      await Future<void>.delayed(Duration.zero);

      expect(
        container.read(agentsControllerProvider).agents.value?.map((a) => a.id),
        <String>['architect'],
      );
    });
  });
}
