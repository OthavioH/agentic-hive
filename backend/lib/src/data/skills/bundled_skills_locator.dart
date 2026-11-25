import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/runtime/runtime_mode.dart';
import 'package:path/path.dart' as p;

/// Finds the folder that holds the bundled skills.
final class BundledSkillsLocator {
  /// Creates a locator; hooks exist for tests.
  new({
    String? resolvedExecutable,
    bool Function(String path)? directoryExists,
    p.Context? pathContext,
    RuntimeMode? runtimeMode,
    String? currentWorkingDirectory,
  }) : _resolvedExecutable = resolvedExecutable ?? Platform.resolvedExecutable,
       _directoryExists =
           directoryExists ?? ((path) => Directory(path).existsSync()),
       _ctx = pathContext ?? p.context,
       _runtimeMode = runtimeMode ?? RuntimeMode.current,
       _currentWorkingDirectory =
           currentWorkingDirectory ?? Directory.current.path;

  final String _resolvedExecutable;
  final bool Function(String path) _directoryExists;
  final p.Context _ctx;
  final RuntimeMode _runtimeMode;
  final String _currentWorkingDirectory;

  /// Returns the existing skills root or a `NotFoundFailure`.
  Result<String> resolveRoot() {
    final candidates = <String>[
      _ctx.normalize(
        _ctx.join(_ctx.dirname(_resolvedExecutable), '..', 'skills'),
      ),
      if (_runtimeMode == RuntimeMode.development) ...[
        _ctx.join(_currentWorkingDirectory, 'skills'),
        _ctx.join(_currentWorkingDirectory, 'backend', 'skills'),
        if (Platform.script.scheme == 'file' &&
            Platform.script.toFilePath().endsWith('.dart'))
          _ctx.join(
            _ctx.dirname(_ctx.dirname(Platform.script.toFilePath())),
            'skills',
          ),
      ],
    ];

    for (final candidate in candidates) {
      if (_directoryExists(candidate)) {
        return Success(candidate);
      }
    }

    return const FailureResult(
      NotFoundFailure('Could not find the bundled skills folder.'),
    );
  }
}
