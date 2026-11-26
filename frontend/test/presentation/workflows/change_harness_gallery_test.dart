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

Future<void> _capture(
  WidgetTester tester,
  String name, {
  Key? boundaryKey,
}) async {
  if (_captureDir.isEmpty) return;
  final dir = Directory(_captureDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final finder = boundaryKey != null
      ? find.byKey(boundaryKey)
      : find.byType(RepaintBoundary).first;
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  });
  if (bytes == null) return;
  File(p.join(_captureDir, '$name.png')).writeAsBytesSync(bytes);
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

Widget _buildGalleryHost({
  required WorkflowNode node,
  required ThemeData theme,
  required _FakeAgentRepository agentRepo,
  required Key boundaryKey,
  bool isSaving = false,
  double textScale = 1.0,
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
    child: RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: NodeVisualScope(
          registry: createNodeVisualRegistry(),
          child: Scaffold(
            body: Row(
              children: <Widget>[
                const Expanded(flex: 2, child: SizedBox.shrink()),
                Expanded(
                  child: WorkflowInspectorPanel(
                    state: state,
                    onUpdateMetadata: ({name, description}) {},
                    onUpdateNodeLabel: (_, _) {},
                    onUpdateNodeConfig: (_, _) {},
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
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  late _FakeAgentRepository agentRepo;

  setUp(() {
    agentRepo = _FakeAgentRepository();
  });

  tearDown(() async {
    await agentRepo.dispose();
  });

  final viewports = <String, Size>{
    '1280x800': const Size(1280, 800),
    '1920x1080': const Size(1920, 1080),
  };
  final themes = <String, ThemeData>{
    'light': HiveTheme.light(),
    'dark': HiveTheme.dark(),
  };

  for (final vp in viewports.entries) {
    for (final th in themes.entries) {
      final suffix = '${vp.key}_${th.key}';

      testWidgets('gallery cells $suffix', (tester) async {
        await tester.binding.setSurfaceSize(vp.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundaryKey = GlobalKey();

        const claudeNode = WorkflowNode(
          id: 'n1',
          type: NodeTypeId.claudeCode,
          label: 'Coder',
          position: WorkflowPosition(x: 0, y: 0),
          config: <String, dynamic>{'effort': 'high'},
        );
        const terminalNode = WorkflowNode(
          id: 't1',
          type: NodeTypeId.terminal,
          label: 'Done',
          position: WorkflowPosition(x: 0, y: 0),
        );

        await tester.pumpWidget(
          _buildGalleryHost(
            node: claudeNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'idle_$suffix', boundaryKey: boundaryKey);

        await tester.pumpWidget(
          _buildGalleryHost(
            node: terminalNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(
          tester,
          'not-available_$suffix',
          boundaryKey: boundaryKey,
        );

        await tester.pumpWidget(
          _buildGalleryHost(
            node: claudeNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inspector_change_harness')));
        await tester.pumpAndSettle();
        await _capture(tester, 'picking_$suffix', boundaryKey: boundaryKey);

        await tester.tap(
          find.byKey(const Key('inspector_change_harness_select')),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'picker-open_$suffix', boundaryKey: boundaryKey);
        await tester.tap(find.text('Gemini CLI').last);
        await tester.pumpAndSettle();
        await _capture(
          tester,
          'confirm-with-drops_$suffix',
          boundaryKey: boundaryKey,
        );
        await tester.tap(find.text('Cancel'));
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('inspector_change_harness')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('inspector_change_harness_select')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Codex').last);
        await tester.pumpAndSettle();
        final codexNode = claudeNode.copyWith(type: NodeTypeId.codex);
        await tester.pumpWidget(
          _buildGalleryHost(
            node: codexNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Codex'), findsWidgets);
        await _capture(tester, 'no-drops_$suffix', boundaryKey: boundaryKey);

        await tester.pumpWidget(
          _buildGalleryHost(
            node: claudeNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
            isSaving: true,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'saving_$suffix', boundaryKey: boundaryKey);

        await tester.pumpWidget(
          _buildGalleryHost(
            node: claudeNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
            onChangeNodeType: (_, _) async =>
                const FailureResult<WorkflowResponse>(
                  NetworkFailure('offline'),
                ),
          ),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.byKey(const Key('inspector_change_harness')));
        await tester.pumpAndSettle();
        await tester.tap(
          find.byKey(const Key('inspector_change_harness_select')),
        );
        await tester.pumpAndSettle();
        await tester.tap(find.text('Codex').last);
        await tester.pumpAndSettle();
        await _capture(tester, 'error_$suffix', boundaryKey: boundaryKey);

        await tester.pumpWidget(const SizedBox.shrink());
        await tester.pumpAndSettle();

        await tester.pumpWidget(
          _buildGalleryHost(
            node: claudeNode,
            theme: th.value,
            agentRepo: agentRepo,
            boundaryKey: boundaryKey,
            textScale: 2,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'large-text_$suffix', boundaryKey: boundaryKey);
      });
    }
  }
}
