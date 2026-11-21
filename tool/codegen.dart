import 'dart:io';

Future<void> main() async {
  const steps = <_CodegenStep>[
    _CodegenStep(
      label: 'flutter pub get (workspace root)',
      executable: 'flutter',
      arguments: ['pub', 'get'],
    ),
    _CodegenStep(
      label: 'build_runner (shared)',
      executable: 'dart',
      arguments: [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: 'shared',
    ),
    _CodegenStep(
      label: 'build_runner (backend)',
      executable: 'dart',
      arguments: [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: 'backend',
    ),
    _CodegenStep(
      label: 'flutter gen-l10n (frontend)',
      executable: 'flutter',
      arguments: ['gen-l10n'],
      workingDirectory: 'frontend',
    ),
    _CodegenStep(
      label: 'build_runner (frontend)',
      executable: 'dart',
      arguments: [
        'run',
        'build_runner',
        'build',
        '--delete-conflicting-outputs',
      ],
      workingDirectory: 'frontend',
    ),
  ];

  for (final step in steps) {
    stdout.writeln('==> ${step.label}');
    final process = await Process.start(
      step.executable,
      step.arguments,
      workingDirectory: step.workingDirectory,
      runInShell: Platform.isWindows,
      mode: ProcessStartMode.inheritStdio,
    );
    final code = await process.exitCode;
    if (code != 0) {
      stderr.writeln('Step "${step.label}" failed with exit code $code.');
      exit(code);
    }
  }

  stdout.writeln('Codegen completed successfully.');
}

final class _CodegenStep {
  const new({
    required this.label,
    required this.executable,
    required this.arguments,
    this.workingDirectory,
  });

  final String label;
  final String executable;
  final List<String> arguments;
  final String? workingDirectory;
}
