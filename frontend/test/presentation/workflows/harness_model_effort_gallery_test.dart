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
import 'package:flutter/gestures.dart';
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

WorkflowNode _nodeOf(String type, [JsonMap extra = const <String, dynamic>{}]) {
  return WorkflowNode(
    id: 'n1',
    type: type,
    label: 'Code Review',
    config: <String, dynamic>{
      ...NodeDescriptors.of(type)!.defaultConfig(),
      ...extra,
    },
    position: const WorkflowPosition(x: 0, y: 0),
  );
}

WorkflowEditorState _stateWith(WorkflowNode node) {
  final now = DateTime.utc(2026, 11, 21, 4);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: <WorkflowNode>[node],
    edges: const <WorkflowEdge>[],
    entryNodeId: node.id,
    createdAt: now,
    updatedAt: now,
  );
  return WorkflowEditorState(
    workflow: workflow,
    savedWorkflow: workflow,
    validation: const WorkflowValidationResult(isValid: true),
    selectedNodeId: node.id,
  );
}

Future<void> _scrollToConfigFields(WidgetTester tester) async {
  const effortKey = Key('config_harness_effort');
  const modelKey = Key('config_harness_model');
  const extraArgsKey = Key('config_harness_extra_args');
  if (find.byKey(effortKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(effortKey));
  }
  if (find.byKey(modelKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(modelKey));
  }
  if (find.byKey(extraArgsKey).evaluate().isNotEmpty) {
    await tester.ensureVisible(find.byKey(extraArgsKey));
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
  final outPath = p.join(
    _captureDir,
    '${id}_${themeName}_${size.width.toInt()}x${size.height.toInt()}.png',
  );
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
        (
          id: 'supported-empty',
          node: _nodeOf(NodeTypeId.claudeCode),
          drive: null,
        ),
        (
          id: 'supported-filled',
          node: _nodeOf(NodeTypeId.claudeCode, const <String, dynamic>{
            'model': 'opus',
            'effort': 'high',
          }),
          drive: null,
        ),
        (id: 'not-supported', node: _nodeOf(NodeTypeId.terminal), drive: null),
        (id: 'gemini', node: _nodeOf(NodeTypeId.geminiCli), drive: null),
        (
          id: 'invalid-effort',
          node: _nodeOf(NodeTypeId.geminiCli, const <String, dynamic>{
            'effort': 'high',
          }),
          drive: null,
        ),
        (
          id: 'invalid-model',
          node: _nodeOf(NodeTypeId.terminal, const <String, dynamic>{
            'model': 'opus',
          }),
          drive: null,
        ),
        (
          id: 'unknown-effort',
          node: _nodeOf(NodeTypeId.claudeCode, const <String, dynamic>{
            'effort': 'ultra',
          }),
          drive: null,
        ),
        (
          id: 'select-open',
          node: _nodeOf(NodeTypeId.claudeCode),
          drive: (tester) async {
            final effortFinder = find.byKey(const Key('config_harness_effort'));
            await tester.ensureVisible(effortFinder);
            await tester.tap(effortFinder);
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'focused-model',
          node: _nodeOf(NodeTypeId.claudeCode),
          drive: (tester) async {
            final modelFinder = find.byKey(const Key('config_harness_model'));
            await tester.ensureVisible(modelFinder);
            await tester.tap(modelFinder);
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'hovered-model',
          node: _nodeOf(NodeTypeId.claudeCode),
          drive: (tester) async {
            final modelFinder = find.byKey(const Key('config_harness_model'));
            await tester.ensureVisible(modelFinder);
            final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
            addTearDown(g.removePointer);
            await g.addPointer(location: Offset.zero);
            await g.moveTo(tester.getCenter(modelFinder));
            await tester.pump();
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

    testWidgets('capture supported-empty-large (${themeEntry.key} 1280x720)', (
      tester,
    ) async {
      await _capture(
        tester,
        id: 'supported-empty-large',
        themeName: themeEntry.key,
        theme: themeEntry.value,
        size: sizes.first,
        node: _nodeOf(NodeTypeId.claudeCode),
        textScale: 2,
      );
    });

    testWidgets('capture invalid-effort-large (${themeEntry.key} 1280x720)', (
      tester,
    ) async {
      await _capture(
        tester,
        id: 'invalid-effort-large',
        themeName: themeEntry.key,
        theme: themeEntry.value,
        size: sizes.first,
        node: _nodeOf(NodeTypeId.geminiCli, const <String, dynamic>{
          'effort': 'high',
        }),
        textScale: 2,
      );
    });
  }
}
