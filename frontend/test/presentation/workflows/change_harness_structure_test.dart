import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeAgentRepository implements AgentRepository {
  final StreamController<AgentsChangedPayload> _changes =
      StreamController<AgentsChangedPayload>.broadcast();

  Future<void> dispose() => _changes.close();

  @override
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) async =>
      const Success<List<AgentSummary>>(<AgentSummary>[]);

  @override
  Future<Result<AgentDetail>> getAgent(
    String id, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteAgent(String id, {String? workspaceId}) async =>
      const Success<void>(null);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() => _changes.stream;
}

Widget _buildHost(WorkflowNode node, _FakeAgentRepository agentRepo) {
  final now = DateTime.utc(2026, 11, 25, 12);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: <WorkflowNode>[node],
    edges: const <WorkflowEdge>[],
    createdAt: now,
    updatedAt: now,
  );
  return UncontrolledProviderScope(
    container: ProviderContainer.test(
      overrides: [agentRepositoryProvider.overrideWithValue(agentRepo)],
    ),
    child: MaterialApp(
      theme: HiveTheme.dark(),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: NodeVisualScope(
        registry: createNodeVisualRegistry(),
        child: Scaffold(
          body: SizedBox.expand(
            child: WorkflowInspectorPanel(
              state: WorkflowEditorState(
                workflow: workflow,
                savedWorkflow: workflow,
                validation: const WorkflowValidationResult(isValid: true),
                revision: 'rev-1',
                selectedNodeId: node.id,
              ),
              onUpdateMetadata: ({name, description}) {},
              onUpdateNodeLabel: (_, _) {},
              onUpdateNodeConfig: (_, _) {},
              onChangeNodeType: (_, _) async =>
                  const FailureResult<WorkflowResponse>(
                    UnexpectedFailure('unused'),
                  ),
              onToggleEntryNode: (_, {required isEntry}) {},
              onDeleteNode: (_) {},
              onUpdateEdge: (
                _, {
                sourceOutput,
                maxRetries,
                clearMaxRetries = false,
              }) {},
              onDeleteEdge: (_) {},
              onFocusIssue: (_) {},
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  late _FakeAgentRepository agentRepo;

  setUp(() {
    agentRepo = _FakeAgentRepository();
  });

  tearDown(() async {
    await agentRepo.dispose();
  });

  testWidgets('semantics labels, tap targets, and focus order', (tester) async {
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
      config: <String, dynamic>{'effort': 'high'},
    );
    await tester.pumpWidget(_buildHost(node, agentRepo));
    await tester.pumpAndSettle();

    final buttonFinder = find.byKey(const Key('inspector_change_harness'));
    expect(buttonFinder, findsOneWidget);
    expect(tester.getSemantics(buttonFinder).label, contains('Change harness'));
    final buttonSize = tester.getSize(buttonFinder);
    expect(buttonSize.height, greaterThanOrEqualTo(32));

    await tester.tap(buttonFinder);
    await tester.pumpAndSettle();

    final selectFinder = find.byKey(
      const Key('inspector_change_harness_select'),
    );
    expect(selectFinder, findsOneWidget);
    expect(find.bySemanticsLabel('New harness'), findsOneWidget);
    expect(tester.getSize(selectFinder).height, greaterThanOrEqualTo(32));
    expect(
      tester.getTopLeft(buttonFinder).dy,
      lessThan(tester.getTopLeft(selectFinder).dy),
    );

    // Autofocus: focus moves into the picker when it appears.
    final autofocusTarget = FocusManager.instance.primaryFocus;
    expect(autofocusTarget, isNotNull);
    expect(
      find.ancestor(
        of: find.byElementPredicate((e) => e == autofocusTarget!.context),
        matching: selectFinder,
      ),
      findsOneWidget,
    );

    // Focus order: button precedes select.
    Focus.of(tester.element(find.text('Change harness'))).requestFocus();
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final primary = FocusManager.instance.primaryFocus;
    expect(primary, isNotNull);
    expect(
      find.ancestor(
        of: find.byElementPredicate((e) => e == primary!.context),
        matching: selectFinder,
      ),
      findsOneWidget,
    );

    await tester.tap(selectFinder);
    await tester.pumpAndSettle();
    expect(
      find.descendant(
        of: find.byType(MenuItemButton),
        matching: find.byType(HiveIcon),
      ),
      findsNWidgets(3),
    );
    await tester.tap(find.text('Gemini CLI').last);
    await tester.pumpAndSettle();

    final dialogFinder = find.byType(HiveConfirmDialog);
    expect(dialogFinder, findsOneWidget);
    expect(ModalRoute.of(tester.element(dialogFinder))?.isCurrent, isTrue);
    expect(find.text('Switch'), findsOneWidget);
    expect(find.text('Cancel'), findsOneWidget);
  });
}
