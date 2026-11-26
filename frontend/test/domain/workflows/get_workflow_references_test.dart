import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workflows/use_cases/get_workflow_references.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

final class _FakeWorkflowReferenceRepository
    implements WorkflowReferenceRepository {
  final List<({String workflowId, DefinitionScope scope})> calls =
      <({String workflowId, DefinitionScope scope})>[];
  Result<List<WorkflowReference>> nextResult = const Success(
    <WorkflowReference>[],
  );

  @override
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    calls.add((workflowId: workflowId, scope: scope));
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
      scope: WorkspaceScope('ws-1'),
      nodeIds: <String>['n1'],
    );
    repo.nextResult = const Success(<WorkflowReference>[ref]);

    final useCase = GetWorkflowReferences(repo);
    final success = await useCase(
      'wf-child',
      scope: const WorkspaceScope('ws-1'),
    );

    expect(repo.calls, <({String workflowId, DefinitionScope scope})>[
      (workflowId: 'wf-child', scope: const WorkspaceScope('ws-1')),
    ]);
    expect(success, isA<Success<List<WorkflowReference>>>());
    expect(success.valueOrNull, <WorkflowReference>[ref]);

    const failure = FailureResult<List<WorkflowReference>>(
      BackendFailure('boom'),
    );
    repo.nextResult = failure;
    final failed = await useCase('wf-global');

    expect(repo.calls.last, (
      workflowId: 'wf-global',
      scope: const GlobalScope(),
    ));
    expect(failed, failure);
  });
}
