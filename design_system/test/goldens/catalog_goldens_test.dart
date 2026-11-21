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

      testWidgets('HiveTextField', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_text_field',
          const SizedBox(
            width: 360,
            child: HiveTextField(
              label: 'Agent id',
              hintText: 'code-reviewer',
              errorText: 'An agent with this id already exists',
            ),
          ),
        );
      });

      testWidgets('HiveTextArea', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_text_area',
          const SizedBox(
            width: 360,
            child: HiveTextArea(
              label: 'Prompt',
              hintText: '# Role',
              mono: true,
            ),
          ),
        );
      });

      testWidgets('HiveChip', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_chip',
          Wrap(
            spacing: 8,
            children: <Widget>[
              HiveChip.removable(
                label: 'review',
                removeSemanticLabel: 'Remove tag review',
                onRemoved: () {},
              ),
              HiveChip.filter(
                label: 'backend',
                selected: true,
                onSelected: (_) {},
              ),
              HiveChip.filter(
                label: 'docs',
                selected: false,
                onSelected: (_) {},
              ),
            ],
          ),
        );
      });

      testWidgets('HiveSegmentedControl', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_segmented_control',
          HiveSegmentedControl<String>(
            segments: const <HiveSegment<String>>[
              HiveSegment<String>(value: 'raw', label: 'Raw'),
              HiveSegment<String>(value: 'preview', label: 'Preview'),
            ],
            selected: 'raw',
            semanticLabel: 'Prompt view',
            onChanged: (_) {},
          ),
        );
      });

      testWidgets('HiveConfirmDialog', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_confirm_dialog',
          HiveConfirmDialog(
            title: 'Delete agent?',
            message: 'code-reviewer.md will be removed from disk.',
            confirmLabel: 'Delete',
            cancelLabel: 'Cancel',
            tone: HiveConfirmTone.destructive,
            icon: HiveIcons.delete,
            onConfirm: () {},
            onCancel: () {},
          ),
          size: const Size(560, 400),
        );
      });

      testWidgets('HiveBanner', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_banner',
          const SizedBox(
            width: 440,
            child: HiveBanner(
              tone: HiveFeedbackTone.danger,
              title: 'This agent could not be read',
              message: 'Fix the YAML frontmatter or delete the file.',
            ),
          ),
        );
      });

      testWidgets('HiveToast', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_toast',
          const HiveToast(
            tone: HiveFeedbackTone.success,
            message: 'Agent saved',
          ),
        );
      });

      testWidgets('HiveCollapsibleSection', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_collapsible_section',
          const SizedBox(
            width: 400,
            child: HiveCollapsibleSection(
              title: 'Capabilities & tools',
              subtitle: 'Informational; not enforced',
              initiallyExpanded: true,
              child: Text('flutter-validation, context7'),
            ),
          ),
        );
      });

      testWidgets('HiveMasterDetail', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_master_detail',
          const SizedBox(
            width: 800,
            height: 280,
            child: HiveMasterDetail(
              master: Center(child: Text('Agent list')),
              detail: Center(child: Text('Agent editor')),
            ),
          ),
          size: const Size(840, 320),
        );
      });

      testWidgets('HiveMarkdownView', (tester) async {
        await pumpAndMatch(
          tester,
          'hive_markdown_view',
          const SizedBox(
            width: 440,
            child: HiveMarkdownView(
              data:
                  '## Responsibilities\n\n'
                  '- Review **pull requests**\n'
                  '- Run `dart analyze`\n\n'
                  '> Never approve your own changes.',
            ),
          ),
          size: const Size(480, 320),
        );
      });
    });
  }
}
