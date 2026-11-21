import 'dart:io';

import 'package:agentic_hive_backend/src/data/runs/posix_process_tree_killer.dart';
import 'package:agentic_hive_backend/src/data/runs/windows_process_tree_killer.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';

/// Combined OS process-tree killer and tracker selected at startup (ADR 0012).
typedef ManagedProcessTreeKiller = ({
  ProcessTreeKiller killer,
  ProcessTreeTracker tracker,
});

/// Creates the OS-specific [ProcessTreeKiller] and [ProcessTreeTracker] for
/// [operatingSystem] (`Platform.operatingSystem`).
ManagedProcessTreeKiller processTreeKillerFor(String operatingSystem) =>
    switch (operatingSystem) {
      'windows' => () {
        final impl = WindowsProcessTreeKiller();
        return (killer: impl, tracker: impl);
      }(),
      'linux' || 'macos' => () {
        final impl = PosixProcessTreeKiller();
        return (killer: impl, tracker: impl);
      }(),
      _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
    };

/// Returns the [ProcessTreeKiller] and [ProcessTreeTracker] for the current
/// operating system.
ManagedProcessTreeKiller currentProcessTreeKiller() =>
    processTreeKillerFor(Platform.operatingSystem);
