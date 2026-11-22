import 'dart:io';

import 'package:agentic_hive_frontend/core/lifecycle/backend_launcher.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('BackendLauncher path resolution', () {
    test(r'windows resolves backend\bin\server.exe in release', () {
      const bundled = r'C:\Program Files\AgenticHive\backend\bin\server.exe';
      final launcher = backendLauncherFor(
        'windows',
        resolvedExecutable: r'C:\Program Files\AgenticHive\agentic_hive.exe',
        isDebugMode: false,
        environment: const {},
        currentDirectory: r'C:\Users\Ada',
        fileExists: (path) => path == bundled,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, bundled);
      expect(target.arguments, isEmpty);
      expect(target.workingDirectory, isNull);
    });

    test('linux resolves backend/bin/server in release', () {
      const bundled = '/opt/agentic-hive/backend/bin/server';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic-hive/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/home/ada',
        fileExists: (path) => path == bundled,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, bundled);
      expect(target.arguments, isEmpty);
      expect(target.workingDirectory, isNull);
    });

    test('macos resolves backend/bin/server next to the app executable in '
        'release', () {
      const bundled =
          '/Applications/agentic_hive.app/Contents/MacOS/backend/bin/server';
      final launcher = backendLauncherFor(
        'macos',
        resolvedExecutable:
            '/Applications/agentic_hive.app/Contents/MacOS/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/Users/ada',
        fileExists: (path) => path == bundled,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, bundled);
      expect(target.arguments, isEmpty);
      expect(target.workingDirectory, isNull);
    });

    test('no longer resolves the old sibling agentic_hive_backend', () {
      final winLauncher = backendLauncherFor(
        'windows',
        resolvedExecutable: r'C:\App\agentic_hive.exe',
        isDebugMode: false,
        environment: const {},
        currentDirectory: r'C:\App',
        fileExists: (path) => path == r'C:\App\agentic_hive_backend.exe',
      );
      final winResult = winLauncher.resolveLaunchTarget();
      expect(winResult, isA<FailureResult<BackendLaunchTarget>>());
      expect(
        (winResult as FailureResult<BackendLaunchTarget>).failure,
        isA<NotFoundFailure>(),
      );

      final linuxLauncher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/app/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/app',
        fileExists: (path) => path == '/app/agentic_hive_backend',
      );
      final linuxResult = linuxLauncher.resolveLaunchTarget();
      expect(linuxResult, isA<FailureResult<BackendLaunchTarget>>());
      expect(
        (linuxResult as FailureResult<BackendLaunchTarget>).failure,
        isA<NotFoundFailure>(),
      );
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

    test('bundled server wins over debug fallback in debug mode', () {
      const bundled =
          '/repo/frontend/build/linux/x64/debug/bundle/backend/bin/server';
      const entrypoint = '/repo/backend/bin/server.dart';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable:
            '/repo/frontend/build/linux/x64/debug/bundle/agentic_hive',
        isDebugMode: true,
        environment: const {},
        currentDirectory: '/repo',
        fileExists: (path) => path == bundled || path == entrypoint,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, bundled);
      expect(target.arguments, isEmpty);
    });

    test('AGENTIC_HIVE_BACKEND_BIN wins over the bundled server', () {
      const binOverride = '/custom/bin/server';
      const bundled = '/app/backend/bin/server';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/app/agentic_hive',
        isDebugMode: false,
        environment: const {backendBinEnvVar: binOverride},
        currentDirectory: '/app',
        fileExists: (path) => path == binOverride || path == bundled,
      );

      final result = launcher.resolveLaunchTarget();
      expect(result, isA<Success<BackendLaunchTarget>>());
      final target = (result as Success<BackendLaunchTarget>).value;
      expect(target.executable, binOverride);
    });

    test('respects AGENTIC_HIVE_BACKEND_BIN and entrypoint env overrides', () {
      const binOverride = '/custom/bin/server';
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

    test('returns NotFoundFailure naming the bundled path when the server is '
        'missing', () {
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
      final failure = (result as FailureResult<BackendLaunchTarget>).failure;
      expect(failure, isA<NotFoundFailure>());
      expect(failure.message, contains(r'C:\App\backend\bin\server.exe'));
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

      const bundled = '/opt/backend/bin/server';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/opt',
        fileExists: (path) => path == bundled,
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
      expect(startedExe, bundled);
      expect(startedArgs, isEmpty);
      expect(startedMode, ProcessStartMode.detached);
    });

    test('maps ProcessException to NotFoundFailure', () async {
      const bundled = '/opt/backend/bin/server';
      final launcher = backendLauncherFor(
        'linux',
        resolvedExecutable: '/opt/agentic_hive',
        isDebugMode: false,
        environment: const {},
        currentDirectory: '/opt',
        fileExists: (path) => path == bundled,
        startProcess:
            (executable, arguments, {workingDirectory, mode = .normal}) {
              throw const ProcessException(
                '/opt/backend/bin/server',
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
