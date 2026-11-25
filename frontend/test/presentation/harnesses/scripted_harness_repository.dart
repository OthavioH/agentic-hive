import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';

/// Builds a [HarnessInfo] fixture for skill UI and controller tests.
HarnessInfo harnessWith({
  HarnessId id = HarnessId.claudeCode,
  HarnessStatus status = HarnessStatus.ready,
  HarnessSkillStatus? skill,
  String? skillMessage,
  HarnessMcpStatus mcp = HarnessMcpStatus.installed,
  String? mcpMessage,
  String? version = '1.0.5',
  String? executablePath = '/usr/local/bin/claude',
}) => HarnessInfo(
  id: id,
  displayName: id.displayName,
  status: status,
  version: version,
  executablePath: executablePath,
  mcpStatus: mcp,
  mcpMessage: mcpMessage,
  skillStatus: skill,
  skillMessage: skillMessage,
  checkedAt: DateTime.utc(2026, 11, 20),
);

/// Scripted [HarnessRepository] fake with controllable responses, pending
/// [Completer]s, update stream, and call logs.
final class ScriptedHarnessRepository implements HarnessRepository {
  Completer<Result<List<HarnessInfo>>>? pendingGet;
  Completer<Result<List<HarnessInfo>>>? pendingRefreshAll;
  Completer<Result<HarnessInfo>>? pendingRefreshOne;
  Completer<Result<HarnessInfo>>? pendingInstallMcp;
  Completer<Result<HarnessInfo>>? pendingInstallSkill;
  Completer<Result<HarnessInfo>>? pendingRemoveSkill;

  Result<List<HarnessInfo>> getResult = const Success(<HarnessInfo>[]);
  Result<List<HarnessInfo>> refreshAllResult = const Success(<HarnessInfo>[]);
  Result<HarnessInfo> refreshOneResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  Result<HarnessInfo> installMcpResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  Result<HarnessInfo> installSkillResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  Result<HarnessInfo> removeSkillResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );

  final StreamController<HarnessInfo> updates =
      StreamController<HarnessInfo>.broadcast();

  final List<HarnessId> refreshHarnessCalls = <HarnessId>[];
  final List<HarnessId> installMcpCalls = <HarnessId>[];
  final List<({HarnessId id, bool overwriteModified})> installSkillCalls =
      <({HarnessId id, bool overwriteModified})>[];
  final List<HarnessId> removeSkillCalls = <HarnessId>[];

  @override
  Future<Result<List<HarnessInfo>>> getHarnesses() =>
      pendingGet?.future ?? Future<Result<List<HarnessInfo>>>.value(getResult);

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() =>
      pendingRefreshAll?.future ??
      Future<Result<List<HarnessInfo>>>.value(refreshAllResult);

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) {
    refreshHarnessCalls.add(id);
    return pendingRefreshOne?.future ??
        Future<Result<HarnessInfo>>.value(refreshOneResult);
  }

  @override
  Future<Result<HarnessInfo>> installMcp(HarnessId id) {
    installMcpCalls.add(id);
    return pendingInstallMcp?.future ??
        Future<Result<HarnessInfo>>.value(installMcpResult);
  }

  @override
  Future<Result<HarnessInfo>> installSkill(
    HarnessId id, {
    required bool overwriteModified,
  }) {
    installSkillCalls.add((id: id, overwriteModified: overwriteModified));
    return pendingInstallSkill?.future ??
        Future<Result<HarnessInfo>>.value(installSkillResult);
  }

  @override
  Future<Result<HarnessInfo>> removeSkill(HarnessId id) {
    removeSkillCalls.add(id);
    return pendingRemoveSkill?.future ??
        Future<Result<HarnessInfo>>.value(removeSkillResult);
  }

  @override
  Stream<HarnessInfo> watchHarnessUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}
