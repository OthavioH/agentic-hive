import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_graph_view.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeRunRepository implements RunRepository {
  new(this.run, this.events);

  final Run run;
  final List<RunEvent> events;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(run);

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async =>
      Success(RunEventsResponse(items: events, lastSequence: events.length));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => Success(
    RunNodeLogsResponse(
      runId: id,
      nodeId: nodeId,
      attempt: attempt ?? 1,
      availableAttempts: const <int>[1],
    ),
  );

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async => Success(run);

  @override
  Future<Result<Run>> cancelRun(String id) async => Success(run);

  @override
  Future<Result<Run>> resumeRun(String id) async => Success(run);

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

void main() {
  final now = DateTime.utc(2026, 11, 25, 12);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Fallback Flow',
    nodes: const <WorkflowNode>[
      WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 40, y: 40),
      ),
      WorkflowNode(
        id: 'n2',
        type: NodeTypeId.geminiCli,
        label: 'Reviewer',
        position: WorkflowPosition(x: 320, y: 40),
      ),
    ],
    edges: const <WorkflowEdge>[],
    createdAt: now,
    updatedAt: now,
  );

  testWidgets('RunGraphView shows Ran on chip and appends semantics', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: HiveTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NodeVisualScope(
          registry: createNodeVisualRegistry(),
          child: Scaffold(
            body: RunGraphView(
              workflow: workflow,
              nodeStatuses: const <String, HiveNodeStatus>{
                'n1': HiveNodeStatus.succeeded,
                'n2': HiveNodeStatus.succeeded,
              },
              selectedNodeId: 'n1',
              ranOn: const <String, FallbackEntry>{
                'n1': FallbackEntry(harness: NodeTypeId.codex, model: 'gpt-x'),
              },
              onSelectNode: (_) {},
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_graph_node_ran_on_n1')), findsOneWidget);
    expect(find.text('Ran on Codex · gpt-x'), findsOneWidget);
    expect(find.byKey(const Key('run_graph_node_ran_on_n2')), findsNothing);
    expect(
      find.bySemanticsLabel(RegExp('Coder.*Ran on Codex · gpt-x')),
      findsOneWidget,
    );
  });

  testWidgets('Events tab shows fallback summary when from/to are present', (
    tester,
  ) async {
    final run = Run(
      id: 'run-1',
      workflowId: 'wf-1',
      workflowName: 'Fallback Flow',
      workflowDefinition: workflow,
      workspaceRoot: '/tmp/repo',
      status: RunStatus.succeeded,
      startedAt: now,
      finishedAt: DateTime.utc(2026, 11, 25, 12, 0, 5),
    );
    final events = <RunEvent>[
      RunEvent(
        id: 'evt-1',
        runId: 'run-1',
        sequence: 1,
        type: RunEventType.nodeFallback,
        nodeId: 'n1',
        createdAt: now,
        payload: const <String, Object?>{
          'from': <String, Object?>{'harness': NodeTypeId.claudeCode},
          'to': <String, Object?>{
            'harness': NodeTypeId.codex,
            'model': 'gpt-x',
          },
          'reason': 'rate limit',
        },
      ),
      RunEvent(
        id: 'evt-2',
        runId: 'run-1',
        sequence: 2,
        type: RunEventType.nodeFallback,
        nodeId: 'n1',
        createdAt: now,
        payload: const <String, Object?>{'reason': 'missing endpoints'},
      ),
    ];

    await tester.binding.setSurfaceSize(const Size(1280, 800));
    addTearDown(() => tester.binding.setSurfaceSize(null));

    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: ProviderContainer.test(
          overrides: [
            runRepositoryProvider.overrideWithValue(
              _FakeRunRepository(run, events),
            ),
            backendWsMessagesProvider.overrideWith(
              (_) => const Stream<WsEnvelope>.empty(),
            ),
          ],
        ),
        child: MaterialApp(
          theme: HiveTheme.dark(),
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: NodeVisualScope(
            registry: createNodeVisualRegistry(),
            child: const Scaffold(body: RunDetailPage(runId: 'run-1')),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.text('Events'));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('run_event_fallback_summary_evt-1')),
      findsOneWidget,
    );
    expect(
      find.text('Switched from Claude Code to Codex · gpt-x: rate limit'),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('run_event_fallback_summary_evt-2')),
      findsNothing,
    );
  });
}
