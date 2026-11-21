import 'dart:io';

import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/data/workspace/git_client.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Inspects git availability and repository capabilities for a workspace path.
final class WorkspaceCapabilitiesService {
  /// Creates a capabilities service backed by [_git].
  const new(this._git);

  final GitClient _git;

  /// Reports git availability, version, and (when [path] is provided) whether
  /// [path] is inside a git repository with at least one commit.
  Future<Result<WorkspaceCapabilities>> getCapabilities({String? path}) async {
    final versionResult = await _git.run(const ['--version']);
    if (versionResult.launchError != null ||
        versionResult.timedOut ||
        versionResult.exitCode != 0) {
      return const Success(
        WorkspaceCapabilities(
          gitAvailable: false,
          isGitRepo: false,
          hasCommits: false,
        ),
      );
    }

    final rawVersion = versionResult.stdout.trim();
    final gitVersion = rawVersion.isEmpty ? null : rawVersion;

    if (path == null || path.trim().isEmpty) {
      return Success(
        WorkspaceCapabilities(
          gitAvailable: true,
          gitVersion: gitVersion,
          isGitRepo: false,
          hasCommits: false,
        ),
      );
    }

    if (!Directory(path).existsSync()) {
      return FailureResult(
        ValidationFailure('Workspace path "$path" does not exist.'),
      );
    }

    final insideResult = await _git.run([
      '-C',
      path,
      'rev-parse',
      '--is-inside-work-tree',
    ]);
    final isGitRepo =
        insideResult.launchError == null &&
        !insideResult.timedOut &&
        insideResult.exitCode == 0 &&
        insideResult.stdout.trim() == 'true';

    var hasCommits = false;
    if (isGitRepo) {
      final headResult = await _git.run([
        '-C',
        path,
        'rev-parse',
        '--verify',
        'HEAD',
      ]);
      hasCommits =
          headResult.launchError == null &&
          !headResult.timedOut &&
          headResult.exitCode == 0 &&
          headResult.stdout.trim().isNotEmpty;
    }

    return Success(
      WorkspaceCapabilities(
        gitAvailable: true,
        gitVersion: gitVersion,
        isGitRepo: isGitRepo,
        hasCommits: hasCommits,
      ),
    );
  }
}
