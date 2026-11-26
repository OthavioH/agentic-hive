import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/controllers/harnesses_controller.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_frontend/presentation/workflows/widgets/node_config_forms/fallback_list_editor.dart';
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

Widget _buildHost({
  required ThemeData theme,
  required Key boundaryKey,
  required String stateName,
  required List<FallbackEntry> entries,
  Map<String, HarnessStatus>? statuses,
}) {
  return UncontrolledProviderScope(
    container: ProviderContainer.test(
      overrides: [harnessStatusByTypeIdProvider.overrideWithValue(statuses)],
    ),
    child: RepaintBoundary(
      key: boundaryKey,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: theme,
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: NodeVisualScope(
          registry: createNodeVisualRegistry(),
          child: Scaffold(
            body: Row(
              children: <Widget>[
                const Expanded(flex: 2, child: SizedBox.shrink()),
                Expanded(
                  child: SingleChildScrollView(
                    padding: EdgeInsets.all(HiveSpacing.standard.space2),
                    child: FallbackListEditor(
                      key: ValueKey<String>(stateName),
                      nodeType: NodeTypeId.claudeCode,
                      entries: entries,
                      onChanged: (_) {},
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );
}

void main() {
  setUpAll(_loadFonts);

  final viewports = <String, Size>{
    '1280x800': const Size(1280, 800),
    '1920x1080': const Size(1920, 1080),
  };
  final themes = <String, ThemeData>{
    'light': HiveTheme.light(),
    'dark': HiveTheme.dark(),
  };

  final allReady = <String, HarnessStatus>{
    NodeTypeId.claudeCode: HarnessStatus.ready,
    NodeTypeId.codex: HarnessStatus.ready,
    NodeTypeId.geminiCli: HarnessStatus.ready,
    NodeTypeId.antigravity: HarnessStatus.ready,
  };

  for (final vp in viewports.entries) {
    for (final th in themes.entries) {
      final suffix = '${vp.key}_${th.key}';

      testWidgets('fallback gallery $suffix', (tester) async {
        await tester.binding.setSurfaceSize(vp.value);
        addTearDown(() => tester.binding.setSurfaceSize(null));
        final boundaryKey = GlobalKey();

        // Empty
        await tester.pumpWidget(
          _buildHost(
            theme: th.value,
            boundaryKey: boundaryKey,
            stateName: 'empty_$suffix',
            entries: const <FallbackEntry>[],
            statuses: allReady,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'empty_$suffix', boundaryKey: boundaryKey);

        // Populated + first/last row
        await tester.pumpWidget(
          _buildHost(
            theme: th.value,
            boundaryKey: boundaryKey,
            stateName: 'populated_$suffix',
            entries: const <FallbackEntry>[
              FallbackEntry(
                harness: NodeTypeId.codex,
                model: 'gpt-5',
                effort: 'high',
              ),
              FallbackEntry(harness: NodeTypeId.geminiCli),
            ],
            statuses: allReady,
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'populated_$suffix', boundaryKey: boundaryKey);

        // Effort unsupported + invalid input + redundant (equal) entries
        await tester.pumpWidget(
          _buildHost(
            theme: th.value,
            boundaryKey: boundaryKey,
            stateName: 'invalid_$suffix',
            entries: const <FallbackEntry>[
              FallbackEntry(
                harness: NodeTypeId.geminiCli,
                model: '-bad',
                effort: 'high',
              ),
              FallbackEntry(harness: NodeTypeId.claudeCode, model: 'sonnet'),
              FallbackEntry(harness: NodeTypeId.claudeCode, model: 'sonnet'),
            ],
            statuses: allReady,
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Model must not start with "-".'), findsOneWidget);
        expect(
          find.text('Gemini CLI does not support choosing an effort.'),
          findsOneWidget,
        );
        await _capture(tester, 'invalid_$suffix', boundaryKey: boundaryKey);

        // Not installed + not signed in
        await tester.pumpWidget(
          _buildHost(
            theme: th.value,
            boundaryKey: boundaryKey,
            stateName: 'status_$suffix',
            entries: const <FallbackEntry>[
              FallbackEntry(harness: NodeTypeId.codex),
              FallbackEntry(harness: NodeTypeId.geminiCli),
            ],
            statuses: const <String, HarnessStatus>{
              NodeTypeId.codex: HarnessStatus.notInstalled,
              NodeTypeId.geminiCli: HarnessStatus.authError,
            },
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Codex is not installed'), findsOneWidget);
        expect(find.text('Gemini CLI is not signed in'), findsOneWidget);
        await _capture(tester, 'status_$suffix', boundaryKey: boundaryKey);

        // Loading status (null)
        await tester.pumpWidget(
          _buildHost(
            theme: th.value,
            boundaryKey: boundaryKey,
            stateName: 'loading_$suffix',
            entries: const <FallbackEntry>[
              FallbackEntry(harness: NodeTypeId.codex),
            ],
          ),
        );
        await tester.pumpAndSettle();
        await _capture(tester, 'loading_$suffix', boundaryKey: boundaryKey);
      });
    }
  }
}
