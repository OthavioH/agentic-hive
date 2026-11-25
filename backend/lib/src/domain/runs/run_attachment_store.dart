import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';

/// Persistence port for decoded Run attachment files on disk (ADR 0030).
abstract interface class RunAttachmentStore {
  /// Returns `<runsDir>/<runId>/attachments`.
  String attachmentsDir(String runId);

  /// Writes files as `1.<ext>`, `2.<ext>`, ...
  ///
  /// On failure, deletes what it wrote and returns a [FailureResult].
  Future<Result<void>> write(String runId, List<DecodedRunAttachment> files);

  /// Deletes a run's attachments folder (missing folder = success).
  Future<Result<void>> deleteRun(String runId);

  /// Returns run ids that currently have an attachments folder.
  Future<Result<List<String>>> listRunIds();
}
