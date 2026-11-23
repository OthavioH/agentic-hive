import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';

/// Motion tokens and the Flux Motion trial behind `HiveMotion`.
///
/// Every demo replays on "Replay". Turn on "Reduce motion" to check that
/// each widget renders its child without animation.
class MotionPage extends StatefulWidget {
  /// Creates the page.
  const new({required this.reduceMotion, super.key});

  /// Simulates `MediaQuery.disableAnimations`.
  final bool reduceMotion;

  @override
  State<MotionPage> createState() => _MotionPageState();
}

class _MotionPageState extends State<MotionPage> {
  int _generation = 0;
  final GlobalKey<NavigatorState> _navigator = GlobalKey<NavigatorState>();

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final mono = context.hiveTypography.mono.copyWith(color: colors.onSurface);

    Widget sampleCard(String title, String detail) {
      return SizedBox(
        width: spacing.space8 * 4,
        child: HiveCard(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              const HiveAgentAvatar(
                visual: NodeVisual(
                  icon: HiveIcons.harnessClaudeCode,
                  labelKey: 'harnessClaudeCode',
                ),
                semanticLabel: 'Claude Code',
                size: HiveAvatarSize.small,
              ),
              SizedBox(width: spacing.space2),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    Text(title, style: context.hiveTypography.labelLarge),
                    Text(
                      detail,
                      style: context.hiveTypography.bodySmall.copyWith(
                        color: colors.onSurfaceMuted,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      );
    }

    return MediaQuery(
      data: MediaQuery.of(context)
          .copyWith(disableAnimations: widget.reduceMotion),
      child: ShowcasePage(
        title: 'Motion',
        subtitle:
            'Flux Motion trial (flutter_flux_motion 0.1.0) behind '
            'HiveMotion. Reduce motion: ${widget.reduceMotion ? 'on' : 'off'}.',
        children: <Widget>[
          ShowcaseSection(
            title: 'Tokens',
            children: <Widget>[
              for (final e in motion.durations.entries)
                Text('${e.key}: ${e.value.inMilliseconds} ms', style: mono),
              for (final e in motion.curves.entries)
                Text('${e.key}: ${e.value}', style: mono),
            ],
          ),
          HiveButton(
            label: 'Replay',
            icon: HiveIcons.refresh,
            variant: HiveButtonVariant.secondary,
            onPressed: () => setState(() => _generation++),
          ),
          ShowcaseSection(
            key: ValueKey<int>(_generation),
            title: 'Entrances',
            children: <Widget>[
              Labeled(
                label: 'HiveFadeIn · medium, standard',
                child: HiveFadeIn(
                  child: sampleCard('Fix flaky test', 'Running for 2 min'),
                ),
              ),
              Labeled(
                label: 'HiveSlideIn · medium, emphasized, space2',
                child: HiveSlideIn(
                  child: sampleCard('Review pull request', 'Waiting'),
                ),
              ),
              Labeled(
                label: 'HiveStagger · interval short/2',
                child: HiveStagger(
                  children: <Widget>[
                    sampleCard('Plan feature', 'Succeeded'),
                    SizedBox(height: spacing.space1),
                    sampleCard('Write tests', 'Running'),
                    SizedBox(height: spacing.space1),
                    sampleCard('Update changelog', 'Idle'),
                  ],
                ),
              ),
            ],
          ),
          ShowcaseSection(
            title: 'Page transition',
            description:
                'HiveMotion.route: Flux fade-through, long / '
                'emphasized in, medium / exit out.',
            children: <Widget>[
              SizedBox(
                width: spacing.space8 * 8,
                height: spacing.space8 * 4,
                child: ClipRRect(
                  borderRadius: context.hiveRadii.panel,
                  child: Navigator(
                    key: _navigator,
                    onGenerateRoute: (_) => PageRouteBuilder<void>(
                      pageBuilder: (context, _, _) => _DemoPage(
                        title: 'Runs',
                        actionLabel: 'Open run',
                        onAction: () => _navigator.currentState!.push(
                          HiveMotion.route<void>(
                            context,
                            (context) => _DemoPage(
                              title: 'Release checklist · run 42',
                              actionLabel: 'Back to runs',
                              onAction: () => _navigator.currentState!.pop(),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DemoPage extends StatelessWidget {
  const new({
    required this.title,
    required this.actionLabel,
    required this.onAction,
  });

  final String title;
  final String actionLabel;
  final VoidCallback onAction;

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: context.hiveColors.surface1,
      child: Padding(
        padding: EdgeInsets.all(context.hiveSpacing.space3),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: <Widget>[
            HivePageHeader(title: title),
            HiveButton(label: actionLabel, onPressed: onAction),
          ],
        ),
      ),
    );
  }
}
