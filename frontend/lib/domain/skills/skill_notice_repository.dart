import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Repository for retrieving, dismissing, and observing automatic skill
/// install notices from the backend.
abstract interface class SkillNoticeRepository {
  /// Fetches the currently pending automatic install notice, if any.
  Future<Result<SkillAutoInstallNotice?>> getPendingNotice();

  /// Dismisses the currently pending automatic install notice on the backend.
  Future<Result<void>> dismissNotice();

  /// Broadcast stream of newly recorded automatic install notices.
  Stream<SkillAutoInstallNotice> watchNotices();
}
