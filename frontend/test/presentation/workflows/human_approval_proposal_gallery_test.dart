import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/agents/agent_providers.dart';
import 'package:agentic_hive_frontend/domain/agents/agent_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/controllers/workflow_editor_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/workflow_inspector_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

const String _captureDir = String.fromEnvironment('HIVE_CAPTURE_DIR');

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

Future<void> _loadFonts() async {
  const fonts = <String, String>{
    'BricolageGrotesque':
        'assets/fonts/bricolage_grotesque/BricolageGrotesque-Variable.ttf',
    'Geist': 'assets/fonts/geist/Geist-Variable.ttf',
    'GeistMono': 'assets/fonts/geist_mono/GeistMono-Variable.ttf',
  };
  for (final entry in fonts.entries) {
    final candidates = <String>[
      'design_system/${entry.value}',
      '../design_system/${entry.value}',
    ];
    for (final path in candidates) {
      final file = File(path);
      if (!file.existsSync()) continue;
      final bytes = await file.readAsBytes();
      final loader = FontLoader('packages/design_system/${entry.key}')
        ..addFont(Future<ByteData>.value(ByteData.sublistView(bytes)));
      await loader.load();
      break;
    }
  }
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

WorkflowEditorState _stateWith(WorkflowNode approval) {
  final now = DateTime.utc(2026, 11, 21, 4);
  final nodes = <WorkflowNode>[
    _terminalNode('planner', 'Planner'),
    _terminalNode('reviewer', 'Reviewer'),
    approval,
  ];
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
    selectedNodeId: approval.id,
  );
}

Future<void> _scrollToConfigFields(WidgetTester tester) async {
  const proposalNodeKey = Key('config_human_proposal_node');
  const proposalPathKey = Key('config_human_proposal_path');
  const proposalSchemaKey = Key('config_human_proposal_schema');
  if (find.byKey(proposalNodeKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(proposalNodeKey));
  }
  if (find.byKey(proposalPathKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(proposalPathKey));
  }
  if (find.byKey(proposalSchemaKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(proposalSchemaKey));
  }
  await tester.pumpAndSettle();
}

Future<void> _capture(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required WorkflowNode node,
  Future<void> Function(WidgetTester tester)? drive,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final repo = _FakeAgentRepository();
  addTearDown(repo.dispose);

  final dims = '${size.width.toInt()}x${size.height.toInt()}';
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [agentRepositoryProvider.overrideWithValue(repo)],
      child: NodeVisualScope(
        registry: createNodeVisualRegistry(),
        child: MaterialApp(
          debugShowCheckedModeBanner: false,
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(
              child: WorkflowInspectorPanel(
                key: ValueKey<String>('${id}_${themeName}_$dims'),
                state: _stateWith(node),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: RepaintBoundary(key: boundaryKey, child: child),
          ),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await _scrollToConfigFields(tester);
  if (drive != null) {
    await drive(tester);
  }

  expect(tester.takeException(), isNull);

  Directory(_captureDir).createSync(recursive: true);
  final outPath = p.join(_captureDir, '${id}_${themeName}_$dims.png');
  await tester.runAsync(() async {
    final boundary =
        boundaryKey.currentContext!.findRenderObject()!
            as RenderRepaintBoundary;
    final image = await boundary.toImage();
    final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
    File(outPath).writeAsBytesSync(byteData!.buffer.asUint8List());
  });
  expect(File(outPath).existsSync(), isTrue);

  handle.dispose();
}

void main() {
  if (_captureDir.isEmpty) {
    test(
      'capture skipped without HIVE_CAPTURE_DIR',
      () {},
      skip: 'set --dart-define=HIVE_CAPTURE_DIR=<dir>',
    );
    return;
  }

  setUpAll(_loadFonts);

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  final themes = <String, ThemeData>{
    'dark': HiveTheme.dark(),
    'light': HiveTheme.light(),
  };
  const sizes = <Size>[Size(1280, 720), Size(1440, 900)];

  final matrix =
      <
        ({
          String id,
          WorkflowNode node,
          Future<void> Function(WidgetTester)? drive,
        })
      >[
        (id: 'cfg-none', node: _approvalNode(), drive: null),
        (
          id: 'cfg-source-empty',
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': '',
          }),
          drive: null,
        ),
        (
          id: 'cfg-source-filled',
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': 'issues',
            'proposalSchema': '{"type":"array"}',
          }),
          drive: null,
        ),
        (
          id: 'cfg-schema-invalid',
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': 'issues',
            'proposalSchema': '{bad',
          }),
          drive: null,
        ),
        (
          id: 'cfg-dangling',
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'gone',
            'proposalPath': 'issues',
          }),
          drive: null,
        ),
        (
          id: 'cfg-select-open',
          node: _approvalNode(),
          drive: (tester) async {
            final selectFinder = find.byKey(
              const Key('config_human_proposal_node'),
            );
            await tester.ensureVisible(selectFinder);
            await tester.tap(selectFinder);
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'cfg-focused-schema',
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': 'issues',
          }),
          drive: (tester) async {
            final schemaFinder = find.byKey(
              const Key('config_human_proposal_schema'),
            );
            await tester.ensureVisible(schemaFinder);
            await tester.tap(schemaFinder);
            await tester.pumpAndSettle();
          },
        ),
      ];

  for (final themeEntry in themes.entries) {
    for (final size in sizes) {
      for (final cell in matrix) {
        final dims = '${size.width.toInt()}x${size.height.toInt()}';
        testWidgets('capture ${cell.id} (${themeEntry.key} $dims)', (
          tester,
        ) async {
          await _capture(
            tester,
            id: cell.id,
            themeName: themeEntry.key,
            theme: themeEntry.value,
            size: size,
            node: cell.node,
            drive: cell.drive,
          );
        });
      }
    }

    testWidgets(
      'capture cfg-source-filled-large (${themeEntry.key} 1280x720)',
      (tester) async {
        await _capture(
          tester,
          id: 'cfg-source-filled-large',
          themeName: themeEntry.key,
          theme: themeEntry.value,
          size: sizes.first,
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': 'issues',
            'proposalSchema': '{"type":"array"}',
          }),
          textScale: 2,
        );
      },
    );

    testWidgets(
      'capture cfg-schema-invalid-large (${themeEntry.key} 1280x720)',
      (tester) async {
        await _capture(
          tester,
          id: 'cfg-schema-invalid-large',
          themeName: themeEntry.key,
          theme: themeEntry.value,
          size: sizes.first,
          node: _approvalNode(const <String, dynamic>{
            'proposalNodeId': 'planner',
            'proposalPath': 'issues',
            'proposalSchema': '{bad',
          }),
          textScale: 2,
        );
      },
    );
  }
}
