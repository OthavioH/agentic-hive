import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_chat_outputs_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final DateTime _now = DateTime.utc(2026, 11, 21, 4, 30);

Checkpoint _checkpoint(String id, int sequence, String nodeId, Object? s) =>
    Checkpoint(
      id: id,
      runId: 'run-1',
      sequence: sequence,
      completedNodeId: nodeId,
      pendingNodeIds: const <String>[],
      attemptsByEdge: const <String, int>{},
      circuitBreakerCount: 0,
      nodeOutputs: <String, JsonMap>{
        nodeId: <String, Object?>{
          'data': <String, Object?>{'summary': s, 'extra': 1},
        },
      },
      createdAt: _now,
    );

RunDetailState _state(List<Checkpoint> checkpoints) => RunDetailState(
  run: Run(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'Flow',
    workflowDefinition: Workflow(
      id: 'wf-1',
      name: 'Flow',
      nodes: const <WorkflowNode>[
        WorkflowNode(
          id: 'a',
          type: 'command',
          label: 'Plan',
          position: WorkflowPosition(x: 0, y: 0),
        ),
        WorkflowNode(
          id: 'b',
          type: 'command',
          label: 'Build',
          position: WorkflowPosition(x: 0, y: 0),
        ),
      ],
      edges: const <WorkflowEdge>[],
      createdAt: _now,
      updatedAt: _now,
    ),
    workspaceRoot: '/projects/hive',
    status: RunStatus.running,
    startedAt: _now,
  ),
  events: const <RunEvent>[],
  checkpoints: checkpoints,
);

Future<void> _pump(WidgetTester tester, RunDetailState state) async {
  tester.view.physicalSize = const Size(900, 700);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  await tester.pumpWidget(
    ProviderScope(
      child: MaterialApp(
        theme: HiveTheme.light(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: Column(
            children: <Widget>[
              Expanded(child: RunChatOutputsPanel(detailState: state)),
            ],
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('shows the empty state when no node published a summary', (
    tester,
  ) async {
    await _pump(tester, _state(<Checkpoint>[_checkpoint('cp-1', 1, 'a', ' ')]));

    expect(find.byKey(const Key('run_chat_outputs_panel')), findsOneWidget);
    expect(find.byKey(const Key('run_chat_outputs_empty')), findsOneWidget);
    expect(find.byKey(const Key('run_chat_outputs_list')), findsNothing);
  });

  testWidgets('renders one plain-text bubble per node with its label', (
    tester,
  ) async {
    await _pump(
      tester,
      _state(<Checkpoint>[
        _checkpoint('cp-1', 1, 'a', 'Planned the work'),
        _checkpoint('cp-2', 2, 'b', 'Built it'),
      ]),
    );

    expect(find.byKey(const Key('run_chat_outputs_empty')), findsNothing);
    expect(find.byKey(const Key('run_chat_outputs_list')), findsOneWidget);
    expect(find.byKey(const Key('run_chat_output_cp-1')), findsOneWidget);
    expect(find.byKey(const Key('run_chat_output_cp-2')), findsOneWidget);
    expect(
      tester.widget<Text>(find.byKey(const Key('run_chat_output_label_cp-1'))),
      isA<Text>().having((t) => t.data, 'data', 'Plan'),
    );
    expect(
      tester.widget<Text>(find.byKey(const Key('run_chat_output_label_cp-2'))),
      isA<Text>().having((t) => t.data, 'data', 'Build'),
    );
    expect(find.text('Planned the work'), findsOneWidget);
    expect(find.text('Built it'), findsOneWidget);
    expect(find.textContaining('{'), findsNothing);
    expect(find.textContaining('extra'), findsNothing);
  });

  testWidgets('bubble text is selectable', (tester) async {
    await _pump(
      tester,
      _state(<Checkpoint>[_checkpoint('cp-1', 1, 'a', 'Copy me')]),
    );

    final text = find.byKey(const Key('run_chat_output_text_cp-1'));
    expect(text, findsOneWidget);
    expect(tester.widget(text), isA<SelectableText>());
  });
}
