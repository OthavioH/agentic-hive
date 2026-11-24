import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/get_workflow_references.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowReferenceRepository
    implements WorkflowReferenceRepository {
  final List<({String workflowId, String? workspaceId})> calls =
      <({String workflowId, String? workspaceId})>[];
  Result<List<WorkflowReference>> nextResult = const Success(
    <WorkflowReference>[],
  );

  @override
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    String? workspaceId,
  }) async {
    calls.add((workflowId: workflowId, workspaceId: workspaceId));
    return nextResult;
  }
}

void main() {
  test('GetWorkflowReferences forwards id and workspace to the repository and '
      'returns its result', () async {
    final repo = _FakeWorkflowReferenceRepository();
    const ref = WorkflowReference(
      workflowId: 'parent-1',
      workflowName: 'Parent Flow',
      scope: WorkflowScope.workspace,
      workspaceId: 'ws-1',
      nodeIds: <String>['n1'],
    );
    repo.nextResult = const Success(<WorkflowReference>[ref]);

    final useCase = GetWorkflowReferences(repo);
    final success = await useCase('wf-child', workspaceId: 'ws-1');

    expect(repo.calls, <({String workflowId, String? workspaceId})>[
      (workflowId: 'wf-child', workspaceId: 'ws-1'),
    ]);
    expect(success, isA<Success<List<WorkflowReference>>>());
    expect(success.valueOrNull, <WorkflowReference>[ref]);

    const failure = FailureResult<List<WorkflowReference>>(
      BackendFailure('boom'),
    );
    repo.nextResult = failure;
    final failed = await useCase('wf-global');

    expect(repo.calls.last, (workflowId: 'wf-global', workspaceId: null));
    expect(failed, failure);
  });
}
