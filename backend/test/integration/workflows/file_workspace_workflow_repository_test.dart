import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workflows/file_workspace_workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;
import 'package:test/test.dart';

void main() {
  late Directory root;
  late FileWorkspaceWorkflowRepository repository;

  setUp(() {
    root = Directory.systemTemp.createTempSync('hive_ws_workflows_');
    repository = FileWorkspaceWorkflowRepository();
  });

  tearDown(() {
    if (root.existsSync()) root.deleteSync(recursive: true);
  });

  Workflow sample(String id, {String name = 'Deploy'}) => Workflow(
    id: id,
    name: name,
    description: 'desc',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'command',
        label: 'Start',
        position: WorkflowPosition(x: 1, y: 2),
        config: {'command': 'echo hi'},
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 23, 9),
    updatedAt: DateTime.utc(2026, 11, 23, 10),
  );

  String fileFor(String id) =>
      p.join(root.path, '.agentic-hive', 'workflows', '$id.json');

  test('create writes <root>/.agentic-hive/workflows/<id>.json', () async {
    final result = await repository.create(root.path, sample('deploy'));

    expect(result, isA<Success<Workflow>>());
    final file = File(fileFor('deploy'));
    expect(file.existsSync(), isTrue);
    final decoded = jsonDecode(file.readAsStringSync()) as Map<String, Object?>;
    expect(decoded['name'], 'Deploy');
  });

  test('create refuses an id that already has a file', () async {
    await repository.create(root.path, sample('deploy'));
    final again = await repository.create(root.path, sample('deploy'));

    expect(again.failureOrNull, isA<ConflictFailure>());
  });

  test('getById round-trips the workflow', () async {
    final workflow = sample('deploy');
    await repository.create(root.path, workflow);

    final loaded = (await repository.getById(root.path, 'deploy')).valueOrNull;

    expect(loaded, workflow);
  });

  test('getById on a missing file is NotFound', () async {
    final result = await repository.getById(root.path, 'nope');

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('ids that try to leave the folder are rejected', () async {
    final result = await repository.getById(root.path, '../secret');

    expect(result.failureOrNull, isA<ValidationFailure>());
  });

  test('listAll is empty when the folder does not exist', () async {
    final result = await repository.listAll(root.path);

    expect(result.valueOrNull, isEmpty);
  });

  test('listAll reads files, newest first, and skips invalid ones', () async {
    await repository.create(root.path, sample('a', name: 'A'));
    await repository.create(
      root.path,
      sample('b', name: 'B').copyWith(updatedAt: DateTime.utc(2026, 11, 24)),
    );
    File(fileFor('broken')).writeAsStringSync('{not json');
    File(p.join(root.path, '.agentic-hive', 'workflows', 'notes.txt'))
        .writeAsStringSync('ignored');

    final list = (await repository.listAll(root.path)).valueOrNull!;

    expect(list.map((w) => w.id), ['b', 'a']);
  });

  test(
    'getById is NotFound, not a persistence failure, when the file is deleted '
    'between the lookup and the read (background deletion, ADR 0027)',
    () async {
      await repository.create(root.path, sample('deploy'));
      final racing = FileWorkspaceWorkflowRepository(
        beforeRead: (file) async => file.deleteSync(),
      );

      final result = await racing.getById(root.path, 'deploy');

      expect(result.failureOrNull, isA<NotFoundFailure>());
    },
  );

  test(
    'listAll skips a file deleted after it was listed instead of failing',
    () async {
      await repository.create(root.path, sample('a', name: 'A'));
      await repository.create(root.path, sample('b', name: 'B'));
      final racing = FileWorkspaceWorkflowRepository(
        beforeRead: (file) async {
          if (file.path.endsWith('a.json')) file.deleteSync();
        },
      );

      final result = await racing.listAll(root.path);

      expect(result.failureOrNull, isNull);
      expect(result.valueOrNull!.map((w) => w.id), ['b']);
    },
  );

  test(
    'a file edited externally is picked up with the file basename as id',
    () async {
      await repository.create(root.path, sample('deploy'));
      final json = sample('other-id', name: 'Edited').toJson();
      File(fileFor('deploy')).writeAsStringSync(jsonEncode(json));

      final loaded = (await repository.getById(
        root.path,
        'deploy',
      )).valueOrNull!;

      expect(loaded.id, 'deploy');
      expect(loaded.name, 'Edited');
    },
  );

  test('update rewrites the file, or NotFound when absent', () async {
    await repository.create(root.path, sample('deploy'));

    final updated = await repository.update(
      root.path,
      sample('deploy', name: 'Renamed'),
    );
    expect(updated, isA<Success<Workflow>>());
    expect(
      (await repository.getById(root.path, 'deploy')).valueOrNull!.name,
      'Renamed',
    );

    final missing = await repository.update(root.path, sample('ghost'));
    expect(missing.failureOrNull, isA<NotFoundFailure>());
  });

  test('delete removes the file, or NotFound when absent', () async {
    await repository.create(root.path, sample('deploy'));

    expect(await repository.delete(root.path, 'deploy'), isA<Success<void>>());
    expect(File(fileFor('deploy')).existsSync(), isFalse);
    expect(
      (await repository.delete(root.path, 'deploy')).failureOrNull,
      isA<NotFoundFailure>(),
    );
  });

  test('workflowsDirectory points at the versionable folder', () {
    expect(
      FileWorkspaceWorkflowRepository.workflowsDirectory(root.path),
      p.join(root.path, '.agentic-hive', 'workflows'),
    );
  });
}
