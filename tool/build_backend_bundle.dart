import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/bundle/bundle_layout.dart';
import 'src/bundle/bundle_platform.dart';

// Builds the backend with `dart build cli` and assembles <bundle-dir>/backend/.
// `dart build cli` builds one entry point per run and wipes its output folder,
// so server and hive_mcp are built separately and merged.
//
//   dart run tool/build_backend_bundle.dart <bundle-dir>   # from the repo root

const _usage =
    'Usage: dart run tool/build_backend_bundle.dart <bundle-dir>\n\n'
    'Builds backend/bin/server and backend/bin/hive_mcp with `dart build cli` '
    'and merges them into <bundle-dir>/backend/.';

Future<void> main(List<String> arguments) async {
  if (arguments.length == 1 &&
      (arguments.single == '-h' || arguments.single == '--help')) {
    stdout.writeln(_usage);
    return;
  }

  if (arguments.length != 1) {
    stderr.writeln(_usage);
    exitCode = 64;
    return;
  }

  if (!File(p.join('backend', 'pubspec.yaml')).existsSync()) {
    stderr.writeln('Run this from the repository root.');
    exitCode = 64;
    return;
  }

  final layout = BundleLayout(
    p.absolute(arguments.single),
    platform: bundlePlatformFor(Platform.operatingSystem),
  );
  final buildRoot = p.join(layout.root, '.backend-build');
  final buildRootDir = Directory(buildRoot);
  if (buildRootDir.existsSync()) {
    buildRootDir.deleteSync(recursive: true);
  }
  final backendDir = Directory(layout.backendDir);
  if (backendDir.existsSync()) {
    backendDir.deleteSync(recursive: true);
  }
  buildRootDir.createSync(recursive: true);

  for (final name in ['server', 'hive_mcp']) {
    final process = await Process.start(
      Platform.resolvedExecutable,
      ['build', 'cli', '-t', 'bin/$name.dart', '-o', p.join(buildRoot, name)],
      workingDirectory: 'backend',
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln('dart build cli failed for $name (exit $code).');
      exitCode = 1;
      return;
    }
  }

  Directory(p.join(buildRoot, 'server', 'bundle'))
      .renameSync(layout.backendDir);
  File(
    p.join(
      buildRoot,
      'hive_mcp',
      'bundle',
      'bin',
      layout.platform.executableFileName('hive_mcp'),
    ),
  ).renameSync(layout.hiveMcpPath);
  buildRootDir.deleteSync(recursive: true);

  final missing = [
    layout.serverPath,
    layout.hiveMcpPath,
    layout.sqliteLibraryPath,
  ].where((file) => !File(file).existsSync()).toList();
  if (missing.isNotEmpty) {
    for (final path in missing) {
      stderr.writeln('Missing built file: $path');
    }
    exitCode = 1;
    return;
  }

  stdout.writeln('Backend bundle ready: ${layout.backendDir}');
}
