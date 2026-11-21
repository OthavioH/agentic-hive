import 'package:agentic_hive_frontend/core/result/failure.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Localization helpers for the Pauses inbox.
abstract final class PauseL10n {
  /// Returns the localized label for [kind].
  static String kindLabel(AppLocalizations l10n, PauseKind kind) =>
      switch (kind) {
        PauseKind.humanApproval => l10n.pausesKindApproval,
        PauseKind.askHuman => l10n.pausesKindQuestion,
      };

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

  /// Maps an error object or [Failure] to a localized display message.
  static String localizeError(AppLocalizations l10n, Object error) {
    if (error is Failure) {
      return error.message.isNotEmpty ? error.message : l10n.pausesUnknownError;
    }
    return l10n.pausesUnknownError;
  }
}
