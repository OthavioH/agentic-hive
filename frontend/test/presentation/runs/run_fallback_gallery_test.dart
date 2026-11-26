import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/run_graph_view.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
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

final class _FakeRunRepository implements RunRepository {
  new(this.run, this.events);

  final Run run;
  final List<RunEvent> events;

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(run);

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async =>
      Success(RunEventsResponse(items: events, lastSequence: events.length));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => Success(
    RunNodeLogsResponse(
      runId: id,
      nodeId: nodeId,
      attempt: attempt ?? 1,
      availableAttempts: const <int>[1],
    ),
  );

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async => Success(run);

  @override
  Future<Result<Run>> cancelRun(String id) async => Success(run);

  @override
  Future<Result<Run>> resumeRun(String id) async => Success(run);

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

void main() {
  setUpAll(_loadFonts);

  final now = DateTime.utc(2026, 11, 25, 12);
  final workflow = Workflow(
    id: 'wf-1',
    name: 'Fallback Flow',
    nodes: const <WorkflowNode>[
      WorkflowNode(
        id: 'n1',
        type: NodeTypeId.claudeCode,
        label: 'Coder',
        position: WorkflowPosition(x: 80, y: 120),
      ),
      WorkflowNode(
        id: 'n2',
        type: NodeTypeId.geminiCli,
        label: 'Reviewer',
        position: WorkflowPosition(x: 360, y: 120),
      ),
    ],
    edges: const <WorkflowEdge>[
      WorkflowEdge(
        id: 'e1',
        sourceNodeId: 'n1',
        sourceOutput: NodeOutput.onSuccess,
        targetNodeId: 'n2',
      ),
    ],
    createdAt: now,
    updatedAt: now,
  );

  final run = Run(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'Fallback Flow',
    workflowDefinition: workflow,
    workspacePath: '/tmp/repo',
    status: RunStatus.succeeded,
    startedAt: now,
    finishedAt: DateTime.utc(2026, 11, 25, 12, 0, 5),
  );

  final events = <RunEvent>[
    RunEvent(
      id: 'evt-fb',
      runId: 'run-1',
      sequence: 1,
      type: RunEventType.nodeFallback,
      nodeId: 'n1',
      createdAt: now,
      payload: const <String, Object?>{
        'from': <String, Object?>{'harness': NodeTypeId.claudeCode},
        'to': <String, Object?>{'harness': NodeTypeId.codex, 'model': 'gpt-x'},
        'reason': 'rate limit',
      },
    ),
  ];

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

      testWidgets('run fallback gallery $suffix', (tester) async {
        await tester.binding.setSurfaceSize(vp.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundaryKey = GlobalKey();

        // Card fell back + card without fallback
        await tester.pumpWidget(
          RepaintBoundary(
            key: boundaryKey,
            child: MaterialApp(
              debugShowCheckedModeBanner: false,
              theme: th.value,
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              supportedLocales: AppLocalizations.supportedLocales,
              home: NodeVisualScope(
                registry: createNodeVisualRegistry(),
                child: Scaffold(
                  body: RunGraphView(
                    workflow: workflow,
                    nodeStatuses: const <String, HiveNodeStatus>{
                      'n1': HiveNodeStatus.succeeded,
                      'n2': HiveNodeStatus.succeeded,
                    },
                    selectedNodeId: 'n1',
                    ranOn: const <String, FallbackEntry>{
                      'n1': FallbackEntry(
                        harness: NodeTypeId.codex,
                        model: 'gpt-x',
                      ),
                    },
                    onSelectNode: (_) {},
                  ),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'graph_$suffix', boundaryKey: boundaryKey);

        // Events tab fallback row
        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: ProviderContainer.test(
              overrides: [
                runRepositoryProvider.overrideWithValue(
                  _FakeRunRepository(run, events),
                ),
                backendWsMessagesProvider.overrideWith(
                  (_) => const Stream<WsEnvelope>.empty(),
                ),
              ],
            ),
            child: RepaintBoundary(
              key: boundaryKey,
              child: MaterialApp(
                debugShowCheckedModeBanner: false,
                theme: th.value,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: NodeVisualScope(
                  registry: createNodeVisualRegistry(),
                  child: const Scaffold(body: RunDetailPage(runId: 'run-1')),
                ),
              ),
            ),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(find.text('Events'));
        await tester.pumpAndSettle();
        await _capture(tester, 'events_$suffix', boundaryKey: boundaryKey);
      });
    }
  }
}
