import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference_store.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../workspace/fake_workspace_repository.dart';

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

Future<void> _capture(WidgetTester tester, String name) async {
  if (_captureDir.isEmpty) return;
  final dir = Directory(_captureDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final finder = find.byType(RepaintBoundary).first;
  final boundary = tester.renderObject<RenderRepaintBoundary>(finder);
  final bytes = await tester.runAsync(() async {
    final image = await boundary.toImage();
    final data = await image.toByteData(format: ui.ImageByteFormat.png);
    return data?.buffer.asUint8List();
  });
  if (bytes == null) return;
  File(p.join(_captureDir, '$name.png')).writeAsBytesSync(bytes);
}

final class _InMemorySplitterStore implements RunDetailSplitterPreferenceStore {
  RunDetailSplitterPreference value = const RunDetailSplitterPreference();

  @override
  Future<RunDetailSplitterPreference> load() async => value;

  @override
  Future<void> save(RunDetailSplitterPreference preference) async {
    value = preference;
  }
}

final class _FakeWsSession implements BackendWebSocketSession {
  final StreamController<WsEnvelope> _messages =
      StreamController<WsEnvelope>.broadcast();
  final Completer<void> _done = Completer<void>();

  @override
  ServerHelloPayload get serverHello => const ServerHelloPayload(
    protocolVersion: wsProtocolVersion,
    serverVersion: '0.1.0',
  );

  @override
  Stream<WsEnvelope> get messages => _messages.stream;

  @override
  Future<void> get done => _done.future;

  @override
  bool get isClosed => false;

  @override
  Future<Result<void>> send(WsEnvelope envelope) async => const Success(null);

  @override
  Future<void> close([int? code, String? reason]) async {
    if (!_done.isCompleted) _done.complete();
    await _messages.close();
  }
}

final class _GalleryRunRepository implements RunRepository {
  new({this.rawLogTruncated = false});

  final bool rawLogTruncated;
  final DateTime now = DateTime.utc(2026, 11, 27, 12);

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    String? workspaceId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(
    Run(
      id: id,
      workflowId: 'wf-1',
      workflowName: 'Spec #251 Run',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Spec #251 Run',
        nodes: const <WorkflowNode>[
          WorkflowNode(
            id: 'n1',
            type: NodeTypeId.claudeCode,
            label: 'Implementer',
            position: WorkflowPosition(x: 80, y: 120),
          ),
          WorkflowNode(
            id: 'n2',
            type: NodeTypeId.codex,
            label: 'Reviewer',
            position: WorkflowPosition(x: 340, y: 120),
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
      ),
      workspaceRoot: '/projects/agentic-hive',
      status: RunStatus.succeeded,
      input: 'Implement Run Detail inspector transcripts',
      startedAt: now,
      finishedAt: DateTime.utc(2026, 11, 27, 12, 0, 42),
    ),
  );

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async => Success(
    RunEventsResponse(
      items: <RunEvent>[
        RunEvent(
          id: 'evt-1',
          runId: id,
          sequence: 1,
          type: RunEventType.nodeStarted,
          nodeId: 'n1',
          createdAt: now,
        ),
        RunEvent(
          id: 'evt-2',
          runId: id,
          sequence: 2,
          type: RunEventType.nodeCompleted,
          nodeId: 'n1',
          createdAt: DateTime.utc(2026, 11, 27, 12, 0, 42),
        ),
      ],
      lastSequence: 2,
    ),
  );

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
      rawLogTruncated: rawLogTruncated,
      offset: 2,
      entries: <RunLogEntry>[
        RunLogEntry(
          stream: RunOutputStream.stdout,
          chunk: '{"type":"assistant","text":"Done"}',
          timestamp: now,
          offset: 1,
        ),
        RunLogEntry(
          stream: RunOutputStream.stderr,
          chunk: 'note: formatted 3 files',
          timestamp: now,
          offset: 2,
        ),
      ],
      transcript: const <TranscriptEntry>[
        TranscriptEntry.agentMessage(
          id: 'm1',
          firstOffset: 1,
          lastOffset: 1,
          text:
              'Updated **RunDetailPage** with collapsible cards and splitter.',
        ),
        TranscriptEntry.toolCall(
          id: 't1',
          firstOffset: 1,
          lastOffset: 1,
          name: 'edit_file',
          input: <String, Object?>{
            'path': 'lib/presentation/runs/pages/run_detail_page.dart',
          },
        ),
        TranscriptEntry.toolResult(
          id: 'r1',
          firstOffset: 1,
          lastOffset: 1,
          output: 'Applied edit cleanly.',
        ),
        TranscriptEntry.finalResult(
          id: 'f1',
          firstOffset: 2,
          lastOffset: 2,
          status: 'Succeeded',
          durationMs: 42000,
          costUsd: 0.042,
        ),
      ],
    ),
  );

  @override
  Future<Result<Run>> startRun(StartRunRequest request) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> cancelRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<Run>> resumeRun(String id) async =>
      const FailureResult(NotFoundFailure('unused'));

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
}

void main() {
  setUpAll(_loadFonts);

  const viewports = <({String name, Size size})>[
    (name: '1440x900', size: Size(1440, 900)),
    (name: '1024x768', size: Size(1024, 768)),
    (name: '800x700', size: Size(800, 700)),
  ];

  for (final themeEntry in <({String name, ThemeData theme})>[
    (name: 'dark', theme: HiveTheme.dark()),
    (name: 'light', theme: HiveTheme.light()),
  ]) {
    for (final viewport in viewports) {
      testWidgets(
        'gallery: ${viewport.name} ${themeEntry.name} collapsed + transcript',
        (tester) async {
          tester.view.physicalSize = viewport.size;
          tester.view.devicePixelRatio = 1.0;
          addTearDown(tester.view.reset);

          final ws = _FakeWsSession();
          addTearDown(ws.close);

          await tester.pumpWidget(
            ProviderScope(
              overrides: [
                runRepositoryProvider.overrideWithValue(
                  _GalleryRunRepository(rawLogTruncated: true),
                ),
                workspaceRepositoryProvider.overrideWithValue(
                  FakeWorkspaceRepository(),
                ),
                backendWebSocketSessionProvider.overrideWithValue(ws),
                backendWsMessagesProvider.overrideWith((ref) => ws.messages),
                runDetailSplitterPreferenceStoreProvider.overrideWithValue(
                  _InMemorySplitterStore(),
                ),
              ],
              child: MaterialApp(
                theme: themeEntry.theme,
                localizationsDelegates: AppLocalizations.localizationsDelegates,
                supportedLocales: AppLocalizations.supportedLocales,
                home: const Scaffold(body: RunDetailPage(runId: 'run-1')),
              ),
            ),
          );
          await tester.pumpAndSettle();

          await _capture(
            tester,
            '${viewport.name}_${themeEntry.name}_transcript',
          );

          await tester.tap(
            find.byKey(const Key('run_inspector_maximize_button')),
          );
          await tester.pumpAndSettle();

          await _capture(
            tester,
            '${viewport.name}_${themeEntry.name}_maximized',
          );
        },
      );
    }
  }
}
