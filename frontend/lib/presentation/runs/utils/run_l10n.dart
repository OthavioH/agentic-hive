import 'dart:convert';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:intl/intl.dart';

/// Localization, formatting, and visual status mapping helpers for Runs UI.
abstract final class RunL10n {
  static final DateFormat _timestampFormat = DateFormat.yMMMd().add_Hms();
  static const JsonEncoder _prettyJsonEncoder = JsonEncoder.withIndent('  ');

  /// Returns localized copy for a run [Failure] or arbitrary error object.
  static String localizeError(AppLocalizations l10n, Object? error) {
    if (error is Failure) {
      return localizeFailure(l10n, error);
    }
    return l10n.runsFailureUnexpected;
  }

  /// Returns localized copy for a typed [Failure].
  static String localizeFailure(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.runsFailureNetwork,
      NotFoundFailure() => l10n.runsFailureNotFound,
      ValidationFailure() => l10n.runsFailureValidation,
      BackendFailure() => l10n.runsFailureBackend,
      UnexpectedFailure() => l10n.runsFailureUnexpected,
    };
  }

  /// Returns the localized label for [status].
  static String localizeStatus(AppLocalizations l10n, RunStatus status) {
    return switch (status) {
      RunStatus.running => l10n.runsStatusRunning,
      RunStatus.paused => l10n.runsStatusPaused,
      RunStatus.interrupted => l10n.runsStatusInterrupted,
      RunStatus.succeeded => l10n.runsStatusSucceeded,
      RunStatus.failed => l10n.runsStatusFailed,
      RunStatus.cancelled => l10n.runsStatusCancelled,
    };
  }

  /// Maps a [RunStatus] to its [HiveNodeStatus] visual shape and color.
  static HiveNodeStatus nodeStatusFor(RunStatus status) {
    return switch (status) {
      RunStatus.running => HiveNodeStatus.running,
      RunStatus.paused => HiveNodeStatus.paused,
      RunStatus.interrupted => HiveNodeStatus.interrupted,
      RunStatus.succeeded => HiveNodeStatus.succeeded,
      RunStatus.failed => HiveNodeStatus.failed,
      RunStatus.cancelled => HiveNodeStatus.cancelled,
    };
  }

  /// Maps a [RunStatus] to a [HiveBadgeTone].
  static HiveBadgeTone badgeToneFor(RunStatus status) {
    return switch (status) {
      RunStatus.running => HiveBadgeTone.info,
      RunStatus.paused => HiveBadgeTone.warning,
      RunStatus.interrupted => HiveBadgeTone.warning,
      RunStatus.succeeded => HiveBadgeTone.success,
      RunStatus.failed => HiveBadgeTone.danger,
      RunStatus.cancelled => HiveBadgeTone.neutral,
    };
  }

  /// Maps a [RunEventType] to a [HiveBadgeTone].
  static HiveBadgeTone eventToneFor(RunEventType type) {
    return switch (type) {
      RunEventType.runStarted ||
      RunEventType.runResumed ||
      RunEventType.nodeStarted => HiveBadgeTone.info,
      RunEventType.runPaused ||
      RunEventType.runInterrupted ||
      RunEventType.nodeRetried => HiveBadgeTone.warning,
      RunEventType.runSucceeded ||
      RunEventType.nodeCompleted => HiveBadgeTone.success,
      RunEventType.runFailed || RunEventType.nodeFailed => HiveBadgeTone.danger,
      RunEventType.runCancelled ||
      RunEventType.checkpointSaved => HiveBadgeTone.neutral,
    };
  }

  /// Formats [timestamp] in local time for display.
  static String formatTimestamp(DateTime timestamp) =>
      _timestampFormat.format(timestamp.toLocal());

  /// Formats the elapsed duration between [startedAt] and [finishedAt].
  static String formatDuration(
    AppLocalizations l10n,
    DateTime startedAt,
    DateTime? finishedAt,
  ) {
    if (finishedAt == null) return l10n.runsDurationInProgress;
    final duration = finishedAt.difference(startedAt);
    if (duration.isNegative) return '0s';
    final hours = duration.inHours;
    final minutes = duration.inMinutes.remainder(60);
    final seconds = duration.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    if (duration.inSeconds > 0) return '${duration.inSeconds}s';
    return '${duration.inMilliseconds}ms';
  }

  /// Pretty-prints [value] as indented JSON, returning an empty string when
  /// [value] is an empty map.
  static String prettyJsonMap(JsonMap value) {
    if (value.isEmpty) return '';
    return _prettyJsonEncoder.convert(value);
  }
}
