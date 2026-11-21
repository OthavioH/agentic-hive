import 'dart:convert';
import 'dart:typed_data';

import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_colors.dart';
import 'package:design_system/src/tokens/hive_terminal_colors.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';
import 'package:xterm/xterm.dart' as xterm;

/// How a person relates to the session shown by a [HiveTerminalView].
///
/// Each mode carries its own icon and icon color, so the header tells the
/// modes apart by shape as well as color.
enum HiveTerminalMode {
  /// Read-only: output streams in, no input or terminal replies are sent.
  watch(HiveIcons.watch, _infoRole),

  /// The person has taken over: keystrokes and pastes go to `onInput`.
  interactive(HiveIcons.keyboard, _accentMutedRole),

  /// The session has ended: read-only, the cursor is hidden for good and
  /// size changes are no longer reported.
  ended(HiveIcons.stop, _mutedRole);

  new(this.icon, this.iconColor);

  /// Header icon for this mode.
  final HiveIconData icon;

  /// Color role of [icon]. Text stays on `onSurface` roles.
  final HiveColorRole iconColor;

  /// Whether the view forwards input in this mode.
  bool get acceptsInput => this == HiveTerminalMode.interactive;
}

Color _infoRole(HiveColors colors) => colors.info;
Color _accentMutedRole(HiveColors colors) => colors.accentMuted;
Color _mutedRole(HiveColors colors) => colors.onSurfaceMuted;

/// Holds the screen and scrollback of a [HiveTerminalView] and accepts the
/// raw bytes a program writes to its terminal.
///
/// Bytes are decoded as UTF-8 across chunk boundaries (a multi-byte
/// character split between two chunks is joined; malformed bytes become
/// U+FFFD), then parsed as VT100/xterm escape sequences: colors (16, 256
/// and true color), cursor movement, erase, scroll regions, the alternate
/// screen and bracketed paste.
///
/// Create it once per session, keep it while the view is rebuilt, and
/// [dispose] it with the session.
class HiveTerminalController {
  /// Creates a controller that keeps [scrollbackLines] lines (screen plus
  /// history) before dropping the oldest.
  new({this.scrollbackLines = 10000})
    : assert(scrollbackLines > 0, 'scrollbackLines must be > 0.');

  /// Lines kept, screen plus history; the oldest are dropped beyond it.
  final int scrollbackLines;

  late final xterm.Terminal _terminal = xterm.Terminal(
    maxLines: scrollbackLines,
  );

  late final ByteConversionSink _decoder = const Utf8Decoder(
    allowMalformed: true,
  ).startChunkedConversion(_TerminalSink(_terminal));

  bool _disposed = false;

  /// Columns of the visible screen.
  int get columns => _terminal.viewWidth;

  /// Rows of the visible screen.
  int get rows => _terminal.viewHeight;

  /// Lines held (screen plus scrollback), at most [scrollbackLines].
  int get lineCount => _terminal.buffer.lines.length;

  /// Appends raw output [bytes] exactly as the program wrote them.
  void appendBytes(List<int> bytes) {
    assert(!_disposed, 'HiveTerminalController used after dispose.');
    if (bytes.isEmpty) return;
    _decoder.add(bytes);
  }

  /// Appends already-decoded output [text] (escape sequences included).
  void appendText(String text) {
    assert(!_disposed, 'HiveTerminalController used after dispose.');
    if (text.isEmpty) return;
    _terminal.write(text);
  }

  /// The plain text of every held line, without colors or attributes.
  ///
  /// Meant for tests, copy-all and accessibility summaries.
  String get plainText => _terminal.buffer.getText();

  /// Releases the decoder. The controller must not be used afterwards.
  void dispose() {
    if (_disposed) return;
    _disposed = true;
    _decoder.close();
  }
}

class _TerminalSink implements Sink<String> {
  const new(this._terminal);

  final xterm.Terminal _terminal;

  @override
  void add(String data) {
    if (data.isNotEmpty) _terminal.write(data);
  }

  @override
  void close() {}
}

/// A VT100/xterm terminal emulator for a harness session.
///
/// It draws a [HiveTerminalController]'s screen in Geist Mono with the
/// terminal palette ([HiveTerminalColors], derived from `HiveColors`). The
/// frame is a `surface1` panel with `radiusPanel` and a hairline; a header
/// shows the [mode] (icon plus [modeLabel]) and an optional [trailing]
/// action such as a **Take over** `HiveButton`; the screen sits in a
/// `background` well with `radiusCard`.
///
/// * [HiveTerminalMode.watch]: read-only. Text can still be selected and
///   copied; nothing is sent, not even the terminal's own replies.
/// * [HiveTerminalMode.interactive]: key presses, text and pastes are
///   encoded as the bytes a terminal would send and passed to [onInput].
///   The well shows a `focusRing` border while it has keyboard focus.
/// * [HiveTerminalMode.ended]: read-only, cursor hidden, no more resizes.
///
/// The screen fits the available size: whenever the size in cells
/// changes, [onResize] gets the new columns and rows after the frame.
/// Resizes arrive on every layout change (for example while a window is
/// dragged), so the consumer debounces them before resizing the PTY.
///
/// The view fills its parent, which must give it a bounded size.
class HiveTerminalView extends StatefulWidget {
  /// Creates a view of [controller]'s session in [mode].
  const new({
    required this.controller,
    required this.mode,
    required this.modeLabel,
    required this.semanticLabel,
    this.onInput,
    this.onResize,
    this.trailing,
    this.focusNode,
    this.autofocus = false,
    super.key,
  });

  /// The session's screen and scrollback.
  final HiveTerminalController controller;

  /// Whether the person watches, has taken over, or the session ended.
  final HiveTerminalMode mode;

  /// Localized name of [mode] shown in the header, such as `Watching`,
  /// `You have control` or `Session ended`.
  final String modeLabel;

  /// Localized name of the terminal region, such as `Claude Code terminal`.
  final String semanticLabel;

  /// Called with the UTF-8 bytes to write to the program's input, only in
  /// [HiveTerminalMode.interactive].
  final ValueChanged<Uint8List>? onInput;

  /// Called with the new screen size in cells (columns, rows) after a
  /// layout changes it, except in [HiveTerminalMode.ended].
  final void Function(int columns, int rows)? onResize;

  /// Optional header action, aligned to the end.
  final Widget? trailing;

  /// Focus node of the screen; one is created when null.
  final FocusNode? focusNode;

  /// Whether the screen requests focus when first built.
  final bool autofocus;

  @override
  State<HiveTerminalView> createState() => _HiveTerminalViewState();
}

class _HiveTerminalViewState extends State<HiveTerminalView> {
  FocusNode? _ownFocusNode;
  bool _hasFocus = false;
  (int, int)? _pendingSize;
  (int, int)? _reportedSize;

  FocusNode get _focusNode =>
      widget.focusNode ?? (_ownFocusNode ??= FocusNode());

  xterm.Terminal get _terminal => widget.controller._terminal;

  @override
  void initState() {
    super.initState();
    _focusNode.addListener(_onFocus);
    _attach();
  }

  @override
  void didUpdateWidget(HiveTerminalView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.focusNode != widget.focusNode) {
      (oldWidget.focusNode ?? _ownFocusNode)?.removeListener(_onFocus);
      _focusNode.addListener(_onFocus);
    }
    if (oldWidget.controller != widget.controller) {
      _detach(oldWidget.controller._terminal);
      _reportedSize = null;
    }
    _attach();
  }

  @override
  void dispose() {
    _focusNode.removeListener(_onFocus);
    _ownFocusNode?.dispose();
    _detach(_terminal);
    super.dispose();
  }

  void _attach() {
    _terminal
      ..onOutput = _onOutput
      ..onResize = _onTerminalResize;
    if (widget.mode == HiveTerminalMode.ended) {
      _terminal.setCursorVisibleMode(false);
    }
  }

  void _detach(xterm.Terminal terminal) {
    terminal
      ..onOutput = null
      ..onResize = null;
  }

  void _onFocus() {
    if (_focusNode.hasFocus != _hasFocus) {
      setState(() => _hasFocus = _focusNode.hasFocus);
    }
  }

  void _onOutput(String data) {
    if (!widget.mode.acceptsInput) return;
    widget.onInput?.call(utf8.encode(data));
  }

  /// The terminal resizes during layout; report after the frame, once, with
  /// the latest size.
  void _onTerminalResize(int columns, int rows, int _, int _) {
    final scheduled = _pendingSize != null;
    _pendingSize = (columns, rows);
    if (scheduled) return;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      final size = _pendingSize;
      _pendingSize = null;
      if (!mounted || size == null || size == _reportedSize) return;
      if (widget.mode == HiveTerminalMode.ended) return;
      _reportedSize = size;
      widget.onResize?.call(size.$1, size.$2);
    });
  }

  @override
  Widget build(BuildContext context) {
    final colors = context.hiveColors;
    final spacing = context.hiveSpacing;
    final radii = context.hiveRadii;
    final elevation = context.hiveElevation;
    final typography = context.hiveTypography;
    final palette = context.hiveTerminalColors;
    final mode = widget.mode;
    final trailing = widget.trailing;
    final focused = _hasFocus && mode.acceptsInput;

    final header = Padding(
      padding: EdgeInsetsDirectional.fromSTEB(
        spacing.space3,
        spacing.space2,
        spacing.space2,
        spacing.space2,
      ),
      child: Row(
        children: <Widget>[
          HiveIcon(
            mode.icon,
            size: spacing.space2,
            color: mode.iconColor(colors),
          ),
          SizedBox(width: spacing.space1),
          Expanded(
            child: Text(
              widget.modeLabel,
              key: const ValueKey<String>('hive-terminal-mode-label'),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: typography.label.copyWith(
                color: mode == HiveTerminalMode.ended
                    ? colors.onSurfaceMuted
                    : colors.onSurface,
              ),
            ),
          ),
          if (trailing != null) ...<Widget>[
            SizedBox(width: spacing.space1),
            trailing,
          ],
        ],
      ),
    );

    final screen = xterm.TerminalView(
      _terminal,
      theme: _theme(palette),
      textStyle: xterm.TerminalStyle.fromTextStyle(typography.mono),
      padding: EdgeInsets.all(spacing.space1),
      focusNode: _focusNode,
      autofocus: widget.autofocus,
      readOnly: !mode.acceptsInput,
      hardwareKeyboardOnly: true,
      cursorType: mode.acceptsInput
          ? xterm.TerminalCursorType.block
          : xterm.TerminalCursorType.underline,
    );

    return Semantics(
      container: true,
      label: '${widget.semanticLabel}, ${widget.modeLabel}',
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: colors.surface1,
          borderRadius: radii.panel,
          border: Border.all(
            color: colors.borderSubtle,
            width: elevation.hairline,
          ),
        ),
        child: Padding(
          padding: EdgeInsetsDirectional.only(
            start: spacing.space1,
            end: spacing.space1,
            bottom: spacing.space1,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              Expanded(
                child: DecoratedBox(
                  key: const ValueKey<String>('hive-terminal-well'),
                  position: DecorationPosition.foreground,
                  decoration: BoxDecoration(
                    borderRadius: radii.card,
                    border: Border.all(
                      color: focused ? colors.focusRing : colors.borderSubtle,
                      width: focused
                          ? elevation.focusRingWidth
                          : elevation.hairline,
                    ),
                  ),
                  child: ClipRRect(
                    borderRadius: radii.card,
                    child: ColoredBox(color: palette.background, child: screen),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static xterm.TerminalTheme _theme(HiveTerminalColors p) {
    return xterm.TerminalTheme(
      cursor: p.cursor,
      selection: p.selection,
      foreground: p.foreground,
      background: p.background,
      black: p.black,
      red: p.red,
      green: p.green,
      yellow: p.yellow,
      blue: p.blue,
      magenta: p.magenta,
      cyan: p.cyan,
      white: p.white,
      brightBlack: p.brightBlack,
      brightRed: p.brightRed,
      brightGreen: p.brightGreen,
      brightYellow: p.brightYellow,
      brightBlue: p.brightBlue,
      brightMagenta: p.brightMagenta,
      brightCyan: p.brightCyan,
      brightWhite: p.brightWhite,
      searchHitBackground: p.searchHitBackground,
      searchHitBackgroundCurrent: p.searchHitBackgroundCurrent,
      searchHitForeground: p.searchHitForeground,
    );
  }
}
