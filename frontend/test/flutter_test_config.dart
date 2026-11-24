import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_frontend/core/backend/platform_paths.dart';
import 'package:flutter_test/flutter_test.dart';

import 'support/test_data_sandbox.dart';

/// Isolates every frontend test from the real user data folder (issue #149).
Future<void> testExecutable(FutureOr<void> Function() testMain) async {
  final sandboxRoot = Directory.systemTemp.createTempSync(
    'agentic_hive_test_data_',
  );
  final overrides = _tryBuildOverrides(sandboxRoot.path);
  if (overrides != null) {
    IOOverrides.global = overrides;
  }
  tearDownAll(() {
    IOOverrides.global = null;
    if (sandboxRoot.existsSync()) {
      sandboxRoot.deleteSync(recursive: true);
    }
  });
  await testMain();
}

SandboxIOOverrides? _tryBuildOverrides(String sandboxRoot) {
  try {
    final paths = currentPlatformPaths();
    return SandboxIOOverrides(
      dataDir: paths.defaultDataDir(),
      sandboxRoot: sandboxRoot,
      context: paths.context,
    );
  } on Object {
    return null;
  }
}
