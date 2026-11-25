import 'dart:io';

import 'package:logging/logging.dart';
import 'package:path/path.dart' as p;

/// What [AgentsDirectoryMigration.run] did.
final class AgentsMigrationReport {
  /// Creates a report.
  const new({this.copied = const [], this.conflicts = const []});

  /// Relative paths of the files copied into the target folder.
  final List<String> copied;

  /// Relative paths of files that exist in both folders with different
  /// content. The target file was kept untouched.
  final List<String> conflicts;
}

/// Copies the agent files of the former app-data `agents` folder into the
/// user's shared library `~/.agents/agents` (ADR 0025).
///
/// It never overwrites an existing file and never deletes the source, so it is
/// safe to run on every startup: a second run copies nothing.
final class AgentsDirectoryMigration {
  /// Creates a migration from [legacyDir] into [targetDir].
  const new({required this.legacyDir, required this.targetDir});

  static final _log = Logger('agents.migration');

  /// The folder to read from.
  final String legacyDir;

  /// The folder to copy into.
  final String targetDir;

  /// Copies every file that is missing in [targetDir] and reports files whose
  /// content differs.
  Future<AgentsMigrationReport> run() async {
    final source = Directory(legacyDir);
    if (p.equals(legacyDir, targetDir) || !source.existsSync()) {
      return const AgentsMigrationReport();
    }

    final copied = <String>[];
    final conflicts = <String>[];
    await for (final entity in source.list(recursive: true)) {
      if (entity is! File) continue;
      final relative = p.relative(entity.path, from: legacyDir);
      final destination = File(p.join(targetDir, relative));
      if (destination.existsSync()) {
        if (!await _sameContent(entity, destination)) conflicts.add(relative);
        continue;
      }
      await destination.parent.create(recursive: true);
      await entity.copy(destination.path);
      copied.add(relative);
    }

    if (copied.isNotEmpty) {
      _log.info('Migrated ${copied.length} agent file(s) to $targetDir.');
    }
    if (conflicts.isNotEmpty) {
      _log.warning(
        'Kept existing agent files in $targetDir; the copies in $legacyDir '
        'differ: ${conflicts.join(', ')}.',
      );
    }
    return AgentsMigrationReport(copied: copied, conflicts: conflicts);
  }

  Future<bool> _sameContent(File a, File b) async {
    if (await a.length() != await b.length()) return false;
    final bytesA = await a.readAsBytes();
    final bytesB = await b.readAsBytes();
    for (var i = 0; i < bytesA.length; i++) {
      if (bytesA[i] != bytesB[i]) return false;
    }
    return true;
  }
}
