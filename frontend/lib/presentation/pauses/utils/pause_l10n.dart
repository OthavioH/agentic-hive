import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';

/// Centralized presentation mapping for [PauseKind].
extension PauseKindPresentation on PauseKind {
  /// Returns the localized badge label for this [PauseKind].
  String label(AppLocalizations l10n) => switch (this) {
    PauseKind.humanApproval => l10n.pausesKindApproval,
    PauseKind.askHuman => l10n.pausesKindQuestion,
  };

  /// Returns the semantic [HiveBadgeTone] for this [PauseKind].
  HiveBadgeTone get badgeTone => switch (this) {
    PauseKind.humanApproval => HiveBadgeTone.warning,
    PauseKind.askHuman => HiveBadgeTone.info,
  };
}

/// Localization helpers for the Pauses inbox.
abstract final class PauseL10n {
  /// Returns the localized label for [kind].
  static String kindLabel(AppLocalizations l10n, PauseKind kind) =>
      kind.label(l10n);

  /// Formats how long a pause has been waiting since [createdAt].
  static String formatWaitingTime(
    AppLocalizations l10n,
    DateTime createdAt, {
    DateTime? now,
  }) {
    final elapsed = (now ?? DateTime.now().toUtc()).difference(
      createdAt.toUtc(),
    );
    if (elapsed.inMinutes < 1) {
      return l10n.pausesWaitingJustNow;
    }
    if (elapsed.inHours < 1) {
      return l10n.pausesWaitingMinutes(elapsed.inMinutes);
    }
    if (elapsed.inDays < 1) {
      return l10n.pausesWaitingHours(elapsed.inHours);
    }
    return l10n.pausesWaitingDays(elapsed.inDays);
  }

  /// Maps an error object or [Failure] to a localized display message from
  /// [AppLocalizations], never exposing raw backend error strings.
  static String localizeError(AppLocalizations l10n, Object? error) {
    if (error is Failure) {
      return localizeFailure(l10n, error);
    }
    return l10n.pausesUnknownError;
  }

  /// Returns localized copy for a typed [Failure].
  static String localizeFailure(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      NetworkFailure() => l10n.pausesFailureNetwork,
      NotFoundFailure() => l10n.pausesFailureNotFound,
      ValidationFailure() => l10n.pausesFailureValidation,
      ConflictFailure() ||
      BackendFailure(statusCode: 409) => l10n.pausesConflictMessage,
      BackendFailure() => l10n.pausesFailureBackend,
      UnexpectedFailure() => l10n.pausesUnknownError,
    };
  }
}
