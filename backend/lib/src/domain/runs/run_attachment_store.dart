import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';
import 'package:agentic_hive_backend/src/logging/log_event.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:logging/logging.dart';

/// Persistence port for decoded Run attachment files on disk (ADR 0030).
abstract interface class RunAttachmentStore {
  /// Returns `<runsDir>/<runId>/attachments`.
  String attachmentsDir(String runId);

  /// Absolute path of the [index]-th (0-based) stored file of [attachment].
  String filePath(String runId, int index, RunAttachment attachment);

  /// Writes files as `1.<ext>`, `2.<ext>`, ...
  ///
  /// On failure, deletes what it wrote and returns a [FailureResult].
  Future<Result<void>> write(String runId, List<DecodedRunAttachment> files);

  /// Deletes a run's attachments folder (missing folder = success).
  Future<Result<void>> deleteRun(String runId);

  /// Returns run ids that currently have an attachments folder.
  Future<Result<List<String>>> listRunIds();
}

/// Run statuses whose attachments are deleted (ADR 0030).
const Set<RunStatus> attachmentDeletingStatuses = {
  RunStatus.succeeded,
  RunStatus.failed,
  RunStatus.cancelled,
};

/// Best-effort deletion (ADR 0030).
extension RunAttachmentCleanup on RunAttachmentStore {
  /// Deletes [runId]'s attachments folder; logs failures, never throws.
  Future<void> deleteRunBestEffort(String runId) async {
    Object? error;
    try {
      final result = await deleteRun(runId);
      if (result case FailureResult(:final failure)) error = failure.message;
    } on Object catch (e) {
      error = e;
    }
    if (error != null) {
      Logger('run_attachments').warning(
        LogEvent(
          'runs.attachments_delete_failed',
          fields: {'runId': runId, 'error': '$error'},
        ),
      );
    }
  }
}
