import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Live feed of workspace workflow files that changed on disk.
abstract interface class WorkflowChangesSource {
  /// Emits a [WorkflowsChangedPayload] each time the backend reports that a
  /// workspace workflow file was created, edited or deleted.
  Stream<WorkflowsChangedPayload> get changes;
}
