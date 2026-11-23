@Tags(<String>['golden'])
library;

import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  setUpAll(loadHiveFonts);

  final themes = <String, ThemeData>{
    'dark': HiveTheme.dark(),
    'light': HiveTheme.light(),
  };

  for (final themeEntry in themes.entries) {
    final themeName = themeEntry.key;
    final theme = themeEntry.value;

    group('Catalog goldens ($themeName)', () {
      Future<void> pumpAndMatch(
        WidgetTester tester,
        String name,
        Widget child, {
        Size size = const Size(480, 240),
      }) async {
        await tester.binding.setSurfaceSize(size);
        addTearDown(() => tester.binding.setSurfaceSize(null));

        await tester.pumpWidget(
          hiveTestApp(
            theme: theme,
            child: Center(child: child),
          ),
        );
        await tester.pumpAndSettle();

        await expectLater(
          find.byType(HiveSurface),
          matchesGoldenFile('goldens/${name}_$themeName.png'),
        );
      }

      testWidgets('HiveSideRail', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_side_rail',
          SizedBox(
            height: 400,
            child: HiveSideRail(
              destinations: const <HiveRailDestination>[
                HiveRailDestination(
                  icon: HiveIcons.overview,
                  label: 'Overview',
                ),
                HiveRailDestination(
                  icon: HiveIcons.workflows,
                  label: 'Workflows',
                ),
              ],
              selectedIndex: 0,
              onSelected: (_) {},
              markLabel: 'Agentic Hive',
              expandLabel: 'Expand',
              collapseLabel: 'Collapse',
            ),
          ),
          size: const Size(320, 440),
        );
      });

      testWidgets('HiveRailItem', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_rail_item',
          HiveRailItem(
            icon: HiveIcons.workflows,
            label: 'Workflows',
            selected: true,
            expanded: true,
            onPressed: () {},
          ),
        );
      });

      testWidgets('HivePageHeader', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_page_header',
          const HivePageHeader(
            title: 'Workflows',
            subtitle: 'Automate multi-agent runs',
          ),
          size: const Size(720, 160),
        );
      });

      testWidgets('HiveEmptyState', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_empty_state',
          HiveEmptyState(
            icon: HiveIcons.workflows,
            title: 'No workflows yet',
            message: 'Create your first workflow to orchestrate agents.',
            action: HiveButton(label: 'New workflow', onPressed: () {}),
          ),
          size: const Size(520, 320),
        );
      });

      testWidgets('HiveButton', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_button',
          HiveButton(
            label: 'Run workflow',
            icon: HiveIcons.runs,
            onPressed: () {},
          ),
        );
      });

      testWidgets('HiveIconButton', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_icon_button',
          HiveIconButton(
            icon: HiveIcons.settings,
            semanticLabel: 'Settings',
            variant: HiveButtonVariant.secondary,
            onPressed: () {},
          ),
        );
      });

      testWidgets('HiveIconButton dangerHover', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_icon_button_danger_hover',
          HiveIconButton.dangerHover(
            icon: HiveIcons.close,
            semanticLabel: 'Close',
            onPressed: () {},
          ),
        );
      });

      testWidgets('Window caption icons', (tester) async {
        await pumpAndMatch(
          tester,
          'window_caption_icons',
          const Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: <Widget>[
              HiveIcon(HiveIcons.minimize, semanticLabel: 'Minimize'),
              HiveIcon(HiveIcons.maximize, semanticLabel: 'Maximize'),
              HiveIcon(HiveIcons.restore, semanticLabel: 'Restore'),
            ],
          ),
        );
      });

      testWidgets('HiveCard', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_card',
          const SizedBox(
            width: 320,
            child: HiveCard(child: Text('Workflow summary')),
          ),
        );
      });

      testWidgets('HiveBadge', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_badge',
          const HiveBadge(label: 'Running', tone: HiveBadgeTone.success),
        );
      });

      testWidgets('HiveStatusDot', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_status_dot',
          const HiveStatusDot(
            status: HiveNodeStatus.running,
            semanticLabel: 'Running',
          ),
        );
      });

      testWidgets('HiveAgentAvatar', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_agent_avatar',
          const HiveAgentAvatar(
            visual: NodeVisual.fallback,
            semanticLabel: 'Agent',
            status: HiveNodeStatus.succeeded,
            statusLabel: 'Succeeded',
          ),
        );
      });

      testWidgets('HiveConnectionIndicator', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_connection_indicator',
          const HiveConnectionIndicator(
            state: HiveConnectionState.connected,
            label: 'Connected',
          ),
        );
      });

      testWidgets('HiveHexMark', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_hex_mark',
          const HiveHexMark(semanticLabel: 'Agentic Hive'),
        );
      });

      testWidgets('HiveTitleBar restored', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_title_bar_restored',
          Align(
            alignment: Alignment.topCenter,
            child: HiveTitleBar(
              isMaximized: false,
              labels: const HiveTitleBarLabels(
                minimize: 'Minimize',
                maximize: 'Maximize',
                restore: 'Restore',
                close: 'Close to tray',
              ),
              onMinimize: () {},
              onToggleMaximize: () {},
              onClose: () {},
            ),
          ),
          size: const Size(720, 80),
        );
      });

      testWidgets('HiveTitleBar maximized', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_title_bar_maximized',
          Align(
            alignment: Alignment.topCenter,
            child: HiveTitleBar(
              isMaximized: true,
              labels: const HiveTitleBarLabels(
                minimize: 'Minimize',
                maximize: 'Maximize',
                restore: 'Restore',
                close: 'Close to tray',
              ),
              onMinimize: () {},
              onToggleMaximize: () {},
              onClose: () {},
            ),
          ),
          size: const Size(720, 80),
        );
      });

      testWidgets('HiveTitleBar caption button states', (tester) async {
        Widget row(Set<WidgetState> states) {
          WidgetStatesController seeded() {
            final controller = WidgetStatesController(states);
            addTearDown(controller.dispose);
            return controller;
          }

          return Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 4,
            children: <Widget>[
              HiveIconButton(
                icon: HiveIcons.minimize,
                semanticLabel: 'Minimize',
                size: HiveButtonSize.small,
                statesController: seeded(),
                onPressed: () {},
              ),
              HiveIconButton(
                icon: HiveIcons.maximize,
                semanticLabel: 'Maximize',
                size: HiveButtonSize.small,
                statesController: seeded(),
                onPressed: () {},
              ),
              HiveIconButton.dangerHover(
                icon: HiveIcons.close,
                semanticLabel: 'Close to tray',
                size: HiveButtonSize.small,
                statesController: seeded(),
                onPressed: () {},
              ),
            ],
          );
        }

        await pumpAndMatch(
          tester,
          'hive_title_bar_caption_states',
          Column(
            mainAxisSize: MainAxisSize.min,
            spacing: 16,
            children: <Widget>[
              row(<WidgetState>{WidgetState.hovered}),
              row(<WidgetState>{WidgetState.focused}),
              row(<WidgetState>{WidgetState.pressed}),
            ],
          ),
          size: const Size(240, 200),
        );
      });
    });
  }
}
