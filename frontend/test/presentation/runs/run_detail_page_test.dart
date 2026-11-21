import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeRunRepository implements RunRepository {
  final DateTime now = DateTime.utc(2026, 11, 21, 4, 30);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(
    Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: 'Release Build',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Release Build',
        nodes: const <WorkflowNode>[],
        edges: const <WorkflowEdge>[],
        createdAt: now,
        updatedAt: now,
      ),
      workspacePath: '/projects/hive',
      status: RunStatus.failed,
      startedAt: now,
      finishedAt: DateTime.utc(2026, 11, 21, 4, 30, 15),
      errorMessage: 'Build script exited with 1',
    ),
  );

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: <RunEvent>[
        RunEvent(
          id: 'evt-1',
          runId: id,
          sequence: 1,
          type: RunEventType.nodeStarted,
          nodeId: 'node-build',
          createdAt: now,
          payload: const <String, Object?>{'command': 'dart test'},
        ),
      ],
      lastSequence: 1,
    ),
  );

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      Success(<Checkpoint>[
        Checkpoint(
          id: 'cp-1',
          runId: id,
          sequence: 1,
          completedNodeId: 'node-prep',
          pendingNodeIds: const <String>['node-build'],
          attemptsByEdge: const <String, int>{'edge-prep': 1},
          circuitBreakerCount: 0,
          nodeOutputs: const <String, JsonMap>{
            'node-prep': <String, Object?>{'prepared': true},
          },
          createdAt: now,
        ),
        Checkpoint(
          id: 'cp-2',
          runId: id,
          sequence: 2,
          completedNodeId: 'node-build',
          pendingNodeIds: const <String>[],
          attemptsByEdge: const <String, int>{'edge-build': 2},
          circuitBreakerCount: 1,
          nodeOutputs: const <String, JsonMap>{
            'node-build': <String, Object?>{'exitCode': 1},
          },
          createdAt: DateTime.utc(2026, 11, 21, 4, 30, 15),
        ),
      ]);

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

Widget _buildRouterHost() {
  final router = GoRouter(
    initialLocation: '/runs/run-1',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs',
        builder: (_, _) => const Scaffold(body: Text('runs-list')),
      ),
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) =>
            Scaffold(body: RunDetailPage(runId: state.pathParameters['id']!)),
      ),
    ],
  );

  return MaterialApp.router(
    theme: HiveTheme.light(),
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    routerConfig: router,
  );
}

void main() {
  testWidgets(
    'renders summary, error banner, event payload, and checkpoint inspector',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            runRepositoryProvider.overrideWithValue(_FakeRunRepository()),
          ],
          child: _buildRouterHost(),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('Release Build'), findsOneWidget);
      expect(find.text('/projects/hive'), findsWidgets);
      expect(find.text('Build script exited with 1'), findsOneWidget);

      // Event timeline: expand JSON payload
      expect(find.text('node.started'), findsOneWidget);
      expect(find.byKey(const Key('run_event_payload_evt-1')), findsNothing);
      await tester.tap(find.byKey(const Key('run_event_toggle_evt-1')));
      await tester.pumpAndSettle();
      expect(find.byKey(const Key('run_event_payload_evt-1')), findsOneWidget);
      expect(find.textContaining('"command": "dart test"'), findsOneWidget);

      // Checkpoint inspector: defaults to latest (cp-2), switch to cp-1
      expect(find.textContaining('"exitCode": 1'), findsOneWidget);
      await tester.tap(find.byKey(const Key('checkpoint_chip_cp-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('"prepared": true'), findsOneWidget);
      expect(find.text('node-prep'), findsOneWidget);
    },
  );
}
