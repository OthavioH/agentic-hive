import 'dart:io';

import 'package:agentic_hive_backend/src/data/nodes/posix_pty_runner.dart';
import 'package:agentic_hive_backend/src/data/nodes/windows_pty_runner.dart';
import 'package:agentic_hive_backend/src/domain/nodes/node_ports.dart';
import 'package:agentic_hive_backend/src/domain/nodes/pty_session.dart';
import 'package:agentic_hive_backend/src/domain/runs/process_tree_killer.dart';

/// Creates the OS-specific [PtyRunner] for [operatingSystem]
/// (`Platform.operatingSystem`, ADR 0012).
PtyRunner ptyRunnerFor(
  String operatingSystem, {
  ProcessTreeTracker? processTracker,
  ProcessTreeKiller? processTreeKiller,
  PtySessionRegistry? sessionRegistry,
}) => switch (operatingSystem) {
  'windows' => WindowsPtyRunner(
    processTracker: processTracker,
    processTreeKiller: processTreeKiller,
    sessionRegistry: sessionRegistry,
  ),
  'linux' => PosixPtyRunner(
    config: PosixPtyConfig.linux,
    processTracker: processTracker,
    processTreeKiller: processTreeKiller,
    sessionRegistry: sessionRegistry,
  ),
  'macos' => PosixPtyRunner(
    config: PosixPtyConfig.macos,
    processTracker: processTracker,
    processTreeKiller: processTreeKiller,
    sessionRegistry: sessionRegistry,
  ),
  _ => throw UnsupportedError('Unsupported platform: $operatingSystem'),
};

/// Returns the [PtyRunner] for the current operating system.
PtyRunner currentPtyRunner({
  ProcessTreeTracker? processTracker,
  ProcessTreeKiller? processTreeKiller,
  PtySessionRegistry? sessionRegistry,
}) => ptyRunnerFor(
  Platform.operatingSystem,
  processTracker: processTracker,
  processTreeKiller: processTreeKiller,
  sessionRegistry: sessionRegistry,
);
