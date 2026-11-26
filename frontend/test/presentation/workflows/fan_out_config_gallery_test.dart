import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

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
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

import '../workspace/fake_workspace_repository.dart';
import 'scripted_workflow_repository.dart';

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

WorkflowNode _fanOutNode({JsonMap extra = const <String, Object?>{}}) =>
    WorkflowNode(
      id: 'fan',
      type: NodeTypeId.fanOut,
      label: 'Fan Out',
      config: <String, Object?>{
        ...NodeDescriptors.fanOut.defaultConfig(),
        ...extra,
      },
      position: const WorkflowPosition(x: 100, y: 100),
    );

WorkflowEditorState _stateWith(WorkflowNode fanNode) {
  final now = DateTime.utc(2026, 11, 21, 4);
  const planner = WorkflowNode(
    id: 'planner',
    type: NodeTypeId.claudeCode,
    label: 'Planner',
    position: WorkflowPosition(x: 0, y: 0),
  );
  const reviewer = WorkflowNode(
    id: 'reviewer',
    type: NodeTypeId.codex,
    label: 'Reviewer',
    position: WorkflowPosition(x: 200, y: 0),
  );
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Test Flow',
    nodes: <WorkflowNode>[planner, reviewer, fanNode],
    edges: const <WorkflowEdge>[],
    entryNodeId: planner.id,
    createdAt: now,
    updatedAt: now,
  );
  return WorkflowEditorState(
    workflow: workflow,
    savedWorkflow: workflow,
    validation: const WorkflowValidationResult(isValid: true),
    selectedNodeId: fanNode.id,
  );
}

Future<void> _saveCapture(
  WidgetTester tester,
  GlobalKey boundaryKey,
  String id,
  String themeName,
  Size size,
) async {
  expect(tester.takeException(), isNull);
  Directory(_captureDir).createSync(recursive: true);
  final dims = '${size.width.toInt()}x${size.height.toInt()}';
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
}

Future<void> _captureConfig(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required WorkflowNode fanNode,
  WorkflowRepository? workflowRepository,
  Future<void> Function(WidgetTester tester)? drive,
  double textScale = 1.0,
  bool waitSettle = true,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final boundaryKey = GlobalKey();
  final dims = '${size.width.toInt()}x${size.height.toInt()}';

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
                state: _stateWith(fanNode),
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
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context).copyWith(
              textScaler: TextScaler.linear(textScale),
              disableAnimations: true,
            ),
            child: RepaintBoundary(key: boundaryKey, child: child),
          ),
        ),
      ),
    ),
  );

  if (waitSettle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump();
  }

  final wfFinder = find.byKey(const Key('config_fan_out_workflow'));
  if (wfFinder.evaluate().isNotEmpty) {
    await tester.ensureVisible(wfFinder);
    if (waitSettle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  if (drive != null) {
    await drive(tester);
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
  handle.dispose();
}

Future<void> _captureDeleteDialog(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required List<WorkflowReference> refs,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final repo = ScriptedWorkflowRepository()
    ..items.add(
      WorkflowSummary(
        id: 'wf-1',
        name: 'Child Flow',
        nodeCount: 2,
        edgeCount: 1,
        hasValidationErrors: false,
        updatedAt: DateTime.utc(2026, 11, 20, 12),
        revision: 'r1',
      ),
    );
  addTearDown(() async {
    for (final c in repo.live) {
      await c.close();
    }
  });
  final refRepo = _FakeWorkflowReferenceRepository()
    ..nextResult = Success(refs);
  final router = GoRouter(
    initialLocation: '/workflows',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: WorkflowsPage()),
      ),
    ],
  );
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[
        workflowRepositoryProvider.overrideWithValue(repo),
        workflowReferenceRepositoryProvider.overrideWithValue(refRepo),
      ],
      child: MaterialApp.router(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context).copyWith(
            textScaler: TextScaler.linear(textScale),
            disableAnimations: true,
          ),
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await tester.tap(find.byKey(const Key('delete_workflow_wf-1')));
  await tester.pumpAndSettle();

  await _saveCapture(tester, boundaryKey, id, themeName, size);
  handle.dispose();
}

WorkflowNode _filledNode() => _fanOutNode(
  extra: const <String, Object?>{
    'workflowId': 'wf-release',
    'itemsNodeId': 'planner',
    'itemsPath': 'issues',
    'inputField': 'issue',
    'overridesField': 'overrides',
    'nameField': 'title',
    'concurrency': 4,
    'maxItems': 50,
  },
);

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

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    for (final size in sizes) {
      final dims = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('capture cfg-fresh ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-fresh',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _fanOutNode(),
        );
      });

      testWidgets('capture cfg-filled ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-filled',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _filledNode(),
        );
      });

      testWidgets('capture cfg-int-error ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-int-error',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _filledNode(),
          drive: (tester) async {
            final field = find.byKey(const Key('config_fan_out_concurrency'));
            await tester.ensureVisible(field);
            await tester.enterText(field, '0');
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture cfg-wf-loading ($themeName $dims)', (tester) async {
        final completer = Completer<Result<List<WorkflowSummary>>>();
        await _captureConfig(
          tester,
          id: 'cfg-wf-loading',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _fanOutNode(),
          waitSettle: false,
          workflowRepository: _FakeWorkflowRepository(
            onListWorkflows: () => completer.future,
          ),
        );
      });

      testWidgets('capture cfg-wf-error ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-wf-error',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _fanOutNode(),
          workflowRepository: _FakeWorkflowRepository(
            onListWorkflows: () async =>
                const FailureResult(NetworkFailure('offline')),
          ),
        );
      });

      testWidgets('capture cfg-wf-empty ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-wf-empty',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _fanOutNode(),
          workflowRepository: _FakeWorkflowRepository(
            onListWorkflows: () async => const Success(<WorkflowSummary>[]),
          ),
        );
      });

      testWidgets('capture cfg-wf-missing ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-wf-missing',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _fanOutNode(
            extra: const <String, Object?>{'workflowId': 'wf-deleted'},
          ),
        );
      });

      testWidgets('capture cfg-select-open ($themeName $dims)', (tester) async {
        await _captureConfig(
          tester,
          id: 'cfg-select-open',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _filledNode(),
          drive: (tester) async {
            final wf = find.byKey(const Key('config_fan_out_workflow'));
            await tester.ensureVisible(wf);
            await tester.tap(wf);
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture cfg-focused-path ($themeName $dims)', (
        tester,
      ) async {
        await _captureConfig(
          tester,
          id: 'cfg-focused-path',
          themeName: themeName,
          theme: theme,
          size: size,
          fanNode: _filledNode(),
          drive: (tester) async {
            final pathField = find.byKey(
              const Key('config_fan_out_items_path'),
            );
            await tester.ensureVisible(pathField);
            await tester.tap(pathField);
            await tester.pumpAndSettle();
          },
        );
      });

      testWidgets('capture delete-referenced ($themeName $dims)', (
        tester,
      ) async {
        await _captureDeleteDialog(
          tester,
          id: 'delete-referenced',
          themeName: themeName,
          theme: theme,
          size: size,
          refs: const <WorkflowReference>[
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
          ],
        );
      });

      testWidgets('capture delete-referenced-long ($themeName $dims)', (
        tester,
      ) async {
        await _captureDeleteDialog(
          tester,
          id: 'delete-referenced-long',
          themeName: themeName,
          theme: theme,
          size: size,
          refs: const <WorkflowReference>[
            WorkflowReference(
              workflowId: 'wf-1',
              workflowName: 'Nightly Regression Suite Orchestrator',
              nodeIds: <String>['n1'],
            ),
            WorkflowReference(
              workflowId: 'wf-2',
              workflowName: 'Multi-Region Canary Verification Pipeline',
              nodeIds: <String>['n2'],
            ),
            WorkflowReference(
              workflowId: 'wf-3',
              workflowName: 'Customer Feedback Triage & Classification',
              nodeIds: <String>['n3'],
            ),
            WorkflowReference(
              workflowId: 'wf-4',
              workflowName: 'Automated Security Patch Rollout Flow',
              nodeIds: <String>['n4'],
            ),
            WorkflowReference(
              workflowId: 'wf-5',
              workflowName: 'Documentation Sync & Link Verification',
              nodeIds: <String>['n5'],
            ),
            WorkflowReference(
              workflowId: 'wf-6',
              workflowName: 'Workspace Snapshot Integrity Sweep',
              nodeIds: <String>['n6'],
            ),
          ],
        );
      });

      testWidgets('capture delete-plain ($themeName $dims)', (tester) async {
        await _captureDeleteDialog(
          tester,
          id: 'delete-plain',
          themeName: themeName,
          theme: theme,
          size: size,
          refs: const <WorkflowReference>[],
        );
      });
    }

    testWidgets('capture cfg-filled-large ($themeName 1280x720)', (
      tester,
    ) async {
      await _captureConfig(
        tester,
        id: 'cfg-filled-large',
        themeName: themeName,
        theme: theme,
        size: sizes.first,
        fanNode: _filledNode(),
        textScale: 2,
      );
    });

    testWidgets('capture delete-referenced-large ($themeName 1280x720)', (
      tester,
    ) async {
      await _captureDeleteDialog(
        tester,
        id: 'delete-referenced-large',
        themeName: themeName,
        theme: theme,
        size: sizes.first,
        textScale: 2,
        refs: const <WorkflowReference>[
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
        ],
      );
    });
  }
}
