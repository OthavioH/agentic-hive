import 'package:agentic_hive_frontend/core/di/use_case_providers.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeRunRepository implements RunRepository {
  RunStatus? lastStatus;
  String? lastWorkflowId;
  int? lastLimit;
  int? lastOffset;
  String? lastId;
  int? lastAfterSequence;

  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async {
    lastStatus = status;
    lastWorkflowId = workflowId;
    lastLimit = limit;
    lastOffset = offset;
    return const Success(RunsListResponse(items: <RunSummary>[], total: 0));
  }

  @override
  Future<Result<Run>> getRun(String id) async {
    lastId = id;
    return Success(
      Run(
        id: id,
        workflowName: 'Test',
        workflowDefinition: Workflow(
          id: 'wf-1',
          name: 'Test',
          nodes: const <WorkflowNode>[],
          edges: const <WorkflowEdge>[],
          createdAt: now,
          updatedAt: now,
        ),
        workspacePath: '/tmp',
        status: RunStatus.succeeded,
        startedAt: now,
      ),
    );
  }

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async {
    lastId = id;
    lastAfterSequence = afterSequence;
    lastLimit = limit;
    return const Success(
      RunEventsResponse(items: <RunEvent>[], lastSequence: 0),
    );
  }

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async {
    lastId = id;
    return const Success(<Checkpoint>[]);
  }

  @override
  Future<Result<void>> deleteRun(String id) async {
    lastId = id;
    return const Success(null);
  }
}

void main() {
  group('Run use cases', () {
    test('delegate all operations to RunRepository', () async {
      final repo = _FakeRunRepository();
      final container = ProviderContainer.test(
        overrides: [runRepositoryProvider.overrideWithValue(repo)],
      );

      final listRes = await container
          .read(listRunsProvider)
          .call(
            status: RunStatus.failed,
            workflowId: 'wf-1',
            limit: 10,
            offset: 2,
          );
      expect(listRes.isSuccess, isTrue);
      expect(repo.lastStatus, RunStatus.failed);
      expect(repo.lastWorkflowId, 'wf-1');
      expect(repo.lastLimit, 10);
      expect(repo.lastOffset, 2);

      final getRes = await container.read(getRunProvider).call('run-1');
      expect(getRes.valueOrNull?.id, 'run-1');
      expect(repo.lastId, 'run-1');

      final eventsRes = await container
          .read(getRunEventsProvider)
          .call('run-1', afterSequence: 3, limit: 50);
      expect(eventsRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');
      expect(repo.lastAfterSequence, 3);
      expect(repo.lastLimit, 50);

      final cpRes = await container
          .read(getRunCheckpointsProvider)
          .call('run-1');
      expect(cpRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');

      final delRes = await container.read(deleteRunProvider).call('run-1');
      expect(delRes.isSuccess, isTrue);
      expect(repo.lastId, 'run-1');
    });
  });
}
