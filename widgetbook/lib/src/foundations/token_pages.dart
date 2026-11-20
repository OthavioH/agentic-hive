import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';

String _hex(Color color) {
  final argb = color.toARGB32().toRadixString(16).padLeft(8, '0');
  return '#${argb.substring(2).toUpperCase()}';
}

/// Every color role of the current theme, plus every WCAG AA pair.
class ColorRolesPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final c = context.hiveColors;
    final pairs = <String, (Color, Color)>{
      'background / onSurface': (c.background, c.onSurface),
      'surface1 / onSurface': (c.surface1, c.onSurface),
      'surface2 / onSurface': (c.surface2, c.onSurface),
      'surface3 / onSurfaceMuted': (c.surface3, c.onSurfaceMuted),
      'accent / onAccent': (c.accent, c.onAccent),
      'accentMuted / onAccentMuted': (c.accentMuted, c.onAccentMuted),
      'success / onSuccess': (c.success, c.onSuccess),
      'warning / onWarning': (c.warning, c.onWarning),
      'danger / onDanger': (c.danger, c.onDanger),
      'info / onInfo': (c.info, c.onInfo),
    };
    final singles = <String, Color>{
      'borderSubtle': c.borderSubtle,
      'focusRing': c.focusRing,
      'statusIdle': c.statusIdle,
      'statusRunning': c.statusRunning,
      'statusPaused': c.statusPaused,
      'statusFailed': c.statusFailed,
      'statusSucceeded': c.statusSucceeded,
    };
    final contrast = c.contrastPairs;
    final failing = contrast.where((p) => !p.passes).length;
    return ShowcasePage(
      title: 'Color roles',
      subtitle:
          '${c.brightness.name} theme · ${contrast.length} WCAG AA pairs, '
          '$failing failing',
      children: <Widget>[
        ShowcaseSection(
          title: 'Background and foreground pairs',
          children: <Widget>[
            for (final e in pairs.entries)
              _PairSwatch(
                name: e.key,
                background: e.value.$1,
                foreground: e.value.$2,
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Structure and status roles',
          description:
              'Ratios are against surface1. Status and focus are UI '
              'components (3:1); borderSubtle is decorative.',
          children: <Widget>[
            for (final e in singles.entries)
              _SingleSwatch(name: e.key, color: e.value, against: c.surface1),
          ],
        ),
        ShowcaseSection(
          title: 'Categorical chart palette',
          children: <Widget>[
            for (var i = 0; i < c.chart.length; i++)
              _SingleSwatch(
                name: 'chart[$i]',
                color: c.chart[i],
                against: c.surface1,
              ),
          ],
        ),
        ShowcaseSection(
          title: 'Every tested pair',
          description:
              'Text pairs need 4.5:1; UI pairs need 3:1 (WCAG 2.x AA).',
          children: <Widget>[
            for (final pair in contrast) _ContrastRow(pair: pair),
          ],
        ),
      ],
    );
  }
}

class _PairSwatch extends StatelessWidget {
  const new({
    required this.name,
    required this.background,
    required this.foreground,
  });

  final String name;
  final Color background;
  final Color foreground;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final ratio = HiveContrast.ratio(foreground, background);
    return Container(
      width: spacing.space8 * 3,
      padding: EdgeInsets.all(spacing.space2),
      decoration: BoxDecoration(
        color: background,
        borderRadius: context.hiveRadii.card,
        border: Border.all(
          color: context.hiveColors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text(name, style: typography.label.copyWith(color: foreground)),
          SizedBox(height: spacing.space1),
          Text(
            '${ratio.toStringAsFixed(2)}:1',
            style: typography.display.copyWith(color: foreground),
          ),
          Text(
            '${_hex(background)} / ${_hex(foreground)}',
            style: typography.mono.copyWith(color: foreground),
          ),
        ],
      ),
    );
  }
}

class _SingleSwatch extends StatelessWidget {
  const new({required this.name, required this.color, required this.against});

  final String name;
  final Color color;
  final Color against;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    return SizedBox(
      width: spacing.space8 * 2,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Container(
            height: spacing.space6,
            decoration: BoxDecoration(
              color: color,
              borderRadius: context.hiveRadii.pill,
              border: Border.all(
                color: colors.borderSubtle,
                width: context.hiveElevation.hairline,
              ),
            ),
          ),
          SizedBox(height: spacing.space1),
          Text(name, style: typography.label.copyWith(color: colors.onSurface)),
          Text(
            '${_hex(color)} · '
            '${HiveContrast.ratio(color, against).toStringAsFixed(2)}:1',
            style: typography.mono.copyWith(color: colors.onSurfaceMuted),
          ),
        ],
      ),
    );
  }
}

class _ContrastRow extends StatelessWidget {
  const new({required this.pair});

  final HiveContrastPair pair;

  @override
  Widget build(BuildContext context) {
    final spacing = context.hiveSpacing;
    return SizedBox(
      width: spacing.space8 * 5,
      child: Row(
        children: <Widget>[
          Container(
            width: spacing.space5,
            height: spacing.space5,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: pair.background,
              shape: BoxShape.circle,
              border: Border.all(
                color: context.hiveColors.borderSubtle,
                width: context.hiveElevation.hairline,
              ),
            ),
            child: Text(
              'Aa',
              style: context.hiveTypography.label.copyWith(
                color: pair.foreground,
              ),
            ),
          ),
          SizedBox(width: spacing.space1),
          Expanded(
            child: Text(
              '${pair.foregroundRole} on ${pair.backgroundRole}',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: context.hiveTypography.mono.copyWith(
                color: context.hiveColors.onSurface,
              ),
            ),
          ),
          HiveBadge(
            label:
                '${pair.ratio.toStringAsFixed(2)}:1 '
                '${pair.passes ? 'AA' : 'FAIL'} ${pair.level.name}',
            tone: pair.passes ? HiveBadgeTone.success : HiveBadgeTone.danger,
          ),
        ],
      ),
    );
  }
}

/// Every typography role with its family and metrics.
class TypeScalePage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  static const Map<String, String> _samples = <String, String>{
    'number': '1,284',
    'display': 'Active runs',
    'title': 'Workflows',
    'titleSmall': 'Release checklist',
    'body': 'Runs continue when the window closes; the backend owns them.',
    'bodySmall': 'Last run finished 4 minutes ago',
    'labelLarge': 'Run workflow',
    'label': 'RUNNING',
    'mono': r'$ claude -p --output-format stream-json < prompt.md',
  };

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return ShowcasePage(
      title: 'Type scale',
      subtitle:
          'Bricolage Grotesque for display and numbers, Geist for UI, '
          'Geist Mono for logs. Sizes and line heights on the 4/8 rhythm.',
      children: <Widget>[
        for (final e in context.hiveTypography.roles.entries)
          Padding(
            padding: EdgeInsets.only(bottom: spacing.space1),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: <Widget>[
                SizedBox(
                  width: spacing.space8 * 3,
                  child: Text(
                    '${e.key}\n${e.value.fontFamily} '
                    '${e.value.fontSize!.toInt()}/'
                    '${(e.value.fontSize! * e.value.height!).round()} '
                    'w${e.value.fontWeight!.value}',
                    style: context.hiveTypography.mono.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
                Expanded(
                  child: Text(
                    _samples[e.key] ?? e.key,
                    style: e.value.copyWith(color: colors.onSurface),
                  ),
                ),
              ],
            ),
          ),
      ],
    );
  }
}

/// The spacing scale as bars.
class SpacingPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return ShowcasePage(
      title: 'Spacing',
      subtitle:
          '8-point scale; spaceHalf only for tight gaps inside small '
          'controls.',
      children: <Widget>[
        for (final e in spacing.steps.entries)
          Row(
            children: <Widget>[
              SizedBox(
                width: spacing.space8 * 2,
                child: Text(
                  '${e.key} · ${e.value.toInt()}',
                  style: context.hiveTypography.mono.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
              Container(
                width: e.value,
                height: spacing.space3,
                decoration: BoxDecoration(
                  color: colors.accentMuted,
                  borderRadius: context.hiveRadii.pill,
                ),
              ),
            ],
          ),
      ],
    );
  }
}

/// The radius roles.
class RadiusPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final radii = context.hiveRadii;
    final uses = <String, String>{
      'radiusPill': 'buttons, inputs, chips, badges, nav items, avatars',
      'radiusCard': 'cards',
      'radiusPanel': 'large containers, dialogs, the side rail',
    };
    return ShowcasePage(
      title: 'Radius',
      subtitle: 'One radius per role; never mixed within a role.',
      children: <Widget>[
        ShowcaseSection(
          title: 'Roles',
          children: <Widget>[
            for (final e in radii.roles.entries)
              Labeled(
                label: '${e.key} · ${e.value.toInt()}\n${uses[e.key]}',
                child: Container(
                  width: spacing.space8 * 3,
                  height: spacing.space8 * 2,
                  decoration: BoxDecoration(
                    color: colors.surface2,
                    borderRadius: BorderRadius.circular(e.value),
                    border: Border.all(
                      color: colors.borderSubtle,
                      width: context.hiveElevation.hairline,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ],
    );
  }
}

/// Surface steps, hairlines and the two shadow tokens.
class ElevationPage extends StatelessWidget {
  /// Creates the page.
  const new({super.key});

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final elevation = context.hiveElevation;
    Widget box(String label, Color color, List<BoxShadow> shadows) {
      return Labeled(
        label: label,
        child: Container(
          width: spacing.space8 * 2,
          height: spacing.space8 * 2,
          decoration: BoxDecoration(
            color: color,
            borderRadius: context.hiveRadii.card,
            boxShadow: shadows,
            border: Border.all(
              color: colors.borderSubtle,
              width: elevation.hairline,
            ),
          ),
        ),
      );
    }

    return ShowcasePage(
      title: 'Elevation',
      subtitle:
          'Surface steps plus 1px hairlines; at most two small layered '
          'shadows.',
      children: <Widget>[
        ShowcaseSection(
          title: 'Surface steps',
          children: <Widget>[
            for (final e in colors.surfaces.entries)
              box(e.key, e.value, const <BoxShadow>[]),
          ],
        ),
        ShowcaseSection(
          title: 'Shadow tokens',
          children: <Widget>[
            box('shadowSmall', colors.surface2, elevation.shadowSmall),
            box('shadowMedium', colors.surface2, elevation.shadowMedium),
          ],
        ),
      ],
    );
  }
}
