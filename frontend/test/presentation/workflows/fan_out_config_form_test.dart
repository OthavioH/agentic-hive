import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_palette.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';

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
  Future<Result<List<AgentSummary>>> listAgents({String? workspaceId}) async =>
      const Success(<AgentSummary>[]);

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
  Stream<AgentsChangedPayload> watchAgentChanges() =>
      const Stream<AgentsChangedPayload>.empty();
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  new({this.onListWorkflows});

  final Future<Result<List<WorkflowSummary>>> Function()? onListWorkflows;
  final DateTime now = DateTime.utc(2026, 11, 21);

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({String? workspaceId}) {
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
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<WorkflowResponse>> duplicateWorkflow(
    String id, {
    String? name,
    String? workspaceId,
  }) async => const FailureResult(NotFoundFailure('unused'));

  @override
  Stream<WorkflowDeletionUpdate> deleteWorkflow(
    String id, {
    String? workspaceId,
    String? revision,
    bool force = false,
  }) => const Stream<WorkflowDeletionUpdate>.empty();

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async => const Success(WorkflowValidationResult(isValid: true));
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
  List<WorkflowNode>? extraNodes,
  WorkflowRepository? workflowRepository,
  ValueChanged<JsonMap>? onConfigChanged,
}) async {
  tester.view.physicalSize = const Size(1100, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final nodes = <WorkflowNode>[_plannerNode(), fanNode, ...?extraNodes];
  await tester.pumpWidget(
    ProviderScope(
      retry: (_, _) => null,
      overrides: [
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
          onUpdateNodeConfig: (_, config) => onConfigChanged?.call(config),
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
  );
}

void main() {
  testWidgets('shows all eight fields in order', (tester) async {
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
    for (final key in keys) {
      expect(find.byKey(key), findsOneWidget);
    }
    var previousTop = double.negativeInfinity;
    for (final key in keys) {
      final top = tester.getTopLeft(find.byKey(key)).dy;
      expect(top, greaterThan(previousTop));
      previousTop = top;
    }
  });

  testWidgets('defaults are 2 and 20', (tester) async {
    await _pumpInspector(tester, fanNode: _fanOutNode());
    await tester.pumpAndSettle();

    final concurrencyField = tester.widget<HiveTextField>(
      find.byKey(const Key('config_fan_out_concurrency')),
    );
    final maxItemsField = tester.widget<HiveTextField>(
      find.byKey(const Key('config_fan_out_max_items')),
    );
    expect(concurrencyField.controller!.text, '2');
    expect(maxItemsField.controller!.text, '20');
  });

  testWidgets('a fresh node shows required errors', (tester) async {
    await _pumpInspector(tester, fanNode: _fanOutNode());
    await tester.pumpAndSettle();

    expect(find.text('Must not be blank.'), findsNWidgets(3));
  });

  testWidgets(
    'child workflow select lists workflows by name and emits the id',
    (tester) async {
      JsonMap? latestConfig;
      await _pumpInspector(
        tester,
        fanNode: _fanOutNode(),
        onConfigChanged: (config) => latestConfig = config,
      );
      await tester.pumpAndSettle();

      await tester.tap(find.byKey(const Key('config_fan_out_workflow')));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Release').last);
      await tester.pumpAndSettle();

      expect(latestConfig, isNotNull);
      expect(FanOutNodeConfig.fromJson(latestConfig!).workflowId, 'wf-release');
    },
  );

  testWidgets('child workflow loading state is disabled with the hint', (
    tester,
  ) async {
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

    final select = tester.widget<HiveSelect<String>>(
      find.byKey(const Key('config_fan_out_workflow')),
    );
    expect(select.onChanged, isNull);
    expect(find.text('Loading workflows…'), findsOneWidget);
  });

  testWidgets('child workflow load error', (tester) async {
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(),
      workflowRepository: _FakeWorkflowRepository(
        onListWorkflows: () async =>
            const FailureResult(NetworkFailure('offline')),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Could not load workflows.'), findsOneWidget);
  });

  testWidgets('child workflow empty state', (tester) async {
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(),
      workflowRepository: _FakeWorkflowRepository(
        onListWorkflows: () async => const Success(<WorkflowSummary>[]),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('No saved workflows'), findsOneWidget);
  });

  testWidgets('missing saved workflow keeps its id and shows the error', (
    tester,
  ) async {
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(
        extra: const <String, Object?>{'workflowId': 'gone'},
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Workflow "gone" was not found.'), findsOneWidget);
    final select = tester.widget<HiveSelect<String>>(
      find.byKey(const Key('config_fan_out_workflow')),
    );
    expect(select.options.any((o) => o.value == 'gone'), isTrue);
  });

  testWidgets('items node select lists other nodes only', (tester) async {
    JsonMap? latestConfig;
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(),
      onConfigChanged: (config) => latestConfig = config,
    );
    await tester.pumpAndSettle();

    final select = tester.widget<HiveSelect<String>>(
      find.byKey(const Key('config_fan_out_items_node')),
    );
    expect(select.options.map((o) => o.label).toList(), <String>['Planner']);
    expect(select.options.any((o) => o.value == 'fan'), isFalse);

    await tester.tap(find.byKey(const Key('config_fan_out_items_node')));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Planner').last);
    await tester.pumpAndSettle();

    expect(latestConfig, isNotNull);
    expect(FanOutNodeConfig.fromJson(latestConfig!).itemsNodeId, 'planner');
  });

  testWidgets('dangling items node keeps its id', (tester) async {
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(
        extra: const <String, Object?>{'itemsNodeId': 'removed'},
      ),
    );
    await tester.pumpAndSettle();

    final select = tester.widget<HiveSelect<String>>(
      find.byKey(const Key('config_fan_out_items_node')),
    );
    expect(select.options.any((o) => o.value == 'removed'), isTrue);
  });

  testWidgets('text fields are trimmed and optional ones omitted when blank', (
    tester,
  ) async {
    JsonMap? latestConfig;
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(
        extra: const <String, Object?>{
          'workflowId': 'wf-release',
          'itemsNodeId': 'planner',
          'itemsPath': 'old',
          'nameField': 'title',
        },
      ),
      onConfigChanged: (config) => latestConfig = config,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('config_fan_out_items_path')),
      '  issues  ',
    );
    await tester.enterText(
      find.byKey(const Key('config_fan_out_name_field')),
      '   ',
    );
    await tester.pump();

    expect(latestConfig, isNotNull);
    final parsed = FanOutNodeConfig.fromJson(latestConfig!);
    expect(parsed.itemsPath, 'issues');
    expect(parsed.nameField, isNull);
  });

  testWidgets('invalid concurrency shows the error and does not emit', (
    tester,
  ) async {
    JsonMap? latestConfig;
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(
        extra: const <String, Object?>{
          'workflowId': 'wf-release',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
        },
      ),
      onConfigChanged: (config) => latestConfig = config,
    );
    await tester.pumpAndSettle();

    for (final bad in const <String>['0', 'abc', '']) {
      latestConfig = null;
      await tester.enterText(
        find.byKey(const Key('config_fan_out_concurrency')),
        bad,
      );
      await tester.pump();
      expect(find.text('Enter a whole number of 1 or more.'), findsOneWidget);
      expect(latestConfig, isNull);
    }

    await tester.enterText(
      find.byKey(const Key('config_fan_out_concurrency')),
      '3',
    );
    await tester.pump();
    expect(find.text('Enter a whole number of 1 or more.'), findsNothing);
    expect(FanOutNodeConfig.fromJson(latestConfig!).concurrency, 3);
  });

  testWidgets('invalid item cap shows the error and does not emit', (
    tester,
  ) async {
    JsonMap? latestConfig;
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(
        extra: const <String, Object?>{
          'workflowId': 'wf-release',
          'itemsNodeId': 'planner',
          'itemsPath': 'issues',
        },
      ),
      onConfigChanged: (config) => latestConfig = config,
    );
    await tester.pumpAndSettle();

    for (final bad in const <String>['0', 'abc', '']) {
      latestConfig = null;
      await tester.enterText(
        find.byKey(const Key('config_fan_out_max_items')),
        bad,
      );
      await tester.pump();
      expect(find.text('Enter a whole number of 1 or more.'), findsOneWidget);
      expect(latestConfig, isNull);
    }

    await tester.enterText(
      find.byKey(const Key('config_fan_out_max_items')),
      '10',
    );
    await tester.pump();
    expect(find.text('Enter a whole number of 1 or more.'), findsNothing);
    expect(FanOutNodeConfig.fromJson(latestConfig!).maxItems, 10);
  });

  testWidgets('editing emits immediately', (tester) async {
    JsonMap? latestConfig;
    await _pumpInspector(
      tester,
      fanNode: _fanOutNode(),
      onConfigChanged: (config) => latestConfig = config,
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('config_fan_out_items_path')),
      'items',
    );
    await tester.pump();

    expect(latestConfig, isNotNull);
    expect(FanOutNodeConfig.fromJson(latestConfig!).itemsPath, 'items');
  });

  testWidgets('switching nodes re-syncs the fields', (tester) async {
    final first = _fanOutNode(
      id: 'fan-1',
      extra: const <String, Object?>{'itemsPath': 'first_items'},
    );
    final second = _fanOutNode(
      id: 'fan-2',
      extra: const <String, Object?>{'itemsPath': 'second_items'},
    );

    await _pumpInspector(tester, fanNode: first);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<HiveTextField>(
            find.byKey(const Key('config_fan_out_items_path')),
          )
          .controller!
          .text,
      'first_items',
    );

    await _pumpInspector(tester, fanNode: second);
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<HiveTextField>(
            find.byKey(const Key('config_fan_out_items_path')),
          )
          .controller!
          .text,
      'second_items',
    );
  });

  testWidgets('palette lists the fan-out node with its label', (tester) async {
    tester.view.physicalSize = const Size(1200, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    await tester.pumpWidget(_wrapWithHost(NodePalette(onInsertNode: (_) {})));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('palette_item_fan_out')), findsOneWidget);
    expect(find.text('Fan-out'), findsOneWidget);
  });
}
