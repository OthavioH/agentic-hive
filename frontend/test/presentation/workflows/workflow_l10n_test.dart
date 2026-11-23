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

    test('maps other BackendFailures to the generic backend copy', () {
      const failure = BackendFailure('x', code: ApiErrorCode.conflict);
      expect(
        WorkflowL10n.localizeFailure(l10n, failure),
        l10n.workflowsFailureBackend,
      );
    });
  });
}
