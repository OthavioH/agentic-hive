import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/agents/local_agent_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory tempDir;
  late LocalAgentRepository repository;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('agents_repo_');
    addTearDown(() async {
      if (tempDir.existsSync()) {
        await tempDir.delete(recursive: true);
      }
    });
    repository = LocalAgentRepository(agentsDir: tempDir.path);
  });

  group('LocalAgentRepository', () {
    test('list returns empty when directory does not exist', () async {
      final missingRepo = LocalAgentRepository(
        agentsDir: p.join(tempDir.path, 'missing'),
      );
      final result = await missingRepo.list();
      expect(result.valueOrNull, isEmpty);
    });

    test(
      'list ignores subdirectories and non-md files, includes malformed md',
      () async {
        await Directory(p.join(tempDir.path, 'nested')).create();
        await File(p.join(tempDir.path, 'nested', 'ignored.md'))
            .writeAsString('---\nname: Ignored\n---\n');
        await File(p.join(tempDir.path, 'notes.txt')).writeAsString('hi');
        await File(p.join(tempDir.path, 'broken.md'))
            .writeAsString('no frontmatter');
        await File(p.join(tempDir.path, 'alpha.md'))
            .writeAsString('---\nname: Alpha\n---\nPrompt');

        final result = await repository.list();
        final agents = result.valueOrNull!;
        expect(agents.map((a) => a.id), ['alpha', 'broken']);
        expect(agents[0].parseError, isNull);
        expect(agents[1].parseError, isNotNull);
      },
    );

    test('create, getById, update with expectedHash, and delete', () async {
      final created = await repository.create(
        const CreateAgentRequest(
          id: 'reviewer',
          name: 'Reviewer',
          description: 'Reviews code',
          tags: ['review'],
          prompt: 'Check everything.',
        ),
      );
      expect(created, isA<Success<AgentDetail>>());
      final initial = created.valueOrNull!;

      final duplicate = await repository.create(
        const CreateAgentRequest(id: 'reviewer', name: 'Dup'),
      );
      expect(duplicate.failureOrNull, isA<ConflictFailure>());

      final loaded = await repository.getById('reviewer');
      expect(loaded.valueOrNull?.contentHash, initial.contentHash);

      final staleUpdate = await repository.update(
        'reviewer',
        const UpdateAgentRequest(name: 'Updated', expectedHash: 'wrong-hash'),
      );
      expect(staleUpdate.failureOrNull, isA<ConflictFailure>());

      final updated = await repository.update(
        'reviewer',
        UpdateAgentRequest(
          name: 'Reviewer v2',
          description: 'Updated desc',
          tags: const ['review', 'strict'],
          prompt: 'Updated prompt.',
          expectedHash: initial.contentHash,
        ),
      );
      expect(updated, isA<Success<AgentDetail>>());
      expect(updated.valueOrNull!.name, 'Reviewer v2');
      expect(updated.valueOrNull!.contentHash, isNot(initial.contentHash));

      final deleted = await repository.delete('reviewer');
      expect(deleted, isA<Success<void>>());

      final afterDelete = await repository.getById('reviewer');
      expect(afterDelete.failureOrNull, isA<NotFoundFailure>());
    });

    test('update rejects overwriting an unparseable file', () async {
      final file = File(p.join(tempDir.path, 'broken.md'));
      await file.writeAsString('---\nname: [broken\n---\n');
      final detail = (await repository.getById('broken')).valueOrNull!;

      final result = await repository.update(
        'broken',
        UpdateAgentRequest(name: 'Fixed', expectedHash: detail.contentHash),
      );
      expect(result.failureOrNull, isA<ValidationFailure>());
    });
  });
}
