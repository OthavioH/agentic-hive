import 'dart:async';

import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference.dart';
import 'package:agentic_hive_frontend/core/preferences/run_detail_splitter_preference_store.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/pty_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../workspace/fake_workspace_repository.dart';

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

final class _FakePtyRepository implements PtyRepository {
  final List<(int cols, int rows)> resizes = <(int, int)>[];

  @override
  Future<Result<void>> subscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) async => const Success(null);

  @override
  Future<Result<void>> unsubscribe({
    required String runId,
    required String nodeId,
    required int attempt,
  }) async => const Success(null);

  @override
  Future<Result<void>> sendInput({
    required String runId,
    required String nodeId,
    required int attempt,
    required List<int> bytes,
  }) async => const Success(null);

  @override
  Future<Result<void>> resize({
    required String runId,
    required String nodeId,
    required int attempt,
    required int cols,
    required int rows,
  }) async {
    resizes.add((cols, rows));
    return const Success(null);
  }
}

final class _RichTranscriptRunRepository implements RunRepository {
  new({
    this.isTerminal = false,
    this.failLogs = false,
    this.rawLogTruncated = false,
    this.entries = const <RunLogEntry>[],
    this.transcript = const <TranscriptEntry>[],
  });

  final bool isTerminal;
  bool failLogs;
  final bool rawLogTruncated;
  final List<RunLogEntry> entries;
  final List<TranscriptEntry> transcript;
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
      workflowName: 'Inspector Spec Flow',
      workflowDefinition: Workflow(
        id: 'wf-1',
        name: 'Inspector Spec Flow',
        nodes: <WorkflowNode>[
          WorkflowNode(
            id: 'node-1',
            type: isTerminal ? NodeTypeId.terminal : NodeTypeId.claudeCode,
            label: isTerminal
                ? 'Interactive Shell'
                : 'Very Long Node Name That Should Ellipsize Gracefully',
            position: const WorkflowPosition(x: 40, y: 40),
          ),
        ],
        edges: const <WorkflowEdge>[],
        createdAt: now,
        updatedAt: now,
      ),
      workspaceRoot: '/projects/hive',
      status: RunStatus.running,
      input: 'Implement transcript inspector',
      startedAt: now,
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
          nodeId: 'node-1',
          createdAt: now,
        ),
      ],
      lastSequence: 1,
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
  }) async {
    if (failLogs) {
      return const FailureResult(NetworkFailure('Cannot reach backend'));
    }
    return Success(
      RunNodeLogsResponse(
        runId: id,
        nodeId: nodeId,
        attempt: attempt ?? 1,
        availableAttempts: const <int>[1],
        entries: entries,
        transcript: transcript,
        rawLogTruncated: rawLogTruncated,
        offset: entries.length,
      ),
    );
  }

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

Future<void> _pumpPage(
  WidgetTester tester, {
  required RunRepository runs,
  required Size size,
  RunDetailSplitterPreferenceStore? splitterStore,
  PtyRepository? pty,
  double textScale = 1.0,
}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.reset);

  final ws = _FakeWsSession();
  addTearDown(ws.close);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(runs),
        workspaceRepositoryProvider.overrideWithValue(
          FakeWorkspaceRepository(),
        ),
        backendWebSocketSessionProvider.overrideWithValue(ws),
        backendWsMessagesProvider.overrideWith((ref) => ws.messages),
        runDetailSplitterPreferenceStoreProvider.overrideWithValue(
          splitterStore ?? _InMemorySplitterStore(),
        ),
        if (pty != null) ptyRepositoryProvider.overrideWithValue(pty),
      ],
      child: MaterialApp(
        theme: HiveTheme.dark(),
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: child!,
        ),
        home: const Scaffold(body: RunDetailPage(runId: 'run-1')),
      ),
    ),
  );
  await tester.pumpAndSettle();
}

void main() {
  testWidgets(
    'cards start collapsed, splitter switches at 840px, persists drag, and '
    'maximize/Esc restore work',
    (tester) async {
      final store = _InMemorySplitterStore();
      final repo = _RichTranscriptRunRepository();

      await _pumpPage(
        tester,
        runs: repo,
        size: const Size(1440, 900),
        splitterStore: store,
      );

      // Metadata and input cards start collapsed.
      expect(find.text('Direct'), findsNothing);
      expect(find.text('Implement transcript inspector'), findsNothing);

      await tester.tap(find.text('Run details'));
      await tester.pumpAndSettle();
      expect(find.text('Direct'), findsOneWidget);

      await tester.tap(find.text('Run input'));
      await tester.pumpAndSettle();
      expect(find.text('Implement transcript inspector'), findsOneWidget);

      // Wide layout uses horizontal HiveSplitter.
      final splitter = tester.widget<HiveSplitter>(find.byType(HiveSplitter));
      expect(splitter.axis, Axis.horizontal);

      // Dragging splitter updates and persists sideBySide fraction.
      final handleFinder = find.bySemanticsLabel('Resize graph and inspector');
      await tester.drag(handleFinder, const Offset(80, 0));
      await tester.pumpAndSettle();
      expect(store.value.sideBySide, greaterThan(0.45));

      // Maximize hides graph and Esc restores it.
      await tester.tap(find.byKey(const Key('run_inspector_maximize_button')));
      await tester.pumpAndSettle();
      expect(find.byType(HiveSplitter), findsNothing);
      expect(
        find.byKey(const Key('run_inspector_maximize_button')),
        findsOneWidget,
      );

      await tester.sendKeyEvent(LogicalKeyboardKey.escape);
      await tester.pumpAndSettle();
      expect(find.byType(HiveSplitter), findsOneWidget);

      // Narrow layout (< 840px) uses vertical HiveSplitter.
      await _pumpPage(
        tester,
        runs: repo,
        size: const Size(800, 700),
        splitterStore: store,
      );
      final verticalSplitter = tester.widget<HiveSplitter>(
        find.byType(HiveSplitter),
      );
      expect(verticalSplitter.axis, Axis.vertical);
    },
  );

  testWidgets('terminal node preserves session and resizes across maximize', (
    tester,
  ) async {
    final pty = _FakePtyRepository();
    final repo = _RichTranscriptRunRepository(isTerminal: true);

    await _pumpPage(tester, runs: repo, size: const Size(1200, 800), pty: pty);

    expect(find.byType(HiveTerminalView), findsOneWidget);
    final initialResizes = pty.resizes.length;

    await tester.tap(find.byKey(const Key('run_inspector_maximize_button')));
    await tester.pumpAndSettle();
    expect(find.byType(HiveTerminalView), findsOneWidget);
    expect(pty.resizes.length, greaterThan(initialResizes));

    await tester.sendKeyEvent(LogicalKeyboardKey.escape);
    await tester.pumpAndSettle();
    expect(find.byType(HiveTerminalView), findsOneWidget);
  });

  testWidgets('renders all transcript entry kinds, collapse/expand, Show all, '
      'truncation banner, Raw switch, copy, and error retry', (tester) async {
    String? copiedText;
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        if (call.method == 'Clipboard.setData') {
          copiedText =
              (call.arguments as Map<Object?, Object?>)['text'] as String?;
        }
        return null;
      },
    );
    addTearDown(() {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      );
    });

    final now = DateTime.utc(2026, 11, 27, 12);
    final longPlainText = List<String>.generate(
      210,
      (i) => 'plain line ${i + 1}',
    ).join('\n');
    final repo = _RichTranscriptRunRepository(
      rawLogTruncated: true,
      entries: <RunLogEntry>[
        RunLogEntry(
          stream: RunOutputStream.stdout,
          chunk: '{"type":"assistant","text":"Hello"}',
          timestamp: now,
          offset: 1,
        ),
        RunLogEntry(
          stream: RunOutputStream.stderr,
          chunk: 'stderr warning line',
          timestamp: now,
          offset: 2,
        ),
      ],
      transcript: <TranscriptEntry>[
        const TranscriptEntry.agentMessage(
          id: 'e1',
          firstOffset: 1,
          lastOffset: 1,
          text: 'Agent summary message',
        ),
        const TranscriptEntry.thinking(
          id: 'e2',
          firstOffset: 1,
          lastOffset: 1,
          text: 'Secret reasoning text',
        ),
        const TranscriptEntry.toolCall(
          id: 'e3',
          firstOffset: 1,
          lastOffset: 1,
          name: 'read_file',
          input: <String, Object?>{'path': 'lib/main.dart'},
        ),
        const TranscriptEntry.toolResult(
          id: 'e4',
          firstOffset: 1,
          lastOffset: 1,
          output: 'tool output body',
        ),
        const TranscriptEntry.error(
          id: 'e5',
          firstOffset: 1,
          lastOffset: 1,
          message: 'Tool failed',
        ),
        const TranscriptEntry.finalResult(
          id: 'e6',
          firstOffset: 1,
          lastOffset: 1,
          status: 'Succeeded',
          durationMs: 1200,
        ),
        TranscriptEntry.plainText(
          id: 'e7',
          firstOffset: 2,
          lastOffset: 2,
          stream: RunOutputStream.stdout,
          text: longPlainText,
        ),
      ],
    );

    await _pumpPage(tester, runs: repo, size: const Size(1440, 900));

    // Truncation banner is shown.
    expect(
      find.byKey(const Key('run_transcript_truncated_banner')),
      findsOneWidget,
    );

    // Scroll to top to verify early blocks in the lazy list, then expand
    // thinking.
    tester
        .state<ScrollableState>(
          find.descendant(
            of: find.byType(HiveTranscriptView),
            matching: find.byType(Scrollable),
          ),
        )
        .position
        .jumpTo(0);
    await tester.pumpAndSettle();
    expect(
      find.text('Agent summary message', findRichText: true),
      findsOneWidget,
    );
    expect(find.text('Tool failed'), findsOneWidget);
    expect(find.text('Secret reasoning text'), findsNothing);
    expect(find.text('tool output body'), findsNothing);

    await tester.tap(find.text('Thinking'));
    await tester.pumpAndSettle();
    expect(find.text('Secret reasoning text'), findsOneWidget);

    // Scroll down to verify Final result omits null Cost and Tokens.
    await tester.scrollUntilVisible(
      find.text('Succeeded'),
      200,
      scrollable: find.descendant(
        of: find.byType(HiveTranscriptView),
        matching: find.byType(Scrollable),
      ),
    );
    expect(find.text('Succeeded'), findsOneWidget);
    expect(find.text('Duration: 1.2s'), findsOneWidget);
    expect(find.textContaining('Cost:'), findsNothing);
    expect(find.textContaining('Tokens:'), findsNothing);

    // Copy in Transcript mode copies transcript text.
    await tester.tap(find.byKey(const Key('run_transcript_copy_button')));
    await tester.pump();
    expect(copiedText, contains('Agent summary message'));
    expect(find.text('Copied to clipboard'), findsOneWidget);

    // Switch to Raw and copy raw lines.
    await tester.tap(find.text('Raw'));
    await tester.pumpAndSettle();
    expect(find.text('stderr warning line'), findsOneWidget);

    await tester.tap(find.byKey(const Key('run_transcript_copy_button')));
    await tester.pump();
    expect(copiedText, contains('stderr warning line'));

    // Accessibility guidelines pass on the page.
    await expectLater(tester, meetsGuideline(labeledTapTargetGuideline));
  });

  testWidgets('transcript error banner retries and recovers', (tester) async {
    final repo = _RichTranscriptRunRepository(
      failLogs: true,
      transcript: const <TranscriptEntry>[
        TranscriptEntry.agentMessage(
          id: 'm1',
          firstOffset: 1,
          lastOffset: 1,
          text: 'Recovered message',
        ),
      ],
    );

    await _pumpPage(tester, runs: repo, size: const Size(1440, 900));

    expect(
      find.byKey(const Key('run_transcript_error_banner')),
      findsOneWidget,
    );
    expect(find.text("Couldn't load the transcript"), findsOneWidget);

    repo.failLogs = false;
    await tester.tap(find.byKey(const Key('run_transcript_retry_button')));
    await tester.pumpAndSettle();

    expect(find.byKey(const Key('run_transcript_error_banner')), findsNothing);
    expect(find.text('Recovered message', findRichText: true), findsOneWidget);
  });

  testWidgets('inspector header row survives 200% text scaling', (
    tester,
  ) async {
    final repo = _RichTranscriptRunRepository(
      transcript: const <TranscriptEntry>[
        TranscriptEntry.agentMessage(
          id: 'm1',
          firstOffset: 1,
          lastOffset: 1,
          text: 'Scaled message',
        ),
      ],
    );

    await _pumpPage(
      tester,
      runs: repo,
      size: const Size(1440, 900),
      textScale: 2,
    );

    await tester.tap(find.byKey(const Key('run_inspector_maximize_button')));
    await tester.pumpAndSettle();

    expect(find.text('Scaled message', findRichText: true), findsOneWidget);
  });
}
