import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;

import 'fake_pause_repository.dart';

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

Pause _makeApproval({
  String id = 'pause-approval',
  Object? proposal,
  String? proposalSource,
  String? proposalSchema,
}) => Pause(
  id: id,
  runId: 'run-42',
  nodeId: 'node-approve',
  kind: PauseKind.humanApproval,
  status: PauseStatus.pending,
  workflowName: 'Release Workflow',
  nodeLabel: 'Manual Gate',
  createdAt: DateTime.utc(2026, 11, 21, 10),
  title: 'Proceed with release?',
  instructions: 'Verify all artifacts before approving.',
  proposal: proposal,
  proposalSource: proposalSource,
  proposalSchema: proposalSchema,
);

Future<void> _capture(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  required Pause pause,
  void Function(FakePauseRepository repo)? setupRepo,
  Future<void> Function(WidgetTester tester, FakePauseRepository repo)? drive,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final repo = FakePauseRepository(initial: <Pause>[pause]);
  addTearDown(repo.dispose);
  setupRepo?.call(repo);

  final dims = '${size.width.toInt()}x${size.height.toInt()}';
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: [pauseRepositoryProvider.overrideWithValue(repo)],
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
          AppLocalizations.delegate,
          GlobalMaterialLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
        ],
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: PausesPage(key: ValueKey<String>('${id}_${themeName}_$dims')),
        ),
        builder: (context, child) => MediaQuery(
          data: MediaQuery.of(context)
              .copyWith(textScaler: TextScaler.linear(textScale)),
          child: RepaintBoundary(key: boundaryKey, child: child),
        ),
      ),
    ),
  );
  await tester.pumpAndSettle();

  if (drive != null) {
    await drive(tester, repo);
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

  final longProposal = <String, Object?>{
    'items': <String>[
      for (var i = 1; i <= 60; i++) 'Item #$i: verify step $i before release',
    ],
  };

  final matrix =
      <
        ({
          String id,
          Pause Function() buildPause,
          void Function(FakePauseRepository repo)? setupRepo,
          Future<void> Function(WidgetTester tester, FakePauseRepository repo)?
          drive,
        })
      >[
        (
          id: 'no-proposal',
          buildPause: _makeApproval,
          setupRepo: null,
          drive: null,
        ),
        (
          id: 'proposal-readonly',
          buildPause: () => _makeApproval(
            proposal: const <String, Object?>{
              'items': <String>['alpha', 'beta'],
              'count': 2,
            },
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: null,
        ),
        (
          id: 'proposal-readonly-long',
          buildPause: () =>
              _makeApproval(proposal: longProposal, proposalSource: 'planner'),
          setupRepo: null,
          drive: null,
        ),
        (
          id: 'proposal-no-source',
          buildPause: () =>
              _makeApproval(proposal: const <String, Object?>{'ok': true}),
          setupRepo: null,
          drive: null,
        ),
        (
          id: 'editing-valid',
          buildPause: () => _makeApproval(
            proposal: const <String, Object?>{'step': 1, 'approvedBy': 'ops'},
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'editing-invalid-json',
          buildPause: () => _makeApproval(
            proposal: const <String, Object?>{'step': 1},
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('pauses_proposal_field')),
              '{bad',
            );
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'editing-invalid-schema',
          buildPause: () => _makeApproval(
            proposal: const <int>[1],
            proposalSource: 'planner',
            proposalSchema: '{"type":"array"}',
          ),
          setupRepo: null,
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('pauses_proposal_field')),
              '{}',
            );
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'submitting',
          buildPause: () => _makeApproval(
            proposal: const <int>[1],
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: (tester, repo) async {
            final completer = Completer<Result<Pause>>();
            addTearDown(() {
              if (!completer.isCompleted) {
                completer.complete(
                  Success(
                    _makeApproval().copyWith(status: PauseStatus.answered),
                  ),
                );
              }
            });
            repo.onAnswerPause = (_, _) => completer.future;
            final approveFinder = find.byKey(
              const Key('pauses_approve_button'),
            );
            await tester.ensureVisible(approveFinder);
            await tester.pumpAndSettle();
            await tester.tap(approveFinder);
            await tester.pump(const Duration(milliseconds: 50));
          },
        ),
        (
          id: 'error',
          buildPause: () => _makeApproval(
            proposal: const <int>[1],
            proposalSource: 'planner',
          ),
          setupRepo: (repo) {
            repo.onAnswerPause = (_, _) async => const FailureResult(
              BackendFailure('Proposal does not match the schema'),
            );
          },
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('pauses_proposal_field')),
              '[1]',
            );
            await tester.pumpAndSettle();
            final approveFinder = find.byKey(
              const Key('pauses_approve_button'),
            );
            await tester.ensureVisible(approveFinder);
            await tester.pumpAndSettle();
            await tester.tap(approveFinder);
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'focused-editor',
          buildPause: () => _makeApproval(
            proposal: const <String, Object?>{'step': 1},
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
            await tester.tap(find.byKey(const Key('pauses_proposal_field')));
            await tester.pumpAndSettle();
          },
        ),
        (
          id: 'hovered-edit-button',
          buildPause: () => _makeApproval(
            proposal: const <String, Object?>{'step': 1},
            proposalSource: 'planner',
          ),
          setupRepo: null,
          drive: (tester, _) async {
            final editButton = find.byKey(
              const Key('pauses_proposal_edit_button'),
            );
            final g = await tester.createGesture(kind: PointerDeviceKind.mouse);
            addTearDown(g.removePointer);
            await g.addPointer(location: Offset.zero);
            await g.moveTo(tester.getCenter(editButton));
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
            pause: cell.buildPause(),
            setupRepo: cell.setupRepo,
            drive: cell.drive,
          );
        });
      }
    }

    testWidgets(
      'capture editing-invalid-schema-large (${themeEntry.key} 1280x720)',
      (tester) async {
        await _capture(
          tester,
          id: 'editing-invalid-schema-large',
          themeName: themeEntry.key,
          theme: themeEntry.value,
          size: sizes.first,
          pause: _makeApproval(
            proposal: const <int>[1],
            proposalSource: 'planner',
            proposalSchema: '{"type":"array"}',
          ),
          drive: (tester, _) async {
            await tester.tap(
              find.byKey(const Key('pauses_proposal_edit_button')),
            );
            await tester.pumpAndSettle();
            await tester.enterText(
              find.byKey(const Key('pauses_proposal_field')),
              '{}',
            );
            await tester.pumpAndSettle();
          },
          textScale: 2,
        );
      },
    );

    testWidgets(
      'capture proposal-readonly-large (${themeEntry.key} 1280x720)',
      (tester) async {
        await _capture(
          tester,
          id: 'proposal-readonly-large',
          themeName: themeEntry.key,
          theme: themeEntry.value,
          size: sizes.first,
          pause: _makeApproval(
            proposal: const <String, Object?>{
              'items': <String>['alpha', 'beta'],
              'count': 2,
            },
            proposalSource: 'planner',
          ),
          textScale: 2,
        );
      },
    );
  }
}
