import 'dart:collection';

import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// The output stream a [HiveLogLine] came from.
enum HiveLogStream {
  /// Standard output: `onSurface` text.
  stdout,

  /// Standard error: `danger` text plus a `danger` marker in the gutter, so
  /// the stream never depends on color alone.
  stderr,
}

/// One line of harness output shown by a [HiveLogStreamViewer].
@immutable
class HiveLogLine {
  /// Creates a line of [text] from [stream].
  const new(this.text, {this.stream = HiveLogStream.stdout});

  /// The line text, without its line terminator.
  final String text;

  /// The stream the line came from.
  final HiveLogStream stream;

  @override
  bool operator ==(Object other) =>
      other is HiveLogLine && other.text == text && other.stream == stream;

  @override
  int get hashCode => Object.hash(text, stream);

  @override
  String toString() => 'HiveLogLine(${stream.name}: $text)';
}

/// Holds the lines of a [HiveLogStreamViewer] and accepts output chunks as
/// they arrive.
///
/// [append] takes raw chunks that may end mid-line: the unterminated tail
/// stays open and the next chunk from the same stream continues it. A chunk
/// from the other stream closes it. `\r\n` is treated as `\n`.
class HiveLogStreamController extends ChangeNotifier {
  /// Creates a controller, optionally seeded with [initialLines].
  ///
  /// When [maxLines] is set, the oldest lines are dropped beyond it.
  new({
    Iterable<HiveLogLine> initialLines = const <HiveLogLine>[],
    this.maxLines,
  }) : assert(maxLines == null || maxLines > 0, 'maxLines must be > 0.') {
    _lines.addAll(initialLines);
    _trim();
  }

  /// The most lines kept; null keeps every line.
  final int? maxLines;

  final List<HiveLogLine> _lines = <HiveLogLine>[];

  /// The stream whose last line has no terminator yet, if any.
  HiveLogStream? _openStream;

  /// The current lines, oldest first.
  UnmodifiableListView<HiveLogLine> get lines =>
      UnmodifiableListView<HiveLogLine>(_lines);

  /// Number of lines.
  int get length => _lines.length;

  /// Whether there are no lines.
  bool get isEmpty => _lines.isEmpty;

  /// Appends a raw output [chunk] from [stream].
  void append(String chunk, {HiveLogStream stream = HiveLogStream.stdout}) {
    if (chunk.isEmpty) return;
    final parts = chunk.replaceAll('\r\n', '\n').split('\n');
    final endsLine = parts.last.isEmpty;
    if (endsLine) parts.removeLast();

    var first = 0;
    if (_openStream == stream && _lines.isNotEmpty && parts.isNotEmpty) {
      final open = _lines.removeLast();
      _lines.add(HiveLogLine(open.text + parts.first, stream: stream));
      first = 1;
    }
    for (var i = first; i < parts.length; i++) {
      _lines.add(HiveLogLine(parts[i], stream: stream));
    }
    _openStream = endsLine ? null : stream;
    _trim();
    notifyListeners();
  }

  /// Appends whole [lines] (each one already terminated).
  void appendLines(Iterable<HiveLogLine> lines) {
    _lines.addAll(lines);
    _openStream = null;
    _trim();
    notifyListeners();
  }

  /// Removes every line.
  void clear() {
    _lines.clear();
    _openStream = null;
    notifyListeners();
  }

  void _trim() {
    final max = maxLines;
    if (max != null && _lines.length > max) {
      _lines.removeRange(0, _lines.length - max);
    }
  }
}

/// A live log viewer for harness output.
///
/// It sits on `surface1` with a hairline border and `radiusCard`; lines use
/// the `mono` role (Geist Mono) and wrap. `stderr` lines are drawn in
/// `danger` (4.5:1 on `surface1` in both themes) with a `danger` gutter
/// marker, so the stream is told apart by shape as well as color.
///
/// While the view is at the bottom it follows new lines. Scrolling up pauses
/// following and shows a **Jump to bottom** button ([jumpToBottomLabel]),
/// which scrolls back and resumes following; scrolling back to the bottom by
/// hand resumes it too.
///
/// The viewer fills its parent, which must give it a bounded height.
class HiveLogStreamViewer extends StatefulWidget {
  /// Creates a viewer showing [controller]'s lines.
  const new({
    required this.controller,
    required this.semanticLabel,
    required this.jumpToBottomLabel,
    required this.stderrSemanticLabel,
    this.emptyLabel,
    super.key,
  });

  /// The lines to show; the viewer rebuilds when it changes.
  final HiveLogStreamController controller;

  /// Localized name of the log region, such as `Harness output`.
  final String semanticLabel;

  /// Localized label of the jump button, such as `Jump to bottom`.
  final String jumpToBottomLabel;

  /// Localized prefix announced before `stderr` lines, such as `Error`.
  final String stderrSemanticLabel;

  /// Muted text shown while there are no lines, such as `No output yet`.
  final String? emptyLabel;

  @override
  State<HiveLogStreamViewer> createState() => HiveLogStreamViewerState();
}

/// State of a [HiveLogStreamViewer]; exposes whether it follows new lines.
class HiveLogStreamViewerState extends State<HiveLogStreamViewer> {
  final ScrollController _scroll = ScrollController();
  bool _following = true;
  bool _scrollScheduled = false;

  /// Whether the viewer is pinned to the bottom and follows new lines.
  bool get isFollowing => _following;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_onLines);
    _scroll.addListener(_onScroll);
    _scheduleScrollToEnd();
  }

  @override
  void didUpdateWidget(HiveLogStreamViewer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller.removeListener(_onLines);
      widget.controller.addListener(_onLines);
      _onLines();
    }
  }

  @override
  void dispose() {
    widget.controller.removeListener(_onLines);
    _scroll.dispose();
    super.dispose();
  }

  void _onLines() {
    setState(() {});
    if (_following) _scheduleScrollToEnd();
  }

  /// Follows again only once the user is back within `space1` of the end.
  void _onScroll() {
    if (!_scroll.hasClients) return;
    final position = _scroll.position;
    final atEnd =
        position.pixels >=
        position.maxScrollExtent - context.hiveSpacing.space1;
    if (atEnd != _following) setState(() => _following = atEnd);
  }

  void _scheduleScrollToEnd() {
    if (_scrollScheduled) return;
    _scrollScheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scrollScheduled = false;
      _scrollToEnd(attemptsLeft: 3);
    });
  }

  /// Jumps to the end. Lazily built lines only estimate the scroll extent,
  /// so the jump repeats after layout until the extent settles.
  void _scrollToEnd({required int attemptsLeft}) {
    if (!mounted || !_following || !_scroll.hasClients) return;
    final position = _scroll.position;
    if (position.pixels == position.maxScrollExtent) return;
    position.jumpTo(position.maxScrollExtent);
    if (attemptsLeft > 1) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _scrollToEnd(attemptsLeft: attemptsLeft - 1),
      );
    }
  }

  /// Scrolls to the newest line and resumes following.
  void jumpToBottom() {
    setState(() => _following = true);
    _scrollToEnd(attemptsLeft: 3);
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final hairline = context.hiveElevation.hairline;
    final lines = widget.controller.lines;
    final emptyLabel = widget.emptyLabel;

    final Widget body;
    if (lines.isEmpty) {
      body = Padding(
        padding: EdgeInsets.all(spacing.space2),
        child: Text(
          emptyLabel ?? '',
          style: context.hiveTypography.mono.copyWith(
            color: colors.onSurfaceMuted,
          ),
        ),
      );
    } else {
      body = Scrollbar(
        controller: _scroll,
        child: SelectionArea(
          child: ListView.builder(
            controller: _scroll,
            padding: EdgeInsets.symmetric(vertical: spacing.space1),
            itemCount: lines.length,
            itemBuilder: (context, index) => _LogLineRow(
              line: lines[index],
              stderrSemanticLabel: widget.stderrSemanticLabel,
            ),
          ),
        ),
      );
    }

    return Semantics(
      container: true,
      explicitChildNodes: true,
      label: widget.semanticLabel,
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
              if (!_following && lines.isNotEmpty)
                PositionedDirectional(
                  end: spacing.space2,
                  bottom: spacing.space2,
                  child: HiveButton(
                    label: widget.jumpToBottomLabel,
                    icon: HiveIcons.scrollToBottom,
                    variant: HiveButtonVariant.secondary,
                    size: HiveButtonSize.small,
                    onPressed: jumpToBottom,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _LogLineRow extends StatelessWidget {
  const new({required this.line, required this.stderrSemanticLabel});

  final HiveLogLine line;
  final String stderrSemanticLabel;

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final isStderr = line.stream == HiveLogStream.stderr;
    return Padding(
      padding: EdgeInsetsDirectional.only(end: spacing.space2),
      child: IntrinsicHeight(
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: <Widget>[
            // Gutter: `space2` wide, with a `spaceHalf` danger bar for
            // stderr so the stream reads by shape, not only by color.
            SizedBox(
              width: spacing.space2,
              child: isStderr
                  ? Align(
                      alignment: AlignmentDirectional.centerEnd,
                      child: Padding(
                        padding: EdgeInsetsDirectional.only(
                          end: spacing.spaceHalf,
                        ),
                        child: SizedBox(
                          width: spacing.spaceHalf,
                          child: DecoratedBox(
                            key: const ValueKey<String>('stderr-marker'),
                            decoration: BoxDecoration(
                              color: colors.danger,
                              borderRadius: context.hiveRadii.pill,
                            ),
                            child: const SizedBox.expand(),
                          ),
                        ),
                      ),
                    )
                  : null,
            ),
            Expanded(
              child: Text(
                line.text,
                semanticsLabel: isStderr
                    ? '$stderrSemanticLabel: ${line.text}'
                    : null,
                style: context.hiveTypography.mono.copyWith(
                  color: isStderr ? colors.danger : colors.onSurface,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
