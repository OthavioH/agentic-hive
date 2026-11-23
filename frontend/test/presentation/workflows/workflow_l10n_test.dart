import 'dart:ui';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/utils/workflow_l10n.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  group('WorkflowL10n.localizeFailure', () {
    test(
      'maps workflow_has_active_runs BackendFailure to the active-runs copy',
      () {
        const failure = BackendFailure(
          'x',
          code: ApiErrorCode.workflowHasActiveRuns,
          statusCode: 409,
        );
        expect(
          WorkflowL10n.localizeFailure(l10n, failure),
          l10n.workflowsFailureActiveRuns,
        );
      },
    );

    test('maps workflow_deleting to workflowsFailureDeleting', () {
      const failure = BackendFailure(
        'x',
        code: ApiErrorCode.workflowDeleting,
        statusCode: 409,
      );
      expect(
        WorkflowL10n.localizeFailure(l10n, failure),
        l10n.workflowsFailureDeleting,
      );
    });

    test('maps other BackendFailures to the generic backend copy', () {
      const failure = BackendFailure('x', code: ApiErrorCode.conflict);
      expect(
        WorkflowL10n.localizeFailure(l10n, failure),
        l10n.workflowsFailureBackend,
      );
    });
  });

  test('delete flow plurals', () {
    expect(
      l10n.workflowsDeleteActiveRunsMessage(1, 'Release Flow'),
      '1 run of "Release Flow" is running. Stop it and delete?',
    );
    expect(
      l10n.workflowsDeleteActiveRunsMessage(2, 'Release Flow'),
      '2 runs of "Release Flow" are running. Stop them and delete?',
    );
    expect(
      l10n.workflowsDeletingStoppingRuns(2, 3),
      'Deleting… (stopping 2 of 3 runs)',
    );
    expect(
      l10n.workflowsDeletingStoppingRuns(0, 1),
      'Deleting… (stopping 0 of 1 run)',
    );
    expect(
      l10n.workflowsDeletePartialNotice(1),
      'Workflow deleted. 1 run could not be confirmed as stopped and was '
      'kept so you can retry.',
    );
    expect(
      l10n.workflowsDeletePartialNotice(3),
      'Workflow deleted. 3 runs could not be confirmed as stopped and were '
      'kept so you can retry.',
    );
    expect(
      l10n.workflowsDeleteKeptRunsDetail(1),
      '1 run could not be confirmed as stopped and was kept so you can retry.',
    );
    expect(
      l10n.workflowsDeleteKeptRunsDetail(2),
      '2 runs could not be confirmed as stopped and were kept so you can '
      'retry.',
    );
  });
}
