import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/harnesses/harness_repository_impl.dart';
import 'package:agentic_hive_frontend/domain/harnesses/harness_repository.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/harnesses/pages/harnesses_page.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

final class _FakeHarnessRepository implements HarnessRepository {
  Completer<Result<List<HarnessInfo>>>? pendingGet;
  Completer<Result<List<HarnessInfo>>>? pendingRefreshAll;
  Completer<Result<HarnessInfo>>? pendingRefreshOne;

  Result<List<HarnessInfo>> getResult = const Success(<HarnessInfo>[]);
  Result<List<HarnessInfo>> refreshAllResult = const Success(<HarnessInfo>[]);
  Result<HarnessInfo> refreshOneResult = const FailureResult<HarnessInfo>(
    NotFoundFailure('missing'),
  );
  final StreamController<HarnessInfo> updates =
      StreamController<HarnessInfo>.broadcast();

  @override
  Future<Result<List<HarnessInfo>>> getHarnesses() =>
      pendingGet?.future ?? Future<Result<List<HarnessInfo>>>.value(getResult);

  @override
  Future<Result<List<HarnessInfo>>> refreshAll() =>
      pendingRefreshAll?.future ??
      Future<Result<List<HarnessInfo>>>.value(refreshAllResult);

  @override
  Future<Result<HarnessInfo>> refreshHarness(HarnessId id) =>
      pendingRefreshOne?.future ??
      Future<Result<HarnessInfo>>.value(refreshOneResult);

  @override
  Stream<HarnessInfo> watchHarnessUpdates() => updates.stream;

  Future<void> dispose() => updates.close();
}

Widget _buildTestApp() => MaterialApp(
  localizationsDelegates: AppLocalizations.localizationsDelegates,
  supportedLocales: AppLocalizations.supportedLocales,
  theme: HiveTheme.dark(),
  home: const Scaffold(body: HarnessesPage()),
);

void main() {
  const desktopSize = Size(1280, 900);
  final now = DateTime.utc(2026, 11, 20);

  final allFiveStates = <HarnessInfo>[
    HarnessInfo(
      id: HarnessId.claudeCode,
      displayName: 'Claude Code',
      status: HarnessStatus.ready,
      version: '1.0.5',
      executablePath: r'C:\tools\claude.exe',
      checkedAt: now,
    ),
    HarnessInfo(
      id: HarnessId.codex,
      displayName: 'Codex',
      status: HarnessStatus.authError,
      version: '0.8.0',
      executablePath: r'C:\tools\codex.exe',
      errorMessage: 'Run codex login',
      checkedAt: now,
    ),
    HarnessInfo(
      id: HarnessId.geminiCli,
      displayName: 'Gemini CLI',
      status: HarnessStatus.notInstalled,
      checkedAt: now,
    ),
    HarnessInfo(
      id: HarnessId.antigravity,
      displayName: 'Antigravity',
      status: HarnessStatus.outdated,
      version: '0.2.0',
      executablePath: r'C:\tools\agy.exe',
      errorMessage: 'Update to 0.3.0',
      checkedAt: now,
    ),
  ];

  final unavailableCodex = HarnessInfo(
    id: HarnessId.codex,
    displayName: 'Codex',
    status: HarnessStatus.unavailable,
    executablePath: r'C:\tools\codex.exe',
    errorMessage: 'Timed out after 5s',
    checkedAt: now,
  );

  group('HarnessesPage', () {
    testWidgets('renders all five HarnessStatus states and guidance', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _FakeHarnessRepository()
        ..getResult = Success(<HarnessInfo>[
          ...allFiveStates,
          unavailableCodex,
        ]);
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
          child: _buildTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HarnessesPage)),
      )!;

      expect(find.text('Claude Code'), findsOneWidget);
      expect(find.text(l10n.harnessStatusReady), findsOneWidget);
      expect(find.text(l10n.harnessesVersionLabel('1.0.5')), findsOneWidget);
      expect(find.text(r'C:\tools\claude.exe'), findsOneWidget);

      expect(find.text(l10n.harnessStatusAuthError), findsOneWidget);
      expect(find.text(l10n.harnessGuidanceAuthError('Codex')), findsOneWidget);
      expect(find.text('Run codex login'), findsNothing);

      expect(find.text(l10n.harnessStatusNotInstalled), findsOneWidget);
      expect(find.text(l10n.harnessGuidanceNotInstalled), findsOneWidget);

      expect(find.text(l10n.harnessStatusOutdated), findsOneWidget);
      expect(
        find.text(l10n.harnessGuidanceOutdated('Antigravity')),
        findsOneWidget,
      );

      expect(find.text(l10n.harnessStatusUnavailable), findsOneWidget);
      expect(find.text(l10n.harnessGuidanceUnavailable), findsOneWidget);
      expect(find.text('Timed out after 5s'), findsNothing);
    });

    testWidgets('renders empty state and error state with retry', (
      tester,
    ) async {
      await tester.binding.setSurfaceSize(desktopSize);
      addTearDown(() => tester.binding.setSurfaceSize(null));

      final repo = _FakeHarnessRepository()
        ..getResult = const FailureResult(NetworkFailure('Socket offline'));
      addTearDown(repo.dispose);

      await tester.pumpWidget(
        ProviderScope(
          overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
          child: _buildTestApp(),
        ),
      );
      await tester.pumpAndSettle();

      final l10n = AppLocalizations.of(
        tester.element(find.byType(HarnessesPage)),
      )!;
      expect(find.text(l10n.harnessesLoadErrorTitle), findsOneWidget);
      expect(find.text(l10n.harnessesErrorNetwork), findsOneWidget);
      expect(find.text('Socket offline'), findsNothing);

      repo.getResult = const Success(<HarnessInfo>[]);
      await tester.tap(
        find.byKey(const ValueKey<String>('harnesses_retry_button')),
      );
      await tester.pumpAndSettle();

      expect(find.text(l10n.harnessesEmptyTitle), findsOneWidget);
    });

    testWidgets(
      'global refresh updates cards and shows error toast on failure',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pending = Completer<Result<List<HarnessInfo>>>();
        final repo = _FakeHarnessRepository()
          ..getResult = Success(<HarnessInfo>[allFiveStates.first])
          ..pendingRefreshAll = pending;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(HarnessesPage)),
        )!;

        await tester.tap(
          find.byKey(const ValueKey<String>('harnesses_refresh_all_button')),
        );
        await tester.pump();

        final refreshButton = tester.widget<HiveButton>(
          find.byKey(const ValueKey<String>('harnesses_refresh_all_button')),
        );
        expect(refreshButton.loading, isTrue);

        pending.complete(const FailureResult(NetworkFailure('Refresh failed')));
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(find.byType(HiveToast), findsOneWidget);
        expect(
          find.text(l10n.harnessesRefreshError(l10n.harnessesErrorNetwork)),
          findsOneWidget,
        );
        expect(find.textContaining('Refresh failed'), findsNothing);
      },
    );

    testWidgets(
      'individual re-check shows loading only on target card and preserves '
      'data',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        final pending = Completer<Result<HarnessInfo>>();
        final repo = _FakeHarnessRepository()
          ..getResult = Success(<HarnessInfo>[
            allFiveStates[0],
            allFiveStates[1],
          ])
          ..pendingRefreshOne = pending;
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        await tester.tap(
          find.byKey(const ValueKey<String>('harness_recheck_codex')),
        );
        await tester.pump();

        expect(
          tester
              .widget<HiveIconButton>(
                find.byKey(const ValueKey<String>('harness_recheck_codex')),
              )
              .loading,
          isTrue,
        );
        expect(
          tester
              .widget<HiveIconButton>(
                find.byKey(
                  const ValueKey<String>('harness_recheck_claude_code'),
                ),
              )
              .loading,
          isFalse,
        );
        expect(find.text('Codex'), findsOneWidget);

        pending.complete(
          Success(
            allFiveStates[1].copyWith(
              status: HarnessStatus.ready,
              errorMessage: null,
            ),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(HarnessesPage)),
        )!;
        expect(find.text(l10n.harnessStatusReady), findsNWidgets(2));
      },
    );

    testWidgets(
      'copy path copies to clipboard, shows toast, and WS updates card live',
      (tester) async {
        await tester.binding.setSurfaceSize(desktopSize);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        String? copiedText;
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              if (call.method == 'Clipboard.setData') {
                final args = call.arguments as Map<Object?, Object?>;
                copiedText = args['text'] as String?;
              }
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        final repo = _FakeHarnessRepository()
          ..getResult = Success(<HarnessInfo>[allFiveStates[1]]);
        addTearDown(repo.dispose);

        await tester.pumpWidget(
          ProviderScope(
            overrides: [harnessRepositoryProvider.overrideWithValue(repo)],
            child: _buildTestApp(),
          ),
        );
        await tester.pumpAndSettle();

        final l10n = AppLocalizations.of(
          tester.element(find.byType(HarnessesPage)),
        )!;

        await tester.tap(
          find.byKey(const ValueKey<String>('harness_copy_codex')),
        );
        await tester.pump();
        await tester.pump(HiveMotionTokens.standard.medium);

        expect(copiedText, r'C:\tools\codex.exe');
        expect(find.text(l10n.harnessesPathCopiedToast), findsOneWidget);

        repo.updates.add(
          allFiveStates[1].copyWith(
            status: HarnessStatus.ready,
            errorMessage: null,
          ),
        );
        await tester.pumpAndSettle();

        expect(find.text(l10n.harnessStatusReady), findsOneWidget);
      },
    );
  });
}
