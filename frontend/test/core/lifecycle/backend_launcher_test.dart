import 'dart:io';

import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackendLauncher path resolution', () {
    test('windows resolves sibling agentic_hive_backend.exe in release', () {
      const sibling = r'C:\Program Files\AgenticHive\agentic_hive_backend.exe';
      final launcher = backendLauncherFor(
        'windows',
        resolvedExecutable: r'C:\Program Files\AgenticHive\agentic_hive.exe',
        isDebugMode: false,
        environment: const {},
        currentDirectory: r'C:\Users\Ada',
        fileExists: (path) => path == sibling,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, sibling);
      expect(target.arguments, isEmpty);
    });

    test('linux resolves sibling agentic_hive_backend in release', () {
      const sibling = '/opt/agentic-hive/agentic_hive_backend';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic-hive/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/home/ada',
        fileExists: (path) => path == sibling,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, sibling);
      expect(target.arguments, isEmpty);
    });

    test('macos resolves sibling agentic_hive_backend in release', () {
      const sibling =
          '/Applications/Agentic Hive.app/Contents/MacOS/agentic_hive_backend';
      final launcher = backendLauncherFor(
        'macos',
        resolvedExecutable:
            '/Applications/Agentic Hive.app/Contents/MacOS/Agentic Hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/Users/ada',
        fileExists: (path) => path == sibling,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, sibling);
      expect(target.arguments, isEmpty);
    });

    test('debug mode falls back to dart run backend/bin/server.dart', () {
      const entrypoint = r'C:\repo\backend\bin\server.dart';
      final windowsLauncher = backendLauncherFor(
        'windows',
        resolvedExecutable: r'C:\repo\frontend\build\windows\runner.exe',
        isDebugMode: true,
        environment: const {},
        currentDirectory: r'C:\repo\frontend',
        fileExists: (path) => path == entrypoint,
      );

      final winTarget =
          (windowsLauncher.resolveLaunchTarget()
                  as Success<BackendLaunchTarget>)
              .value;
      expect(winTarget.executable, 'dart.exe');
      expect(winTarget.arguments, ['run', entrypoint]);
      expect(winTarget.workingDirectory, r'C:\repo\backend');

      const linuxEntrypoint = '/repo/backend/bin/server.dart';
      final linuxLauncher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/repo/frontend/build/linux/runner',
        isDebugMode: true,
        environment: const {},
        currentDirectory: '/repo',
        fileExists: (path) => path == linuxEntrypoint,
      );
      final linuxTarget =
          (linuxLauncher.resolveLaunchTarget() as Success<BackendLaunchTarget>)
              .value;
      expect(linuxTarget.executable, 'dart');
      expect(linuxTarget.arguments, ['run', linuxEntrypoint]);
      expect(linuxTarget.workingDirectory, '/repo/backend');
    });

    test('respects AGENTIC_HIVE_BACKEND_BIN and entrypoint env overrides', () {
      const binOverride = '/custom/bin/agentic_hive_backend';
      final binLauncher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/app/agentic_hive',
        isDebugMode: false,
        environment: const {backendBinEnvVar: binOverride},
        currentDirectory: '/app',
        fileExists: (path) => path == binOverride,
      );
      final binTarget =
          (binLauncher.resolveLaunchTarget() as Success<BackendLaunchTarget>)
              .value;
      expect(binTarget.executable, binOverride);

      const entryOverride = '/custom/backend/bin/server.dart';
      final entryLauncher = backendLauncherFor(
        'macos',
        resolvedExecutable: '/app/Agentic Hive',
        isDebugMode: true,
        environment: const {backendEntrypointEnvVar: entryOverride},
        currentDirectory: '/app',
        fileExists: (path) => path == entryOverride,
      );
      final entryTarget =
          (entryLauncher.resolveLaunchTarget() as Success<BackendLaunchTarget>)
              .value;
      expect(entryTarget.executable, 'dart');
      expect(entryTarget.arguments, ['run', entryOverride]);
    });

    test('returns NotFoundFailure when binary is missing in release', () {
      final launcher = backendLauncherFor(
        'windows',
        resolvedExecutable: r'C:\App\agentic_hive.exe',
        isDebugMode: false,
        environment: const {},
        currentDirectory: r'C:\App',
        fileExists: (_) => false,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<FailureResult<BackendLaunchTarget>>());
      expect(
        (result as FailureResult<BackendLaunchTarget>).failure,
        isA<NotFoundFailure>(),
      );
    });

    test('unsupported OS throws UnsupportedError', () {
      expect(
        () => backendLauncherFor(
          'fuchsia',
          resolvedExecutable: '/app',
          isDebugMode: false,
          environment: const {},
          currentDirectory: '/',
        ),
        throwsUnsupportedError,
      );
    });
  });

  group('BackendLauncher.launch', () {
    test('spawns process in detached mode', () async {
      String? startedExe;
      List<String>? startedArgs;
      ProcessStartMode? startedMode;

      const sibling = '/opt/agentic_hive_backend';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/opt',
        fileExists: (path) => path == sibling,
        startProcess:
            (executable, arguments, {workingDirectory, mode = .normal}) async {
              startedExe = executable;
              startedArgs = arguments;
              startedMode = mode;
              return _DummyProcess();
            },
      );

      final result = await launcher.launch();
      expect(result, isA<Success<void>>());
      expect(startedExe, sibling);
      expect(startedArgs, isEmpty);
      expect(startedMode, ProcessStartMode.detached);
    });

    test('maps ProcessException to NotFoundFailure', () async {
      const sibling = '/opt/agentic_hive_backend';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/opt',
        fileExists: (path) => path == sibling,
        startProcess:
            (executable, arguments, {workingDirectory, mode = .normal}) {
              throw const ProcessException(
                '/opt/agentic_hive_backend',
                <String>['bad'],
                'No such file',
              );
            },
      );

      final result = await launcher.launch();
      expect(result, isA<FailureResult<void>>());
      expect((result as FailureResult<void>).failure, isA<NotFoundFailure>());
    });
  });
}

final class _DummyProcess implements Process {
  @override
  Future<int> get exitCode => Future.value(0);

  @override
  bool kill([ProcessSignal signal = ProcessSignal.sigterm]) => true;

  @override
  int get pid => 1234;

  @override
  Stream<List<int>> get stderr => const Stream<List<int>>.empty();

  @override
  IOSink get stdin => throw UnimplementedError();

  @override
  Stream<List<int>> get stdout => const Stream<List<int>>.empty();
}
