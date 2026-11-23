import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_spacing.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:design_system/src/tokens/hive_typography.dart';
import 'package:flutter/gestures.dart';
import 'package:markdown/markdown.dart' as md;
import 'package:material_ui/material_ui.dart';

/// Renders GitHub-flavored Markdown with design-system tokens only.
///
/// Headings use `title`, `titleSmall` and `labelLarge`; paragraphs and list
/// items `body` in `onSurface`; inline and fenced code Geist Mono on
/// `surface3` / `surface2` (`radiusCard` blocks); quotes an `onSurfaceMuted`
/// text with a `borderSubtle` bar; rules and tables `borderSubtle`
/// hairlines. Links are underlined, show a click cursor and call
/// [onTapLink]; nothing is opened by the design system. Raw HTML is shown as
/// text, never interpreted.
///
/// The view lays out its blocks in a [Column]; put it in a scroll view for
/// long documents.
class HiveMarkdownView extends StatefulWidget {
  /// Creates a Markdown view of [data].
  const new({
    required this.data,
    this.onTapLink,
    this.selectable = true,
    super.key,
  });

  /// The Markdown source.
  final String data;

  /// Called with the link target when a link is activated.
  final ValueChanged<String>? onTapLink;

  /// Whether the text can be selected and copied.
  final bool selectable;

  @override
  State<HiveMarkdownView> createState() => _HiveMarkdownViewState();
}

class _HiveMarkdownViewState extends State<HiveMarkdownView> {
  final List<TapGestureRecognizer> _recognizers = <TapGestureRecognizer>[];
  List<md.Node> _nodes = const <md.Node>[];
  List<Widget> _blocks = const <Widget>[];

  @override
  void initState() {
    super.initState();
    _nodes = _parse(widget.data);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _render();
  }

  @override
  void didUpdateWidget(HiveMarkdownView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.data != widget.data) _nodes = _parse(widget.data);
    if (oldWidget.data != widget.data ||
        oldWidget.onTapLink != widget.onTapLink) {
      _render();
    }
  }

  @override
  void dispose() {
    _disposeRecognizers();
    super.dispose();
  }

  static List<md.Node> _parse(String data) {
    final document = md.Document(
      extensionSet: md.ExtensionSet.gitHubFlavored,
      encodeHtml: false,
    );
    return document.parseLines(data.replaceAll('\r\n', '\n').split('\n'));
  }

  void _disposeRecognizers() {
    for (final recognizer in _recognizers) {
      recognizer.dispose();
    }
    _recognizers.clear();
  }

  void _render() {
    _disposeRecognizers();
    _blocks = _MarkdownRenderer(
      colors: context.hiveColors,
      spacing: context.hiveSpacing,
      typography: context.hiveTypography,
      cardRadius: context.hiveRadii.card,
      hairline: context.hiveElevation.hairline,
      onTapLink: widget.onTapLink,
      recognizers: _recognizers,
    ).blocks(_nodes);
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: _blocks,
    );
    return widget.selectable ? SelectionArea(child: content) : content;
  }
}

const Set<String> _blockTags = <String>{
  'p',
  'h1',
  'h2',
  'h3',
  'h4',
  'h5',
  'h6',
  'ul',
  'ol',
  'li',
  'blockquote',
  'pre',
  'hr',
  'table',
};

class _MarkdownRenderer {
  new({
    required this.colors,
    required this.spacing,
    required this.typography,
    required this.cardRadius,
    required this.hairline,
    required this.onTapLink,
    required this.recognizers,
  });

  final HiveColors colors;
  final HiveSpacing spacing;
  final HiveTypography typography;
  final BorderRadius cardRadius;
  final double hairline;
  final ValueChanged<String>? onTapLink;
  final List<TapGestureRecognizer> recognizers;

  TextStyle get _body => typography.body.copyWith(color: colors.onSurface);

  List<Widget> blocks(List<md.Node> nodes, {double? gap}) {
    final widgets = <Widget>[];
    final inlineRun = <md.Node>[];
    void flushInline() {
      if (inlineRun.isEmpty) return;
      final run = List<md.Node>.of(inlineRun);
      inlineRun.clear();
      if (run.every((n) => n is md.Text && n.text.trim().isEmpty)) return;
      widgets.add(_paragraph(run, _body));
    }

    for (final node in nodes) {
      if (node is md.Element && _blockTags.contains(node.tag)) {
        flushInline();
        widgets.add(_block(node));
      } else {
        inlineRun.add(node);
      }
    }
    flushInline();
    final between = gap ?? spacing.space2;
    return <Widget>[
      for (var i = 0; i < widgets.length; i++) ...<Widget>[
        if (i > 0) SizedBox(height: between),
        widgets[i],
      ],
    ];
  }

  Widget _block(md.Element element) {
    final children = element.children ?? const <md.Node>[];
    switch (element.tag) {
      case 'h1':
        return _heading(children, typography.title);
      case 'h2':
        return _heading(children, typography.titleSmall);
      case 'h3' || 'h4' || 'h5' || 'h6':
        return _heading(children, typography.labelLarge);
      case 'ul' || 'ol':
        return _list(element);
      case 'blockquote':
        return _quote(children);
      case 'pre':
        return _codeBlock(element.textContent);
      case 'hr':
        return SizedBox(
          height: hairline,
          child: ColoredBox(color: colors.borderSubtle),
        );
      case 'table':
        return _table(element);
      case 'li':
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: blocks(children, gap: spacing.space1),
        );
      default:
        return _paragraph(children, _body);
    }
  }

  Widget _paragraph(List<md.Node> nodes, TextStyle style) {
    return Text.rich(TextSpan(style: style, children: _inlines(nodes, style)));
  }

  Widget _heading(List<md.Node> nodes, TextStyle role) {
    return Semantics(
      header: true,
      child: _paragraph(nodes, role.copyWith(color: colors.onSurface)),
    );
  }

  Widget _list(md.Element list) {
    final ordered = list.tag == 'ol';
    final start = int.tryParse(list.attributes['start'] ?? '') ?? 1;
    final items = (list.children ?? const <md.Node>[])
        .whereType<md.Element>()
        .where((e) => e.tag == 'li')
        .toList();
    final markerStyle = _body.copyWith(color: colors.onSurfaceMuted);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: <Widget>[
        for (var i = 0; i < items.length; i++) ...<Widget>[
          if (i > 0) SizedBox(height: spacing.space1),
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              SizedBox(
                width: spacing.space3,
                child: Text(
                  ordered ? '${start + i}.' : '•',
                  style: markerStyle,
                ),
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: blocks(
                    items[i].children ?? const <md.Node>[],
                    gap: spacing.space1,
                  ),
                ),
              ),
            ],
          ),
        ],
      ],
    );
  }

  Widget _quote(List<md.Node> nodes) {
    return Container(
      padding: EdgeInsetsDirectional.only(start: spacing.space2),
      decoration: BoxDecoration(
        border: BorderDirectional(
          start: BorderSide(
            color: colors.borderSubtle,
            width: spacing.spaceHalf,
          ),
        ),
      ),
      child: DefaultTextStyle.merge(
        style: TextStyle(color: colors.onSurfaceMuted),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: _MarkdownRenderer(
            colors: colors.copyWith(onSurface: colors.onSurfaceMuted),
            spacing: spacing,
            typography: typography,
            cardRadius: cardRadius,
            hairline: hairline,
            onTapLink: onTapLink,
            recognizers: recognizers,
          ).blocks(nodes),
        ),
      ),
    );
  }

  Widget _codeBlock(String code) {
    final text = code.endsWith('\n')
        ? code.substring(0, code.length - 1)
        : code;
    return Container(
      padding: EdgeInsets.all(spacing.space2),
      decoration: BoxDecoration(
        color: colors.surface2,
        borderRadius: cardRadius,
        border: Border.all(color: colors.borderSubtle, width: hairline),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Text(
          text,
          style: typography.mono.copyWith(color: colors.onSurface),
        ),
      ),
    );
  }

  Widget _table(md.Element table) {
    final rows = <md.Element>[];
    void collect(md.Element element) {
      for (final child in element.children ?? const <md.Node>[]) {
        if (child is! md.Element) continue;
        if (child.tag == 'tr') {
          rows.add(child);
        } else {
          collect(child);
        }
      }
    }

    collect(table);
    if (rows.isEmpty) return const SizedBox.shrink();
    final cells = <List<md.Element>>[
      for (final row in rows)
        (row.children ?? const <md.Node>[]).whereType<md.Element>().toList(),
    ];
    final columns = cells.fold<int>(
      0,
      (count, row) => row.length > count ? row.length : count,
    );
    final header = typography.labelLarge.copyWith(color: colors.onSurface);
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Table(
        defaultColumnWidth: const IntrinsicColumnWidth(),
        border: TableBorder.all(color: colors.borderSubtle, width: hairline),
        children: <TableRow>[
          for (final row in cells)
            TableRow(
              children: <Widget>[
                for (var c = 0; c < columns; c++)
                  Padding(
                    padding: EdgeInsets.symmetric(
                      horizontal: spacing.space2,
                      vertical: spacing.space1,
                    ),
                    child: c < row.length
                        ? _paragraph(
                            row[c].children ?? const <md.Node>[],
                            row[c].tag == 'th' ? header : _body,
                          )
                        : const SizedBox.shrink(),
                  ),
              ],
            ),
        ],
      ),
    );
  }

  List<InlineSpan> _inlines(List<md.Node> nodes, TextStyle style) {
    return <InlineSpan>[for (final node in nodes) _inline(node, style)];
  }

  InlineSpan _inline(md.Node node, TextStyle style) {
    if (node is md.Text) return TextSpan(text: node.text);
    if (node is! md.Element) return TextSpan(text: node.textContent);
    final children = node.children ?? const <md.Node>[];
    switch (node.tag) {
      case 'strong':
        final strong = style.copyWith(
          fontWeight: FontWeight.w600,
          fontVariations: const <FontVariation>[FontVariation.weight(600)],
        );
        return TextSpan(style: strong, children: _inlines(children, strong));
      case 'em':
        final em = style.copyWith(fontStyle: FontStyle.italic);
        return TextSpan(style: em, children: _inlines(children, em));
      case 'del':
        final del = style.copyWith(decoration: TextDecoration.lineThrough);
        return TextSpan(style: del, children: _inlines(children, del));
      case 'code':
        return TextSpan(
          text: node.textContent,
          style: typography.mono.copyWith(
            color: colors.onSurface,
            backgroundColor: colors.surface3,
            fontSize: style.fontSize,
            height: style.height,
          ),
        );
      case 'br':
        return const TextSpan(text: '\n');
      case 'a':
        final href = node.attributes['href'] ?? '';
        final tap = onTapLink;
        TapGestureRecognizer? recognizer;
        if (tap != null && href.isNotEmpty) {
          recognizer = TapGestureRecognizer()..onTap = () => tap(href);
          recognizers.add(recognizer);
        }
        final link = style.copyWith(
          decoration: TextDecoration.underline,
          decorationColor: style.color,
        );
        return TextSpan(
          text: node.textContent,
          style: link,
          recognizer: recognizer,
          mouseCursor: recognizer == null ? null : SystemMouseCursors.click,
        );
      case 'img':
        return TextSpan(
          text: node.attributes['alt'] ?? '',
          style: style.copyWith(color: colors.onSurfaceMuted),
        );
      case 'input':
        final checked = node.attributes.containsKey('checked');
        return WidgetSpan(
          alignment: PlaceholderAlignment.middle,
          child: Padding(
            padding: EdgeInsetsDirectional.only(end: spacing.space1),
            child: _TaskBox(checked: checked, colors: colors, spacing: spacing),
          ),
        );
      default:
        return TextSpan(children: _inlines(children, style));
    }
  }
}

class _TaskBox extends StatelessWidget {
  const new({
    required this.checked,
    required this.colors,
    required this.spacing,
  });

  final bool checked;
  final HiveColors colors;
  final HiveSpacing spacing;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      checked: checked,
      child: Container(
        width: spacing.space2,
        height: spacing.space2,
        alignment: Alignment.center,
        decoration: ShapeDecoration(
          color: checked ? colors.onSurface : colors.surface3,
          shape: CircleBorder(
            side: BorderSide(
              color: checked ? colors.onSurface : colors.onSurfaceMuted,
              width: context.hiveElevation.hairline,
            ),
          ),
        ),
        child: checked
            ? HiveIcon(
                HiveIcons.check,
                size: spacing.space2 - spacing.spaceHalf,
                color: colors.background,
              )
            : null,
      ),
    );
  }
}
