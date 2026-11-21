import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// One kind of change counted by a [HiveDiffStat].
enum HiveDiffKind {
  /// Added files: `+` sign, `success` icon.
  added('+', 'added', HiveIcons.add, _success, _added),

  /// Modified files: `~` sign, `warning` icon.
  modified('~', 'modified', HiveIcons.edit, _warning, _modified),

  /// Deleted files: `-` sign, `danger` icon.
  deleted('-', 'deleted', HiveIcons.delete, _danger, _deleted);

  new(this.sign, this.word, this.icon, this.tone, this._count);

  /// The sign printed before the count.
  final String sign;

  /// The word used in the accessibility label, for example `added`.
  final String word;

  /// The leading icon of the segment.
  final HiveIconData icon;

  /// The feedback role that colors the icon (never the text).
  final HiveColorRole tone;

  final int Function(HiveDiffStat stat) _count;

  /// The count of this kind in [stat].
  int countIn(HiveDiffStat stat) => _count(stat);
}

int _added(HiveDiffStat s) => s.added;
int _modified(HiveDiffStat s) => s.modified;
int _deleted(HiveDiffStat s) => s.deleted;

Color _success(HiveColors c) => c.success;
Color _warning(HiveColors c) => c.warning;
Color _danger(HiveColors c) => c.danger;

/// A compact pill summarizing a change set as `+A ~M -D`.
///
/// Sits on `surface2` with `radiusPill`. Counts use Geist Mono in `onSurface`;
/// the feedback tones (`success`, `warning`, `danger`) color only the leading
/// icons, so the text keeps 4.5:1 contrast in both themes. A zero count is
/// shown in `onSurfaceMuted` so the non-zero kinds stand out.
class HiveDiffStat extends StatelessWidget {
  /// Creates a diff summary. Every count must be zero or more.
  const new({
    required this.added,
    required this.modified,
    required this.deleted,
    this.semanticLabel,
    super.key,
  }) : assert(added >= 0, 'added must not be negative'),
       assert(modified >= 0, 'modified must not be negative'),
       assert(deleted >= 0, 'deleted must not be negative');

  /// Number of added entries.
  final int added;

  /// Number of modified entries.
  final int modified;

  /// Number of deleted entries.
  final int deleted;

  /// Accessibility label; defaults to `A added, M modified, D deleted`.
  final String? semanticLabel;

  String get _defaultSemanticLabel => <String>[
    for (final kind in HiveDiffKind.values)
      '${kind.countIn(this)} ${kind.word}',
  ].join(', ');

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    return Semantics(
      label: semanticLabel ?? _defaultSemanticLabel,
      child: ExcludeSemantics(
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: colors.surface2,
            borderRadius: context.hiveRadii.pill,
          ),
          child: Padding(
            padding: EdgeInsets.symmetric(
              horizontal: spacing.space1,
              vertical: spacing.spaceHalf,
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: spacing.space1,
              children: <Widget>[
                for (final kind in HiveDiffKind.values)
                  _DiffSegment(kind: kind, count: kind.countIn(this)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _DiffSegment extends StatelessWidget {
  const new({required this.kind, required this.count});

  final HiveDiffKind kind;
  final int count;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final isZero = count == 0;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: spacing.spaceHalf,
      children: <Widget>[
        HiveIcon(
          kind.icon,
          size: spacing.space2,
          color: isZero ? colors.onSurfaceMuted : kind.tone(colors),
        ),
        Text(
          '${kind.sign}$count',
          maxLines: 1,
          style: context.hiveTypography.mono.copyWith(
            color: isZero ? colors.onSurfaceMuted : colors.onSurface,
          ),
        ),
      ],
    );
  }
}
