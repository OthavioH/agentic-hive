import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/workflows/node_visuals.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:material_ui/material_ui.dart';

/// Categorized palette of workflow node types supporting click-to-insert and
/// drag-and-drop onto the workflow canvas.
class NodePalette extends StatelessWidget {
  /// Creates a [NodePalette].
  const new({required this.onInsertNode, super.key});

  /// Called when the user clicks a palette item to insert a node of `typeId`.
  final ValueChanged<String> onInsertNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;

    return Container(
      key: const Key('node_palette'),
      width: spacing.space8 * 4,
      decoration: BoxDecoration(
        color: colors.surface1,
        borderRadius: context.hiveRadii.panel,
        border: Border.all(
          color: colors.borderSubtle,
          width: elevation.hairline,
        ),
      ),
      padding: EdgeInsets.all(spacing.space3),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: <Widget>[
          Semantics(
            header: true,
            child: Text(
              l10n.editorPaletteTitle,
              style: typography.titleSmall.copyWith(color: colors.onSurface),
            ),
          ),
          SizedBox(height: spacing.spaceHalf),
          Text(
            l10n.editorPaletteHint,
            style: typography.bodySmall.copyWith(color: colors.onSurfaceMuted),
          ),
          SizedBox(height: spacing.space3),
          Expanded(
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: <Widget>[
                  for (final category in NodeCategory.values) ...<Widget>[
                    _CategorySection(
                      category: category,
                      descriptors: NodeDescriptors.all
                          .where((d) => d.category == category)
                          .toList(),
                      onInsertNode: onInsertNode,
                    ),
                    if (category != NodeCategory.values.last)
                      SizedBox(height: spacing.space3),
                  ],
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _CategorySection extends StatelessWidget {
  const new({
    required this.category,
    required this.descriptors,
    required this.onInsertNode,
  });

  final NodeCategory category;
  final List<NodeDescriptor> descriptors;
  final ValueChanged<String> onInsertNode;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;

    return Column(
      key: Key('palette_category_${category.name}'),
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        Text(
          resolveNodeCategoryLabel(l10n, category),
          style: typography.label.copyWith(color: colors.onSurfaceMuted),
        ),
        SizedBox(height: spacing.space1),
        for (var i = 0; i < descriptors.length; i++) ...<Widget>[
          _PaletteNodeItem(
            descriptor: descriptors[i],
            onTap: () => onInsertNode(descriptors[i].typeId),
          ),
          if (i < descriptors.length - 1) SizedBox(height: spacing.space1),
        ],
      ],
    );
  }
}

class _PaletteNodeItem extends StatelessWidget {
  const new({required this.descriptor, required this.onTap});

  final NodeDescriptor descriptor;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final elevation = context.hiveElevation;

    final scope = context.dependOnInheritedWidgetOfExactType<NodeVisualScope>();
    final visual = scope != null
        ? scope.registry.resolve(descriptor.typeId)
        : NodeVisual.fallback;
    final label = resolveNodeVisualLabel(l10n, visual.labelKey);
    final iconColor = visual.accent?.call(colors) ?? colors.onSurface;

    final card = HiveCard(
      key: Key('palette_item_${descriptor.typeId}'),
      surface: HiveCardSurface.surface2,
      semanticLabel: l10n.editorPaletteInsertSemantic(label),
      onPressed: onTap,
      child: Row(
        children: <Widget>[
          HiveIcon(visual.icon, size: spacing.space2, color: iconColor),
          SizedBox(width: spacing.space2),
          Expanded(
            child: Text(
              label,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.labelLarge.copyWith(color: colors.onSurface),
            ),
          ),
        ],
      ),
    );

    final feedback = DecoratedBox(
      decoration: BoxDecoration(
        color: colors.surface3,
        borderRadius: context.hiveRadii.card,
        border: Border.all(
          color: colors.accent,
          width: elevation.focusRingWidth,
        ),
        boxShadow: elevation.shadowMedium,
      ),
      child: Padding(
        padding: EdgeInsets.symmetric(
          horizontal: spacing.space3,
          vertical: spacing.space2,
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            HiveIcon(visual.icon, size: spacing.space2, color: iconColor),
            SizedBox(width: spacing.space2),
            Text(
              label,
              style: typography.labelLarge.copyWith(color: colors.onSurface),
            ),
          ],
        ),
      ),
    );

    return Draggable<String>(
      data: descriptor.typeId,
      feedback: feedback,
      childWhenDragging: Opacity(opacity: colors.disabledOpacity, child: card),
      child: card,
    );
  }
}
