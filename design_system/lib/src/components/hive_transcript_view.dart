import 'dart:collection';

import 'package:design_system/src/components/hive_banner.dart';
import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/components/hive_chip.dart';
import 'package:design_system/src/components/hive_log_stream_viewer.dart';
import 'package:design_system/src/components/hive_markdown_view.dart';
import 'package:design_system/src/foundation/hive_feedback_tone.dart';
import 'package:design_system/src/foundation/hive_follow_bottom.dart';
import 'package:design_system/src/foundation/hive_interaction.dart';
import 'package:design_system/src/foundation/hive_log_line_row.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:material_ui/material_ui.dart';

/// Maximum number of lines shown before a block body is cut with a
/// "Show all" toggle.
const int hiveTranscriptCutLines = 200;

/// Localized labels required by [HiveTranscriptView].
@immutable
class HiveTranscriptLabels {
  /// Creates a set of labels for a transcript view.
  const new({
    required this.semanticLabel,
    required this.jumpToBottom,
    required this.thinking,
    required this.toolResult,
    required this.error,
    required this.stderr,
    required this.showLess,
    required this.showAll,
    this.emptyLabel,
  });

  /// Localized name of the transcript region, such as `Transcript`.
  final String semanticLabel;

  /// Localized label of the jump button, such as `Jump to bottom`.
  final String jumpToBottom;

  /// Title for thinking blocks, such as `Thinking`.
  final String thinking;

  /// Title for tool result blocks, such as `Tool result`.
  final String toolResult;

  /// Title for error banners, such as `Error`.
  final String error;

  /// Semantics prefix announced before `stderr` lines, such as `Error`.
  final String stderr;

  /// Button label to collapse a long block back to [hiveTranscriptCutLines].
  final String showLess;

  /// Builds the button label to expand a cut block, given its total line count.
  final String Function(int lines) showAll;

  /// Muted text shown while there are no entries.
  final String? emptyLabel;
}

/// A single metric chip displayed on a [HiveTranscriptFinalResult].
@immutable
class HiveTranscriptMetric {
  /// Creates a metric with a [label] and formatted [value].
  const new({required this.label, required this.value});

  /// Metric name, such as `Duration` or `Cost`.
  final String label;

  /// Formatted metric value, such as `12s` or `$0.04`.
  final String value;
}

/// One entry in a [HiveTranscriptView].
///
/// Each subclass draws itself via [_buildBlock]; the view never switches on
/// the block type.
@immutable
sealed class HiveTranscriptBlock {
  /// Creates a transcript block with a stable [id].
  const new({required this.id});

  /// Stable identifier used to update streamed blocks in place and preserve
  /// per-block UI state (expanded and show-all).
  final String id;

  Widget _buildBlock(BuildContext context, _BlockScope scope);
}

/// An agent Markdown message (always open).
final class HiveTranscriptMessage extends HiveTranscriptBlock {
  /// Creates a Markdown message block.
  const new({required super.id, required this.markdown});

  /// The Markdown source.
  final String markdown;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    return _CutText(
      text: markdown,
      showAll: scope.isShowAll(id),
      labels: scope.labels,
      onToggleShowAll: () => scope.toggleShowAll(id),
      builder: (context, visible) =>
          HiveMarkdownView(data: visible, selectable: false),
    );
  }
}

/// An agent thinking/reasoning block (collapsed by default).
final class HiveTranscriptThinking extends HiveTranscriptBlock {
  /// Creates a thinking block.
  const new({required super.id, required this.text});

  /// The thinking text.
  final String text;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    return _Disclosure(
      icon: HiveIcons.thinking,
      title: scope.labels.thinking,
      expanded: scope.isExpanded(id),
      onToggle: () => scope.toggleExpanded(id),
      body: _CutText(
        text: text,
        showAll: scope.isShowAll(id),
        labels: scope.labels,
        onToggleShowAll: () => scope.toggleShowAll(id),
        builder: (context, visible) => Text(
          visible,
          style: context.hiveTypography.body.copyWith(
            color: context.hiveColors.onSurfaceMuted,
          ),
        ),
      ),
    );
  }
}

/// A tool invocation block showing [name] and a one-line preview of [input]
/// in the header, expanding to the full mono [input].
final class HiveTranscriptToolCall extends HiveTranscriptBlock {
  /// Creates a tool call block.
  const new({required super.id, required this.name, required this.input});

  /// Tool name.
  final String name;

  /// Full tool input payload.
  final String input;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    final preview = _firstNonEmptyLine(input);
    return _Disclosure(
      icon: HiveIcons.tool,
      title: name,
      subtitle: preview,
      expanded: scope.isExpanded(id),
      onToggle: () => scope.toggleExpanded(id),
      body: _CutText(
        text: input,
        showAll: scope.isShowAll(id),
        labels: scope.labels,
        onToggleShowAll: () => scope.toggleShowAll(id),
        builder: (context, visible) => Text(
          visible,
          style: context.hiveTypography.mono.copyWith(
            color: context.hiveColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// Output returned by a tool call (collapsed by default, mono body).
final class HiveTranscriptToolResult extends HiveTranscriptBlock {
  /// Creates a tool result block.
  const new({required super.id, required this.text});

  /// The tool result text.
  final String text;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    return _Disclosure(
      title: scope.labels.toolResult,
      expanded: scope.isExpanded(id),
      onToggle: () => scope.toggleExpanded(id),
      body: _CutText(
        text: text,
        showAll: scope.isShowAll(id),
        labels: scope.labels,
        onToggleShowAll: () => scope.toggleShowAll(id),
        builder: (context, visible) => Text(
          visible,
          style: context.hiveTypography.mono.copyWith(
            color: context.hiveColors.onSurface,
          ),
        ),
      ),
    );
  }
}

/// An inline error block rendered as a compact danger [HiveBanner].
final class HiveTranscriptError extends HiveTranscriptBlock {
  /// Creates an error block.
  const new({required super.id, required this.message});

  /// Error message.
  final String message;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    return HiveBanner(
      tone: HiveFeedbackTone.danger,
      title: scope.labels.error,
      message: message,
      density: HiveBannerDensity.compact,
    );
  }
}

/// The terminal outcome of a run or turn, with optional metric chips.
final class HiveTranscriptFinalResult extends HiveTranscriptBlock {
  /// Creates a final result block.
  const new({
    required super.id,
    required this.statusLabel,
    required this.tone,
    this.metrics = const <HiveTranscriptMetric>[],
  });

  /// Human-readable status, such as `Succeeded` or `Failed`.
  final String statusLabel;

  /// Visual tone for the leading status icon.
  final HiveFeedbackTone tone;

  /// Optional metrics; no chips are rendered when empty.
  final List<HiveTranscriptMetric> metrics;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    return Container(
      padding: EdgeInsets.all(spacing.space2),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: context.hiveRadii.card,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          Row(
            children: <Widget>[
              HiveIcon(
                tone.icon,
                size: spacing.space2,
                color: tone.color(colors),
              ),
              SizedBox(width: spacing.space1),
              Expanded(
                child: Text(
                  statusLabel,
                  style: typography.labelLarge.copyWith(
                    color: colors.onSurface,
                  ),
                ),
              ),
            ],
          ),
          if (metrics.isNotEmpty) ...<Widget>[
            SizedBox(height: spacing.space1),
            Wrap(
              spacing: spacing.space1,
              runSpacing: spacing.space1,
              children: <Widget>[
                for (final metric in metrics)
                  HiveChip.readOnly(label: '${metric.label}: ${metric.value}'),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

/// Plain text output (stdout or stderr), rendered line by line in mono with
/// the `stderr` gutter marker when [stream] is [HiveLogStream.stderr].
final class HiveTranscriptPlainText extends HiveTranscriptBlock {
  /// Creates a plain text block.
  const new({
    required super.id,
    required this.text,
    this.stream = HiveLogStream.stdout,
  });

  /// Output text (may span multiple lines).
  final String text;

  /// Output stream (`stdout` or `stderr`).
  final HiveLogStream stream;

  @override
  Widget _buildBlock(BuildContext context, _BlockScope scope) {
    final isStderr = stream == HiveLogStream.stderr;
    return _CutText(
      text: text,
      showAll: scope.isShowAll(id),
      labels: scope.labels,
      onToggleShowAll: () => scope.toggleShowAll(id),
      builder: (context, visible) {
        final lines = visible.split('\n');
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            for (final line in lines)
              HiveLogLineRow(
                text: line,
                isStderr: isStderr,
                stderrSemanticLabel: scope.labels.stderr,
              ),
          ],
        );
      },
    );
  }
}

/// Holds the ordered [HiveTranscriptBlock]s of a [HiveTranscriptView] and
/// supports in-place updates by block id.
class HiveTranscriptController extends ChangeNotifier {
  /// Creates a controller, optionally seeded with [initialBlocks].
  new({
    Iterable<HiveTranscriptBlock> initialBlocks = const <HiveTranscriptBlock>[],
  }) {
    initialBlocks.forEach(_upsertOne);
  }

  final List<HiveTranscriptBlock> _blocks = <HiveTranscriptBlock>[];
  final Map<String, int> _indexById = <String, int>{};

  /// The current blocks in display order.
  UnmodifiableListView<HiveTranscriptBlock> get blocks =>
      UnmodifiableListView<HiveTranscriptBlock>(_blocks);

  /// Number of blocks.
  int get length => _blocks.length;

  /// Whether there are no blocks.
  bool get isEmpty => _blocks.isEmpty;

  /// Replaces the existing block with the same `id` in place, or appends it.
  void upsert(HiveTranscriptBlock block) {
    _upsertOne(block);
    notifyListeners();
  }

  /// Upserts all [blocks] and notifies listeners once.
  void upsertAll(Iterable<HiveTranscriptBlock> blocks) {
    blocks.forEach(_upsertOne);
    notifyListeners();
  }

  /// Removes every block.
  void clear() {
    _blocks.clear();
    _indexById.clear();
    notifyListeners();
  }

  void _upsertOne(HiveTranscriptBlock block) {
    final existing = _indexById[block.id];
    if (existing != null) {
      _blocks[existing] = block;
    } else {
      _indexById[block.id] = _blocks.length;
      _blocks.add(block);
    }
  }
}

/// A lazy, auto-following transcript of [HiveTranscriptBlock]s.
///
/// Sits on `surface1` with a hairline border and `radiusCard`, and fills its
/// parent, which must give it bounded constraints.
class HiveTranscriptView extends StatefulWidget {
  /// Creates a transcript view driven by [controller].
  const new({required this.controller, required this.labels, super.key});

  /// The blocks to display; the view rebuilds when it changes.
  final HiveTranscriptController controller;

  /// Localized labels for headers, buttons, and semantics.
  final HiveTranscriptLabels labels;

  @override
  State<HiveTranscriptView> createState() => HiveTranscriptViewState();
}

/// State of a [HiveTranscriptView]; exposes [isFollowing] and [jumpToBottom].
class HiveTranscriptViewState extends State<HiveTranscriptView>
    with HiveFollowBottomMixin<HiveTranscriptView> {
  final Set<String> _expanded = <String>{};
  final Set<String> _showAll = <String>{};

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(onFollowContentChanged);
    initFollowBottom();
  }

  @override
  void didUpdateWidget(HiveTranscriptView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(onFollowContentChanged);
      widget.controller.addListener(onFollowContentChanged);
      onFollowContentChanged();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(onFollowContentChanged);
    disposeFollowBottom();
    super.dispose();
  }

  void _toggleExpanded(String id) {
    setState(() {
      if (!_expanded.add(id)) {
        _expanded.remove(id);
      }
    });
  }

  /// Sets the expanded state of the block with [id].
  void setBlockExpanded(String id, {required bool expanded}) {
    setState(() {
      if (expanded) {
        _expanded.add(id);
      } else {
        _expanded.remove(id);
      }
    });
  }

  void _toggleShowAll(String id) {
    setState(() {
      if (!_showAll.add(id)) {
        _showAll.remove(id);
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final hairline = context.hiveElevation.hairline;
    final blocks = widget.controller.blocks;
    final emptyLabel = widget.labels.emptyLabel;

    final scope = _BlockScope(
      labels: widget.labels,
      isExpanded: _expanded.contains,
      toggleExpanded: _toggleExpanded,
      isShowAll: _showAll.contains,
      toggleShowAll: _toggleShowAll,
    );

    final Widget body;
    if (blocks.isEmpty) {
      body = Padding(
        padding: EdgeInsets.all(spacing.space2),
        child: Text(
          emptyLabel ?? '',
          style: context.hiveTypography.body.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
      );
    } else {
      body = Scrollbar(
        controller: followScrollController,
        child: SelectionArea(
          child: ListView.builder(
            controller: followScrollController,
            padding: EdgeInsets.all(spacing.space2),
            itemCount: blocks.length,
            itemBuilder: (context, index) {
              final block = blocks[index];
              final built = block._buildBlock(context, scope);
              return Padding(
                key: ValueKey<String>(block.id),
                padding: EdgeInsets.only(top: index == 0 ? 0 : spacing.space1),
                child: built,
              );
            },
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.labels.semanticLabel,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: context.hiveRadii.card,
          border: Border.all(color: colors.borderSubtle, width: hairline),
        ),
        child: ClipRRect(
          borderRadius: context.hiveRadii.card,
          child: Stack(
            children: <Widget>[
              Positioned.fill(child: body),
              if (!isFollowing && blocks.isNotEmpty)
                buildJumpToBottomButton(widget.labels.jumpToBottom),
            ],
          ),
        ),
      ),
    );
  }
}

class _BlockScope {
  const new({
    required this.labels,
    required this.isExpanded,
    required this.toggleExpanded,
    required this.isShowAll,
    required this.toggleShowAll,
  });

  final HiveTranscriptLabels labels;
  final bool Function(String id) isExpanded;
  final ValueChanged<String> toggleExpanded;
  final bool Function(String id) isShowAll;
  final ValueChanged<String> toggleShowAll;
}

class _Disclosure extends StatelessWidget {
  const new({
    required this.title,
    required this.expanded,
    required this.onToggle,
    required this.body,
    this.icon,
    this.subtitle,
  });

  final HiveIconData? icon;
  final String title;
  final String? subtitle;
  final bool expanded;
  final VoidCallback onToggle;
  final Widget body;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final typography = context.hiveTypography;
    final motion = context.hiveMotion;
    final radius = context.hiveRadii.card;
    final leading = icon;
    final preview = subtitle;

    final header = HiveInteraction(
      semanticLabel: title,
      expanded: expanded,
      onPressed: onToggle,
      builder: (context, states) => HiveFocusRing(
        focused: states.contains(WidgetState.focused),
        shape: RoundedRectangleBorder(borderRadius: radius),
        child: AnimatedContainer(
          duration: motion.resolve(context, motion.short),
          curve: motion.standardCurve,
          padding: EdgeInsets.all(spacing.space2),
          decoration: BoxDecoration(
            borderRadius: radius,
            color: hiveStateLayer(
              base: colors.surface1.withValues(alpha: 0),
              foreground: colors.onSurface,
              states: states,
              colors: colors,
            ),
          ),
          child: Row(
            children: <Widget>[
              if (leading != null) ...<Widget>[
                HiveIcon(
                  leading,
                  size: spacing.space2,
                  color: colors.onSurfaceMuted,
                ),
                SizedBox(width: spacing.space1),
              ],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    _EllipsisTooltip(
                      message: title,
                      child: Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: typography.labelLarge.copyWith(
                          color: colors.onSurface,
                        ),
                      ),
                    ),
                    if (preview != null)
                      _EllipsisTooltip(
                        message: preview,
                        child: Text(
                          preview,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: typography.bodySmall.copyWith(
                            color: colors.onSurfaceMuted,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              SizedBox(width: spacing.space1),
              AnimatedRotation(
                turns: expanded ? 0.5 : 0,
                duration: motion.resolve(context, motion.medium),
                curve: motion.standardCurve,
                child: HiveIcon(
                  HiveIcons.chevronDown,
                  size: spacing.space2,
                  color: colors.onSurfaceMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: radius,
        border: Border.all(
          color: colors.borderSubtle,
          width: context.hiveElevation.hairline,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          header,
          if (expanded)
            Padding(
              padding: EdgeInsets.fromLTRB(
                spacing.space2,
                0,
                spacing.space2,
                spacing.space2,
              ),
              child: body,
            ),
        ],
      ),
    );
  }
}

class _EllipsisTooltip extends StatelessWidget {
  const new({required this.message, required this.child});

  final String message;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final motion = context.hiveMotion;
    final typography = context.hiveTypography;
    return Tooltip(
      message: message,
      excludeFromSemantics: true,
      waitDuration: motion.resolve(context, motion.long),
      exitDuration: motion.resolve(context, motion.short),
      padding: EdgeInsets.symmetric(
        horizontal: spacing.space1,
        vertical: spacing.spaceHalf,
      ),
      decoration: ShapeDecoration(
        color: colors.surface3,
        shape: StadiumBorder(
          side: BorderSide(
            color: colors.borderSubtle,
            width: context.hiveElevation.hairline,
          ),
        ),
      ),
      textStyle: typography.bodySmall.copyWith(color: colors.onSurface),
      child: child,
    );
  }
}

class _CutText extends StatelessWidget {
  const new({
    required this.text,
    required this.showAll,
    required this.labels,
    required this.onToggleShowAll,
    required this.builder,
  });

  final String text;
  final bool showAll;
  final HiveTranscriptLabels labels;
  final VoidCallback onToggleShowAll;
  final Widget Function(BuildContext context, String visibleText) builder;

  @override
  Widget build(BuildContext context) {
    final lines = text.split('\n');
    if (lines.length <= hiveTranscriptCutLines) {
      return builder(context, text);
    }
    final visible = showAll
        ? text
        : lines.take(hiveTranscriptCutLines).join('\n');
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: <Widget>[
        builder(context, visible),
        SizedBox(height: context.hiveSpacing.space1),
        HiveButton(
          label: showAll ? labels.showLess : labels.showAll(lines.length),
          variant: HiveButtonVariant.ghost,
          size: HiveButtonSize.small,
          onPressed: onToggleShowAll,
        ),
      ],
    );
  }
}

String? _firstNonEmptyLine(String text) {
  for (final line in text.split('\n')) {
    final trimmed = line.trim();
    if (trimmed.isNotEmpty) return trimmed;
  }
  return null;
}
