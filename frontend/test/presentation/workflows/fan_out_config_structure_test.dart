import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_reference_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_reference_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../workspace/fake_workspace_repository.dart';
import 'scripted_workflow_repository.dart';

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  String? savedId;

  @override
  Future<String?> load() async => savedId;

  @override
  Future<void> save(String? workspaceId) async {
    savedId = workspaceId;
  }
}

final class _FakeAgentRepository implements AgentRepository {
  @override
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<AgentSummary>[]);

  @override
  Future<Result<AgentDetail>> getAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<AgentDetail>> createAgent(
    CreateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<AgentDetail>> updateAgent(
    String id,
    UpdateAgentRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteAgent(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success<void>(null);

  @override
  Stream<AgentsChangedPayload> watchAgentChanges() =>
      const Stream<AgentsChangedPayload>.empty();
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  new({this.onListWorkflows});

  final Future<Result<List<WorkflowSummary>>> Function()? onListWorkflows;
  final DateTime now = DateTime.utc(2026, 11, 21);

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) {
    if (onListWorkflows != null) return onListWorkflows!();
    return Future<Result<List<WorkflowSummary>>>.value(
      Success<List<WorkflowSummary>>(<WorkflowSummary>[
        WorkflowSummary(
          id: 'wf-planner',
          name: 'Planner',
          nodeCount: 1,
          edgeCount: 0,
          hasValidationErrors: false,
          updatedAt: now,
        ),
        WorkflowSummary(
          id: 'wf-release',
          name: 'Release',
          nodeCount: 2,
          edgeCount: 1,
          hasValidationErrors: false,
          updatedAt: now,
        ),
      ]),
    );
  }

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    DefinitionScope scope = const GlobalScope(),
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
    String? revision,
    bool force = false,
  }) => const Stream<WorkflowDeletionUpdate>.empty();

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
}

final class _FakeWorkflowReferenceRepository
    implements WorkflowReferenceRepository {
  Result<List<WorkflowReference>> nextResult = const Success(
    <WorkflowReference>[],
  );

  @override
  Future<Result<List<WorkflowReference>>> getReferences(
    String workflowId, {
    DefinitionScope scope = const GlobalScope(),
  }) async => nextResult;
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

WorkflowNode _fanOutNode({
  String id = 'fan',
  String label = 'Fan',
  JsonMap extra = const <String, Object?>{},
}) => WorkflowNode(
  id: id,
  type: NodeTypeId.fanOut,
  label: label,
  config: <String, Object?>{
    ...NodeDescriptors.fanOut.defaultConfig(),
    ...extra,
  },
  position: const WorkflowPosition(x: 100, y: 100),
);

WorkflowNode _plannerNode() => const WorkflowNode(
  id: 'planner',
  type: NodeTypeId.claudeCode,
  label: 'Planner',
  position: WorkflowPosition(x: 0, y: 0),
);

WorkflowNode _reviewerNode() => const WorkflowNode(
  id: 'reviewer',
  type: NodeTypeId.codex,
  label: 'Reviewer',
  position: WorkflowPosition(x: 200, y: 0),
);

WorkflowEditorState _stateWith({
  required List<WorkflowNode> nodes,
  String? selectedNodeId,
}) {
  final now = DateTime.utc(2026, 11, 21, 4);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: nodes,
    edges: const <WorkflowEdge>[],
    entryNodeId: nodes.isNotEmpty ? nodes.first.id : null,
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

Future<void> _pumpInspector(
  WidgetTester tester, {
  required WorkflowNode fanNode,
  WorkflowRepository? workflowRepository,
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  await tester.pumpWidget(const SizedBox.shrink());

  final nodes = <WorkflowNode>[_plannerNode(), _reviewerNode(), fanNode];
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: <Override>[
        agentRepositoryProvider.overrideWithValue(_FakeAgentRepository()),
        workflowRepositoryProvider.overrideWithValue(
          workflowRepository ?? _FakeWorkflowRepository(),
        ),
        workspaceRepositoryProvider.overrideWithValue(
          FakeWorkspaceRepository(workspaces: <Workspace>[makeWorkspace()]),
        ),
        workspaceSelectionStoreProvider.overrideWithValue(
          _FakeSelectionStore(),
        ),
      ],
      child: _wrapWithHost(
        WorkflowInspectorPanel(
          state: _stateWith(nodes: nodes, selectedNodeId: fanNode.id),
          onUpdateMetadata: ({name, description}) {},
          onUpdateNodeLabel: (_, _) {},
          onUpdateNodeConfig: (_, _) {},
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
  );
}

WorkflowSummary _workflowSummary({
  String id = 'wf-1',
  String name = 'Child Flow',
}) => WorkflowSummary(
  id: id,
  name: name,
  nodeCount: 2,
  edgeCount: 1,
  hasValidationErrors: false,
  updatedAt: DateTime.utc(2026, 11, 20, 12),
  revision: 'r1',
);

Future<void> _pumpWorkflowsPage(
  WidgetTester tester,
  ScriptedWorkflowRepository repo,
  _FakeWorkflowReferenceRepository refRepo,
) async {
  tester.view.physicalSize = const Size(1440, 900);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  addTearDown(() async {
    for (final controller in repo.live) {
      await controller.close();
    }
  });

  final router = GoRouter(
    initialLocation: '/workflows',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: WorkflowsPage()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        workflowRepositoryProvider.overrideWithValue(repo),
        workflowReferenceRepositoryProvider.overrideWithValue(refRepo),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        theme: HiveTheme.dark(),
        routerConfig: router,
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  group('FanOutConfigForm structure guards', () {
    testWidgets('eight fields in order', (tester) async {
      await _pumpInspector(tester, fanNode: _fanOutNode());
      await tester.pumpAndSettle();

      const keys = <Key>[
        Key('config_fan_out_workflow'),
        Key('config_fan_out_items_node'),
        Key('config_fan_out_items_path'),
        Key('config_fan_out_input_field'),
        Key('config_fan_out_overrides_field'),
        Key('config_fan_out_name_field'),
        Key('config_fan_out_concurrency'),
        Key('config_fan_out_max_items'),
      ];

      var previousTop = double.negativeInfinity;
      for (final key in keys) {
        final finder = find.byKey(key);
        expect(finder, findsOneWidget);
        await tester.ensureVisible(finder);
        await tester.pumpAndSettle();
        final top = tester.getTopLeft(finder).dy;
        expect(top, greaterThan(previousTop));
        previousTop = top;
      }
    });

    testWidgets('labels and hints', (tester) async {
      await _pumpInspector(tester, fanNode: _fanOutNode());
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      final expectedLabels = <String>[
        l10n.nodeConfigFanOutWorkflowLabel,
        l10n.nodeConfigFanOutItemsNodeLabel,
        l10n.nodeConfigFanOutItemsPathLabel,
        l10n.nodeConfigFanOutInputFieldLabel,
        l10n.nodeConfigFanOutOverridesFieldLabel,
        l10n.nodeConfigFanOutNameFieldLabel,
        l10n.nodeConfigFanOutConcurrencyLabel,
        l10n.nodeConfigFanOutMaxItemsLabel,
      ];
      for (final label in expectedLabels) {
        expect(find.text(label), findsWidgets);
      }

      final concurrencyField = tester.widget<HiveTextField>(
        find.byKey(const Key('config_fan_out_concurrency')),
      );
      final maxItemsField = tester.widget<HiveTextField>(
        find.byKey(const Key('config_fan_out_max_items')),
      );
      expect(concurrencyField.controller!.text, '2');
      expect(maxItemsField.controller!.text, '20');
    });

    testWidgets('fresh node shows required errors', (tester) async {
      await _pumpInspector(tester, fanNode: _fanOutNode());
      await tester.pumpAndSettle();

      expect(find.text('Must not be blank.'), findsNWidgets(3));
    });

    testWidgets('integer error', (tester) async {
      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(
          extra: const <String, Object?>{
            'workflowId': 'wf-release',
            'itemsNodeId': 'planner',
            'itemsPath': 'issues',
          },
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      await tester.ensureVisible(
        find.byKey(const Key('config_fan_out_concurrency')),
      );
      await tester.enterText(
        find.byKey(const Key('config_fan_out_concurrency')),
        '0',
      );
      await tester.pump();

      expect(find.text(l10n.nodeConfigFanOutPositiveIntError), findsOneWidget);
    });

    testWidgets('workflow select states', (tester) async {
      final completer = Completer<Result<List<WorkflowSummary>>>();
      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(),
        workflowRepository: _FakeWorkflowRepository(
          onListWorkflows: () => completer.future,
        ),
      );
      await tester.pump();
      await tester.pump();

      var l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      expect(
        find.text(l10n.nodeConfigFanOutWorkflowLoadingHint),
        findsOneWidget,
      );

      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(),
        workflowRepository: _FakeWorkflowRepository(
          onListWorkflows: () async =>
              const FailureResult(NetworkFailure('offline')),
        ),
      );
      await tester.pumpAndSettle();
      l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      expect(find.text(l10n.nodeConfigFanOutWorkflowLoadError), findsOneWidget);

      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(),
        workflowRepository: _FakeWorkflowRepository(
          onListWorkflows: () async => const Success(<WorkflowSummary>[]),
        ),
      );
      await tester.pumpAndSettle();
      l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      expect(find.text(l10n.nodeConfigFanOutWorkflowEmptyHint), findsOneWidget);

      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(
          extra: const <String, Object?>{'workflowId': 'wf-release'},
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Release'), findsOneWidget);

      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(
          extra: const <String, Object?>{'workflowId': 'missing-id'},
        ),
      );
      await tester.pumpAndSettle();
      l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowInspectorPanel)),
      )!;
      expect(
        find.text(l10n.nodeConfigFanOutWorkflowMissingError('missing-id')),
        findsOneWidget,
      );
    });
  });

  group('WorkflowsPage delete dialog references structure guards', () {
    testWidgets('delete dialog lists references', (tester) async {
      final repo = ScriptedWorkflowRepository()..items.add(_workflowSummary());
      final refRepo = _FakeWorkflowReferenceRepository()
        ..nextResult = const Success(<WorkflowReference>[
          WorkflowReference(
            workflowId: 'wf-p',
            workflowName: 'Planner',
            nodeIds: <String>['n1'],
          ),
          WorkflowReference(
            workflowId: 'wf-r',
            workflowName: 'Release',
            nodeIds: <String>['n2'],
          ),
        ]);
      await _pumpWorkflowsPage(tester, repo, refRepo);

      await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowsPage)),
      )!;
      expect(
        find.textContaining(
          '${l10n.workflowsDeleteMessage('Child Flow')}\n\n'
          'Used by fan-out nodes in: Planner, Release',
        ),
        findsOneWidget,
      );

      await tester.tap(find.text(l10n.workflowsCancelAction));
      await tester.pumpAndSettle();

      refRepo.nextResult = const Success(<WorkflowReference>[]);
      await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
      await tester.pumpAndSettle();
      expect(find.textContaining('Used by fan-out nodes in'), findsNothing);

      await tester.tap(find.text(l10n.workflowsCancelAction));
      await tester.pumpAndSettle();

      refRepo.nextResult = const FailureResult<List<WorkflowReference>>(
        NetworkFailure('offline'),
      );
      await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
      await tester.pumpAndSettle();
      expect(
        find.text(l10n.workflowsDeleteMessage('Child Flow')),
        findsOneWidget,
      );
    });
  });
}
