import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/workflows/workspace_workflow_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// [WorkspaceWorkflowRepository] that stores each workflow as
/// `<root>/.agentic-hive/workflows/<id>.json`.
///
/// Every operation runs one at a time in this repository. A background
/// deletion (ADR 0027) can remove a file while a read of it is in progress;
/// on Windows that read and the delete also fail each other with a sharing
/// violation. Serializing the operations keeps a read from overlapping a
/// delete, so a vanished file always shows up as a missing file.
final class FileWorkspaceWorkflowRepository
    implements WorkspaceWorkflowRepository {
  /// Creates a repository using [pathContext] (the host context by default).
  ///
  /// `beforeRead` runs right before a workflow file is read. Tests use it as a
  /// gate to make a concurrent delete land between two steps of a read.
  new({p.Context? pathContext, this._beforeRead})
    : _path = pathContext ?? p.context;

  static const _extension = '.json';

  final p.Context _path;
  final Future<void> Function(File file)? _beforeRead;
  Future<void> _tail = Future<void>.value();

  /// Folder that holds the workflow files of the workspace at [rootPath].
  static String workflowsDirectory(String rootPath, {p.Context? pathContext}) =>
      (pathContext ?? p.context).join(rootPath, '.agentic-hive', 'workflows');

  @override
  Future<Result<List<Workflow>>> listAll(String rootPath) =>
      _serialized(() async {
        try {
          final directory = Directory(
            workflowsDirectory(rootPath, pathContext: _path),
          );
          if (!directory.existsSync()) return const Success(<Workflow>[]);
          final workflows = <Workflow>[];
          await for (final entity in directory.list()) {
            if (entity is! File || _path.extension(entity.path) != _extension) {
              continue;
            }
            final Workflow? workflow;
            try {
              workflow = await _read(
                entity,
                _path.basenameWithoutExtension(entity.path),
              );
            } on PathNotFoundException {
              // Removed after it was listed: it is no longer part of the list.
              continue;
            }
            if (workflow != null) workflows.add(workflow);
          }
          workflows.sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
          return Success(workflows);
        } on FileSystemException catch (error) {
          return FailureResult(
            PersistenceFailure(
              'Failed to list workspace workflows.',
              cause: error,
            ),
          );
        }
      });

  @override
  Future<Result<Workflow>> getById(String rootPath, String id) =>
      _serialized(() async {
        final file = _fileFor(rootPath, id);
        if (file case FailureResult<File>(:final failure)) {
          return FailureResult(failure);
        }
        try {
          // No existence check before the read: the file can be removed
          // between two steps, so a vanished file is detected by the read.
          final workflow = await _read(file.valueOrNull!, id);
          if (workflow == null) {
            return FailureResult(
              ValidationFailure(
                'Workflow file "$id.json" is not a valid workflow.',
              ),
            );
          }
          return Success(workflow);
        } on PathNotFoundException {
          return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
        } on FileSystemException catch (error) {
          return FailureResult(
            PersistenceFailure('Failed to load workflow "$id".', cause: error),
          );
        }
      });

  @override
  Future<Result<Workflow>> create(String rootPath, Workflow workflow) =>
      _serialized(() async {
        final file = _fileFor(rootPath, workflow.id);
        if (file case FailureResult<File>(:final failure)) {
          return FailureResult(failure);
        }
        final target = file.valueOrNull!;
        if (target.existsSync()) {
          return FailureResult(
            ConflictFailure('Workflow "${workflow.id}" already exists.'),
          );
        }
        return await _write(target, workflow);
      });

  @override
  Future<Result<Workflow>> update(String rootPath, Workflow workflow) =>
      _serialized(() async {
        final file = _fileFor(rootPath, workflow.id);
        if (file case FailureResult<File>(:final failure)) {
          return FailureResult(failure);
        }
        final target = file.valueOrNull!;
        if (!target.existsSync()) {
          return FailureResult(
            NotFoundFailure('Workflow "${workflow.id}" not found.'),
          );
        }
        return await _write(target, workflow);
      });

  @override
  Future<Result<void>> delete(String rootPath, String id) => _serialized(
    () async {
      final file = _fileFor(rootPath, id);
      if (file case FailureResult<File>(:final failure)) {
        return FailureResult(failure);
      }
      try {
        final target = file.valueOrNull!;
        if (!target.existsSync()) {
          return FailureResult(NotFoundFailure('Workflow "$id" not found.'));
        }
        await target.delete();
        return const Success<void>(null);
      } on FileSystemException catch (error) {
        return FailureResult(
          PersistenceFailure('Failed to delete workflow "$id".', cause: error),
        );
      }
    },
  );

  /// Runs [action] after every operation queued before it has settled.
  Future<T> _serialized<T>(Future<T> Function() action) {
    final run = _tail.then((_) => action());
    _tail = run.then<void>((_) {}, onError: (Object _, StackTrace _) {});
    return run;
  }

  Result<File> _fileFor(String rootPath, String id) {
    if (id.isEmpty ||
        id.startsWith('.') ||
        id.contains('/') ||
        id.contains(r'\') ||
        id.contains('\u0000')) {
      return FailureResult(
        ValidationFailure('Workflow id "$id" is not a valid file name.'),
      );
    }
    return Success(
      File(
        _path.join(
          workflowsDirectory(rootPath, pathContext: _path),
          '$id$_extension',
        ),
      ),
    );
  }

  Future<Result<Workflow>> _write(File target, Workflow workflow) async {
    try {
      await target.parent.create(recursive: true);
      final temp = File('${target.path}.tmp');
      await temp.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(workflow.toJson())}\n',
      );
      await temp.rename(target.path);
      return Success(workflow);
    } on FileSystemException catch (error) {
      return FailureResult(
        PersistenceFailure(
          'Failed to write workflow "${workflow.id}".',
          cause: error,
        ),
      );
    }
  }

  /// Reads [file] as a workflow whose id is forced to [id]; `null` when the
  /// content is not a valid workflow. Throws [PathNotFoundException] when the
  /// file no longer exists.
  Future<Workflow?> _read(File file, String id) async {
    await _beforeRead?.call(file);
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) return null;
      return Workflow.fromJson(decoded).copyWith(id: id);
    } on FormatException {
      return null;
    }
  }
}
