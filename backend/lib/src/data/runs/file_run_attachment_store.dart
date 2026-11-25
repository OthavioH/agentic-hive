import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_store.dart';
import 'package:agentic_hive_backend/src/domain/runs/run_attachment_validator.dart';
import 'package:path/path.dart' as p;

/// Filesystem-backed [RunAttachmentStore] under `<runsDir>/<runId>/attachments`.
final class FileRunAttachmentStore implements RunAttachmentStore {
  /// Creates a filesystem attachment store rooted at [_runsDir].
  new({required this._runsDir, p.Context? pathContext})
    : _path = pathContext ?? p.context;

  final String _runsDir;
  final p.Context _path;

  @override
  String attachmentsDir(String runId) =>
      _path.join(_runsDir, runId, 'attachments');

  @override
  Future<Result<void>> write(
    String runId,
    List<DecodedRunAttachment> files,
  ) async {
    final dirPath = attachmentsDir(runId);
    try {
      await Directory(dirPath).create(recursive: true);
      for (var i = 0; i < files.length; i++) {
        final f = files[i];
        final filePath = _path.join(dirPath, '${i + 1}.${f.extension}');
        await File(filePath).writeAsBytes(f.bytes, flush: true);
      }
      return const Success<void>(null);
    } on Object catch (e) {
      await deleteRun(runId);
      return FailureResult(
        PersistenceFailure(
          'Failed to store attachments for run "$runId".',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<void>> deleteRun(String runId) async {
    try {
      final dir = Directory(attachmentsDir(runId));
      if (dir.existsSync()) {
        await dir.delete(recursive: true);
      }
      return const Success<void>(null);
    } on Object catch (e) {
      return FailureResult(
        PersistenceFailure(
          'Failed to delete attachments for run "$runId".',
          cause: e,
        ),
      );
    }
  }

  @override
  Future<Result<List<String>>> listRunIds() async {
    try {
      final root = Directory(_runsDir);
      if (!root.existsSync()) {
        return const Success<List<String>>([]);
      }
      final ids = <String>[];
      await for (final entity in root.list(followLinks: false)) {
        if (entity is Directory) {
          final attachments = Directory(_path.join(entity.path, 'attachments'));
          if (attachments.existsSync()) {
            ids.add(_path.basename(entity.path));
          }
        }
      }
      return Success(ids);
    } on Object catch (e) {
      return FailureResult(
        PersistenceFailure(
          'Failed to list run attachment directories.',
          cause: e,
        ),
      );
    }
  }
}
