import 'package:agentic_hive_backend/src/domain/harnesses/executable_locator.dart';
import 'package:agentic_hive_backend/src/domain/harnesses/process_runner.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Default per-harness probe timeout so a stalled CLI cannot hang detection.
const defaultHarnessProbeTimeout = Duration(seconds: 4);

/// Detects and probes a single concrete CLI harness.
abstract interface class HarnessDetector {
  /// The harness identifier this detector handles.
  HarnessId get id;

  /// Probes the local environment and returns the current [HarnessInfo].
  Future<HarnessInfo> detect();

  /// Sets or clears a custom executable path override for detection.
  void setExecutableOverride(String? path);
}

/// Template-method base for concrete CLI harness detectors.
///
/// Subclasses provide only CLI-specific metadata, arguments, and output
/// interpretation; binary lookup, timeout isolation, and status classification
/// live here.
abstract base class CliHarnessDetector implements HarnessDetector {
  /// Creates a CLI harness detector.
  new({
    required this._executableLocator,
    required this._processRunner,
    this._timeout = defaultHarnessProbeTimeout,
    DateTime Function()? now,
  }) : _now = now ?? DateTime.now;

  final ExecutableLocator _executableLocator;
  final ProcessRunner _processRunner;
  final Duration _timeout;
  final DateTime Function() _now;
  String? _executableOverride;

  @override
  void setExecutableOverride(String? path) {
    final trimmed = path?.trim();
    _executableOverride = (trimmed == null || trimmed.isEmpty) ? null : trimmed;
  }

  /// Binary name to look up on `PATH` (for example `claude` or `agy`).
  String get executableName;

  /// Arguments used to probe the CLI version (defaults to `['--version']`).
  List<String> get versionArgs => const ['--version'];

  /// Optional non-LLM local auth check arguments.
  ///
  /// Defaults to `null` so no extra subprocess is spawned unless a CLI exposes
  /// a free local status command.
  List<String>? get authCheckArgs => null;

  @override
  Future<HarnessInfo> detect() async {
    final executablePath =
        _executableOverride ?? await _executableLocator.locate(executableName);
    if (executablePath == null) {
      return HarnessInfo(
        id: id,
        displayName: id.displayName,
        status: HarnessStatus.notInstalled,
        checkedAt: _now(),
      );
    }

    final versionResult = await _processRunner.run(
      executablePath,
      versionArgs,
      timeout: _timeout,
    );

    if (versionResult.timedOut) {
      return _unavailable(
        executablePath: executablePath,
        errorMessage: 'Timed out while checking ${id.displayName} CLI.',
      );
    }

    if (versionResult.launchError != null) {
      return _unavailable(
        executablePath: executablePath,
        errorMessage: 'Failed to run ${id.displayName} CLI.',
      );
    }

    final parsedVersion = parseVersion(
      versionResult.stdout,
      versionResult.stderr,
    );

    final outdatedMessage = detectOutdated(
      versionResult.exitCode,
      versionResult.stdout,
      versionResult.stderr,
    );
    if (outdatedMessage != null) {
      return HarnessInfo(
        id: id,
        displayName: id.displayName,
        status: HarnessStatus.outdated,
        version: parsedVersion,
        executablePath: executablePath,
        errorMessage: outdatedMessage,
        checkedAt: _now(),
      );
    }

    final authMessage = detectAuthError(
      versionResult.exitCode,
      versionResult.stdout,
      versionResult.stderr,
    );
    if (authMessage != null) {
      return HarnessInfo(
        id: id,
        displayName: id.displayName,
        status: HarnessStatus.authError,
        version: parsedVersion,
        executablePath: executablePath,
        errorMessage: authMessage,
        checkedAt: _now(),
      );
    }

    if (versionResult.exitCode != 0) {
      return _unavailable(
        executablePath: executablePath,
        errorMessage:
            '${id.displayName} CLI exited with code ${versionResult.exitCode}.',
      );
    }

    if (parsedVersion == null) {
      return _unavailable(
        executablePath: executablePath,
        errorMessage: 'Could not parse ${id.displayName} CLI version.',
      );
    }

    final extraAuthArgs = authCheckArgs;
    if (extraAuthArgs != null) {
      final authResult = await _processRunner.run(
        executablePath,
        extraAuthArgs,
        timeout: _timeout,
      );
      if (authResult.timedOut) {
        return _unavailable(
          executablePath: executablePath,
          version: parsedVersion,
          errorMessage: 'Timed out while checking ${id.displayName} auth.',
        );
      }
      final extraOutdated = detectOutdated(
        authResult.exitCode,
        authResult.stdout,
        authResult.stderr,
      );
      if (extraOutdated != null) {
        return HarnessInfo(
          id: id,
          displayName: id.displayName,
          status: HarnessStatus.outdated,
          version: parsedVersion,
          executablePath: executablePath,
          errorMessage: extraOutdated,
          checkedAt: _now(),
        );
      }
      final extraAuth = detectAuthError(
        authResult.exitCode,
        authResult.stdout,
        authResult.stderr,
      );
      if (extraAuth != null) {
        return HarnessInfo(
          id: id,
          displayName: id.displayName,
          status: HarnessStatus.authError,
          version: parsedVersion,
          executablePath: executablePath,
          errorMessage: extraAuth,
          checkedAt: _now(),
        );
      }
    }

    return HarnessInfo(
      id: id,
      displayName: id.displayName,
      status: HarnessStatus.ready,
      version: parsedVersion,
      executablePath: executablePath,
      checkedAt: _now(),
    );
  }

  /// Extracts a semantic version string from [stdout] or [stderr], or `null`.
  String? parseVersion(String stdout, String stderr) {
    final combined = '$stdout\n$stderr';
    final match = _semverPattern.firstMatch(combined);
    return match?.group(1);
  }

  /// Returns a safe user-facing message if the output indicates an outdated
  /// CLI or interactive update prompt, or `null` otherwise.
  String? detectOutdated(int exitCode, String stdout, String stderr) {
    final combined = '$stdout\n$stderr'.toLowerCase();
    for (final pattern in _outdatedPatterns) {
      if (pattern.hasMatch(combined)) {
        return 'Update required. Update ${id.displayName} CLI and re-check.';
      }
    }
    return null;
  }

  /// Returns a safe user-facing message if the output indicates an
  /// authentication failure, or `null` otherwise.
  String? detectAuthError(int exitCode, String stdout, String stderr) {
    final combined = '$stdout\n$stderr'.toLowerCase();
    for (final pattern in _authErrorPatterns) {
      if (pattern.hasMatch(combined)) {
        return 'Authentication required. Sign in with ${id.displayName} CLI '
            'and re-check.';
      }
    }
    return null;
  }

  HarnessInfo _unavailable({
    required String executablePath,
    required String errorMessage,
    String? version,
  }) => HarnessInfo(
    id: id,
    displayName: id.displayName,
    status: HarnessStatus.unavailable,
    version: version,
    executablePath: executablePath,
    errorMessage: errorMessage,
    checkedAt: _now(),
  );

  static final _semverPattern = RegExp(
    r'\bv?(\d+\.\d+\.\d+(?:[-+][0-9A-Za-z.-]+)?)\b',
  );

  static final List<RegExp> _outdatedPatterns = [
    RegExp(r'\bupdate required\b'),
    RegExp(r'\bupgrade required\b'),
    RegExp(r'\bplease update\b'),
    RegExp(r'\bmust update\b'),
    RegExp(r'\bcli is out of date\b'),
    RegExp(r'\boutdated\b'),
    RegExp(r'\bminimum supported version\b'),
    RegExp(r'\bpress enter to update\b'),
    RegExp(r'\bnew version required\b'),
  ];

  static final List<RegExp> _authErrorPatterns = [
    RegExp(r'\bnot logged in\b'),
    RegExp(r'\bnot authenticated\b'),
    RegExp(r'\bauthentication required\b'),
    RegExp(r'\blogin required\b'),
    RegExp(r'\bsign in required\b'),
    RegExp(r'\bunauthorized\b'),
    RegExp(r'\binvalid api key\b'),
    RegExp(r'\bapi key not found\b'),
    RegExp(r'\bplease log in\b'),
    RegExp(r'\bplease sign in\b'),
    RegExp(r'\btoken expired\b'),
    RegExp(r'\bexpired token\b'),
  ];
}

/// Detector for Claude Code (`claude`).
final class ClaudeCodeDetector extends CliHarnessDetector {
  /// Creates a Claude Code detector.
  new({
    required super.executableLocator,
    required super.processRunner,
    super.timeout,
    super.now,
  });

  @override
  HarnessId get id => HarnessId.claudeCode;

  @override
  String get executableName => 'claude';
}

/// Detector for OpenAI Codex (`codex`).
final class CodexDetector extends CliHarnessDetector {
  /// Creates a Codex detector.
  new({
    required super.executableLocator,
    required super.processRunner,
    super.timeout,
    super.now,
  });

  @override
  HarnessId get id => HarnessId.codex;

  @override
  String get executableName => 'codex';
}

/// Detector for Google Gemini CLI (`gemini`).
final class GeminiCliDetector extends CliHarnessDetector {
  /// Creates a Gemini CLI detector.
  new({
    required super.executableLocator,
    required super.processRunner,
    super.timeout,
    super.now,
  });

  @override
  HarnessId get id => HarnessId.geminiCli;

  @override
  String get executableName => 'gemini';
}

/// Detector for Antigravity (`agy`).
final class AntigravityDetector extends CliHarnessDetector {
  /// Creates an Antigravity detector.
  new({
    required super.executableLocator,
    required super.processRunner,
    super.timeout,
    super.now,
  });

  @override
  HarnessId get id => HarnessId.antigravity;

  @override
  String get executableName => 'agy';
}
