import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/restore_availability.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';

/// Localization and visual mapping helpers for the Snapshots panel.
abstract final class SnapshotL10n {
  /// Returns the localized label for a snapshot [kind].
  static String localizeKind(AppLocalizations l10n, SnapshotKind kind) {
    return switch (kind) {
      SnapshotKind.preNode => l10n.snapshotKindPreNode,
      SnapshotKind.safetyPreRestore => l10n.snapshotKindSafetyPreRestore,
    };
  }

  /// Maps a snapshot [kind] to a [HiveBadgeTone].
  static HiveBadgeTone toneFor(SnapshotKind kind) {
    return switch (kind) {
      SnapshotKind.preNode => HiveBadgeTone.neutral,
      SnapshotKind.safetyPreRestore => HiveBadgeTone.warning,
    };
  }

  /// Returns the localized word for a file [changeType].
  static String localizeChange(
    AppLocalizations l10n,
    SnapshotChangeType changeType,
  ) {
    return switch (changeType) {
      SnapshotChangeType.added => l10n.snapshotChangeAdded,
      SnapshotChangeType.modified => l10n.snapshotChangeModified,
      SnapshotChangeType.deleted => l10n.snapshotChangeDeleted,
    };
  }

  /// Maps a file [changeType] to the matching [HiveDiffKind].
  static HiveDiffKind diffKindFor(SnapshotChangeType changeType) {
    return switch (changeType) {
      SnapshotChangeType.added => HiveDiffKind.added,
      SnapshotChangeType.modified => HiveDiffKind.modified,
      SnapshotChangeType.deleted => HiveDiffKind.deleted,
    };
  }

  /// Returns the notice explaining why restore is not [availability], or
  /// `null` when it is available.
  static String? restoreNotice(
    AppLocalizations l10n,
    RestoreAvailability availability,
  ) {
    return switch (availability) {
      RestoreAvailability.available => null,
      RestoreAvailability.runActive => l10n.snapshotsRestoreRunActive,
      RestoreAvailability.gitUnavailable => l10n.snapshotsRestoreGitUnavailable,
      RestoreAvailability.checkFailed => l10n.snapshotsRestoreCheckFailed,
    };
  }

  /// Returns localized copy for a failed restore.
  static String localizeRestoreFailure(AppLocalizations l10n, Failure failure) {
    return switch (failure) {
      ConflictFailure() ||
      BackendFailure(statusCode: 409) => l10n.snapshotsRestoreConflict,
      _ => RunL10n.localizeFailure(l10n, failure),
    };
  }
}
