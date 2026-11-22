import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/bundle/backend_assembly.dart';
import 'src/bundle/bundle_layout.dart';
import 'src/bundle/bundle_platform.dart';

// Builds the backend with `dart build cli` and assembles <bundle-dir>/backend/.
// `dart build cli` builds one entry point per run and wipes its output folder,
// so server and hive_mcp are built separately and merged.
// Builds in a temporary folder next to <bundle-dir> and replaces
// <bundle-dir>/backend/ only after both builds succeed.
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
  Directory(layout.root).createSync(recursive: true);
  final buildRootDir = Directory(
    p.dirname(layout.root),
  ).createTempSync('hive_backend_build_');
  try {
    for (final name in BundleLayout.backendEntryPoints) {
      final process = await Process.start(
        Platform.resolvedExecutable,
        [
          'build',
          'cli',
          '-t',
          'bin/$name.dart',
          '-o',
          p.join(buildRootDir.path, name),
        ],
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

    final problems = assembleBackend(
      layout: layout,
      buildRoot: buildRootDir.path,
    );
    if (problems.isNotEmpty) {
      problems.forEach(stderr.writeln);
      exitCode = 1;
      return;
    }
    stdout.writeln('Backend bundle ready: ${layout.backendDir}');
  } finally {
    try {
      buildRootDir.deleteSync(recursive: true);
    } on FileSystemException catch (e) {
      stderr.writeln('warning: could not delete ${buildRootDir.path}: $e');
    }
  }
}
