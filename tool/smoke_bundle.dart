import 'dart:io';

import 'package:path/path.dart' as p;

import 'src/bundle/bundle_layout.dart';
import 'src/bundle/bundle_platform.dart';
import 'src/bundle/bundle_smoke.dart';
import 'src/bundle/smoke_result.dart';

// Smoke test for an assembled Bundle (app executable + backend/ folder).
//
//   dart run tool/smoke_bundle.dart <bundle-dir>
//
// Exit code 0 only when the bundled backend starts, answers GET /health over
// its Unix socket and stops.

const _usage =
    'Usage: dart run tool/smoke_bundle.dart <bundle-dir>\n\n'
    'Checks an assembled Bundle: the app executable, backend/bin/server, '
    'backend/bin/hive_mcp and the SQLite library in backend/lib/, then starts '
    'the bundled backend with a temporary data folder and calls GET /health '
    'over its Unix socket.';

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

  final layout = BundleLayout(
    p.absolute(arguments.single),
    platform: bundlePlatformFor(Platform.operatingSystem),
  );
  final result = await BundleSmoke(
    layout: layout,
    log: (line) => stdout.writeln('smoke: $line'),
  ).run();

  if (result is SmokePassed) {
    stdout.writeln(result.message);
  } else {
    stderr.writeln(result.message);
  }
  exitCode = result.exitCode;
}
