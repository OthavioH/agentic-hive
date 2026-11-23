import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/workflows/workflow_providers.dart';
import 'package:agentic_hive_frontend/domain/workflows/workflow_deletion_update.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/pages/workflows_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:material_ui/material_ui.dart';

import 'scripted_workflow_repository.dart';

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

String _galleryPath(String name) {
  final inFrontend = Directory('test/presentation/workflows').existsSync();
  final dir = inFrontend
      ? 'test/presentation/workflows/gallery'
      : 'frontend/test/presentation/workflows/gallery';
  Directory(dir).createSync(recursive: true);
  return '$dir/$name.png';
}

String _structurePath(String name) {
  final inFrontend = Directory('test/presentation/workflows').existsSync();
  final dir = inFrontend
      ? 'test/presentation/workflows/gallery_structure'
      : 'frontend/test/presentation/workflows/gallery_structure';
  Directory(dir).createSync(recursive: true);
  return '$dir/$name.txt';
}

String _structureDump(WidgetTester tester) {
  SemanticsNode? root;
  tester.binding.rootPipelineOwner.visitChildren((child) {
    root ??= child.semanticsOwner?.rootSemanticsNode;
  });
  final raw = root!.toStringDeep();
  final lines =
      raw
          .split('\n')
          .where(
            (line) =>
                !line.contains('Rect.fromLTRB') &&
                !line.contains('transform') &&
                !line.contains('scaled by') &&
                !line.contains('elevation') &&
                !line.contains('thickness') &&
                !line.contains('textDirection') &&
                !line.contains('scrollExtentMax'),
          )
          .map((line) => line.replaceAll(RegExp('#[0-9a-fA-F]+'), '#'))
          .toList()
        ..add('--- texts ---')
        ..addAll(
          tester
              .widgetList<RichText>(find.byType(RichText))
              .map((w) => w.text.toPlainText()),
        );
  return lines.join('\n');
}

final _updatedAt = DateTime.utc(2026, 11, 20, 12);

/// Seeds the three real product workflows of the gallery.
List<WorkflowSummary> _seed() => <WorkflowSummary>[
  WorkflowSummary(
    id: 'wf-1',
    name: 'Release Flow',
    description: 'Build, test and publish a release candidate.',
    nodeCount: 6,
    edgeCount: 7,
    hasValidationErrors: false,
    updatedAt: _updatedAt,
    scope: WorkflowScope.workspace,
    workspaceId: 'ws-1',
    revision: 'r1',
  ),
  WorkflowSummary(
    id: 'wf-2',
    name: 'Lint Check',
    nodeCount: 2,
    edgeCount: 1,
    hasValidationErrors: false,
    updatedAt: _updatedAt,
    revision: 'r1',
  ),
  WorkflowSummary(
    id: 'wf-3',
    name: 'Nightly Dependency Audit',
    nodeCount: 4,
    edgeCount: 4,
    hasValidationErrors: true,
    updatedAt: _updatedAt,
    revision: 'r1',
  ),
];

const _activeRunsRefusal = WorkflowDeletionRejected(
  BackendFailure(
    'Workflow has 2 active runs.',
    code: ApiErrorCode.workflowHasActiveRuns,
    statusCode: 409,
    details: {
      'run-20261120-0931-a1f3': 'running',
      'run-20261120-1012-b7c2': 'paused',
    },
  ),
);

Future<void> _capture(
  WidgetTester tester, {
  required String name,
  required Size size,
  required ScriptedWorkflowRepository repo,
  required Future<void> Function(WidgetTester tester) drive,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  // Unmount the previous capture so its ProviderScope (and repository) is
  // disposed; a re-pumped ProviderScope would keep its old overrides.
  await tester.pumpWidget(const SizedBox.shrink());
  final boundaryKey = GlobalKey();
  final router = GoRouter(
    initialLocation: '/workflows',
    routes: <RouteBase>[
      GoRoute(
        path: '/workflows',
        builder: (_, _) => const Scaffold(body: WorkflowsPage()),
      ),
    ],
  );

  await tester.pumpWidget(
    ProviderScope(
      overrides: [workflowRepositoryProvider.overrideWithValue(repo)],
      child: MediaQuery(
        data: MediaQueryData(textScaler: TextScaler.linear(textScale)),
        child: MaterialApp.router(
          debugShowCheckedModeBanner: false,
          theme: HiveTheme.dark(),
          localizationsDelegates: const [
            AppLocalizations.delegate,
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
          builder: (context, child) =>
              RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  await drive(tester);
  await tester.pumpAndSettle();

  final dimensions = '${size.width.toInt()}x${size.height.toInt()}';
  final dump = _structureDump(tester);
  final structureFile = File(_structurePath('${name}_$dimensions'));
  if (const bool.fromEnvironment('HIVE_UPDATE_STRUCTURE')) {
    structureFile.writeAsStringSync(dump);
  } else {
    expect(
      dump,
      structureFile.readAsStringSync(),
      reason: 'structure of $name changed',
    );
  }

  // Pass `--dart-define=HIVE_UPDATE_GALLERY=true` to regenerate the gallery
  // PNGs.
  if (const bool.fromEnvironment('HIVE_UPDATE_GALLERY')) {
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      File(_galleryPath('${name}_$dimensions')).writeAsBytesSync(bytes);
    });
  }
  handle.dispose();
  for (final controller in repo.live) {
    await controller.close();
  }
}

Future<void> _openDelete(WidgetTester tester, String id) async {
  await tester.tap(find.byKey(Key('delete_workflow_$id')));
  await tester.pumpAndSettle();
}

Future<void> _confirm(WidgetTester tester) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(WorkflowsPage)))!;
  await tester.tap(find.text(l10n.workflowsDeleteConfirm));
  await tester.pumpAndSettle();
}

Future<void> _confirmStopRuns(WidgetTester tester) async {
  final l10n = AppLocalizations.of(tester.element(find.byType(WorkflowsPage)))!;
  await tester.tap(find.text(l10n.workflowsDeleteStopRunsConfirm));
  await tester.pumpAndSettle();
}

ScriptedWorkflowRepository _repo() =>
    ScriptedWorkflowRepository()..items.addAll(_seed());

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    // Captures show keyboard focus (the Cancel focus of destructive dialogs)
    // as a visible ring, the way a keyboard user sees it.
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  final sizes = <Size>[const Size(1280, 720), const Size(1440, 900)];

  // One cell per matrix state; each is captured at both viewports.
  final states =
      <
        ({
          String name,
          Future<void> Function(WidgetTester) drive,
          ScriptedWorkflowRepository Function() repo,
        })
      >[
        (
          name: 'delete_confirm',
          repo: _repo,
          drive: (tester) => _openDelete(tester, 'wf-1'),
        ),
        (
          name: 'active_runs_confirm',
          repo: () => _repo()..scripts.add([_activeRunsRefusal]),
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
          },
        ),
        (
          name: 'deleting_requested',
          repo: _repo,
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
            // Live stream: the capture drives the operation after the dialog.
          },
        ),
        (
          name: 'deleting_stopping_runs',
          repo: () => _repo()..scripts.add([_activeRunsRefusal]),
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
            await _confirmStopRuns(tester);
          },
        ),
        (
          name: 'deleting_removing_runs',
          repo: _repo,
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
          },
        ),
        (
          name: 'success',
          repo: () => _repo()
            ..scripts.add([
              const WorkflowDeletionStarted(operationId: 'op-1'),
              const WorkflowDeletionSucceeded(deletedRuns: 3),
            ]),
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
          },
        ),
        (
          name: 'partial',
          repo: () => _repo()
            ..scripts.add([
              const WorkflowDeletionStarted(operationId: 'op-1'),
              const WorkflowDeletionSucceeded(
                deletedRuns: 3,
                orphanedRuns: [
                  'run-20261120-0931-a1f3',
                  'run-20261120-1012-b7c2',
                ],
              ),
            ]),
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
          },
        ),
        (
          name: 'error',
          repo: () => _repo()
            ..scripts.add([
              const WorkflowDeletionStarted(operationId: 'op-1'),
              const WorkflowDeletionFailed(
                BackendFailure(
                  'Could not delete workflow: database is locked.',
                  statusCode: 500,
                ),
              ),
            ]),
          drive: (tester) async {
            await _openDelete(tester, 'wf-1');
            await _confirm(tester);
          },
        ),
      ];

  testWidgets('captures the workflow delete flow gallery', (tester) async {
    var index = 1;
    for (final size in sizes) {
      for (final state in states) {
        final number = index.toString().padLeft(2, '0');
        final repo = state.repo();
        await _capture(
          tester,
          name: '${number}_${state.name}',
          size: size,
          repo: repo,
          drive: (tester) async {
            await state.drive(tester);
            // Streams that stay open are driven here, after the dialog.
            if (state.name == 'deleting_requested' && repo.live.isNotEmpty) {
              repo.live.last.add(
                const WorkflowDeletionStarted(operationId: 'op-1'),
              );
              await tester.pump();
            }
            if (state.name == 'deleting_stopping_runs' &&
                repo.live.isNotEmpty) {
              repo.live.last
                ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
                ..add(
                  const WorkflowDeletionProgressed(
                    phase: WorkflowDeletionPhase.stoppingRuns,
                    runsToStop: 3,
                    runsStopped: 2,
                  ),
                );
              await tester.pump();
            }
            if (state.name == 'deleting_removing_runs' &&
                repo.live.isNotEmpty) {
              repo.live.last
                ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
                ..add(
                  const WorkflowDeletionProgressed(
                    phase: WorkflowDeletionPhase.deletingRuns,
                  ),
                );
              await tester.pump();
            }
          },
        );
        index++;
      }
    }

    // Large text (1.6x) at 1280x720 for the four states that carry long copy.
    const largeText = 1.6;
    final large =
        <
          ({
            String name,
            int number,
            ScriptedWorkflowRepository Function() repo,
            Future<void> Function(WidgetTester) drive,
          })
        >[
          (
            name: 'active_runs_confirm_large_text',
            number: 17,
            repo: () => _repo()..scripts.add([_activeRunsRefusal]),
            drive: (tester) async {
              await _openDelete(tester, 'wf-1');
              await _confirm(tester);
            },
          ),
          (
            name: 'deleting_stopping_runs_large_text',
            number: 18,
            repo: () => _repo()..scripts.add([_activeRunsRefusal]),
            drive: (tester) async {
              await _openDelete(tester, 'wf-1');
              await _confirm(tester);
              await _confirmStopRuns(tester);
            },
          ),
          (
            name: 'partial_large_text',
            number: 19,
            repo: () => _repo()
              ..scripts.add([
                const WorkflowDeletionStarted(operationId: 'op-1'),
                const WorkflowDeletionSucceeded(
                  deletedRuns: 3,
                  orphanedRuns: [
                    'run-20261120-0931-a1f3',
                    'run-20261120-1012-b7c2',
                  ],
                ),
              ]),
            drive: (tester) async {
              await _openDelete(tester, 'wf-1');
              await _confirm(tester);
            },
          ),
          (
            name: 'error_large_text',
            number: 20,
            repo: () => _repo()
              ..scripts.add([
                const WorkflowDeletionStarted(operationId: 'op-1'),
                const WorkflowDeletionFailed(
                  BackendFailure(
                    'Could not delete workflow: database is locked.',
                    statusCode: 500,
                  ),
                ),
              ]),
            drive: (tester) async {
              await _openDelete(tester, 'wf-1');
              await _confirm(tester);
            },
          ),
        ];
    for (final cell in large) {
      final repo = cell.repo();
      await _capture(
        tester,
        name: '${cell.number}_${cell.name}',
        size: sizes.first,
        repo: repo,
        drive: (tester) async {
          await cell.drive(tester);
          if (cell.number == 18) {
            repo.live.last
              ..add(const WorkflowDeletionStarted(operationId: 'op-1'))
              ..add(
                const WorkflowDeletionProgressed(
                  phase: WorkflowDeletionPhase.stoppingRuns,
                  runsToStop: 3,
                  runsStopped: 2,
                ),
              );
            await tester.pump();
          }
        },
        textScale: largeText,
      );
    }
  });
}
