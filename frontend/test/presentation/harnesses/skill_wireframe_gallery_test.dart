import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:agentic_hive_frontend/core/backend/app_version_provider.dart';
import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/core/theme/app_theme_preference.dart';
import 'package:agentic_hive_frontend/core/theme/theme_preference_store.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/data/runs/run_providers.dart';
import 'package:agentic_hive_frontend/data/settings/file_picker_data_source.dart';
import 'package:agentic_hive_frontend/data/settings/settings_repository_impl.dart';
import 'package:agentic_hive_frontend/data/skills/file_outdated_banner_store.dart';
import 'package:agentic_hive_frontend/data/skills/skill_notice_repository_impl.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_providers.dart';
import 'package:agentic_hive_frontend/data/workspace/workspace_tree_changes_providers.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_event.dart';
import 'package:agentic_hive_frontend/domain/pauses/pause_repository.dart';
import 'package:agentic_hive_frontend/domain/runs/run_repository.dart';
import 'package:agentic_hive_frontend/domain/settings/settings_repository.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_selection_store.dart';
import 'package:agentic_hive_frontend/domain/workspace/workspace_tree_changes_source.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_frontend/presentation/settings/pages/settings_page.dart';
import 'package:agentic_hive_frontend/presentation/shell/widgets/app_shell.dart';
import 'package:agentic_hive_frontend/presentation/workspace/controllers/side_rail_tree_controller.dart';
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

import '../skills/memory_outdated_banner_store.dart';
import '../skills/scripted_skill_notice_repository.dart';
import '../workspace/fake_workspace_repository.dart';
import 'scripted_harness_repository.dart';

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
  final inFrontend = Directory('test/presentation/harnesses').existsSync();
  final dir = inFrontend
      ? 'test/presentation/harnesses/gallery_skill'
      : 'frontend/test/presentation/harnesses/gallery_skill';
  Directory(dir).createSync(recursive: true);
  return '$dir/$name.png';
}

String _structurePath(String name) {
  final inFrontend = Directory('test/presentation/harnesses').existsSync();
  final dir = inFrontend
      ? 'test/presentation/harnesses/gallery_skill_structure'
      : 'frontend/test/presentation/harnesses/gallery_skill_structure';
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

final class _FakeSelectionStore implements WorkspaceSelectionStore {
  @override
  Future<String?> load() async => null;

  @override
  Future<void> save(String? workspaceId) async {}
}

final class _NoChangesSource implements WorkspaceTreeChangesSource {
  @override
  Stream<WorkspaceTreeChange> get changes =>
      const Stream<WorkspaceTreeChange>.empty();
}

final class _FakeRunsRepo implements RunRepository {
  @override
  Future<Result<RunsListResponse>> listRuns({
    RunStatus? status,
    String? workflowId,
    int? limit,
    int? offset,
  }) async => const Success<RunsListResponse>(
    RunsListResponse(items: <RunSummary>[], total: 0),
  );

  @override
  Future<Result<Run>> cancelRun(String id) => throw UnimplementedError();

  @override
  Future<Result<void>> deleteRun(String id) => throw UnimplementedError();

  @override
  Future<Result<RunNodeLogsResponse>> getNodeLogs(
    String id,
    String nodeId, {
    int? attempt,
    int? tail,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> getRun(String id) => throw UnimplementedError();

  @override
  Future<Result<List<Checkpoint>>> getRunCheckpoints(String id) =>
      throw UnimplementedError();

  @override
  Future<Result<RunEventsResponse>> getRunEvents(
    String id, {
    int? afterSequence,
    int? limit,
  }) => throw UnimplementedError();

  @override
  Future<Result<Run>> resumeRun(String id) => throw UnimplementedError();

  @override
  Future<Result<Run>> startRun(StartRunRequest request) =>
      throw UnimplementedError();
}

final class _FakePauseRepo implements PauseRepository {
  @override
  Future<Result<List<Pause>>> listPendingPauses() async =>
      const Success<List<Pause>>(<Pause>[]);

  @override
  Future<Result<Pause>> answerPause(String id, AnswerPauseRequest request) =>
      throw UnimplementedError();

  @override
  Stream<PauseEvent> watchPauseEvents() => const Stream<PauseEvent>.empty();

  @override
  Stream<int> watchPendingPausesCount() => const Stream<int>.empty();
}

final class _FakeSettingsRepository implements SettingsRepository {
  new({required bool autoInstallSkills})
    : settings = AppSettings(
        effectiveAgentsDir: '/home/user/.agents/agents',
        defaultAgentsDir: '/home/user/.agents/agents',
        autoInstallSkills: autoInstallSkills,
      );

  final AppSettings settings;
  final StreamController<AppSettings> updates =
      StreamController<AppSettings>.broadcast();

  @override
  Future<Result<AppSettings>> getSettings() async => Success(settings);

  @override
  Future<Result<AppSettings>> updateSettings(
    UpdateSettingsRequest request,
  ) async => Success(settings);

  @override
  Stream<AppSettings> watchSettingsUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

final class _FakeThemeStore implements ThemePreferenceStore {
  @override
  Future<AppThemePreference> load() async => AppThemePreference.dark;

  @override
  Future<void> save(AppThemePreference preference) async {}
}

final class _FakeFilePicker implements FilePickerDataSource {
  @override
  Future<String?> pickDirectory({String? initialDirectory}) async => null;

  @override
  Future<String?> pickFile({String? initialDirectory}) async => null;
}

typedef _StateBuilder = ({
  String code,
  String name,
  Future<void> Function(
    WidgetTester tester,
    Size size,
    double textScale,
    String fileStem,
  )
  run,
});

Future<void> _captureWidget(
  WidgetTester tester, {
  required String fileStem,
  required Size size,
  required List<dynamic> overrides,
  required Widget home,
  double textScale = 1.0,
  bool settleInitial = true,
  Future<void> Function(WidgetTester tester)? drive,
  Future<void> Function()? cleanup,
}) async {
  final handle = tester.ensureSemantics();
  await tester.binding.setSurfaceSize(size);
  addTearDown(() => tester.binding.setSurfaceSize(null));
  await tester.pumpWidget(const SizedBox.shrink());

  final boundaryKey = GlobalKey();
  final router = GoRouter(
    initialLocation: '/overview',
    routes: <RouteBase>[
      GoRoute(path: '/overview', builder: (_, _) => home),
      GoRoute(
        path: '/harnesses',
        builder: (_, _) => const Scaffold(body: HarnessesPage()),
      ),
    ],
  );
  addTearDown(router.dispose);

  await tester.pumpWidget(
    ProviderScope(
      overrides: overrides.cast(),
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

  if (settleInitial) {
    await tester.pumpAndSettle();
  } else {
    await tester.pump();
    await tester.pump(HiveMotionTokens.standard.medium);
  }

  if (drive != null) {
    await drive(tester);
  }

  final dump = _structureDump(tester);
  final structureFile = File(_structurePath(fileStem));
  if (const bool.fromEnvironment('HIVE_UPDATE_STRUCTURE')) {
    structureFile.writeAsStringSync(dump);
  } else {
    expect(
      dump,
      structureFile.readAsStringSync(),
      reason: 'structure of $fileStem changed',
    );
  }

  if (const bool.fromEnvironment('HIVE_UPDATE_GALLERY')) {
    await tester.runAsync(() async {
      final boundary =
          boundaryKey.currentContext!.findRenderObject()!
              as RenderRepaintBoundary;
      final image = await boundary.toImage();
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      final bytes = byteData!.buffer.asUint8List();
      File(_galleryPath(fileStem)).writeAsBytesSync(bytes);
    });
  }

  handle.dispose();
  if (cleanup != null) {
    await cleanup();
  }
}

Future<void> _captureHarnessState(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required String fileStem,
  required ScriptedHarnessRepository Function() makeRepo,
  Future<void> Function(WidgetTester tester)? drive,
  Future<void> Function()? cleanup,
}) async {
  final repo = makeRepo();
  await _captureWidget(
    tester,
    fileStem: fileStem,
    size: size,
    textScale: textScale,
    overrides: [
      harnessRepositoryProvider.overrideWithValue(repo),
      outdatedBannerStoreProvider.overrideWithValue(
        MemoryOutdatedBannerStore(),
      ),
      appVersionProvider.overrideWithValue('1.0.0'),
    ],
    home: const Scaffold(body: HarnessesPage()),
    drive: drive,
    cleanup: () async {
      if (cleanup != null) await cleanup();
      await repo.dispose();
    },
  );
}

Future<void> _captureShellState(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required String fileStem,
  required List<HarnessInfo> harnesses,
  SkillAutoInstallNotice? notice,
}) async {
  final harnessRepo = ScriptedHarnessRepository()
    ..getResult = Success<List<HarnessInfo>>(harnesses);
  final noticeRepo = ScriptedSkillNoticeRepository()
    ..getResult = Success<SkillAutoInstallNotice?>(notice);
  final fixedNow = DateTime.utc(2026, 11, 22, 12);

  await _captureWidget(
    tester,
    fileStem: fileStem,
    size: size,
    textScale: textScale,
    overrides: [
      workspaceRepositoryProvider.overrideWithValue(FakeWorkspaceRepository()),
      workspaceSelectionStoreProvider.overrideWithValue(_FakeSelectionStore()),
      runRepositoryProvider.overrideWithValue(_FakeRunsRepo()),
      pauseRepositoryProvider.overrideWithValue(_FakePauseRepo()),
      sideRailTreeClockProvider.overrideWithValue(() => fixedNow),
      workspaceTreeChangesSourceProvider.overrideWithValue(_NoChangesSource()),
      harnessRepositoryProvider.overrideWithValue(harnessRepo),
      skillNoticeRepositoryProvider.overrideWithValue(noticeRepo),
      outdatedBannerStoreProvider.overrideWithValue(
        MemoryOutdatedBannerStore(),
      ),
      appVersionProvider.overrideWithValue('1.0.0'),
    ],
    home: const AppShell(location: '/overview', child: SizedBox.shrink()),
    cleanup: () async {
      await harnessRepo.dispose();
      await noticeRepo.dispose();
    },
  );
}

Future<void> _captureSettingsState(
  WidgetTester tester, {
  required Size size,
  required double textScale,
  required String fileStem,
  required bool autoInstallSkills,
}) async {
  final settingsRepo = _FakeSettingsRepository(
    autoInstallSkills: autoInstallSkills,
  );
  await _captureWidget(
    tester,
    fileStem: fileStem,
    size: size,
    textScale: textScale,
    overrides: [
      settingsRepositoryProvider.overrideWithValue(settingsRepo),
      themePreferenceStoreProvider.overrideWithValue(_FakeThemeStore()),
      filePickerDataSourceProvider.overrideWithValue(_FakeFilePicker()),
    ],
    home: const Scaffold(body: SettingsPage()),
    drive: (tester) async {
      await tester.ensureVisible(
        find.byKey(
          const ValueKey<String>('settings_auto_install_skills_switch'),
        ),
      );
      await tester.pumpAndSettle();
    },
    cleanup: settingsRepo.dispose,
  );
}

void main() {
  setUpAll(_loadFonts);

  setUp(() {
    FocusManager.instance.highlightStrategy =
        FocusHighlightStrategy.alwaysTraditional;
  });

  final installedNotice = SkillAutoInstallNotice(
    id: 'n1',
    createdAt: DateTime.utc(2026, 11, 20),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.claude/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.codex,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.agents/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
    ],
  );

  final partialNotice = SkillAutoInstallNotice(
    id: 'n2',
    createdAt: DateTime.utc(2026, 11, 20),
    results: const <SkillAutoInstallHarnessResult>[
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.claudeCode,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.installed,
          paths: <String>['/home/user/.claude/skills/agentic-hive'],
        ),
        mcp: SkillAutoInstallStep(outcome: SkillAutoInstallOutcome.installed),
      ),
      SkillAutoInstallHarnessResult(
        harnessId: HarnessId.codex,
        skill: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.alreadyInstalled,
        ),
        mcp: SkillAutoInstallStep(
          outcome: SkillAutoInstallOutcome.failed,
          message: 'codex mcp add exited with code 1',
        ),
      ),
    ],
  );

  final states = <_StateBuilder>[
    (
      code: '01',
      name: 'card_installed',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.installed),
          ]),
      ),
    ),
    (
      code: '02',
      name: 'card_not_installed',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.notInstalled),
          ]),
      ),
    ),
    (
      code: '03',
      name: 'card_outdated',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.outdated),
          ]),
      ),
    ),
    (
      code: '04',
      name: 'card_modified',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.modified),
          ]),
      ),
    ),
    (
      code: '05',
      name: 'card_conflict',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.conflict),
          ]),
      ),
    ),
    (
      code: '06',
      name: 'card_unknown',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(
              skill: HarnessSkillStatus.unknown,
              skillMessage:
                  'Could not read hive-skill.json: permission denied.',
            ),
          ]),
      ),
    ),
    (
      code: '07',
      name: 'card_busy_install',
      run: (tester, size, textScale, stem) {
        final pending = Completer<Result<HarnessInfo>>();
        return _captureHarnessState(
          tester,
          size: size,
          textScale: textScale,
          fileStem: stem,
          makeRepo: () => ScriptedHarnessRepository()
            ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
              harnessWith(skill: HarnessSkillStatus.notInstalled),
            ])
            ..pendingInstallSkill = pending,
          drive: (tester) async {
            await tester.tap(
              find.byKey(
                const ValueKey<String>('harness_skill_install_claude_code'),
              ),
            );
            await tester.pump();
            await tester.pump(HiveMotionTokens.standard.medium);
          },
          cleanup: () async {
            if (!pending.isCompleted) {
              pending.complete(
                Success<HarnessInfo>(
                  harnessWith(skill: HarnessSkillStatus.installed),
                ),
              );
            }
          },
        );
      },
    ),
    (
      code: '08',
      name: 'card_error',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.notInstalled),
          ])
          ..installSkillResult = const FailureResult<HarnessInfo>(
            BackendFailure('Could not write to ~/.claude/skills: disk full.'),
          ),
        drive: (tester) async {
          await tester.tap(
            find.byKey(
              const ValueKey<String>('harness_skill_install_claude_code'),
            ),
          );
          await tester.pumpAndSettle();
        },
      ),
    ),
    (
      code: '09',
      name: 'card_mcp_missing',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () =>
            ScriptedHarnessRepository()
              ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
                harnessWith(
                  skill: HarnessSkillStatus.installed,
                  mcp: HarnessMcpStatus.notInstalled,
                ),
              ]),
      ),
    ),
    (
      code: '10',
      name: 'card_loading',
      run: (tester, size, textScale, stem) {
        final pending = Completer<Result<List<HarnessInfo>>>();
        return _captureHarnessState(
          tester,
          size: size,
          textScale: textScale,
          fileStem: stem,
          makeRepo: () => ScriptedHarnessRepository()
            ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
              harnessWith(skill: HarnessSkillStatus.installed),
            ])
            ..pendingRefreshAll = pending,
          drive: (tester) async {
            await tester.tap(
              find.byKey(
                const ValueKey<String>('harnesses_refresh_all_button'),
              ),
            );
            await tester.pump();
            await tester.pump(HiveMotionTokens.standard.medium);
          },
          cleanup: () async {
            if (!pending.isCompleted) {
              pending.complete(
                Success<List<HarnessInfo>>(<HarnessInfo>[
                  harnessWith(skill: HarnessSkillStatus.installed),
                ]),
              );
            }
          },
        );
      },
    ),
    (
      code: '11',
      name: 'card_no_skill_row',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(),
          ]),
      ),
    ),
    (
      code: '12',
      name: 'confirm_overwrite_modified',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.modified),
          ]),
        drive: (tester) async {
          await tester.tap(
            find.byKey(
              const ValueKey<String>('harness_skill_update_claude_code'),
            ),
          );
          await tester.pumpAndSettle();
        },
      ),
    ),
    (
      code: '13',
      name: 'confirm_remove',
      run: (tester, size, textScale, stem) => _captureHarnessState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        makeRepo: () => ScriptedHarnessRepository()
          ..getResult = Success<List<HarnessInfo>>(<HarnessInfo>[
            harnessWith(skill: HarnessSkillStatus.installed),
          ]),
        drive: (tester) async {
          await tester.tap(
            find.byKey(
              const ValueKey<String>('harness_skill_remove_claude_code'),
            ),
          );
          await tester.pumpAndSettle();
        },
      ),
    ),
    (
      code: '14',
      name: 'first_run_installed',
      run: (tester, size, textScale, stem) => _captureShellState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        harnesses: <HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.installed),
        ],
        notice: installedNotice,
      ),
    ),
    (
      code: '15',
      name: 'first_run_partial',
      run: (tester, size, textScale, stem) => _captureShellState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        harnesses: <HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.installed),
        ],
        notice: partialNotice,
      ),
    ),
    (
      code: '16',
      name: 'outdated_banner',
      run: (tester, size, textScale, stem) => _captureShellState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        harnesses: <HarnessInfo>[
          harnessWith(skill: HarnessSkillStatus.outdated),
          harnessWith(
            id: HarnessId.codex,
            skill: HarnessSkillStatus.installed,
            mcp: HarnessMcpStatus.outdated,
          ),
        ],
      ),
    ),
    (
      code: '17',
      name: 'settings_toggle_on',
      run: (tester, size, textScale, stem) => _captureSettingsState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        autoInstallSkills: true,
      ),
    ),
    (
      code: '18',
      name: 'settings_toggle_off',
      run: (tester, size, textScale, stem) => _captureSettingsState(
        tester,
        size: size,
        textScale: textScale,
        fileStem: stem,
        autoInstallSkills: false,
      ),
    ),
  ];

  final viewports = <({String suffix, Size size, double textScale})>[
    (suffix: '1280x720', size: const Size(1280, 720), textScale: 1.0),
    (suffix: '1440x900', size: const Size(1440, 900), textScale: 1.0),
    (
      suffix: 'large_text_1280x720',
      size: const Size(1280, 720),
      textScale: 2.0,
    ),
  ];

  for (final state in states) {
    for (final viewport in viewports) {
      final stem = '${state.code}_${state.name}_${viewport.suffix}';
      testWidgets('captures $stem', (tester) async {
        await state.run(tester, viewport.size, viewport.textScale, stem);
      });
    }
  }
}
