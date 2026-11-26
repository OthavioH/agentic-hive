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
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success<List<AgentSummary>>(<AgentSummary>[]);

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
  Stream<AgentsChangedPayload> watchAgentChanges() => _changes.stream;
}

Workflow _makeWorkflow(WorkflowNode node) {
  final now = DateTime.utc(2026, 11, 25, 12);
  return Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: <WorkflowNode>[node],
    edges: const <WorkflowEdge>[],
    createdAt: now,
    updatedAt: now,
  );
}

WorkflowResponse _makeResponse(WorkflowNode node) => WorkflowResponse(
  workflow: _makeWorkflow(node),
  validation: const WorkflowValidationResult(isValid: true),
  revision: 'rev-1',
);

Widget _buildHost({
  required WorkflowNode node,
  required _FakeAgentRepository agentRepo,
  bool isSaving = false,
  void Function(String nodeId, JsonMap config)? onUpdateNodeConfig,
  Future<Result<WorkflowResponse>> Function(String nodeId, String newType)?
  onChangeNodeType,
}) {
  final workflow = _makeWorkflow(node);
  final state = WorkflowEditorState(
    workflow: workflow,
    savedWorkflow: workflow,
    validation: const WorkflowValidationResult(isValid: true),
    revision: 'rev-1',
    selectedNodeId: node.id,
    isSaving: isSaving,
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
              state: state,
              onUpdateMetadata: ({name, description}) {},
              onUpdateNodeLabel: (_, _) {},
              onUpdateNodeConfig: onUpdateNodeConfig ?? (_, _) {},
              onChangeNodeType:
                  onChangeNodeType ??
                  (_, _) async =>
                      Success<WorkflowResponse>(_makeResponse(node)),
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

Future<void> _openPickerAndSelect(
  WidgetTester tester,
  String targetLabel,
) async {
  await tester.tap(find.byKey(const Key('inspector_change_harness')));
  await tester.pumpAndSettle();
  await tester.tap(find.byKey(const Key('inspector_change_harness_select')));
  await tester.pumpAndSettle();
  await tester.tap(find.text(targetLabel).last);
  await tester.pumpAndSettle();
}

void main() {
  late _FakeAgentRepository agentRepo;

  setUp(() {
    agentRepo = _FakeAgentRepository();
  });

  tearDown(() async {
    await agentRepo.dispose();
  });

  testWidgets('button shown for 4 headless types and hidden for others', (
    tester,
  ) async {
    for (final typeId in headlessHarnessTypeIds) {
      final node = WorkflowNode(
        id: 'n-$typeId',
        type: typeId,
        label: 'Node',
        position: const WorkflowPosition(x: 0, y: 0),
      );
      await tester.pumpWidget(_buildHost(node: node, agentRepo: agentRepo));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inspector_change_harness')),
        findsOneWidget,
        reason: 'Expected button for $typeId',
      );
    }

    for (final typeId in <String>[
      NodeTypeId.terminal,
      NodeTypeId.reviewValidator,
      NodeTypeId.command,
      NodeTypeId.humanApproval,
    ]) {
      final node = WorkflowNode(
        id: 'n-$typeId',
        type: typeId,
        label: 'Node',
        position: const WorkflowPosition(x: 0, y: 0),
      );
      await tester.pumpWidget(_buildHost(node: node, agentRepo: agentRepo));
      await tester.pumpAndSettle();
      expect(
        find.byKey(const Key('inspector_change_harness')),
        findsNothing,
        reason: 'Expected no button for $typeId',
      );
    }
  });

  testWidgets('picker lists exactly the other 3 harness labels', (
    tester,
  ) async {
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
    );
    await tester.pumpWidget(_buildHost(node: node, agentRepo: agentRepo));
    await tester.pumpAndSettle();

    await tester.tap(find.byKey(const Key('inspector_change_harness')));
    await tester.pumpAndSettle();
    await tester.tap(find.byKey(const Key('inspector_change_harness_select')));
    await tester.pumpAndSettle();

    expect(find.text('Codex'), findsWidgets);
    expect(find.text('Gemini CLI'), findsWidgets);
    expect(find.text('Antigravity'), findsWidgets);
    expect(find.text('Claude Code'), findsOneWidget);
  });

  testWidgets(
    'confirm with drops: cancel, Escape, confirm, and Enter behavior',
    (tester) async {
      final calls = <(String, String)>[];
      const node = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
        config: <String, dynamic>{'effort': 'high', 'model': 'm'},
      );
      await tester.pumpWidget(
        _buildHost(
          node: node,
          agentRepo: agentRepo,
          onChangeNodeType: (id, newType) async {
            calls.add((id, newType));
            return Success<WorkflowResponse>(_makeResponse(node));
          },
        ),
      );
      await tester.pumpAndSettle();

      await _openPickerAndSelect(tester, 'Gemini CLI');
      expect(find.text('Switch to Gemini CLI?'), findsOneWidget);
      expect(
        find.text('These settings will be removed: effort'),
        findsOneWidget,
      );
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await _openPickerAndSelect(tester, 'Gemini CLI');
      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(calls, isEmpty);

      await _openPickerAndSelect(tester, 'Gemini CLI');
      await tester.tap(find.text('Switch'));
      await tester.pumpAndSettle();
      expect(calls, <(String, String)>[('n1', NodeTypeId.geminiCli)]);

      calls.clear();
      await _openPickerAndSelect(tester, 'Gemini CLI');
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(calls, <(String, String)>[('n1', NodeTypeId.geminiCli)]);
    },
  );

  testWidgets('focus stays in dialog when pressing Tab', (tester) async {
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
      config: <String, dynamic>{'effort': 'high'},
    );
    await tester.pumpWidget(_buildHost(node: node, agentRepo: agentRepo));
    await tester.pumpAndSettle();

    await _openPickerAndSelect(tester, 'Gemini CLI');
    final dialogFinder = find.byType(HiveConfirmDialog);
    expect(dialogFinder, findsOneWidget);

    for (var i = 0; i < 4; i++) {
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final primaryFocus = FocusManager.instance.primaryFocus;
      expect(primaryFocus, isNotNull);
      final dialogElement = tester.element(dialogFinder);
      var insideDialog = false;
      primaryFocus!.context?.visitAncestorElements((ancestor) {
        if (ancestor == dialogElement) {
          insideDialog = true;
          return false;
        }
        return true;
      });
      expect(insideDialog, isTrue);
    }
  });

  testWidgets('no-drops pick calls callback directly without dialog', (
    tester,
  ) async {
    final calls = <(String, String)>[];
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
      config: <String, dynamic>{'effort': 'high'},
    );
    await tester.pumpWidget(
      _buildHost(
        node: node,
        agentRepo: agentRepo,
        onChangeNodeType: (id, newType) async {
          calls.add((id, newType));
          return Success<WorkflowResponse>(_makeResponse(node));
        },
      ),
    );
    await tester.pumpAndSettle();

    await _openPickerAndSelect(tester, 'Codex');
    expect(find.byType(HiveConfirmDialog), findsNothing);
    expect(calls, <(String, String)>[('n1', NodeTypeId.codex)]);
  });

  testWidgets('failure result shows HiveToast with localized failure', (
    tester,
  ) async {
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
    );
    await tester.pumpWidget(
      _buildHost(
        node: node,
        agentRepo: agentRepo,
        onChangeNodeType: (_, _) async =>
            const FailureResult<WorkflowResponse>(NetworkFailure('offline')),
      ),
    );
    await tester.pumpAndSettle();

    await _openPickerAndSelect(tester, 'Codex');
    expect(find.byType(HiveToast), findsOneWidget);
  });

  testWidgets('button is disabled when state.isSaving is true', (tester) async {
    const node = WorkflowNode(
      id: 'n1',
      type: NodeTypeId.claudeCode,
      label: 'Coder',
      position: WorkflowPosition(x: 0, y: 0),
    );
    await tester.pumpWidget(
      _buildHost(node: node, agentRepo: agentRepo, isSaving: true),
    );
    await tester.pumpAndSettle();

    final button = tester.widget<HiveButton>(
      find.byKey(const Key('inspector_change_harness')),
    );
    expect(button.onPressed, isNull);
  });

  testWidgets(
    'regression: rebuilding with same node id and new type resyncs form',
    (tester) async {
      JsonMap? lastConfig;
      const claudeNode = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
        config: <String, dynamic>{'effort': 'high', 'model': 'old'},
      );
      await tester.pumpWidget(
        _buildHost(
          node: claudeNode,
          agentRepo: agentRepo,
          onUpdateNodeConfig: (_, config) => lastConfig = config,
        ),
      );
      await tester.pumpAndSettle();

      const geminiNode = WorkflowNode(
        id: 'n1',
        type: NodeTypeId.geminiCli,
        label: 'Coder',
        position: WorkflowPosition(x: 0, y: 0),
        config: <String, dynamic>{'model': 'old'},
      );
      await tester.pumpWidget(
        _buildHost(
          node: geminiNode,
          agentRepo: agentRepo,
          onUpdateNodeConfig: (_, config) => lastConfig = config,
        ),
      );
      await tester.pumpAndSettle();

      await tester.enterText(
        find.byKey(const Key('config_harness_model')),
        'gemini-2.5-pro',
      );
      await tester.pumpAndSettle();

      expect(lastConfig, isNotNull);
      expect(lastConfig!.containsKey('effort'), isFalse);
      expect(lastConfig!['model'], 'gemini-2.5-pro');
    },
  );
}
