import 'dart:async';

import 'package:agentic_hive_frontend/core/result/result.dart';
import 'package:agentic_hive_frontend/data/overview/overview_providers.dart';
import 'package:agentic_hive_frontend/data/pauses/pause_providers.dart';
import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/overview/controllers/overview_controller.dart';
import 'package:agentic_hive_frontend/presentation/overview/pages/overview_page.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_active_nodes_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_active_runs_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_metrics_section.dart';
import 'package:agentic_hive_frontend/presentation/overview/widgets/overview_pending_pauses_section.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_localizations/flutter_localizations.dart'
    show GlobalWidgetsLocalizations;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../pauses/fake_pause_repository.dart';
import 'fake_overview_repository.dart';

void main() {
  const desktopSize = Size(1440, 900);
  const narrowDesktopSize = Size(720, 900);
  final baseTime = DateTime.utc(2026, 11, 21, 12);
  final startedEarlier = DateTime.utc(2026, 11, 21, 11, 59);
  final finishedEarlier = DateTime.utc(2026, 11, 21, 11, 59, 30);

  void configureSize(WidgetTester tester, Size size) {
    tester.view.physicalSize = size;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.reset);
  }

  Future<void> pumpOverviewPage(
    WidgetTester tester,
    FakeOverviewRepository overviewRepo,
    FakePauseRepository pauseRepo,
  ) {
    return tester.pumpWidget(
      ProviderScope(
        overrides: [
          overviewRepositoryProvider.overrideWithValue(overviewRepo),
          pauseRepositoryProvider.overrideWithValue(pauseRepo),
          overviewClockConfigProvider.overrideWithValue(
            OverviewClockConfig(now: () => baseTime),
          ),
        ],
        child: NodeVisualScope(
          registry: createNodeVisualRegistry(),
          child: MaterialApp(
            theme: HiveTheme.dark(),
            localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
              AppLocalizations.delegate,
              GlobalMaterialLocalizations.delegate,
              GlobalCupertinoLocalizations.delegate,
              GlobalWidgetsLocalizations.delegate,
            ],
            supportedLocales: AppLocalizations.supportedLocales,
            home: const Scaffold(body: OverviewPage()),
          ),
        ),
      ),
    );
  }

  testWidgets('renders empty state with metrics, CTA, and recent runs', (
    tester,
  ) async {
    configureSize(tester, desktopSize);
    final recentRuns = List<RunSummary>.generate(
      5,
      (i) => RunSummary(
        id: 'recent-$i',
        workflowName: 'Recent Workflow $i',
        status: RunStatus.succeeded,
        startedAt: startedEarlier,
        finishedAt: finishedEarlier,
        checkpointCount: 2,
      ),
    );
    final overviewRepo = FakeOverviewRepository(
      initialResult: Success<OverviewSnapshot>(
        OverviewSnapshot(
          metrics: const OverviewMetrics(
            activeRunsCount: 0,
            activeNodesCount: 0,
            pendingPausesCount: 0,
            succeededLast24hCount: 5,
            failedLast24hCount: 1,
          ),
          activeRuns: const <ActiveRunSummary>[],
          activeNodes: const <ActiveNodeSummary>[],
          pendingPauses: const <PendingPauseSummary>[],
          recentRuns: recentRuns,
        ),
      ),
    );
    final pauseRepo = FakePauseRepository();
    addTearDown(() async {
      await overviewRepo.dispose();
      await pauseRepo.dispose();
    });

    await pumpOverviewPage(tester, overviewRepo, pauseRepo);
    await tester.pumpAndSettle();

    expect(find.byType(HiveEmptyState), findsOneWidget);
    expect(find.byKey(const Key('overview_empty_cta_button')), findsOneWidget);
    expect(find.byType(HiveMetricTile), findsNWidgets(5));
    expect(find.text('Recent Workflow 0'), findsOneWidget);
    expect(find.text('Recent Workflow 4'), findsOneWidget);
  });

  testWidgets(
    'renders populated layout, resolves avatars via NodeVisualRegistry with '
    'robot fallback, and gates inline pause buttons',
    (tester) async {
      configureSize(tester, desktopSize);
      final overviewRepo = FakeOverviewRepository(
        initialResult: Success<OverviewSnapshot>(
          OverviewSnapshot(
            metrics: const OverviewMetrics(
              activeRunsCount: 1,
              activeNodesCount: 2,
              pendingPausesCount: 3,
              succeededLast24hCount: 8,
              failedLast24hCount: 0,
            ),
            activeRuns: <ActiveRunSummary>[
              ActiveRunSummary(
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                status: RunStatus.running,
                startedAt: startedEarlier,
                activeNodeCount: 2,
              ),
            ],
            activeNodes: <ActiveNodeSummary>[
              ActiveNodeSummary(
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                nodeId: 'node-claude',
                nodeType: NodeTypeId.claudeCode,
                nodeLabel: 'Code Review',
                agentId: 'reviewer',
                agentName: 'Code Reviewer',
                status: ActiveNodeStatus.running,
                startedAt: startedEarlier,
              ),
              ActiveNodeSummary(
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                nodeId: 'node-unknown',
                nodeType: 'custom.unknown_type',
                nodeLabel: 'Mystery Step',
                status: ActiveNodeStatus.paused,
                startedAt: startedEarlier,
              ),
            ],
            pendingPauses: <PendingPauseSummary>[
              PendingPauseSummary(
                pauseId: 'pause-simple',
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                nodeId: 'node-approve',
                nodeLabel: 'Simple Approval',
                pauseKind: PauseKind.humanApproval,
                prompt: 'Deploy build?',
                requiresFeedback: false,
                createdAt: startedEarlier,
              ),
              PendingPauseSummary(
                pauseId: 'pause-feedback',
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                nodeId: 'node-feedback',
                nodeLabel: 'Feedback Approval',
                pauseKind: PauseKind.humanApproval,
                prompt: 'Explain your decision.',
                requiresFeedback: true,
                createdAt: startedEarlier,
              ),
              PendingPauseSummary(
                pauseId: 'pause-question',
                runId: 'run-1',
                workflowName: 'Release Pipeline',
                nodeId: 'node-ask',
                nodeLabel: 'Ask Human',
                pauseKind: PauseKind.askHuman,
                prompt: 'Which target?',
                requiresFeedback: false,
                createdAt: startedEarlier,
              ),
            ],
            recentRuns: const <RunSummary>[],
          ),
        ),
      );
      final pauseRepo = FakePauseRepository();
      addTearDown(() async {
        await overviewRepo.dispose();
        await pauseRepo.dispose();
      });

      await pumpOverviewPage(tester, overviewRepo, pauseRepo);
      await tester.pumpAndSettle();

      // Active run + active nodes + avatars.
      expect(find.text('Release Pipeline'), findsWidgets);
      expect(find.text('Code Reviewer'), findsOneWidget);
      expect(find.text('Mystery Step'), findsOneWidget);

      final avatars = tester
          .widgetList<HiveAgentAvatar>(find.byType(HiveAgentAvatar))
          .toList();
      expect(avatars.length, 2);
      expect(avatars[0].visual.icon, HiveIcons.harnessClaudeCode);
      expect(avatars[1].visual.icon, HiveIcons.robot);

      // Inline Approve/Reject only for simple humanApproval without feedback.
      expect(
        find.byKey(const Key('overview_pause_approve_pause-simple')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview_pause_reject_pause-simple')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview_pause_open_pause-feedback')),
        findsOneWidget,
      );
      expect(
        find.byKey(const Key('overview_pause_open_pause-question')),
        findsOneWidget,
      );

      // 409 error on inline Approve displays an inline HiveBanner on that card.
      pauseRepo.onAnswerPause = (_, _) async =>
          const FailureResult<Pause>(ConflictFailure('Already resolved'));
      await tester.tap(
        find.byKey(const Key('overview_pause_approve_pause-simple')),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HiveBanner), findsOneWidget);
    },
  );

  testWidgets(
    'stacks cleanly on narrower desktop width and shows error retry',
    (tester) async {
      configureSize(tester, narrowDesktopSize);
      final overviewRepo = FakeOverviewRepository(
        initialResult: const FailureResult<OverviewSnapshot>(
          NetworkFailure('Socket unreachable'),
        ),
      );
      final pauseRepo = FakePauseRepository();
      addTearDown(() async {
        await overviewRepo.dispose();
        await pauseRepo.dispose();
      });

      await pumpOverviewPage(tester, overviewRepo, pauseRepo);
      await tester.pumpAndSettle();

      expect(
        find.byKey(const Key('overview_error_retry_button')),
        findsOneWidget,
      );

      overviewRepo.nextResult = Success<OverviewSnapshot>(
        OverviewSnapshot(
          metrics: const OverviewMetrics(
            activeRunsCount: 1,
            activeNodesCount: 0,
            pendingPausesCount: 0,
            succeededLast24hCount: 0,
            failedLast24hCount: 0,
          ),
          activeRuns: <ActiveRunSummary>[
            ActiveRunSummary(
              runId: 'run-1',
              workflowName: 'Stacked Workflow',
              status: RunStatus.running,
              startedAt: baseTime,
              activeNodeCount: 0,
            ),
          ],
          activeNodes: const <ActiveNodeSummary>[],
          pendingPauses: const <PendingPauseSummary>[],
          recentRuns: const <RunSummary>[],
        ),
      );

      await tester.tap(find.byKey(const Key('overview_error_retry_button')));
      await tester.pumpAndSettle();
      expect(find.text('Stacked Workflow'), findsOneWidget);
    },
  );

  testWidgets(
    'only elapsed-duration text widgets rebuild on 1-second tick, not page, '
    'metrics, or pause cards',
    (tester) async {
      configureSize(tester, desktopSize);
      var currentTime = baseTime;
      final periodicTimers = <_FakePeriodicTimer>[];
      final overviewRepo = FakeOverviewRepository(
        initialResult: Success<OverviewSnapshot>(
          OverviewSnapshot(
            metrics: const OverviewMetrics(
              activeRunsCount: 1,
              activeNodesCount: 1,
              pendingPausesCount: 1,
              succeededLast24hCount: 0,
              failedLast24hCount: 0,
            ),
            activeRuns: <ActiveRunSummary>[
              ActiveRunSummary(
                runId: 'run-1',
                workflowName: 'Ticker Workflow',
                status: RunStatus.running,
                startedAt: startedEarlier,
                activeNodeCount: 1,
              ),
            ],
            activeNodes: <ActiveNodeSummary>[
              ActiveNodeSummary(
                runId: 'run-1',
                workflowName: 'Ticker Workflow',
                nodeId: 'node-1',
                nodeType: NodeTypeId.claudeCode,
                nodeLabel: 'Build Step',
                status: ActiveNodeStatus.running,
                startedAt: startedEarlier,
              ),
            ],
            pendingPauses: <PendingPauseSummary>[
              PendingPauseSummary(
                pauseId: 'pause-1',
                runId: 'run-1',
                workflowName: 'Ticker Workflow',
                nodeId: 'node-approve',
                nodeLabel: 'Approve Step',
                pauseKind: PauseKind.humanApproval,
                prompt: 'Continue?',
                requiresFeedback: false,
                createdAt: startedEarlier,
              ),
            ],
            recentRuns: const <RunSummary>[],
          ),
        ),
      );
      final pauseRepo = FakePauseRepository();
      addTearDown(() async {
        await overviewRepo.dispose();
        await pauseRepo.dispose();
      });

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            overviewRepositoryProvider.overrideWithValue(overviewRepo),
            pauseRepositoryProvider.overrideWithValue(pauseRepo),
            overviewClockConfigProvider.overrideWithValue(
              OverviewClockConfig(
                now: () => currentTime,
                createPeriodicTimer: (_, callback) {
                  final timer = _FakePeriodicTimer(callback);
                  periodicTimers.add(timer);
                  return timer;
                },
              ),
            ),
          ],
          child: NodeVisualScope(
            registry: createNodeVisualRegistry(),
            child: MaterialApp(
              theme: HiveTheme.dark(),
              localizationsDelegates: const <LocalizationsDelegate<dynamic>>[
                AppLocalizations.delegate,
                GlobalMaterialLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
              ],
              supportedLocales: AppLocalizations.supportedLocales,
              home: const Scaffold(body: OverviewPage()),
            ),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(periodicTimers, hasLength(1));
      expect(periodicTimers.single.isActive, isTrue);
      expect(find.text('1m 0s'), findsNWidgets(2));

      final metricsBefore = tester.widget<OverviewMetricsSection>(
        find.byType(OverviewMetricsSection),
      );
      final pausesBefore = tester.widget<OverviewPendingPausesSection>(
        find.byType(OverviewPendingPausesSection),
      );
      final activeRunsBefore = tester.widget<OverviewActiveRunsSection>(
        find.byType(OverviewActiveRunsSection),
      );
      final activeNodesBefore = tester.widget<OverviewActiveNodesSection>(
        find.byType(OverviewActiveNodesSection),
      );

      // Fire a 1-second tick.
      currentTime = baseTime.add(OverviewClockConfig.defaultTickInterval);
      periodicTimers.single.fire();
      await tester.pump();

      expect(find.text('1m 1s'), findsNWidgets(2));
      expect(
        identical(
          tester.widget<OverviewMetricsSection>(
            find.byType(OverviewMetricsSection),
          ),
          metricsBefore,
        ),
        isTrue,
      );
      expect(
        identical(
          tester.widget<OverviewPendingPausesSection>(
            find.byType(OverviewPendingPausesSection),
          ),
          pausesBefore,
        ),
        isTrue,
      );
      expect(
        identical(
          tester.widget<OverviewActiveRunsSection>(
            find.byType(OverviewActiveRunsSection),
          ),
          activeRunsBefore,
        ),
        isTrue,
      );
      expect(
        identical(
          tester.widget<OverviewActiveNodesSection>(
            find.byType(OverviewActiveNodesSection),
          ),
          activeNodesBefore,
        ),
        isTrue,
      );
    },
  );

  testWidgets(
    'pending-pauses live region is absent on first build and announces on '
    'count change',
    (tester) async {
      configureSize(tester, desktopSize);
      final overviewRepo = FakeOverviewRepository(
        initialResult: const Success<OverviewSnapshot>(
          OverviewSnapshot(
            metrics: OverviewMetrics(
              activeRunsCount: 0,
              activeNodesCount: 0,
              pendingPausesCount: 0,
              succeededLast24hCount: 0,
              failedLast24hCount: 0,
            ),
            activeRuns: <ActiveRunSummary>[],
            activeNodes: <ActiveNodeSummary>[],
            pendingPauses: <PendingPauseSummary>[],
            recentRuns: <RunSummary>[],
          ),
        ),
      );
      final pauseRepo = FakePauseRepository();
      addTearDown(() async {
        await overviewRepo.dispose();
        await pauseRepo.dispose();
      });

      await pumpOverviewPage(tester, overviewRepo, pauseRepo);
      await tester.pumpAndSettle();

      // Not present / not announcing on first build.
      expect(
        find.byKey(const Key('overview_metric_pending_pauses_live_region')),
        findsNothing,
      );

      // Update snapshot so pendingPausesCount changes from 0 -> 1.
      overviewRepo.nextResult = Success<OverviewSnapshot>(
        OverviewSnapshot(
          metrics: const OverviewMetrics(
            activeRunsCount: 1,
            activeNodesCount: 0,
            pendingPausesCount: 1,
            succeededLast24hCount: 0,
            failedLast24hCount: 0,
          ),
          activeRuns: <ActiveRunSummary>[
            ActiveRunSummary(
              runId: 'run-1',
              workflowName: 'Release Pipeline',
              status: RunStatus.paused,
              startedAt: startedEarlier,
              activeNodeCount: 0,
            ),
          ],
          activeNodes: const <ActiveNodeSummary>[],
          pendingPauses: <PendingPauseSummary>[
            PendingPauseSummary(
              pauseId: 'pause-1',
              runId: 'run-1',
              workflowName: 'Release Pipeline',
              nodeId: 'node-approve',
              nodeLabel: 'Approve',
              pauseKind: PauseKind.humanApproval,
              prompt: 'Ship?',
              requiresFeedback: false,
              createdAt: startedEarlier,
            ),
          ],
          recentRuns: const <RunSummary>[],
        ),
      );

      await tester.tap(find.byKey(const Key('overview_refresh_button')));
      await tester.pumpAndSettle();

      final liveRegionFinder = find.byKey(
        const Key('overview_metric_pending_pauses_live_region'),
      );
      expect(liveRegionFinder, findsOneWidget);
      final semantics = tester.getSemantics(liveRegionFinder);
      expect(semantics.flagsCollection.isLiveRegion, isTrue);
      expect(semantics.label, contains('Pending pauses: 1'));
    },
  );
}

final class _FakePeriodicTimer implements Timer {
  new(this._callback);

  final void Function(Timer) _callback;
  bool _active = true;

  void fire() {
    if (!_active) return;
    _callback(this);
  }

  @override
  void cancel() {
    _active = false;
  }

  @override
  bool get isActive => _active;

  @override
  int get tick => 0;
}
