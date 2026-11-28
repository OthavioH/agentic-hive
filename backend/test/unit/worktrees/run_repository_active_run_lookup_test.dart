import 'package:agentic_hive_backend/src/data/worktrees/run_repository_active_run_lookup.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

import '../engine/support/in_memory_repositories.dart';

void main() {
  final sampleWorkflow = Workflow(
    id: 'wf-1',
    name: 'Flow',
    nodes: const [
      WorkflowNode(
        id: 'n1',
        type: 'harness',
        label: 'Step',
        position: WorkflowPosition(x: 0, y: 0),
      ),
    ],
    edges: const [],
    entryNodeId: 'n1',
    createdAt: DateTime.utc(2026, 11, 20, 9),
    updatedAt: DateTime.utc(2026, 11, 20, 9),
  );

  Run makeRun({
    required String id,
    required RunStatus status,
    required String workspaceId,
    String? worktreePath,
  }) => Run(
    id: id,
    workflowId: 'wf-1',
    workflowName: sampleWorkflow.name,
    workflowDefinition: sampleWorkflow,
    workspaceId: workspaceId,
    workspaceRoot: '/tmp/ws',
    worktreePath: worktreePath,
    status: status,
    startedAt: DateTime.utc(2026, 11, 20, 10),
  );

  test(
    'activeTargetFolders includes preparing run worktreePath for workspace',
    () async {
      final runs = InMemoryRunRepository();
      await runs.create(
        makeRun(
          id: 'r-prep-wt',
          status: RunStatus.preparing,
          workspaceId: 'ws-1',
          worktreePath: '/data/worktrees/ws-1/feat',
        ),
      );
      await runs.create(
        makeRun(
          id: 'r-other-ws',
          status: RunStatus.preparing,
          workspaceId: 'ws-2',
          worktreePath: '/data/worktrees/ws-2/other',
        ),
      );
      await runs.create(
        makeRun(
          id: 'r-done',
          status: RunStatus.succeeded,
          workspaceId: 'ws-1',
          worktreePath: '/data/worktrees/ws-1/done',
        ),
      );

      final lookup = RunRepositoryActiveRunLookup(runs);
      final result = await lookup.activeTargetFolders('ws-1');

      expect(result.valueOrNull, {'/data/worktrees/ws-1/feat'});
    },
  );
}
