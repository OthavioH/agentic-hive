import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/attachments/attachment_input_source.dart';
import 'package:agentic_hive_frontend/core/backend/backend_connection.dart';
import 'package:agentic_hive_frontend/core/backend/backend_web_socket_session.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_settings_providers.dart';
import 'package:agentic_hive_frontend/domain/runs/run_attachment_drafts.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/pages/run_detail_page.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/start_run_dialog.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import '../../support/fake_attachment_input_source.dart';
import '../workspace/fake_workspace_repository.dart';
import '../workspace/fake_workspace_settings_repository.dart';

const String _captureDir = String.fromEnvironment('HIVE_CAPTURE_DIR');
final DateTime _baseTime = DateTime.utc(2026, 11, 21, 10);

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

Uint8List _pngBytes([int length = 1024]) =>
    Uint8List(length)
      ..setAll(0, const <int>[0x89, 0x50, 0x4E, 0x47, 0x0D, 0x0A, 0x1A, 0x0A]);

Uint8List _pdfBytes() => Uint8List.fromList('%PDF-1.7\n'.codeUnits);

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

final class _FakeWorkflowRepository implements WorkflowRepository {
  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => Success(<WorkflowSummary>[
    WorkflowSummary(
      id: 'wf-1',
      name: 'Release Build',
      nodeCount: 2,
      edgeCount: 1,
      hasValidationErrors: false,
      updatedAt: _baseTime,
    ),
  ]);

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

final class _GalleryRunRepository implements RunRepository {
  new({Run? run, this.startHandler}) : _run = run ?? _defaultRun();

  final Run _run;
  final Future<Result<Run>> Function(StartRunRequest request)? startHandler;

  static Run _defaultRun({
    String? input = 'Review the attached layout capture and fix alignment.',
    List<RunAttachment>? attachments,
    RunStatus status = RunStatus.running,
  }) => Run(
    id: 'run-1',
    workflowId: 'wf-1',
    workflowName: 'Release Build',
    workflowDefinition: Workflow(
      id: 'wf-1',
      name: 'Release Build',
      nodes: const <WorkflowNode>[
        WorkflowNode(
          id: 'node-1',
          type: 'command',
          label: 'Build',
          position: WorkflowPosition(x: 40, y: 40),
        ),
      ],
      edges: const <WorkflowEdge>[],
      createdAt: _baseTime,
      updatedAt: _baseTime,
    ),
    workspaceRoot: '/projects/hive',
    status: status,
    startedAt: _baseTime,
    finishedAt: status.isActive ? null : DateTime.utc(2026, 11, 21, 10, 2),
    input: input,
    attachments: attachments,
  );

  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success(RunsListResponse(items: <RunSummary>[], total: 0));

  @override
  Future<Result<Run>> getRun(String id) async => Success(_run);

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) async =>
      const Success(RunEventsResponse(items: <RunEvent>[], lastSequence: 0));

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) async =>
      const Success(<Checkpoint>[]);

  @override
  Future<Result<Run>> startRun(StartRunRequest request) {
    if (startHandler != null) return startHandler!(request);
    return Future<Result<Run>>.value(Success(_run));
  }

  @override
  Future<Result<Run>> cancelRun(String id) async => Success(_run);

  @override
  Future<Result<Run>> resumeRun(String id) async => Success(_run);

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) async => Success(
    RunNodeLogsResponse(runId: id, nodeId: nodeId, attempt: attempt ?? 1),
  );

  @override
  Future<Result<void>> deleteRun(String id) async => const Success(null);
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

Future<void> _captureDialog(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  _GalleryRunRepository? runRepo,
  WorkspaceRepository? workspaceRepo,
  Future<void> Function(
    WidgetTester tester,
    FakeAttachmentInputSource inputSource,
  )?
  drive,
  bool settle = true,
}) async {
  const size = Size(1280, 800);
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final inputSource = FakeAttachmentInputSource();
  addTearDown(inputSource.dispose);
  final boundaryKey = GlobalKey();

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(
          runRepo ?? _GalleryRunRepository(),
        ),
        workflowRepositoryProvider.overrideWithValue(_FakeWorkflowRepository()),
        workspaceRepositoryProvider.overrideWithValue(
          workspaceRepo ??
              FakeWorkspaceRepository(
                workspaces: <Workspace>[
                  makeWorkspace(rootPath: '/projects/hive'),
                ],
              ),
        ),
        workspaceSettingsRepositoryProvider.overrideWithValue(
          FakeWorkspaceSettingsRepository(),
        ),
        attachmentInputSourceProvider.overrideWithValue(inputSource),
      ],
      child: RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: Center(child: StartRunDialog())),
        ),
      ),
    ),
  );

  if (settle) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
  }

  if (drive != null) {
    await drive(tester, inputSource);
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
}

Future<void> _captureDetail(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required Run run,
  Future<void> Function(WidgetTester tester)? drive,
}) async {
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  final ws = _FakeWsSession();
  addTearDown(ws.close);
  final boundaryKey = GlobalKey();
  final router = GoRouter(
    initialLocation: '/runs/${run.id}',
    routes: <RouteBase>[
      GoRoute(
        path: '/runs/:id',
        builder: (_, state) =>
            Scaffold(body: RunDetailPage(runId: state.pathParameters['id']!)),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        runRepositoryProvider.overrideWithValue(
          _GalleryRunRepository(run: run),
        ),
        backendWebSocketSessionProvider.overrideWithValue(ws),
        backendWsMessagesProvider.overrideWith((ref) => ws.messages),
      ],
      child: RepaintBoundary(
        key: boundaryKey,
        child: MaterialApp.router(
          theme: theme,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (drive != null) {
    await drive(tester);
  }

  await _saveCapture(tester, boundaryKey, id, themeName, size);
}

void main() {
  setUpAll(() async {
    if (_captureDir.isNotEmpty) {
      await _loadFonts();
    }
  });

  final themes = <String, ThemeData>{
    'light': HiveTheme.light(),
    'dark': HiveTheme.dark(),
  };

  const detailSizes = <Size>[Size(1280, 800), Size(1920, 1080)];

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    group(
      'run attachments gallery ($themeName)',
      skip: _captureDir.isEmpty
          ? 'Requires --dart-define=HIVE_CAPTURE_DIR'
          : false,
      () {
        testWidgets('dialog-loading', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-loading',
            themeName: themeName,
            theme: theme,
            settle: false,
          );
        });

        testWidgets('dialog-empty', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-empty',
            themeName: themeName,
            theme: theme,
          );
        });

        testWidgets('dialog-drag-over', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-drag-over',
            themeName: themeName,
            theme: theme,
            drive: (tester, source) async {
              source.emit(AttachmentDragEntered());
              await tester.pumpAndSettle();
            },
          );
        });

        testWidgets('dialog-with-attachments', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-with-attachments',
            themeName: themeName,
            theme: theme,
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  RunAttachmentCandidate(
                    fileName: 'wireframe.png',
                    sizeBytes: 24576,
                    bytes: _pngBytes(24576),
                  ),
                  RunAttachmentCandidate(
                    fileName: 'Pasted image 1.png',
                    sizeBytes: 4096,
                    bytes: _pngBytes(4096),
                  ),
                ]),
              );
              await tester.pumpAndSettle();
            },
          );
        });

        testWidgets('dialog-type-error', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-type-error',
            themeName: themeName,
            theme: theme,
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  RunAttachmentCandidate(
                    fileName: 'notes.pdf',
                    sizeBytes: _pdfBytes().length,
                    bytes: _pdfBytes(),
                  ),
                ]),
              );
              await tester.pumpAndSettle();
            },
          );
        });

        testWidgets('dialog-limits-error', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-limits-error',
            themeName: themeName,
            theme: theme,
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  const RunAttachmentCandidate(
                    fileName: 'huge.png',
                    sizeBytes: RunAttachmentLimits.maxBytesEach + 1024,
                    bytes: null,
                  ),
                ]),
              );
              await tester.pumpAndSettle();
            },
          );
        });

        testWidgets('dialog-partial', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-partial',
            themeName: themeName,
            theme: theme,
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  RunAttachmentCandidate(
                    fileName: 'screen.png',
                    sizeBytes: 1536,
                    bytes: _pngBytes(1536),
                  ),
                  RunAttachmentCandidate(
                    fileName: 'notes.pdf',
                    sizeBytes: _pdfBytes().length,
                    bytes: _pdfBytes(),
                  ),
                ]),
              );
              await tester.pumpAndSettle();
            },
          );
        });

        testWidgets('dialog-busy', (tester) async {
          final completer = Completer<Result<Run>>();
          await _captureDialog(
            tester,
            id: 'dialog-busy',
            themeName: themeName,
            theme: theme,
            runRepo: _GalleryRunRepository(
              startHandler: (_) => completer.future,
            ),
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  RunAttachmentCandidate(
                    fileName: 'screen.png',
                    sizeBytes: 1536,
                    bytes: _pngBytes(1536),
                  ),
                ]),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const Key('start_run_confirm_button')),
              );
              await tester.pump();
            },
          );
        });

        testWidgets('dialog-start-error', (tester) async {
          await _captureDialog(
            tester,
            id: 'dialog-start-error',
            themeName: themeName,
            theme: theme,
            runRepo: _GalleryRunRepository(
              startHandler: (_) async => const FailureResult(
                BackendFailure('Conflict', statusCode: 409),
              ),
            ),
            drive: (tester, source) async {
              source.emit(
                AttachmentFilesDropped(<RunAttachmentCandidate>[
                  RunAttachmentCandidate(
                    fileName: 'screen.png',
                    sizeBytes: 1536,
                    bytes: _pngBytes(1536),
                  ),
                ]),
              );
              await tester.pumpAndSettle();
              await tester.tap(
                find.byKey(const Key('start_run_confirm_button')),
              );
              await tester.pumpAndSettle();
            },
          );
        });

        for (final size in detailSizes) {
          final dims = '${size.width.toInt()}x${size.height.toInt()}';

          testWidgets('detail-text-present ($dims)', (tester) async {
            await _captureDetail(
              tester,
              id: 'detail-text-present',
              themeName: themeName,
              theme: theme,
              size: size,
              run: _GalleryRunRepository._defaultRun(),
            );
          });

          testWidgets('detail-copied-toast ($dims)', (tester) async {
            tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
              SystemChannels.platform,
              (_) async => null,
            );
            addTearDown(() {
              tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
                SystemChannels.platform,
                null,
              );
            });
            await _captureDetail(
              tester,
              id: 'detail-copied-toast',
              themeName: themeName,
              theme: theme,
              size: size,
              run: _GalleryRunRepository._defaultRun(),
              drive: (tester) async {
                await tester.tap(
                  find.byKey(const Key('run_detail_input_copy')),
                );
                await tester.pump();
                await tester.pump(HiveMotionTokens.standard.medium);
              },
            );
          });

          testWidgets('detail-attachments-active ($dims)', (tester) async {
            await _captureDetail(
              tester,
              id: 'detail-attachments-active',
              themeName: themeName,
              theme: theme,
              size: size,
              run: _GalleryRunRepository._defaultRun(
                attachments: const <RunAttachment>[
                  RunAttachment(
                    fileName: 'wireframe.png',
                    mimeType: 'image/png',
                    sizeBytes: 24576,
                  ),
                  RunAttachment(
                    fileName: 'Pasted image 1.png',
                    mimeType: 'image/png',
                    sizeBytes: 4096,
                  ),
                ],
              ),
            );
          });

          testWidgets('detail-attachments-ended ($dims)', (tester) async {
            await _captureDetail(
              tester,
              id: 'detail-attachments-ended',
              themeName: themeName,
              theme: theme,
              size: size,
              run: _GalleryRunRepository._defaultRun(
                status: RunStatus.succeeded,
                attachments: const <RunAttachment>[
                  RunAttachment(
                    fileName: 'wireframe.png',
                    mimeType: 'image/png',
                    sizeBytes: 24576,
                  ),
                  RunAttachment(
                    fileName: 'Pasted image 1.png',
                    mimeType: 'image/png',
                    sizeBytes: 4096,
                  ),
                ],
              ),
            );
          });

          testWidgets('detail-attachments-only-no-text ($dims)', (
            tester,
          ) async {
            await _captureDetail(
              tester,
              id: 'detail-attachments-only-no-text',
              themeName: themeName,
              theme: theme,
              size: size,
              run: _GalleryRunRepository._defaultRun(
                input: null,
                attachments: const <RunAttachment>[
                  RunAttachment(
                    fileName: 'wireframe.png',
                    mimeType: 'image/png',
                    sizeBytes: 24576,
                  ),
                ],
              ),
            );
          });
        }
      },
    );
  }
}
