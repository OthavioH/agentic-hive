import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';

/// Every `HiveIcons` interface icon.
class IconsPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return ShowcasePage(
      title: 'Icons',
      subtitle: 'HiveIcons over the free Hugeicons stroke-rounded set (MIT).',
      children: <Widget>[
        ShowcaseSection(
          title: 'Interface',
          children: <Widget>[
            for (final e in HiveIcons.interface.entries)
              SizedBox(
                width: spacing.space8 * 2,
                child: Labeled(
                  label: e.key,
                  child: HiveIcon(
                    e.value,
                    size: spacing.space3,
                    color: colors.onSurface,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The Hive robot, the harness logos and the node visual registry.
class FacesPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  static const Map<String, String> _logoSources = <String, String>{
    'harnessClaudeCode': 'Hugeicons free · Claude',
    'harnessCodex': 'Hugeicons free · ChatGPT (OpenAI)',
    'harnessGeminiCli': 'Hugeicons free · Google Gemini',
    'harnessAntigravity': 'Gemini logo (owner decision)',
    'harnessTerminal': 'Hive robot (fallback)',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final registry = NodeVisualRegistry()
      ..register(
        'harness.claudeCode',
        const NodeVisual(
          icon: HiveIcons.harnessClaudeCode,
          labelKey: 'nodeTypeClaudeCode',
        ),
      )
      ..register(
        'harness.codex',
        const NodeVisual(
          icon: HiveIcons.harnessCodex,
          labelKey: 'nodeTypeCodex',
        ),
      )
      ..register(
        'harness.geminiCli',
        const NodeVisual(
          icon: HiveIcons.harnessGeminiCli,
          labelKey: 'nodeTypeGeminiCli',
        ),
      )
      ..register(
        'harness.antigravity',
        const NodeVisual(
          icon: HiveIcons.harnessAntigravity,
          labelKey: 'nodeTypeAntigravity',
        ),
      )
      ..register(
        'harness.terminal',
        const NodeVisual(
          icon: HiveIcons.harnessTerminal,
          labelKey: 'nodeTypeTerminal',
        ),
      )
      ..register(
        'command',
        const NodeVisual(icon: HiveIcons.terminal, labelKey: 'nodeTypeCommand'),
      )
      ..register(
        'validator.tests',
        const NodeVisual(
          icon: HiveIcons.validatorTests,
          labelKey: 'nodeTypeValidatorTests',
        ),
      )
      ..register(
        'validator.checklist',
        const NodeVisual(
          icon: HiveIcons.validatorChecklist,
          labelKey: 'nodeTypeValidatorChecklist',
        ),
      )
      ..register(
        'validator.review',
        const NodeVisual(
          icon: HiveIcons.validatorReview,
          labelKey: 'nodeTypeValidatorReview',
        ),
      )
      ..register(
        'humanApproval',
        NodeVisual(
          icon: HiveIcons.person,
          labelKey: 'nodeTypeHumanApproval',
          accent: (c) => c.info,
        ),
      );

    return ShowcasePage(
      title: 'Robot, logos and node visuals',
      subtitle:
          'Harness logos are agent faces; the flat robot is only the '
          'fallback.',
      children: <Widget>[
        ShowcaseSection(
          title: 'Hive robot',
          description:
              'One flat SVG drawn in currentColor, so it always uses '
              'a token color.',
          children: <Widget>[
            for (final e in <String, Color>{
              'onSurface': colors.onSurface,
              'onSurfaceMuted': colors.onSurfaceMuted,
              'accent': colors.accent,
              'accentMuted': colors.accentMuted,
            }.entries)
              Labeled(
                label: e.key,
                child: HiveIcon(
                  HiveIcons.robot,
                  size: spacing.space8,
                  color: e.value,
                ),
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Harness logos',
          children: <Widget>[
            for (final e in HiveIcons.harnessLogos.entries)
              SizedBox(
                width: spacing.space8 * 3,
                child: Labeled(
                  label: '${e.key}\n${_logoSources[e.key]}',
                  child: HiveIcon(
                    e.value,
                    size: spacing.space6,
                    color: colors.onSurface,
                  ),
                ),
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Node visual registry',
          description:
              'Each node type registers its visual; unknown types '
              'resolve to the robot fallback.',
          children: <Widget>[
            for (final type in <String>[
              ...registry.entries.keys,
              'unregistered.type',
            ])
              SizedBox(
                width: spacing.space8 * 2,
                child: Labeled(
                  label: type,
                  child: HiveAgentAvatar(
                    visual: registry.resolve(type),
                    semanticLabel: registry.resolve(type).labelKey,
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// The system tray icons from `HiveTrayAssets`, at their real pixel sizes
/// and enlarged, on both surface brightnesses.
class TrayIconsPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  static const Map<String, String> _pngs = <String, String>{
    'linux · 32': HiveTrayAssets.linux,
    'linux@2x · 64': HiveTrayAssets.linux2x,
    'macosTemplate · 22': HiveTrayAssets.macosTemplate,
    'macosTemplate@2x · 44': HiveTrayAssets.macosTemplate2x,
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return ShowcasePage(
      title: 'Tray icons',
      subtitle:
          'Static tray assets drawn from the Hive hexagon mark. The Windows '
          '.ico (16 to 64 px) uses the same artwork as the Linux PNGs; the '
          'macOS template is black with alpha and is tinted by the menu bar.',
      children: <Widget>[
        ShowcaseSection(
          title: 'Actual size',
          children: <Widget>[
            for (final entry in _pngs.entries)
              Labeled(
                label: entry.key,
                child: Image.asset(
                  entry.value,
                  filterQuality: FilterQuality.none,
                ),
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Enlarged',
          description: 'Pixel grid at 4x, on a surface3 tile.',
          children: <Widget>[
            for (final entry in _pngs.entries)
              Labeled(
                label: entry.key,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    color: colors.surface3,
                    borderRadius: context.hiveRadii.card,
                  ),
                  child: Padding(
                    padding: EdgeInsets.all(spacing.space2),
                    child: SizedBox.square(
                      dimension: spacing.space8 * 2,
                      child: Image.asset(
                        entry.value,
                        filterQuality: FilterQuality.none,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Asset keys',
          children: <Widget>[
            for (final key in HiveTrayAssets.all)
              Text(
                key,
                style: context.hiveTypography.mono.copyWith(
                  color: colors.onSurface,
                ),
              ),
          ],
        ),
      ],
    );
  }
}
