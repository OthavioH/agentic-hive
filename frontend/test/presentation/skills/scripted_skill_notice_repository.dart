import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/skills/skill_notice_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Scripted [SkillNoticeRepository] fake for notice controller and UI tests.
final class ScriptedSkillNoticeRepository implements SkillNoticeRepository {
  Completer<Result<SkillAutoInstallNotice?>>? pendingGet;
  Result<SkillAutoInstallNotice?> getResult =
      const Success<SkillAutoInstallNotice?>(null);
  Result<void> dismissResult = const Success<void>(null);
  int dismissCalls = 0;

  final StreamController<SkillAutoInstallNotice> notices =
      StreamController<SkillAutoInstallNotice>.broadcast();

  @override
  Future<Result<SkillAutoInstallNotice?>> getPendingNotice() =>
      pendingGet?.future ??
      Future<Result<SkillAutoInstallNotice?>>.value(getResult);

  @override
  Future<Result<void>> dismissNotice() async {
    dismissCalls++;
    return dismissResult;
  }

  @override
  Stream<SkillAutoInstallNotice> watchNotices() => notices.stream;

  Future<void> dispose() => notices.close();
}
