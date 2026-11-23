import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';

/// Localization, status mapping, and elapsed-duration helpers for Overview UI.
abstract final class OverviewL10n {
  /// Formats a live elapsed duration from [startedAt] up to [now].
  static String formatElapsed(DateTime startedAt, DateTime now) {
    final elapsed = now.toUtc().difference(startedAt.toUtc());
    if (elapsed.isNegative) return '0s';
    final hours = elapsed.inHours;
    final minutes = elapsed.inMinutes.remainder(60);
    final seconds = elapsed.inSeconds.remainder(60);
    if (hours > 0) return '${hours}h ${minutes}m ${seconds}s';
    if (minutes > 0) return '${minutes}m ${seconds}s';
    return '${elapsed.inSeconds}s';
  }

  /// Maps an [ActiveNodeStatus] to its [HiveNodeStatus] visual shape.
  static HiveNodeStatus nodeStatusFor(ActiveNodeStatus status) {
    return switch (status) {
      ActiveNodeStatus.running => HiveNodeStatus.running,
      ActiveNodeStatus.paused => HiveNodeStatus.paused,
    };
  }

  /// Maps an [ActiveNodeStatus] to a [HiveBadgeTone].
  static HiveBadgeTone nodeBadgeToneFor(ActiveNodeStatus status) {
    return switch (status) {
      ActiveNodeStatus.running => HiveBadgeTone.info,
      ActiveNodeStatus.paused => HiveBadgeTone.warning,
    };
  }

  /// Returns the localized label for [status].
  static String localizeActiveNodeStatus(
    AppLocalizations l10n,
    ActiveNodeStatus status,
  ) {
    return switch (status) {
      ActiveNodeStatus.running => l10n.runsStatusRunning,
      ActiveNodeStatus.paused => l10n.runsStatusPaused,
    };
  }

  /// Maps an arbitrary error or [Failure] to localized copy.
  static String localizeError(AppLocalizations l10n, Object? error) {
    if (error is Failure) {
      return localizeFailure(l10n, error);
    }
    return l10n.overviewFailureUnexpected;
  }

  /// Maps a typed [Failure] to localized copy.
  static String localizeFailure(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.overviewFailureNetwork,
      NotFoundFailure() => l10n.overviewFailureNotFound,
      ValidationFailure() => l10n.overviewFailureValidation,
      ConflictFailure() ||
      BackendFailure(statusCode: 409) => l10n.overviewFailureConflict,
      BackendFailure() => l10n.overviewFailureBackend,
      UnexpectedFailure() => l10n.overviewFailureUnexpected,
    };
  }
}
