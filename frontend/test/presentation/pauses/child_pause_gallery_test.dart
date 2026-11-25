import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/pauses/pages/pauses_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';
import 'package:path/path.dart' as p;
import 'package:riverpod_annotation/riverpod_annotation.dart' show Override;

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

List<Pause> _pauses() => <Pause>[
  Pause(
    id: 'pause-normal',
    runId: 'run-normal-1234',
    nodeId: 'node-approve',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Release Workflow',
    nodeLabel: 'Manual Gate',
    createdAt: DateTime.utc(2026, 11, 21, 10),
    title: 'Proceed with release?',
    instructions: 'Verify artifacts before approving.',
  ),
  Pause(
    id: 'pause-child',
    runId: 'child-run-9876',
    nodeId: 'node-child-approve',
    kind: PauseKind.humanApproval,
    status: PauseStatus.pending,
    workflowName: 'Issue Processor',
    nodeLabel: 'Review Patch',
    createdAt: DateTime.utc(2026, 11, 21, 10, 5),
    title: 'Apply generated fix?',
    instructions: 'Confirm diff looks clean.',
    parentRunId: 'parent-run-abcdef12',
  ),
];

Future<void> _capture(
  WidgetTester tester, {
  required String id,
  required String themeName,
  required ThemeData theme,
  required Size size,
  Future<void> Function(WidgetTester tester)? drive,
  double textScale = 1.0,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));

  await tester.pumpWidget(const SizedBox.shrink());
  final repo = FakePauseRepository(initial: _pauses());
  addTearDown(repo.dispose);

  final dims = '${size.width.toInt()}x${size.height.toInt()}';
  final boundaryKey = GlobalKey();
  await tester.pumpWidget(
    ProviderScope(
      overrides: <Override>[pauseRepositoryProvider.overrideWithValue(repo)],
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

  if (drive != null) {
    await drive(tester);
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

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    for (final size in sizes) {
      final dims = '${size.width.toInt()}x${size.height.toInt()}';

      testWidgets('capture pause-list-child ($themeName $dims)', (
        tester,
      ) async {
        await _capture(
          tester,
          id: 'pause-list-child',
          themeName: themeName,
          theme: theme,
          size: size,
        );
      });

      testWidgets('capture pause-detail-child ($themeName $dims)', (
        tester,
      ) async {
        await _capture(
          tester,
          id: 'pause-detail-child',
          themeName: themeName,
          theme: theme,
          size: size,
          drive: (tester) async {
            await tester.tap(
              find.byKey(const ValueKey<String>('pause_list_item_pause-child')),
            );
            await tester.pumpAndSettle();
          },
        );
      });
    }

    testWidgets('capture pause-detail-child-large ($themeName 1280x720)', (
      tester,
    ) async {
      await _capture(
        tester,
        id: 'pause-detail-child-large',
        themeName: themeName,
        theme: theme,
        size: sizes.first,
        textScale: 2,
        drive: (tester) async {
          await tester.tap(
            find.byKey(const ValueKey<String>('pause_list_item_pause-child')),
          );
          await tester.pumpAndSettle();
        },
      );
    });
  }
}
