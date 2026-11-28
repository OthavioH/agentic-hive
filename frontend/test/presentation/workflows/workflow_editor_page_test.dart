import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflow_editor_page.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_graph_painter.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeWorkflowRepository implements WorkflowRepository {
  final DateTime now = DateTime.utc(2026, 11, 20, 12);
  int saveCalls = 0;
  int getCalls = 0;
  Result<WorkflowResponse>? saveOverride;

  Workflow stored = Workflow(
    id: 'wf-1',
    name: 'Editable Flow',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  );

  WorkflowValidationResult validation = const WorkflowValidationResult(
    isValid: false,
    issues: <WorkflowValidationIssue>[
      WorkflowValidationIssue(
        severity: WorkflowValidationSeverity.error,
        code: WorkflowValidationCode.emptyNodes,
        message: 'Backend message ignored by localized UI.',
      ),
    ],
  );

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    getCalls++;
    return Success(WorkflowResponse(workflow: stored, validation: validation));
  }

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    saveCalls++;
    if (saveOverride != null) return saveOverride!;
    stored = stored.copyWith(
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
    );
    validation = const WorkflowValidationResult(isValid: true);
    return Success(WorkflowResponse(workflow: stored, validation: validation));
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    if (workflow.nodes.isEmpty) {
      return Success(validation);
    }
    if (workflow.nodes.length > 1 && workflow.edges.isEmpty) {
      final unreachable = workflow.nodes.last;
      return Success(
        WorkflowValidationResult(
          isValid: true,
          issues: <WorkflowValidationIssue>[
            WorkflowValidationIssue(
              severity: WorkflowValidationSeverity.warning,
              code: WorkflowValidationCode.unreachableNode,
              message: 'raw unreachable',
              nodeId: unreachable.id,
            ),
          ],
        ),
      );
    }
    return const Success(WorkflowValidationResult(isValid: true));
  }

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

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
  }) => Stream.value(const WorkflowDeletionSucceeded());
}

Widget _buildEditorHost() {
  final router = GoRouter(
    initialLocation: '/workflows/wf-1',
    routes: $appRoutes,
  );

  return NodeVisualScope(
    registry: createNodeVisualRegistry(),
    child: MaterialApp.router(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      theme: HiveTheme.dark(),
      routerConfig: router,
    ),
  );
}

void main() {
  testWidgets('WorkflowEditorPage adds node, edits inspector, and saves', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowEditorPage)),
    )!;

    expect(find.text('Editable Flow'), findsWidgets);
    expect(find.text(l10n.editorSavedBadge), findsOneWidget);
    expect(find.text(l10n.editorIssueEmptyNodes), findsOneWidget);

    // Add node from palette -> becomes dirty, selects node, shows inspector.
    await tester.tap(
      find.byKey(const Key('palette_item_${NodeTypeId.command}')),
    );
    await tester.pumpAndSettle();

    expect(find.text(l10n.editorUnsavedBadge), findsOneWidget);
    expect(find.byKey(const Key('inspector_node_label')), findsOneWidget);
    expect(find.text(l10n.editorEntryBadge), findsOneWidget);

    // Edit node label in inspector.
    await tester.enterText(
      find.byKey(const Key('inspector_node_label')),
      'Plan Step',
    );
    await tester.pumpAndSettle();
    expect(find.text('Plan Step'), findsWidgets);

    // Save workflow.
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(repo.saveCalls, 1);
    expect(find.text(l10n.editorSavedBadge), findsOneWidget);
    expect(find.text(l10n.editorValidationValid), findsOneWidget);
  });

  testWidgets('Backspace in inspector edits text without deleting node; '
      'Delete on canvas deletes node', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    // Add a node from palette (automatically selected).
    await tester.tap(
      find.byKey(const Key('palette_item_${NodeTypeId.command}')),
    );
    await tester.pumpAndSettle();
    expect(find.byKey(const Key('canvas_node_node_1')), findsOneWidget);

    // Focus the inspector node label field.
    final labelField = find.byKey(const Key('inspector_node_label'));
    await tester.tap(labelField);
    await tester.pumpAndSettle();

    // Press Backspace and Delete while EditableText has focus ->
    // node must remain!
    await tester.sendKeyEvent(LogicalKeyboardKey.backspace);
    await tester.pumpAndSettle();
    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canvas_node_node_1')), findsOneWidget);

    // Tap the selected node on the canvas so focus leaves EditableText
    // and returns to the canvas editor, then press Delete.
    await tester.tap(find.byKey(const Key('canvas_node_node_1')));
    await tester.pumpAndSettle();

    await tester.sendKeyEvent(LogicalKeyboardKey.delete);
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('canvas_node_node_1')), findsNothing);
  });

  testWidgets(
    'Edge creation by port drag, edge selection, and edge inspector edits',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildEditorHost(),
        ),
      );
      await tester.pumpAndSettle();

      // Add two nodes: node_1 at (120, 120) and node_2 at (380, 120).
      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkflowEditorPage)),
      );
      final provider = workflowEditorControllerProvider('wf-1');

      // Drag from node_1 output port to node_2 card center.
      // While an edge is selected, _edgeFlowController repeats continuously,
      // so use pump() with HiveMotionTokens instead of pumpAndSettle().
      final portFinder = find.byKey(const Key('output_port_node_1'));
      final targetNodeFinder = find.byKey(const Key('canvas_node_node_2'));
      final dragDelta =
          tester.getCenter(targetNodeFinder) - tester.getCenter(portFinder);
      await tester.timedDrag(
        portFinder,
        dragDelta,
        HiveMotionTokens.standard.medium,
      );
      await tester.pump();
      await tester.pump(HiveMotionTokens.standard.short);

      var state = container.read(provider).requireValue;
      expect(state.workflow.edges, hasLength(1));
      expect(state.selectedEdgeId, 'edge_3');
      expect(
        find.byKey(const Key('inspector_edge_max_retries')),
        findsOneWidget,
      );

      // Edit maxRetries in edge inspector.
      await tester.enterText(
        find.byKey(const Key('inspector_edge_max_retries')),
        '3',
      );
      await tester.pump();
      state = container.read(provider).requireValue;
      expect(state.workflow.edges.first.maxRetries, 3);

      // Select custom sourceOutput in HiveSelect and enter custom label.
      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowEditorPage)),
      )!;
      await tester.tap(
        find.byKey(const Key('inspector_edge_source_output_select')),
      );
      await tester.pump();
      await tester.pump(HiveMotionTokens.standard.medium);
      await tester.tap(find.text(l10n.editorEdgeSourceOutputCustomOption).last);
      await tester.pump();
      await tester.pump(HiveMotionTokens.standard.medium);

      await tester.enterText(
        find.byKey(const Key('inspector_edge_source_output_custom')),
        'approved',
      );
      await tester.pump();

      state = container.read(provider).requireValue;
      expect(state.workflow.edges.first.sourceOutput, 'approved');

      // Clear selection by tapping node_1 (stops _edgeFlowController),
      // then re-select the edge by tapping its midpoint on the canvas.
      await tester.tap(find.byKey(const Key('canvas_node_node_1')));
      await tester.pumpAndSettle();
      expect(container.read(provider).requireValue.selectedNodeId, 'node_1');

      final edgeMidpoint = WorkflowCanvasGeometry.buildEdgePath(
        state.workflow.nodes[0],
        state.workflow.nodes[1],
      ).midpoint;
      final canvasTopLeft =
          tester.getTopLeft(find.byKey(const Key('canvas_node_node_1'))) -
          Offset(
            state.workflow.nodes[0].position.x,
            state.workflow.nodes[0].position.y,
          );
      await tester.tapAt(canvasTopLeft + edgeMidpoint);
      await tester.pump();

      expect(container.read(provider).requireValue.selectedEdgeId, 'edge_3');
    },
  );

  testWidgets(
    'Clicking validation issue in inspector selects and focuses target node',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildEditorHost(),
        ),
      );
      await tester.pumpAndSettle();

      // Add 2 nodes without connecting them -> node_2 is unreachable warning.
      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();
      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();

      // Select node_1 first so node_2 is not selected.
      await tester.tap(find.byKey(const Key('canvas_node_node_1')));
      await tester.pumpAndSettle();

      final container = ProviderScope.containerOf(
        tester.element(find.byType(WorkflowEditorPage)),
      );
      final provider = workflowEditorControllerProvider('wf-1');
      expect(container.read(provider).requireValue.selectedNodeId, 'node_1');

      final issueCard = find.byKey(
        const Key('validation_issue_${WorkflowValidationCode.unreachableNode}'),
      );
      expect(issueCard, findsOneWidget);

      await tester.ensureVisible(issueCard);
      await tester.pumpAndSettle();
      await tester.tap(issueCard);
      await tester.pumpAndSettle();

      final afterFocus = container.read(provider).requireValue;
      expect(afterFocus.selectedNodeId, 'node_2');
      expect(afterFocus.focusRequest, isNotNull);
    },
  );

  testWidgets(
    'WorkflowEditorPage prompts before discarding unsaved changes via back '
    'button or side rail',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildEditorHost(),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowEditorPage)),
      )!;

      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();

      // 1. Tap Overview in side rail while dirty -> HiveDialog appears;
      // Enter cancels (Cancel is focused) and keeps user in editor.
      await tester.tap(find.bySemanticsLabel(l10n.navOverview));
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsOneWidget);
      expect(find.text(l10n.editorUnsavedDialogTitle), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(HiveDialog), findsNothing);
      expect(find.byType(WorkflowEditorPage), findsOneWidget);

      // 2. Tap back button while dirty -> HiveDialog appears;
      // Enter cancels, then confirm discards and navigates away.
      await tester.tap(find.byKey(const Key('editor_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.byType(HiveDialog), findsNothing);
      expect(find.byType(WorkflowEditorPage), findsOneWidget);

      await tester.tap(find.byKey(const Key('editor_back_button')));
      await tester.pumpAndSettle();

      expect(find.byType(HiveDialog), findsOneWidget);
      await tester.tap(find.text(l10n.editorDiscardAction));
      await tester.pumpAndSettle();

      expect(find.byType(WorkflowEditorPage), findsNothing);
    },
  );

  testWidgets(
    'a revision conflict on save shows the reload dialog and reload refetches',
    (tester) async {
      tester.view.physicalSize = const Size(1440, 900);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final repo = _FakeWorkflowRepository();
      await tester.pumpWidget(
        ProviderScope(
          overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
          child: _buildEditorHost(),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(WorkflowEditorPage)),
      )!;

      await tester.tap(
        find.byKey(const Key('palette_item_${NodeTypeId.command}')),
      );
      await tester.pumpAndSettle();

      repo.saveOverride = const FailureResult(
        BackendFailure(
          'changed',
          code: ApiErrorCode.revisionConflict,
          statusCode: 409,
        ),
      );
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      expect(find.text(l10n.editorRevisionConflictTitle), findsOneWidget);
      expect(find.text(l10n.editorRevisionConflictMessage), findsOneWidget);
      expect(find.text(l10n.editorRevisionConflictBadge), findsOneWidget);

      repo.saveOverride = null;
      await tester.tap(find.text(l10n.editorReloadAction));
      await tester.pumpAndSettle();

      expect(find.text(l10n.editorRevisionConflictTitle), findsNothing);
      expect(repo.getCalls, 2);
      expect(find.text(l10n.editorSavedBadge), findsOneWidget);
    },
  );

  testWidgets('keep editing closes the conflict dialog and keeps the draft', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    final l10n = AppLocalizations.of(
      tester.element(find.byType(WorkflowEditorPage)),
    )!;

    await tester.tap(
      find.byKey(const Key('palette_item_${NodeTypeId.command}')),
    );
    await tester.pumpAndSettle();

    repo.saveOverride = const FailureResult(
      BackendFailure(
        'changed',
        code: ApiErrorCode.revisionConflict,
        statusCode: 409,
      ),
    );
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    await tester.tap(find.text(l10n.editorKeepEditingAction));
    await tester.pumpAndSettle();

    expect(find.text(l10n.editorRevisionConflictTitle), findsNothing);
    expect(find.text(l10n.editorUnsavedBadge), findsOneWidget);
    expect(repo.getCalls, 1);
  });

  testWidgets('inspector proposal source lists other workflow nodes and '
      'excludes the selected approval node', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final repo = _FakeWorkflowRepository();
    repo.stored = repo.stored.copyWith(
      nodes: <WorkflowNode>[
        WorkflowNode(
          id: 'n1',
          type: NodeTypeId.command,
          label: 'Planner Step',
          config: NodeDescriptors.command.defaultConfig(),
          position: const WorkflowPosition(x: 40, y: 40),
        ),
        WorkflowNode(
          id: 'n2',
          type: NodeTypeId.command,
          label: 'Validator Step',
          config: NodeDescriptors.command.defaultConfig(),
          position: const WorkflowPosition(x: 240, y: 40),
        ),
        WorkflowNode(
          id: 'n3',
          type: NodeTypeId.humanApproval,
          label: 'Approval Gate',
          config: NodeDescriptors.humanApproval.defaultConfig(),
          position: const WorkflowPosition(x: 40, y: 200),
        ),
      ],
      entryNodeId: 'n1',
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('canvas_node_n3')));
    await tester.pumpAndSettle();

    final selectFinder = find.byKey(const Key('config_human_proposal_node'));
    await tester.ensureVisible(selectFinder);
    await tester.tap(selectFinder);
    await tester.pumpAndSettle();

    final menuItems = find.byType(MenuItemButton);
    expect(
      find.descendant(of: menuItems, matching: find.text('Planner Step')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menuItems, matching: find.text('Validator Step')),
      findsOneWidget,
    );
    expect(
      find.descendant(of: menuItems, matching: find.text('Approval Gate')),
      findsNothing,
    );
  });

  testWidgets(
    'toolbar actions sit flush right and vertically centered on wide windows',
    (tester) async {
      addTearDown(tester.view.reset);

      for (final size in const <Size>[Size(1440, 900), Size(2560, 1440)]) {
        tester.view.physicalSize = size;
        tester.view.devicePixelRatio = 1.0;

        final repo = _FakeWorkflowRepository();
        await tester.pumpWidget(
          ProviderScope(
            overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
            child: _buildEditorHost(),
          ),
        );
        await tester.pumpAndSettle();

        final spacing = tester
            .element(find.byType(WorkflowEditorPage))
            .hiveSpacing;
        final toolbar = tester.getRect(find.byKey(const Key('editor_toolbar')));
        final save = tester.getRect(
          find.byKey(const Key('editor_save_button')),
        );

        expect(save.right, moreOrLessEquals(toolbar.right - spacing.space3));
        expect(save.center.dy, moreOrLessEquals(toolbar.center.dy));

        await tester.tap(
          find.byKey(const Key('palette_item_${NodeTypeId.command}')),
        );
        await tester.pumpAndSettle();

        final dirtyToolbar = tester.getRect(
          find.byKey(const Key('editor_toolbar')),
        );
        final dirtySave = tester.getRect(
          find.byKey(const Key('editor_save_button')),
        );
        expect(
          dirtySave.right,
          moreOrLessEquals(dirtyToolbar.right - spacing.space3),
        );
        expect(dirtySave.center.dy, moreOrLessEquals(dirtyToolbar.center.dy));
      }
    },
  );

  testWidgets('narrow toolbar ellipsizes long name and keeps Save visible with '
      'save-failure badge', (tester) async {
    tester.view.physicalSize = const Size(900, 800);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    final longName = 'A very long workflow name ' * 8;
    final repo = _FakeWorkflowRepository();
    repo.stored = repo.stored.copyWith(name: longName);

    await tester.pumpWidget(
      ProviderScope(
        overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
        child: _buildEditorHost(),
      ),
    );
    await tester.pumpAndSettle();

    final paletteItem = find.byKey(
      const Key('palette_item_${NodeTypeId.command}'),
    );
    await tester.ensureVisible(paletteItem);
    await tester.tap(paletteItem);
    await tester.pumpAndSettle();

    repo.saveOverride = const FailureResult(NetworkFailure('offline'));
    await tester.tap(find.byKey(const Key('editor_save_button')));
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);

    final spacing = tester.element(find.byType(WorkflowEditorPage)).hiveSpacing;
    final toolbar = tester.getRect(find.byKey(const Key('editor_toolbar')));
    final save = tester.getRect(find.byKey(const Key('editor_save_button')));

    expect(save.right, moreOrLessEquals(toolbar.right - spacing.space3));
    expect(save.left, greaterThanOrEqualTo(toolbar.left));

    final failureBadges = find.byWidgetPredicate(
      (w) =>
          w is HiveBadge &&
          w.tone == HiveBadgeTone.danger &&
          w.icon == HiveIcons.alert,
    );
    expect(failureBadges, findsWidgets);

    final dirtyBadgeRect = tester.getRect(
      find.byKey(const Key('editor_dirty_badge')),
    );
    final firstFailureBadgeRect = tester.getRect(failureBadges.first);
    expect(firstFailureBadgeRect.left, lessThan(dirtyBadgeRect.left));

    final nameRect = tester.getRect(find.text(longName));
    expect(
      nameRect.width,
      lessThanOrEqualTo((toolbar.width - 2 * spacing.space3) / 2 + 0.01),
    );
  });
}
