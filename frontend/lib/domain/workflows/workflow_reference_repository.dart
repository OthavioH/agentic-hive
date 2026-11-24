import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Looks up workflows whose fan-out nodes reference another workflow.
abstract interface class WorkflowReferenceRepository {
  /// Returns workflows that reference [workflowId], scoped to [workspaceId]
  /// when provided.
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    String? workspaceId,
  });
}
