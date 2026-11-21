import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/domain/workspace/restore_availability.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

const _gitOk = Success<WorkspaceCapabilities>(
  WorkspaceCapabilities(
    gitAvailable: true,
    isGitRepo: false,
    hasCommits: false,
  ),
);
const _gitMissing = Success<WorkspaceCapabilities>(
  WorkspaceCapabilities(
    gitAvailable: false,
    isGitRepo: false,
    hasCommits: false,
  ),
);

void main() {
  group('RestoreAvailability.resolve', () {
    test('is runActive while the run is running, regardless of git', () {
      expect(
        RestoreAvailability.resolve(
          status: RunStatus.running,
          capabilities: _gitOk,
        ),
        RestoreAvailability.runActive,
      );
    });

    test('is available for every non-running status when git works', () {
      for (final status in RunStatus.values.where(
        (s) => s != RunStatus.running,
      )) {
        expect(
          RestoreAvailability.resolve(status: status, capabilities: _gitOk),
          RestoreAvailability.available,
          reason: status.name,
        );
      }
    });

    test('is gitUnavailable when the capability check denies git', () {
      expect(
        RestoreAvailability.resolve(
          status: RunStatus.failed,
          capabilities: _gitMissing,
        ),
        RestoreAvailability.gitUnavailable,
      );
    });

    test('is checkFailed when capabilities failed or are missing', () {
      expect(
        RestoreAvailability.resolve(
          status: RunStatus.failed,
          capabilities: const FailureResult<WorkspaceCapabilities>(
            NetworkFailure('down'),
          ),
        ),
        RestoreAvailability.checkFailed,
      );
      expect(
        RestoreAvailability.resolve(
          status: RunStatus.failed,
          capabilities: null,
        ),
        RestoreAvailability.checkFailed,
      );
      expect(RestoreAvailability.checkFailed.isAvailable, isFalse);
      expect(RestoreAvailability.available.isAvailable, isTrue);
    });
  });
}
