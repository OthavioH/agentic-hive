import 'dart:async';
import 'dart:io';

import 'package:agentic_hive_backend/agentic_hive_backend.dart';
import 'package:args/args.dart';
import 'package:path/path.dart' as p;

/// Exit code for invalid command-line usage or configuration (sysexits).
const _usageError = 64;

/// Exit code when the backend cannot start.
const _startFailure = 70;

Future<void> main(List<String> arguments) async {
  final parser = ArgParser()
    ..addOption('config', help: 'Path of a YAML configuration file.')
    ..addOption('data-dir', help: 'Folder for the database, logs and socket.')
    ..addFlag('help', abbr: 'h', negatable: false, help: 'Show this help.');

  final ArgResults args;
  try {
    args = parser.parse(arguments);
  } on FormatException catch (e) {
    stderr.writeln('${e.message}\n\n${parser.usage}');
    exitCode = _usageError;
    return;
  }
  if (args.flag('help')) {
    stdout.writeln('Agentic Hive backend $backendVersion\n\n${parser.usage}');
    return;
  }

  final platformPaths = currentPlatformPaths();
  final AppConfig config;
  try {
    config =
        await ConfigLoader(
          mode: RuntimeMode.current,
          platformPaths: platformPaths,
          devConfigCandidates: _devConfigCandidates(),
        ).load(
          configPath: args.option('config'),
          dataDirOverride: args.option('data-dir'),
        );
  } on ConfigException catch (e) {
    stderr.writeln(e);
    exitCode = _usageError;
    return;
  }

  final Backend backend;
  try {
    backend = await Backend.start(config: config, platformPaths: platformPaths);
  } on BackendAlreadyRunningException catch (e) {
    stderr.writeln(e);
    exitCode = _startFailure;
    return;
  } on SocketPathTooLongException catch (e) {
    stderr.writeln(e);
    exitCode = _startFailure;
    return;
  }

  await _shutdownSignal();
  await backend.stop();
}

/// Where `config/dev.yaml` may be when running from source: next to this
/// script's package, or under the current folder.
List<String> _devConfigCandidates() {
  final script = Platform.script;
  return [
    if (script.isScheme('file') && script.path.endsWith('.dart'))
      p.join(p.dirname(p.dirname(script.toFilePath())), 'config', 'dev.yaml'),
    p.join(Directory.current.path, 'config', 'dev.yaml'),
    p.join(Directory.current.path, 'backend', 'config', 'dev.yaml'),
  ];
}

/// Completes on Ctrl+C (all platforms) or SIGTERM (Linux and macOS).
Future<void> _shutdownSignal() {
  final signals = [
    ProcessSignal.sigint.watch(),
    if (!Platform.isWindows) ProcessSignal.sigterm.watch(),
  ];
  final completer = Completer<void>();
  final subscriptions = <StreamSubscription<ProcessSignal>>[];
  for (final signal in signals) {
    subscriptions.add(
      signal.listen((_) {
        if (completer.isCompleted) return;
        for (final subscription in subscriptions) {
          unawaited(subscription.cancel());
        }
        completer.complete();
      }),
    );
  }
  return completer.future;
}
