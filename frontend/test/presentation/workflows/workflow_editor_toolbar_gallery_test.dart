import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/routes/app_routes.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
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
  required Key boundaryKey,
  Rect? cropRect,
}) async {
  if (_captureDir.isEmpty) return;
  final dir = Directory(_captureDir);
  if (!dir.existsSync()) {
    dir.createSync(recursive: true);
  }
  final boundary = tester.renderObject<RenderRepaintBoundary>(
    find.byKey(boundaryKey),
  );
  final bytes = await tester.runAsync(() async {
    final fullImage = await boundary.toImage();
    try {
      if (cropRect == null) {
        final data = await fullImage.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      }
      final left = cropRect.left.clamp(0.0, fullImage.width.toDouble());
      final top = cropRect.top.clamp(0.0, fullImage.height.toDouble());
      final right = cropRect.right.clamp(left, fullImage.width.toDouble());
      final bottom = cropRect.bottom.clamp(top, fullImage.height.toDouble());
      final width = (right - left).round();
      final height = (bottom - top).round();
      final recorder = ui.PictureRecorder();
      ui.Canvas(recorder).drawImageRect(
        fullImage,
        Rect.fromLTRB(left, top, right, bottom),
        Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
        ui.Paint(),
      );
      final picture = recorder.endRecording();
      final cropped = await picture.toImage(width, height);
      try {
        final data = await cropped.toByteData(format: ui.ImageByteFormat.png);
        return data?.buffer.asUint8List();
      } finally {
        cropped.dispose();
        picture.dispose();
      }
    } finally {
      fullImage.dispose();
    }
  });
  if (bytes == null) return;
  File(p.join(_captureDir, '$name.png')).writeAsBytesSync(bytes);
}

final class _FakeWorkflowRepository implements WorkflowRepository {
  Result<WorkflowResponse>? saveOverride;

  Workflow stored = Workflow(
    id: 'wf-1',
    name: 'Editable Flow',
    nodes: const <WorkflowNode>[],
    edges: const <WorkflowEdge>[],
    createdAt: DateTime.utc(2026, 11, 20, 12),
    updatedAt: DateTime.utc(2026, 11, 20, 12),
  );

  WorkflowValidationResult validation = const WorkflowValidationResult(
    isValid: false,
    issues: <WorkflowValidationIssue>[
      WorkflowValidationIssue(
        severity: WorkflowValidationSeverity.error,
        code: WorkflowValidationCode.emptyNodes,
        message: 'Backend message ignored by localized UI.',
      ),
    ],
  );

  @override
  Future<Result<WorkflowResponse>> getWorkflow(
    String id, {
    DefinitionScope scope = const GlobalScope(),
  }) async =>
      Success(WorkflowResponse(workflow: stored, validation: validation));

  @override
  Future<Result<WorkflowResponse>> updateWorkflow(
    String id,
    UpdateWorkflowRequest request, {
    DefinitionScope scope = const GlobalScope(),
  }) async {
    if (saveOverride != null) return saveOverride!;
    stored = stored.copyWith(
      name: request.name,
      description: request.description,
      nodes: request.nodes,
      edges: request.edges,
      entryNodeId: request.entryNodeId,
    );
    validation = const WorkflowValidationResult(isValid: true);
    return Success(WorkflowResponse(workflow: stored, validation: validation));
  }

  @override
  Future<Result<WorkflowValidationResult>> validateWorkflow(
    Workflow workflow,
  ) async {
    if (workflow.nodes.isEmpty) {
      return Success(validation);
    }
    return const Success(WorkflowValidationResult(isValid: true));
  }

  @override
  Future<Result<List<WorkflowSummary>>> listWorkflows({
    DefinitionScope scope = const GlobalScope(),
  }) async => const Success(<WorkflowSummary>[]);

  @override
  Future<Result<WorkflowResponse>> createWorkflow(
    CreateWorkflowRequest request,
  ) async => const FailureResult(NotFoundFailure('unused'));

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
  }) => Stream.value(const WorkflowDeletionSucceeded());
}

Widget _buildGalleryHost({
  required _FakeWorkflowRepository repo,
  required Key boundaryKey,
  double textScale = 1.0,
}) {
  final router = GoRouter(
    initialLocation: '/workflows/wf-1',
    routes: $appRoutes,
  );
  return UncontrolledProviderScope(
    container: ProviderContainer.test(
      overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
    ),
    child: RepaintBoundary(
      key: boundaryKey,
      child: NodeVisualScope(
        registry: createNodeVisualRegistry(),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: HiveTheme.dark(),
          routerConfig: router,
          builder: (context, child) => MediaQuery(
            data: MediaQuery.of(context)
                .copyWith(textScaler: TextScaler.linear(textScale)),
            child: child!,
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  const viewports = <({String label, Size size, bool narrow})>[
    (label: '2560x1440', size: Size(2560, 1440), narrow: false),
    (label: '1440x900', size: Size(1440, 900), narrow: false),
    (label: '640x800', size: Size(640, 800), narrow: true),
  ];

  for (final vp in viewports) {
    testWidgets('editor toolbar gallery ${vp.label}', (tester) async {
      tester.view.physicalSize = vp.size;
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.reset);

      final originalOnError = FlutterError.onError;
      if (vp.narrow) {
        // Pre-existing body overflow below minDesktopWidth at 640x800;
        // suppress only RenderFlex overflow so the toolbar can be captured.
        FlutterError.onError = (details) {
          final isOverflow = details.exceptionAsString().contains(
            'A RenderFlex overflowed by',
          );
          if (!isOverflow) {
            originalOnError?.call(details);
          }
        };
        addTearDown(() => FlutterError.onError = originalOnError);
      }

      const boundaryKey = Key('toolbar_gallery_boundary');
      final repo = _FakeWorkflowRepository();
      if (vp.narrow) {
        repo.stored = repo.stored.copyWith(
          name: 'A very long workflow name ' * 8,
        );
      }

      await tester.pumpWidget(
        _buildGalleryHost(repo: repo, boundaryKey: boundaryKey),
      );
      await tester.pumpAndSettle();

      Rect? toolbarCrop() {
        if (!vp.narrow) return null;
        final rect = tester.getRect(find.byKey(const Key('editor_toolbar')));
        return Rect.fromLTWH(0, 0, vp.size.width, rect.bottom + 16);
      }

      expect(find.byKey(const Key('editor_toolbar')), findsOneWidget);
      await _capture(
        tester,
        'saved_${vp.label}',
        boundaryKey: boundaryKey,
        cropRect: toolbarCrop(),
      );

      final paletteItem = find.byKey(
        const Key('palette_item_${NodeTypeId.command}'),
      );
      await tester.ensureVisible(paletteItem);
      await tester.tap(paletteItem);
      await tester.pumpAndSettle();

      if (vp.narrow) {
        final scrollView = find.descendant(
          of: find.byKey(const Key('editor_toolbar')),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollView).position;
        position.jumpTo(position.maxScrollExtent / 2);
        await tester.pumpAndSettle();
      }

      await _capture(
        tester,
        'dirty_${vp.label}',
        boundaryKey: boundaryKey,
        cropRect: toolbarCrop(),
      );

      if (vp.narrow) {
        final scrollView = find.descendant(
          of: find.byKey(const Key('editor_toolbar')),
          matching: find.byType(Scrollable),
        );
        tester.state<ScrollableState>(scrollView).position.jumpTo(0);
        await tester.pumpAndSettle();
      }

      repo.saveOverride = const FailureResult(NetworkFailure('offline'));
      await tester.tap(find.byKey(const Key('editor_save_button')));
      await tester.pumpAndSettle();

      if (vp.narrow) {
        final scrollView = find.descendant(
          of: find.byKey(const Key('editor_toolbar')),
          matching: find.byType(Scrollable),
        );
        final position = tester.state<ScrollableState>(scrollView).position;
        position.jumpTo(position.maxScrollExtent);
        await tester.pumpAndSettle();
      }

      await _capture(
        tester,
        'save-failure_${vp.label}',
        boundaryKey: boundaryKey,
        cropRect: toolbarCrop(),
      );
    });
  }

  testWidgets('editor toolbar gallery large-text 1440x900', (tester) async {
    tester.view.physicalSize = const Size(1440, 900);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);

    const boundaryKey = Key('toolbar_gallery_large_text_boundary');
    final repo = _FakeWorkflowRepository();

    await tester.pumpWidget(
      _buildGalleryHost(repo: repo, boundaryKey: boundaryKey, textScale: 2),
    );
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.byKey(const Key('editor_toolbar')), findsOneWidget);

    await _capture(tester, 'large-text_1440x900', boundaryKey: boundaryKey);
  });
}
