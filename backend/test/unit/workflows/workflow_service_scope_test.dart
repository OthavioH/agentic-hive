import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_revision.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_runs_deleter.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_service.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workflow_validator.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_backend/src/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

final class _GlobalRepository implements WorkflowRepository {
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
  Future<Result<List<Workflow>>> listAll() async => Success(
    store.values.toList()..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<Result<Workflow>> update(Workflow workflow) async {
    store[workflow.id] = workflow;
    return Success(workflow);
  }
}

final class _FileRepository implements WorkspaceWorkflowRepository {
  /// Keyed by `<root>|<id>`.
  final store = <String, Workflow>{};

  String _key(String root, String id) => '$root|$id';

  @override
  Future<Result<Workflow>> create(String rootPath, Workflow workflow) async {
    if (store.containsKey(_key(rootPath, workflow.id))) {
      return const FailureResult(ConflictFailure('exists'));
    }
    store[_key(rootPath, workflow.id)] = workflow;
    return Success(workflow);
  }

  @override
  Future<Result<void>> delete(String rootPath, String id) async =>
      store.remove(_key(rootPath, id)) == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : const Success<void>(null);

  @override
  Future<Result<Workflow>> getById(String rootPath, String id) async =>
      store[_key(rootPath, id)] == null
      ? FailureResult(NotFoundFailure('Workflow "$id" not found.'))
      : Success(store[_key(rootPath, id)]!);

  @override
  Future<Result<List<Workflow>>> listAll(String rootPath) async => Success(
    [
      for (final entry in store.entries)
        if (entry.key.startsWith('$rootPath|')) entry.value,
    ]..sort((a, b) => b.updatedAt.compareTo(a.updatedAt)),
  );

  @override
  Future<Result<Workflow>> update(String rootPath, Workflow workflow) async {
    if (!store.containsKey(_key(rootPath, workflow.id))) {
      return const FailureResult(NotFoundFailure('not found'));
    }
    store[_key(rootPath, workflow.id)] = workflow;
    return Success(workflow);
  }
}

final class _Workspaces implements WorkspaceRepository {
  final known = <String, Workspace>{};

  @override
  Future<Result<Workspace>> getById(String id) async => known[id] == null
      ? FailureResult(NotFoundFailure('Workspace "$id" not found.'))
      : Success(known[id]!);

  @override
  Future<Result<Workspace>> create(Workspace workspace) async =>
      Success(workspace);

  @override
  Future<Result<void>> delete(String id) async => const Success<void>(null);

  @override
  Future<Result<List<Workspace>>> list() async =>
      Success(known.values.toList());

  @override
  Future<Result<Workspace>> rename(
    String id, {
    required String name,
    required DateTime updatedAt,
  }) async => Success(known[id]!);
}

void main() {
  late _GlobalRepository globalRepository;
  late _FileRepository fileRepository;
  late _Workspaces workspaces;
  late DateTime now;
  late int idSeq;
  late WorkflowService service;

  setUp(() {
    globalRepository = _GlobalRepository();
    fileRepository = _FileRepository();
    workspaces = _Workspaces()
      ..known['ws-1'] = Workspace(
        id: 'ws-1',
        name: 'Repo',
        rootPath: '/repo',
        isGit: true,
        createdAt: DateTime.utc(2026),
        updatedAt: DateTime.utc(2026),
      );
    now = DateTime.utc(2026, 11, 23, 12);
    idSeq = 0;
    service = WorkflowService(
      repository: globalRepository,
      validator: const WorkflowValidator(),
      workspaceWorkflows: fileRepository,
      workspaces: workspaces,
      generateId: () => 'wf-${++idSeq}',
      now: () => now,
    );
  });

  test('create with a workspace id writes a slug-named file', () async {
    final response = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Build & Verify', workspaceId: 'ws-1'),
    )).valueOrNull!;

    expect(response.scope, const WorkspaceScope('ws-1'));
    expect(response.workflow.id, 'build-verify');
    expect(fileRepository.store.keys, ['/repo|build-verify']);
    expect(globalRepository.store, isEmpty);
  });

  test(
    'a second workspace workflow with the same name gets a free slug',
    () async {
      const request = CreateWorkflowRequest(
        name: 'Deploy',
        workspaceId: 'ws-1',
      );
      await service.createWorkflow(request);
      final second = (await service.createWorkflow(request)).valueOrNull!;

      expect(second.workflow.id, 'deploy-2');
    },
  );

  test('a name with no letters falls back to a generated slug', () async {
    final response = (await service.createWorkflow(
      const CreateWorkflowRequest(name: '???', workspaceId: 'ws-1'),
    )).valueOrNull!;

    expect(response.workflow.id, 'workflow');
  });

  test('create without a workspace id stays global', () async {
    final response = (await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy'),
    )).valueOrNull!;

    expect(response.scope, const GlobalScope());
    expect(globalRepository.store.keys, ['wf-1']);
  });

  test('create in an unknown workspace is NotFound', () async {
    final result = await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'nope'),
    );

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('same name in both scopes lists both with their scope', () async {
    await service.createWorkflow(const CreateWorkflowRequest(name: 'Deploy'));
    now = now.add(const Duration(minutes: 1));
    await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'ws-1'),
    );

    final list = (await service.listWorkflows(
      scope: const WorkspaceScope('ws-1'),
    )).valueOrNull!.workflows;

    expect(list.map((w) => (w.name, w.scope)), [
      ('Deploy', const WorkspaceScope('ws-1')),
      ('Deploy', const GlobalScope()),
    ]);
  });

  test('listing without a workspace id returns only global ones', () async {
    await service.createWorkflow(const CreateWorkflowRequest(name: 'G'));
    await service.createWorkflow(
      const CreateWorkflowRequest(name: 'W', workspaceId: 'ws-1'),
    );

    final list = (await service.listWorkflows()).valueOrNull!.workflows;

    expect(list.map((w) => w.name), ['G']);
  });

  test('get, update and delete resolve in the requested scope', () async {
    await service.createWorkflow(const CreateWorkflowRequest(name: 'Deploy'));
    await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'ws-1'),
    );

    final fetched = (await service.getWorkflow(
      'deploy',
      scope: const WorkspaceScope('ws-1'),
    )).valueOrNull!;
    expect(fetched.scope, const WorkspaceScope('ws-1'));

    now = now.add(const Duration(hours: 1));
    final updated = (await service.updateWorkflow(
      'deploy',
      const UpdateWorkflowRequest(name: 'Deploy v2'),
      scope: const WorkspaceScope('ws-1'),
    )).valueOrNull!;
    expect(updated.workflow.name, 'Deploy v2');
    expect(updated.workflow.id, 'deploy');
    expect(globalRepository.store['wf-1']!.name, 'Deploy');

    final deletion = (await service.deleteWorkflow(
      'deploy',
      scope: const WorkspaceScope('ws-1'),
    )).valueOrNull!;
    await service.whenDeletionFinished(deletion.operationId);
    expect(fileRepository.store, isEmpty);
    expect(globalRepository.store, hasLength(1));
  });

  test('an unregistered workspace id fails with NotFound', () async {
    final result = await service.getWorkflow(
      'x',
      scope: const WorkspaceScope('nope'),
    );

    expect(result.failureOrNull, isA<NotFoundFailure>());
  });

  test('duplicate stays inside the scope of the source', () async {
    await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'ws-1'),
    );

    final copy = (await service.duplicateWorkflow(
      'deploy',
      scope: const WorkspaceScope('ws-1'),
    )).valueOrNull!;

    expect(copy.scope, const WorkspaceScope('ws-1'));
    expect(copy.workflow.name, 'Deploy (Copy)');
    expect(copy.workflow.id, 'deploy-copy');
    expect(globalRepository.store, isEmpty);
  });

  test(
    'workspace reads carry a revision and a stale update is refused',
    () async {
      final created = (await service.createWorkflow(
        const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'ws-1'),
      )).valueOrNull!;
      final r0 = created.revision!;

      final updated = (await service.updateWorkflow(
        'deploy',
        UpdateWorkflowRequest(name: 'Deploy v2', revision: r0),
        scope: const WorkspaceScope('ws-1'),
      )).valueOrNull!;
      expect(updated.revision, workflowRevision(updated.workflow));

      final stale = await service.updateWorkflow(
        'deploy',
        UpdateWorkflowRequest(name: 'Deploy v3', revision: r0),
        scope: const WorkspaceScope('ws-1'),
      );
      expect(stale.failureOrNull, isA<StaleRevisionFailure>());

      final list = (await service.listWorkflows(
        scope: const WorkspaceScope('ws-1'),
      )).valueOrNull!;
      expect(
        list.workflows.single.revision,
        workflowRevision(updated.workflow),
      );
    },
  );

  test('a stale revision on workspace delete keeps the file', () async {
    await service.createWorkflow(
      const CreateWorkflowRequest(name: 'Deploy', workspaceId: 'ws-1'),
    );

    final result = await service.deleteWorkflow(
      'deploy',
      scope: const WorkspaceScope('ws-1'),
      expectedRevision: '0000000000000000',
    );
    expect(result.failureOrNull, isA<StaleRevisionFailure>());
    expect(fileRepository.store, hasLength(1));
  });

  group('deleteWorkflow cascades to runs', () {
    late _RecordingRunsDeleter deleter;
    late WorkflowService cascadingService;

    setUp(() {
      deleter = _RecordingRunsDeleter();
      cascadingService = WorkflowService(
        repository: globalRepository,
        validator: const WorkflowValidator(),
        workspaceWorkflows: fileRepository,
        workspaces: workspaces,
        runsDeleter: deleter,
        generateId: () => 'g1',
        now: () => now,
      );
    });

    test(
      'global: deletes runs then the workflow and reports deletedRuns',
      () async {
        await cascadingService.createWorkflow(
          const CreateWorkflowRequest(name: 'Global'),
        );
        deleter.result = const Success(WorkflowRunsDeletion(deletedRuns: 3));

        final result = await cascadingService.deleteWorkflow('g1');

        expect(result.valueOrNull, isA<WorkflowDeletionAccepted>());
        await cascadingService.whenDeletionFinished(
          result.valueOrNull!.operationId,
        );
        expect(deleter.calls, [('g1', null, false)]);
        expect(globalRepository.store.containsKey('g1'), isFalse);
      },
    );

    test('workspace: passes workspaceId to the deleter', () async {
      await cascadingService.createWorkflow(
        const CreateWorkflowRequest(name: 'Review', workspaceId: 'ws-1'),
      );
      deleter.result = const Success(WorkflowRunsDeletion(deletedRuns: 2));

      final result = await cascadingService.deleteWorkflow(
        'review',
        scope: const WorkspaceScope('ws-1'),
      );

      expect(result.valueOrNull, isA<WorkflowDeletionAccepted>());
      await cascadingService.whenDeletionFinished(
        result.valueOrNull!.operationId,
      );
      expect(deleter.calls, [('review', 'ws-1', false)]);
      expect(fileRepository.store, isEmpty);
    });

    test('active runs: returns the failure and keeps the workflow', () async {
      await cascadingService.createWorkflow(
        const CreateWorkflowRequest(name: 'Global'),
      );
      deleter.activeRuns = {'r1': RunStatus.running};

      final result = await cascadingService.deleteWorkflow('g1');

      final failure = result.failureOrNull! as WorkflowHasActiveRunsFailure;
      expect(failure.activeRuns, {'r1': RunStatus.running});
      expect(deleter.calls, isEmpty);
      expect(globalRepository.store.containsKey('g1'), isTrue);
    });

    test('missing workflow: 404 and the deleter is not called', () async {
      final result = await cascadingService.deleteWorkflow('missing');

      expect(result.failureOrNull, isA<NotFoundFailure>());
      expect(deleter.calls, isEmpty);
    });

    test('force: passes force and reports orphanedRuns', () async {
      await cascadingService.createWorkflow(
        const CreateWorkflowRequest(name: 'Global'),
      );
      deleter.result = const Success(
        WorkflowRunsDeletion(deletedRuns: 2, orphanedRuns: ['r9']),
      );

      final result = await cascadingService.deleteWorkflow('g1', force: true);

      expect(result.valueOrNull, isA<WorkflowDeletionAccepted>());
      await cascadingService.whenDeletionFinished(
        result.valueOrNull!.operationId,
      );
      expect(deleter.calls, [('g1', null, true)]);
      expect(globalRepository.store.containsKey('g1'), isFalse);
    });

    test(
      'force on a missing workflow: 404 and the deleter is not called',
      () async {
        final result = await cascadingService.deleteWorkflow(
          'missing',
          force: true,
        );

        expect(result.failureOrNull, isA<NotFoundFailure>());
        expect(deleter.calls, isEmpty);
      },
    );

    test(
      'without a deleter: deletes the workflow and reports 0 runs',
      () async {
        await service.createWorkflow(
          const CreateWorkflowRequest(name: 'Global'),
        );

        final result = await service.deleteWorkflow('wf-1');

        expect(result.valueOrNull, isA<WorkflowDeletionAccepted>());
      },
    );
  });
}

final class _RecordingRunsDeleter implements WorkflowRunsDeleter {
  Result<WorkflowRunsDeletion> result = const Success(
    WorkflowRunsDeletion(deletedRuns: 0),
  );
  final List<(String, String?, bool)> calls = <(String, String?, bool)>[];

  /// Active runs reported for the workflow (run id to status).
  Map<String, RunStatus> activeRuns = const {};

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
    return result;
  }
}
