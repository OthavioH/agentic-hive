import 'dart:async';
import 'dart:io';

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
  Future<Result<List<AgentSummary>>> listAgents({
    DefinitionScope scope = const GlobalScope(),
  }) {
    return Future<Result<List<AgentSummary>>>.value(
      Success<List<AgentSummary>>(<AgentSummary>[
        AgentSummary(
          id: 'code-reviewer',
          name: 'Code Reviewer',
          contentHash: 'h1',
          updatedAt: DateTime.utc(2026, 11, 21),
        ),
      ]),
    );
  }

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

Future<void> _pumpWithHost(
  WidgetTester tester,
  Widget child, {
  AgentRepository? agentRepository,
}) {
  final repo = agentRepository ?? _FakeAgentRepository();
  if (repo is _FakeAgentRepository) {
    addTearDown(repo.dispose);
  }
  return tester.pumpWidget(
    ProviderScope(
      overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      child: _wrapWithHost(child),
    ),
  );
}

WorkflowEditorState _stateWith({
  List<WorkflowNode> nodes = const <WorkflowNode>[],
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

Future<void> _pumpHarness(
  WidgetTester tester,
  WorkflowNode node, {
  Key? panelKey,
}) {
  tester.view.physicalSize = const Size(900, 1400);
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);
  return _pumpWithHost(
    tester,
    WorkflowInspectorPanel(
      key: panelKey,
      state: _stateWith(nodes: <WorkflowNode>[node], selectedNodeId: node.id),
      onUpdateMetadata: ({name, description}) {},
      onUpdateNodeLabel: (_, _) {},
      onUpdateNodeConfig: (_, _) {},
      onChangeNodeType: (_, _) async =>
          const FailureResult<WorkflowResponse>(UnexpectedFailure('unused')),
      onToggleEntryNode: (_, {required isEntry}) {},
      onDeleteNode: (_) {},
      onUpdateEdge: (_, {sourceOutput, maxRetries, clearMaxRetries = false}) {},
      onDeleteEdge: (_) {},
      onFocusIssue: (_) {},
    ),
  );
}

WorkflowNode _nodeOf(String type, [JsonMap extra = const <String, dynamic>{}]) {
  return WorkflowNode(
    id: 'n1',
    type: type,
    label: 'N',
    config: <String, dynamic>{
      ...NodeDescriptors.of(type)!.defaultConfig(),
      ...extra,
    },
    position: const WorkflowPosition(x: 0, y: 0),
  );
}

File _harnessConfigFormFile() {
  const relative =
      'lib/presentation/workflows/widgets/node_config_forms/harness_config_form.dart';
  for (final candidate in <String>[relative, 'frontend/$relative']) {
    final file = File(candidate);
    if (file.existsSync()) return file;
  }
  throw StateError('Could not locate $relative from ${Directory.current.path}');
}

void main() {
  const agentKey = Key('config_harness_agent_id');
  const instructionsKey = Key('config_harness_additional_instructions');
  const workingDirKey = Key('config_harness_working_directory');
  const timeoutKey = Key('config_harness_timeout_seconds');
  const modelKey = Key('config_harness_model');
  const effortKey = Key('config_harness_effort');
  const extraArgsKey = Key('config_harness_extra_args');

  const fullOrderKeys = <Key>[
    agentKey,
    instructionsKey,
    workingDirKey,
    timeoutKey,
    modelKey,
    effortKey,
    extraArgsKey,
  ];

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

  group('HarnessConfigForm model and effort structure guard', () {
    testWidgets('claude code field order', (tester) async {
      await _pumpHarness(tester, _nodeOf(NodeTypeId.claudeCode));
      await tester.pumpAndSettle();

      for (final key in fullOrderKeys) {
        expect(find.byKey(key), findsOneWidget);
      }
      expectStrictlyIncreasingTops(tester, fullOrderKeys);
    });

    testWidgets('codex and antigravity match claude order', (tester) async {
      final checkedTypes = <String>[];
      for (final descriptor in NodeDescriptors.all.where(
        (d) => d.category == NodeCategory.harnesses,
      )) {
        final fieldNames = descriptor.configFields.map((f) => f.name).toSet();
        if (!fieldNames.contains('model') || !fieldNames.contains('effort')) {
          continue;
        }
        checkedTypes.add(descriptor.typeId);
        await _pumpHarness(
          tester,
          _nodeOf(descriptor.typeId),
          panelKey: ValueKey<String>('panel_${descriptor.typeId}'),
        );
        await tester.pumpAndSettle();

        expectStrictlyIncreasingTops(tester, fullOrderKeys);
      }
      expect(
        checkedTypes,
        containsAll(<String>[
          NodeTypeId.claudeCode,
          NodeTypeId.codex,
          NodeTypeId.antigravity,
        ]),
      );
    });

    testWidgets('gemini hides effort only', (tester) async {
      await _pumpHarness(tester, _nodeOf(NodeTypeId.geminiCli));
      await tester.pumpAndSettle();

      expect(find.byKey(modelKey), findsOneWidget);
      expect(find.byKey(effortKey), findsNothing);
      expectStrictlyIncreasingTops(tester, <Key>[
        agentKey,
        instructionsKey,
        workingDirKey,
        timeoutKey,
        modelKey,
        extraArgsKey,
      ]);
    });

    testWidgets('terminal hides both', (tester) async {
      await _pumpHarness(tester, _nodeOf(NodeTypeId.terminal));
      await tester.pumpAndSettle();

      expect(find.byKey(modelKey), findsNothing);
      expect(find.byKey(effortKey), findsNothing);
    });

    testWidgets('labels and hints', (tester) async {
      await _pumpHarness(tester, _nodeOf(NodeTypeId.claudeCode));
      await tester.pumpAndSettle();

      expect(find.text('Model'), findsWidgets);
      expect(find.text('Effort'), findsWidgets);
      expect(find.text('Harness default'), findsWidgets);
      expect(
        find.descendant(
          of: find.byKey(effortKey),
          matching: find.text('Harness default'),
        ),
        findsOneWidget,
      );
    });

    testWidgets('unsupported error copy', (tester) async {
      await _pumpHarness(
        tester,
        _nodeOf(NodeTypeId.geminiCli, const <String, dynamic>{
          'effort': 'high',
        }),
        panelKey: const ValueKey<String>('panel_gemini_invalid'),
      );
      await tester.pumpAndSettle();

      final geminiContext = tester.element(find.byType(WorkflowInspectorPanel));
      final geminiL10n = AppLocalizations.of(geminiContext)!;
      final geminiName = resolveNodeTypeLabel(
        geminiContext,
        geminiL10n,
        NodeTypeId.geminiCli,
      );
      expect(
        find.text(geminiL10n.nodeConfigEffortUnsupportedError(geminiName)),
        findsOneWidget,
      );

      await _pumpHarness(
        tester,
        _nodeOf(NodeTypeId.terminal, const <String, dynamic>{'model': 'opus'}),
        panelKey: const ValueKey<String>('panel_terminal_invalid'),
      );
      await tester.pumpAndSettle();

      final terminalContext = tester.element(
        find.byType(WorkflowInspectorPanel),
      );
      final terminalL10n = AppLocalizations.of(terminalContext)!;
      final terminalName = resolveNodeTypeLabel(
        terminalContext,
        terminalL10n,
        NodeTypeId.terminal,
      );
      expect(
        find.text(terminalL10n.nodeConfigModelUnsupportedError(terminalName)),
        findsOneWidget,
      );
    });

    testWidgets('effort options', (tester) async {
      await _pumpHarness(tester, _nodeOf(NodeTypeId.claudeCode));
      await tester.pumpAndSettle();

      final effortFinder = find.byKey(effortKey);
      await tester.ensureVisible(effortFinder);
      await tester.tap(effortFinder);
      await tester.pumpAndSettle();

      const expectedLabels = <String>[
        'Harness default',
        'Low',
        'Medium',
        'High',
        'Max',
      ];
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
    });

    test('token-only guard', () {
      final source = _harnessConfigFormFile().readAsStringSync();
      final bannedPatterns = <RegExp>[
        RegExp(r'Color\(0x'),
        RegExp(r'\bColors\.'),
        RegExp(r'EdgeInsets\.[a-zA-Z]+\(\s*\d'),
        RegExp(r'SizedBox\((width|height):\s*\d'),
        RegExp(r'BorderRadius\.circular\(\s*\d'),
        RegExp(r'fontSize:\s*\d'),
        RegExp(r'Duration\('),
      ];
      for (final pattern in bannedPatterns) {
        expect(
          pattern.hasMatch(source),
          isFalse,
          reason: 'Found banned literal matching ${pattern.pattern}',
        );
      }
      expect(source.contains('package:flutter/material.dart'), isFalse);
      expect(source.contains('hugeicons'), isFalse);
    });
  });
}
