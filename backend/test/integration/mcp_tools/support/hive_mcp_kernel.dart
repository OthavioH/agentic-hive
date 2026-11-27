import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:test/test.dart';

/// Compiles `bin/hive_mcp.dart` to a kernel file once for the calling test
/// file and returns a getter for its path. `dart run` recompiles the script on
/// every start (10 s or more), which dominated these tests.
///
/// Call it at declaration time in `main()`; it registers the `setUpAll` that
/// compiles and the `tearDownAll` that deletes the file. Start the proxy with
/// `Process.start(Platform.resolvedExecutable, [hiveMcp(), ...args])`.
String Function() useCompiledHiveMcp() {
  late Directory dir;
  late String kernel;
  setUpAll(() async {
    dir = await Directory.systemTemp.createTemp('hive_mcp_kernel_');
    kernel = p.join(dir.path, 'hive_mcp.dill');
    final result = await Process.run(Platform.resolvedExecutable, [
      'compile',
      'kernel',
      p.join(Directory.current.path, 'bin', 'hive_mcp.dart'),
      '-o',
      kernel,
    ]);
    if (result.exitCode != 0) {
      throw StateError('Compiling hive_mcp failed:\n${result.stderr}');
    }
  });
  tearDownAll(() => dir.delete(recursive: true));
  return () => kernel;
}
