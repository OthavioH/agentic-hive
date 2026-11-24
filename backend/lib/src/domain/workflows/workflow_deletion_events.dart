import 'package:agentic_hive_backend/src/domain/workflows/workflow_deletion_operation.dart';

/// Publishes workflow deletion progress and results (ADR 0027).
abstract interface class WorkflowDeletionEvents {
  /// Publishes a status snapshot.
  void progress(WorkflowDeletionOperation operation);

  /// Publishes successful completion.
  void deleted(WorkflowDeletionOperation operation);

  /// Publishes failed completion.
  void failed(WorkflowDeletionOperation operation);
}
