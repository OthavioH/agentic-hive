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
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeAgentRepository implements AgentRepository {
  final StreamController<AgentsChangedPayload> _changes =
      StreamController<AgentsChangedPayload>.broadcast();

  Future<void> dispose() => _changes.close();

  @override
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) {
    return Future<Result<List<AgentSummary>>>.value(
      const Success<List<AgentSummary>>(<AgentSummary>[]),
    );
  }

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

Widget _wrapWithHost(Widget child) {
  return NodeVisualScope(
    registry: createNodeVisualRegistry(),
    child: MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: HiveTheme.dark(),
      home: Scaffold(body: child),
    ),
  );
}

Future<void> _pumpWithHost(WidgetTester tester, Widget child) {
  final repo = _FakeAgentRepository();
  addTearDown(repo.dispose);
  return tester.pumpWidget(
    ProviderScope(
      overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      child: _wrapWithHost(child),
    ),
  );
}

WorkflowEditorState _stateWith({
  required List<WorkflowNode> nodes,
  required String selectedNodeId,
}) {
  final now = DateTime.utc(2026, 11, 21, 4);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: nodes,
    edges: const <WorkflowEdge>[],
    entryNodeId: nodes.first.id,
    createdAt: now,
    updatedAt: now,
  );
  return WorkflowEditorState(
    workflow: workflow,
    savedWorkflow: workflow,
    validation: const WorkflowValidationResult(isValid: true),
    selectedNodeId: selectedNodeId,
  );
}

WorkflowNode _terminalNode(String id, String label) {
  return WorkflowNode(
    id: id,
    type: NodeTypeId.terminal,
    label: label,
    config: NodeDescriptors.of(NodeTypeId.terminal)!.defaultConfig(),
    position: const WorkflowPosition(x: 0, y: 0),
  );
}

WorkflowNode _approvalNode([JsonMap extra = const <String, dynamic>{}]) {
  return WorkflowNode(
    id: 'n1',
    type: NodeTypeId.humanApproval,
    label: 'Approval Gate',
    config: <String, dynamic>{
      ...NodeDescriptors.of(NodeTypeId.humanApproval)!.defaultConfig(),
      ...extra,
    },
    position: const WorkflowPosition(x: 200, y: 0),
  );
}

Future<void> _pumpApproval(
  WidgetTester tester,
  WorkflowNode approval, {
  Key? panelKey,
}) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  final nodes = <WorkflowNode>[
    _terminalNode('planner', 'Planner'),
    _terminalNode('reviewer', 'Reviewer'),
    approval,
  ];
  return _pumpWithHost(
    tester,
    WorkflowInspectorPanel(
      key: panelKey,
      state: _stateWith(nodes: nodes, selectedNodeId: approval.id),
      onUpdateMetadata: ({name, description}) {},
      onUpdateNodeLabel: (_, _) {},
      onUpdateNodeConfig: (_, _) {},
      onToggleEntryNode: (_, {required isEntry}) {},
      onDeleteNode: (_) {},
      onUpdateEdge: (_, {sourceOutput, maxRetries, clearMaxRetries = false}) {},
      onDeleteEdge: (_) {},
      onFocusIssue: (_) {},
    ),
  );
}

void main() {
  const titleKey = Key('config_human_title');
  const instructionsKey = Key('config_human_instructions');
  const allowFeedbackKey = Key('config_human_allow_feedback');
  const proposalNodeKey = Key('config_human_proposal_node');
  const proposalPathKey = Key('config_human_proposal_path');
  const proposalSchemaKey = Key('config_human_proposal_schema');

  void expectStrictlyIncreasingTops(WidgetTester tester, List<Key> keys) {
    final tops = <double>[
      for (final key in keys) tester.getTopLeft(find.byKey(key)).dy,
    ];
    for (var i = 0; i < tops.length - 1; i++) {
      expect(
        tops[i],
        lessThan(tops[i + 1]),
        reason:
            '${keys[i]} (dy=${tops[i]}) must precede '
            '${keys[i + 1]} (dy=${tops[i + 1]})',
      );
    }
  }

  group('HumanApprovalConfigForm proposal structure guard', () {
    testWidgets('no source', (tester) async {
      await _pumpApproval(tester, _approvalNode());
      await tester.pumpAndSettle();

      const orderedKeys = <Key>[
        titleKey,
        instructionsKey,
        allowFeedbackKey,
        proposalNodeKey,
      ];
      for (final key in orderedKeys) {
        expect(find.byKey(key), findsOneWidget);
      }
      expectStrictlyIncreasingTops(tester, orderedKeys);
      expect(find.byKey(proposalPathKey), findsNothing);
      expect(find.byKey(proposalSchemaKey), findsNothing);
      expect(find.text('Proposal'), findsOneWidget);
    });

    testWidgets('with source', (tester) async {
      await _pumpApproval(
        tester,
        _approvalNode(const <String, dynamic>{
          'proposalNodeId': 'planner',
          'proposalPath': 'issues',
          'proposalSchema': '{"type":"array"}',
        }),
      );
      await tester.pumpAndSettle();

      const orderedKeys = <Key>[
        titleKey,
        instructionsKey,
        allowFeedbackKey,
        proposalNodeKey,
        proposalPathKey,
        proposalSchemaKey,
      ];
      for (final key in orderedKeys) {
        expect(find.byKey(key), findsOneWidget);
      }
      expectStrictlyIncreasingTops(tester, orderedKeys);

      final nodeLeft = tester.getTopLeft(find.byKey(proposalNodeKey)).dx;
      final nodeWidth = tester.getSize(find.byKey(proposalNodeKey)).width;
      for (final key in <Key>[proposalPathKey, proposalSchemaKey]) {
        expect(tester.getTopLeft(find.byKey(key)).dx, nodeLeft);
        expect(tester.getSize(find.byKey(key)).width, nodeWidth);
      }
    });

    testWidgets('select options', (tester) async {
      await _pumpApproval(tester, _approvalNode());
      await tester.pumpAndSettle();

      final selectFinder = find.byKey(proposalNodeKey);
      await tester.ensureVisible(selectFinder);
      await tester.tap(selectFinder);
      await tester.pumpAndSettle();

      const expectedLabels = <String>['None', 'Planner', 'Reviewer'];
      final itemTops = <double>[];
      for (final label in expectedLabels) {
        final itemFinder = find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text(label),
        );
        expect(itemFinder, findsOneWidget);
        itemTops.add(tester.getTopLeft(itemFinder).dy);
      }
      for (var i = 0; i < itemTops.length - 1; i++) {
        expect(
          itemTops[i],
          lessThan(itemTops[i + 1]),
          reason: '${expectedLabels[i]} must precede ${expectedLabels[i + 1]}',
        );
      }
      expect(
        find.descendant(
          of: find.byType(MenuItemButton),
          matching: find.text('Approval Gate'),
        ),
        findsNothing,
      );
    });

    testWidgets('issue copy', (tester) async {
      final approval = _approvalNode(const <String, dynamic>{
        'proposalNodeId': 'planner',
        'proposalPath': '',
      });
      final pathIssues = HumanApprovalNodeConfig.fromJson(approval.config)
          .validate()
          .where((i) => i.field == 'proposalPath')
          .toList();
      expect(pathIssues, hasLength(1));

      await _pumpApproval(tester, approval);
      await tester.pumpAndSettle();

      expect(find.text(pathIssues.single.message), findsOneWidget);
    });

    testWidgets('dangling', (tester) async {
      await _pumpApproval(
        tester,
        _approvalNode(const <String, dynamic>{'proposalNodeId': 'gone'}),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException(), isNull);
      expect(find.text('gone'), findsOneWidget);
    });
  });
}
