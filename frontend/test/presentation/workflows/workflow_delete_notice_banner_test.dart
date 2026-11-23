import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_delete_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_delete_notice_banner.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  final workflow = WorkflowSummary(
    id: 'wf-1',
    name: 'Deploy',
    nodeCount: 1,
    edgeCount: 0,
    updatedAt: DateTime.utc(2026),
    hasValidationErrors: false,
  );

  Widget buildBanner(WorkflowDeleteNotice notice) {
    return MaterialApp(
      theme: ThemeData.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: WorkflowDeleteNoticeBanner(
          notice: notice,
          onDismiss: () {},
          onRetry: () {},
          onReload: () {},
        ),
      ),
    );
  }

  testWidgets('shows backend failure message verbatim when non-empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildBanner(
        WorkflowDeleteFailedNotice(
          workflow: workflow,
          failure: const BackendFailure('Disk full'),
          force: false,
        ),
      ),
    );

    expect(find.text('Disk full'), findsOneWidget);
  });

  testWidgets('localizes backend failure when message is empty', (
    tester,
  ) async {
    await tester.pumpWidget(
      buildBanner(
        WorkflowDeleteFailedNotice(
          workflow: workflow,
          failure: const BackendFailure(''),
          force: false,
        ),
      ),
    );

    final context = tester.element(find.byType(WorkflowDeleteNoticeBanner));
    final l10n = AppLocalizations.of(context)!;
    expect(find.text(l10n.workflowsFailureBackend), findsOneWidget);
  });
}
