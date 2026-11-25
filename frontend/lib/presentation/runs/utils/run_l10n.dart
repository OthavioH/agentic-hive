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
      ConflictFailure() ||
      BackendFailure(statusCode: 409) => l10n.runsFailureConflict,
      BackendFailure() => l10n.runsFailureBackend,
      UnexpectedFailure() => l10n.runsFailureUnexpected,
    };
  }

  /// Returns whether [failure] represents a 409 Conflict response.
  static bool isConflict(Failure failure) {
    return failure is ConflictFailure ||
        (failure is BackendFailure && failure.statusCode == 409);
  }

  /// Returns the localized label for [status].
  static String localizeStatus(AppLocalizations l10n, RunStatus status) {
    return switch (status) {
      RunStatus.running => l10n.runsStatusRunning,
      RunStatus.paused => l10n.runsStatusPaused,
      RunStatus.cancelling => l10n.runsStatusCancelling,
      RunStatus.cancellationUncertain => l10n.runsStatusCancellationUncertain,
      RunStatus.interrupted => l10n.runsStatusInterrupted,
      RunStatus.succeeded => l10n.runsStatusSucceeded,
      RunStatus.failed => l10n.runsStatusFailed,
      RunStatus.cancelled => l10n.runsStatusCancelled,
    };
  }

  /// Returns the localized label for a [HiveNodeStatus].
  static String localizeNodeStatus(
    AppLocalizations l10n,
    HiveNodeStatus status,
  ) {
    return switch (status) {
      HiveNodeStatus.idle => l10n.runsStatusIdle,
      HiveNodeStatus.running => l10n.runsStatusRunning,
      HiveNodeStatus.paused => l10n.runsStatusPaused,
      HiveNodeStatus.cancelling => l10n.runsStatusCancelling,
      HiveNodeStatus.cancellationUncertain =>
        l10n.runsStatusCancellationUncertain,
      HiveNodeStatus.interrupted => l10n.runsStatusInterrupted,
      HiveNodeStatus.succeeded => l10n.runsStatusSucceeded,
      HiveNodeStatus.failed => l10n.runsStatusFailed,
      HiveNodeStatus.cancelled => l10n.runsStatusCancelled,
    };
  }

  /// Maps a [RunStatus] to its [HiveNodeStatus] visual shape and color.
  static HiveNodeStatus nodeStatusFor(RunStatus status) {
    return switch (status) {
      RunStatus.running => HiveNodeStatus.running,
      RunStatus.paused => HiveNodeStatus.paused,
      RunStatus.cancelling => HiveNodeStatus.cancelling,
      RunStatus.cancellationUncertain => HiveNodeStatus.cancellationUncertain,
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
      RunStatus.cancelling => HiveBadgeTone.warning,
      RunStatus.cancellationUncertain => HiveBadgeTone.danger,
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
      RunEventType.runCancelling ||
      RunEventType.runInterrupted ||
      RunEventType.nodeRetried ||
      RunEventType.snapshotWarning ||
      RunEventType.warning => HiveBadgeTone.warning,
      RunEventType.runSucceeded ||
      RunEventType.nodeCompleted ||
      RunEventType.snapshotRestored => HiveBadgeTone.success,
      RunEventType.runFailed ||
      RunEventType.runCancellationUncertain ||
      RunEventType.nodeFailed => HiveBadgeTone.danger,
      RunEventType.runCancelled ||
      RunEventType.checkpointSaved ||
      RunEventType.snapshotCaptured => HiveBadgeTone.neutral,
    };
  }

  /// Formats [timestamp] in local time for display.
  static String formatTimestamp(DateTime timestamp) =>
      _timestampFormat.format(timestamp.toLocal());

  /// Formats the elapsed duration between [startedAt] and [finishedAt] for a
  /// run in [status].
  static String formatDuration(
    AppLocalizations l10n,
    RunStatus status,
    DateTime startedAt,
    DateTime? finishedAt,
  ) {
    if (finishedAt == null) {
      if (status.isActive) return l10n.runsDurationInProgress;
      if (status == RunStatus.interrupted) return l10n.runsStatusInterrupted;
      return l10n.runsDurationUnavailable;
    }
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

  /// Formats an attachment byte count in KB or MB.
  static String formatAttachmentSize(AppLocalizations l10n, int bytes) {
    // shortcut: toStringAsFixed is not locale-aware; use NumberFormat when a
    // 2nd locale lands.
    if (bytes < 1024 * 1024) {
      return l10n.attachmentSizeKb((bytes / 1024).toStringAsFixed(1));
    }
    return l10n.attachmentSizeMb((bytes / 1048576).toStringAsFixed(1));
  }

  /// Pretty-prints [value] as indented JSON, returning an empty string when
  /// [value] is an empty map.
  static String prettyJsonMap(JsonMap value) {
    if (value.isEmpty) return '';
    return _prettyJsonEncoder.convert(value);
  }
}
