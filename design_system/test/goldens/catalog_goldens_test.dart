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

      testWidgets('HiveSideRail section collapsed', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_side_rail_section_collapsed',
          SizedBox(
            height: 440,
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
              section: const HiveRailSection(
                icon: HiveIcons.folder,
                label: 'Workspaces',
                title: 'Workspaces',
                badgeCount: 2,
                semanticLabel: 'Workspaces, 2 active runs',
                child: SizedBox.shrink(),
              ),
            ),
          ),
          size: const Size(320, 480),
        );
      });

      testWidgets('HiveSideRail section expanded', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_side_rail_section_expanded',
          SizedBox(
            height: 440,
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
              initiallyExpanded: true,
              markLabel: 'Agentic Hive',
              expandLabel: 'Expand',
              collapseLabel: 'Collapse',
              section: const HiveRailSection(
                icon: HiveIcons.folder,
                label: 'Workspaces',
                title: 'Workspaces',
                badgeCount: 2,
                semanticLabel: 'Workspaces, 2 active runs',
                child: SizedBox.shrink(),
              ),
            ),
          ),
          size: const Size(360, 480),
        );
      });

      testWidgets('HiveSideRail section pinned', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_side_rail_section_pinned',
          SizedBox(
            height: 440,
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
              section: HiveRailSection(
                icon: HiveIcons.folder,
                label: 'Workspaces',
                title: 'Workspaces',
                badgeCount: 2,
                semanticLabel: 'Workspaces, 2 active runs',
                pinned: true,
                onPinnedChanged: (_) {},
                trailing: HiveIconButton(
                  icon: HiveIcons.refresh,
                  semanticLabel: 'Refresh workspaces',
                  size: HiveButtonSize.small,
                  onPressed: () {},
                ),
                child: ListView(
                  children: <Widget>[
                    HiveTreeItem(
                      label: 'agentic-hive',
                      leading: const HiveIcon(HiveIcons.folder),
                      expanded: true,
                      onPressed: () {},
                    ),
                    HiveTreeItem(
                      label: 'main',
                      indentLevel: 1,
                      leading: const HiveIcon(HiveIcons.branch),
                      onPressed: () {},
                    ),
                  ],
                ),
              ),
            ),
          ),
          size: const Size(520, 480),
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

      testWidgets('HiveInsetPanel', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_inset_panel',
          SizedBox(
            width: 400,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: 16,
              children: <Widget>[
                HiveInsetPanel(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      const HiveBadge(label: 'Not installed'),
                      HiveButton(
                        label: 'Install',
                        size: HiveButtonSize.small,
                        variant: HiveButtonVariant.secondary,
                        onPressed: () {},
                      ),
                    ],
                  ),
                ),
                const HiveInsetPanel(
                  padding: HiveInsetPadding.comfortable,
                  child: Text(
                    'Run claude login in a terminal before using this harness.',
                  ),
                ),
              ],
            ),
          ),
          size: const Size(480, 260),
        );
      });

      testWidgets('HiveBanner compact', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_banner_compact',
          SizedBox(
            width: 400,
            child: HiveBanner(
              tone: HiveFeedbackTone.danger,
              density: HiveBannerDensity.compact,
              title: 'Could not install skill',
              message: 'Permission denied writing to ~/.claude/skills.',
              actions: <Widget>[
                HiveButton(
                  label: 'Retry',
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.secondary,
                  onPressed: () {},
                ),
              ],
            ),
          ),
          size: const Size(480, 220),
        );
      });

      testWidgets('HiveSwitch with helper', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_switch_helper',
          SizedBox(
            width: 400,
            child: HiveSwitch(
              label: 'Install the skill automatically',
              helperText:
                  'Installs the agentic-hive skill when a new harness is '
                  'found.',
              value: true,
              onChanged: (_) {},
            ),
          ),
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
