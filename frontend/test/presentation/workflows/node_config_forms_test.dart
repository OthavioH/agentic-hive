import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_palette.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

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

WorkflowEditorState _stateWith({
  List<WorkflowNode> nodes = const <WorkflowNode>[],
  List<WorkflowEdge> edges = const <WorkflowEdge>[],
  String? selectedNodeId,
  String? selectedEdgeId,
}) {
  final now = DateTime.utc(2026, 11, 21, 4);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: nodes,
    edges: edges,
    entryNodeId: nodes.isNotEmpty ? nodes.first.id : null,
    createdAt: now,
    updatedAt: now,
  );
  return WorkflowEditorState(
    workflow: workflow,
    savedWorkflow: workflow,
    validation: const WorkflowValidationResult(isValid: true),
    selectedNodeId: selectedNodeId,
    selectedEdgeId: selectedEdgeId,
  );
}

void main() {
  testWidgets(
    'NodePalette renders all 4 categories and 10 node types and inserts on tap',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      String? insertedTypeId;
      await tester.pumpWidget(
        _wrapWithHost(
          NodePalette(onInsertNode: (typeId) => insertedTypeId = typeId),
        ),
      );
      await tester.pumpAndSettle();

      for (final category in NodeCategory.values) {
        expect(
          find.byKey(Key('palette_category_${category.name}')),
          findsOneWidget,
        );
      }

      for (final descriptor in NodeDescriptors.all) {
        expect(
          find.byKey(Key('palette_item_${descriptor.typeId}')),
          findsOneWidget,
        );
      }

      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.claudeCode}')),
      );
      await tester.pumpAndSettle();
      expect(insertedTypeId, NodeTypeId.claudeCode);
    },
  );

  testWidgets('CommandNode inspector form edits command and env entries', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    JsonMap? latestConfig;
    final node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.command,
      label: 'Build',
      config: NodeDescriptors.command.defaultConfig(),
      position: const WorkflowPosition(x: 0, y: 0),
    );

    await tester.pumpWidget(
      _wrapWithHost(
        WorkflowInspectorPanel(
          state: _stateWith(nodes: <WorkflowNode>[node], selectedNodeId: 'n1'),
          onUpdateMetadata: ({name, description}) {},
          onUpdateNodeLabel: (_, _) {},
          onUpdateNodeConfig: (_, config) => latestConfig = config,
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
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('config_command_command')),
      'flutter test',
    );
    await tester.pumpAndSettle();

    expect(latestConfig, isNotNull);
    final decoded = CommandNodeConfig.fromJson(latestConfig!);
    expect(decoded.command, 'flutter test');
    expect(find.byKey(const Key('config_command_env')), findsOneWidget);
  });

  testWidgets('HarnessNode inspector form edits agentId and instructions', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(900, 1200);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    JsonMap? latestConfig;
    final node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Implement',
      config: NodeDescriptors.claudeCode.defaultConfig(),
      position: const WorkflowPosition(x: 0, y: 0),
    );

    await tester.pumpWidget(
      _wrapWithHost(
        WorkflowInspectorPanel(
          state: _stateWith(nodes: <WorkflowNode>[node], selectedNodeId: 'n1'),
          onUpdateMetadata: ({name, description}) {},
          onUpdateNodeLabel: (_, _) {},
          onUpdateNodeConfig: (_, config) => latestConfig = config,
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
    );
    await tester.pumpAndSettle();

    await tester.enterText(
      find.byKey(const Key('config_harness_agent_id')),
      'code-reviewer',
    );
    await tester.enterText(
      find.byKey(const Key('config_harness_additional_instructions')),
      'Keep changes minimal.',
    );
    await tester.pumpAndSettle();

    final decoded = HarnessNodeConfig.fromJson(latestConfig!);
    expect(decoded.agentId, 'code-reviewer');
    expect(decoded.additionalInstructions, 'Keep changes minimal.');
  });

  testWidgets('ChecklistValidatorNode inspector form adds rule and switches '
      'conditional fields', (tester) async {
    tester.view.physicalSize = const Size(900, 1400);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    JsonMap? latestConfig;
    final node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.checklistValidator,
      label: 'Checks',
      config: NodeDescriptors.checklistValidator.defaultConfig(),
      position: const WorkflowPosition(x: 0, y: 0),
    );

    await tester.pumpWidget(
      _wrapWithHost(
        WorkflowInspectorPanel(
          state: _stateWith(nodes: <WorkflowNode>[node], selectedNodeId: 'n1'),
          onUpdateMetadata: ({name, description}) {},
          onUpdateNodeLabel: (_, _) {},
          onUpdateNodeConfig: (_, config) => latestConfig = config,
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
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('config_checklist_add_rule')));
    await tester.pumpAndSettle();

    expect(
      find.byKey(const Key('config_checklist_rule_0_path')),
      findsOneWidget,
    );
    expect(
      find.byKey(const Key('config_checklist_rule_0_pattern')),
      findsNothing,
    );

    await tester.enterText(
      find.byKey(const Key('config_checklist_rule_0_label')),
      'Artifact exists',
    );
    await tester.enterText(
      find.byKey(const Key('config_checklist_rule_0_path')),
      'build/out.txt',
    );
    await tester.pumpAndSettle();

    final decoded = ChecklistValidatorNodeConfig.fromJson(latestConfig!);
    expect(decoded.rules, hasLength(1));
    expect(decoded.rules.first.label, 'Artifact exists');
    expect(decoded.rules.first.kind, ChecklistRuleKind.fileExists);
    expect(decoded.rules.first.path, 'build/out.txt');
  });

  testWidgets(
    'ReviewValidatorNode inspector form selects harness and criteria',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      JsonMap? latestConfig;
      final node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.reviewValidator,
        label: 'Review',
        config: NodeDescriptors.reviewValidator.defaultConfig(),
        position: const WorkflowPosition(x: 0, y: 0),
      );

      await tester.pumpWidget(
        _wrapWithHost(
          WorkflowInspectorPanel(
            state: _stateWith(
              nodes: <WorkflowNode>[node],
              selectedNodeId: 'n1',
            ),
            onUpdateMetadata: ({name, description}) {},
            onUpdateNodeLabel: (_, _) {},
            onUpdateNodeConfig: (_, config) => latestConfig = config,
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
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('config_review_criteria')),
        'Verify test coverage',
      );
      await tester.pumpAndSettle();

      final decoded = ReviewValidatorNodeConfig.fromJson(latestConfig!);
      expect(decoded.harnessType, NodeTypeId.claudeCode);
      expect(decoded.reviewCriteria, 'Verify test coverage');
    },
  );

  testWidgets(
    'HumanApprovalNode inspector form edits title, instructions, and switch',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      JsonMap? latestConfig;
      final node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.humanApproval,
        label: 'Release Gate',
        config: NodeDescriptors.humanApproval.defaultConfig(),
        position: const WorkflowPosition(x: 0, y: 0),
      );

      await tester.pumpWidget(
        _wrapWithHost(
          WorkflowInspectorPanel(
            state: _stateWith(
              nodes: <WorkflowNode>[node],
              selectedNodeId: 'n1',
            ),
            onUpdateMetadata: ({name, description}) {},
            onUpdateNodeLabel: (_, _) {},
            onUpdateNodeConfig: (_, config) => latestConfig = config,
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
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('config_human_title')),
        'Deploy to prod?',
      );
      await tester.enterText(
        find.byKey(const Key('config_human_instructions')),
        'Check changelog before approving.',
      );
      await tester.tap(find.byKey(const Key('config_human_allow_feedback')));
      await tester.pumpAndSettle();

      final decoded = HumanApprovalNodeConfig.fromJson(latestConfig!);
      expect(decoded.title, 'Deploy to prod?');
      expect(decoded.instructions, 'Check changelog before approving.');
      expect(decoded.allowFeedback, isFalse);
    },
  );

  testWidgets(
    'Edge inspector dynamically populates sourceOutput presets from source '
    'node descriptor',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      Future<void> verifyOutputsForSourceType(
        String sourceType,
        List<String> expectedOutputs,
      ) async {
        final source = WorkflowNode(
          id: 'src',
          type: sourceType,
          label: 'Source',
          config: NodeDescriptors.of(sourceType)!.defaultConfig(),
          position: const WorkflowPosition(x: 0, y: 0),
        );
        final target = WorkflowNode(
          id: 'dst',
          type: NodeTypeId.command,
          label: 'Target',
          config: NodeDescriptors.command.defaultConfig(),
          position: const WorkflowPosition(x: 200, y: 0),
        );
        final edgeId = 'e_$sourceType';
        final edge = WorkflowEdge(
          id: edgeId,
          sourceNodeId: 'src',
          sourceOutput: expectedOutputs.first,
          targetNodeId: 'dst',
        );

        await tester.pumpWidget(
          _wrapWithHost(
            WorkflowInspectorPanel(
              key: ValueKey<String>(sourceType),
              state: _stateWith(
                nodes: <WorkflowNode>[source, target],
                edges: <WorkflowEdge>[edge],
                selectedEdgeId: edgeId,
              ),
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
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const Key('inspector_edge_source_output_select')),
        );
        await tester.pumpAndSettle();

        for (final output in expectedOutputs) {
          expect(find.text(output), findsWidgets);
        }
      }

      await verifyOutputsForSourceType(NodeTypeId.humanApproval, <String>[
        NodeOutput.approved,
        NodeOutput.rejected,
      ]);
      await verifyOutputsForSourceType(NodeTypeId.reviewValidator, <String>[
        NodeOutput.approved,
        NodeOutput.changesRequested,
      ]);
      await verifyOutputsForSourceType(NodeTypeId.command, <String>[
        NodeOutput.onSuccess,
        NodeOutput.onFailure,
      ]);
    },
  );

  testWidgets(
    'Timeout input shows inline error for non-positive or non-numeric values',
    (tester) async {
      tester.view.physicalSize = const Size(900, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      JsonMap? latestConfig;
      final node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Implement',
        config: NodeDescriptors.claudeCode.defaultConfig(),
        position: const WorkflowPosition(x: 0, y: 0),
      );

      await tester.pumpWidget(
        _wrapWithHost(
          WorkflowInspectorPanel(
            state: _stateWith(
              nodes: <WorkflowNode>[node],
              selectedNodeId: 'n1',
            ),
            onUpdateMetadata: ({name, description}) {},
            onUpdateNodeLabel: (_, _) {},
            onUpdateNodeConfig: (_, config) => latestConfig = config,
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
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('config_harness_timeout_seconds')),
        'abc',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive integer.'), findsOneWidget);
      expect(latestConfig, isNull);

      await tester.enterText(
        find.byKey(const Key('config_harness_timeout_seconds')),
        '0',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive integer.'), findsOneWidget);

      await tester.enterText(
        find.byKey(const Key('config_harness_timeout_seconds')),
        '30',
      );
      await tester.pumpAndSettle();
      expect(find.text('Enter a positive integer.'), findsNothing);
      expect(HarnessNodeConfig.fromJson(latestConfig!).timeoutSeconds, 30);
    },
  );
}
