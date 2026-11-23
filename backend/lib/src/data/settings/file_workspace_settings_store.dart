import 'dart:convert';
import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/settings/workspace_settings_store.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:path/path.dart' as p;

/// File-based [WorkspaceSettingsStore] that keeps the overrides in
/// `<root>/.agentic-hive/settings.json`, so they can be versioned with the
/// project.
final class FileWorkspaceSettingsStore implements WorkspaceSettingsStore {
  /// Creates a store; [pathContext] defaults to the host path style.
  new({p.Context? pathContext}) : _path = pathContext ?? p.context;

  /// Folder inside a workspace that holds Agentic Hive files.
  static const folderName = '.agentic-hive';

  /// Name of the overrides file inside [folderName].
  static const fileName = 'settings.json';

  final p.Context _path;

  File _file(String rootPath) =>
      File(_path.join(rootPath, folderName, fileName));

  @override
  Future<Result<ExecutionSettings>> read(String rootPath) async {
    final file = _file(rootPath);
    try {
      if (!file.existsSync()) return const Success(ExecutionSettings());
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is! Map<String, Object?>) {
        return FailureResult(
          ValidationFailure('"${file.path}" must hold a JSON object.'),
        );
      }
      final known = <String, Object?>{
        for (final key in ExecutionSettings.overridableKeys)
          if (decoded[key] != null) key: decoded[key],
      };
      return Success(ExecutionSettings.fromJson(known));
    } on FormatException catch (error) {
      return FailureResult(
        ValidationFailure('Invalid workspace settings: ${error.message}'),
      );
    } on FileSystemException catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to read "${file.path}".', cause: error),
      );
    }
  }

  @override
  Future<Result<void>> write(
    String rootPath,
    ExecutionSettings settings,
  ) async {
    final file = _file(rootPath);
    try {
      if (settings.isEmpty) {
        if (file.existsSync()) await file.delete();
        return const Success<void>(null);
      }
      final json = <String, Object?>{
        if (settings.defaultIsolationMode != null)
          'defaultIsolationMode': settings.defaultIsolationMode!.name,
        if (settings.ignorePatterns != null)
          'ignorePatterns': settings.ignorePatterns,
        if (settings.defaultShell != null)
          'defaultShell': settings.defaultShell,
      };
      await file.parent.create(recursive: true);
      await file.writeAsString(
        '${const JsonEncoder.withIndent('  ').convert(json)}\n',
      );
      return const Success<void>(null);
    } on FileSystemException catch (error) {
      return FailureResult(
        PersistenceFailure('Failed to write "${file.path}".', cause: error),
      );
    }
  }
}
