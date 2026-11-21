import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:design_system/design_system.dart';
import 'package:hive_widgetbook/src/showcase.dart';
import 'package:material_ui/material_ui.dart';
import 'package:widgetbook/widgetbook.dart';

const String _esc = '\x1b';
const String _reset = '$_esc[0m';
const String _prompt = '$_esc[32m~/workspace$_reset \$ ';

/// What a Claude Code session in a terminal harness writes, chunked as a
/// PTY delivers it (chunks may end mid-line or mid-sequence).
const List<String> _sessionChunks = <String>[
  '$_esc[1mClaude Code$_reset $_esc[90mv2.4.1$_reset\r\n',
  '$_esc[90mcwd: ~/workspace/agentic-hive$_reset\r\n\r\n',
  '$_esc[36m>$_reset Review src/engine/scheduler.dart and its tests\r\n\r\n',
  '$_esc[33m●$_reset Read(src/engine/scheduler.dart)\r\n',
  '  $_esc[90m⎿  Read 214 lines$_reset\r\n',
  '$_esc[33m●$_reset Bash(dart test test/engine/sched',
  'uler_test.dart)\r\n',
  '  $_esc[90m⎿$_reset  00:01 +12: resumes from checkpoint\r\n',
  '     00:02 +27: cancels the process tree\r\n',
  '     $_esc[32m00:03 +41: All tests passed!$_reset\r\n',
  '$_esc[33m●$_reset Edit(src/engine/scheduler.dart)\r\n',
  '  $_esc[32m+ await _store.saveCheckpoint(run);$_reset\r\n',
  '  $_esc[31m- _store.saveCheckpoint(run);$_reset\r\n\r\n',
  '$_esc[1;32m✓$_reset report_result: succeeded (12 files reviewed)\r\n',
];

const String _endedTail =
    '\r\n$_esc[90mSession ended: exit code 0 after 3m 12s$_reset\r\n';

String _palette() {
  const names = <String>[
    'black',
    'red',
    'green',
    'yellow',
    'blue',
    'magenta',
    'cyan',
    'white',
  ];
  final out = StringBuffer('$_esc[1mANSI colors$_reset\r\n\r\n');
  for (var i = 0; i < names.length; i++) {
    out.write(
      '$_esc[3${i}m${names[i].padRight(10)}$_reset'
      '$_esc[9${i}mbright ${names[i].padRight(10)}$_reset'
      '$_esc[4${i}m  $_reset\r\n',
    );
  }
  out
    ..write('\r\n$_esc[1mbold$_reset  $_esc[3mitalic$_reset  ')
    ..write('$_esc[4munderline$_reset  $_esc[7minverse$_reset\r\n')
    ..write('$_esc[38;5;114m256-color 114$_reset  ')
    ..write('$_esc[38;2;198;239;78mtrue color$_reset\r\n');
  return out.toString();
}

/// `HiveTerminalView`: watch (read-only, live output), interactive (taken
/// over, typed keys echoed by a local demo shell), ended, and the ANSI
/// palette. Switch the theme addon to review dark and light.
WidgetbookComponent terminalViewComponent() {
  Widget frame(BuildContext context, Widget child) => UseCaseFrame(
    child: SizedBox(
      width: context.hiveSpacing.space8 * 12,
      height: context.hiveSpacing.space8 * 7,
      child: child,
    ),
  );
  return WidgetbookComponent(
    name: 'HiveTerminalView',
    useCases: <WidgetbookUseCase>[
      WidgetbookUseCase(
        name: 'Watch · Live output',
        builder: (context) => frame(
          context,
          const _TerminalHost(initialMode: HiveTerminalMode.watch, live: true),
        ),
      ),
      WidgetbookUseCase(
        name: 'Interactive · Taken over',
        builder: (context) => frame(
          context,
          const _TerminalHost(initialMode: HiveTerminalMode.interactive),
        ),
      ),
      WidgetbookUseCase(
        name: 'Ended',
        builder: (context) => frame(
          context,
          const _TerminalHost(initialMode: HiveTerminalMode.ended),
        ),
      ),
      WidgetbookUseCase(
        name: 'ANSI palette',
        builder: (context) => frame(
          context,
          const _TerminalHost(
            initialMode: HiveTerminalMode.watch,
            palette: true,
          ),
        ),
      ),
    ],
  );
}

class _TerminalHost extends StatefulWidget {
  const new({
    required this.initialMode,
    this.live = false,
    this.palette = false,
  });

  final HiveTerminalMode initialMode;
  final bool live;
  final bool palette;

  @override
  State<_TerminalHost> createState() => _TerminalHostState();
}

class _TerminalHostState extends State<_TerminalHost> {
  final HiveTerminalController _controller = HiveTerminalController();
  late HiveTerminalMode _mode = widget.initialMode;
  Timer? _timer;
  var _next = 0;
  String _size = '';

  @override
  void initState() {
    super.initState();
    if (widget.palette) {
      _controller.appendText(_palette());
    } else if (widget.live) {
      _controller.appendText(_sessionChunks.take(4).join());
      _next = 4;
    } else {
      _controller.appendText(_sessionChunks.join());
      if (_mode == HiveTerminalMode.ended) {
        _controller.appendText(_endedTail);
      } else {
        _controller.appendText('\r\n$_prompt');
      }
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (widget.live) {
      _timer ??= Timer.periodic(context.hiveMotion.long * 2, (_) {
        if (_mode != HiveTerminalMode.watch) return;
        final chunk = _sessionChunks[_next % _sessionChunks.length];
        _next++;
        _controller.appendBytes(utf8.encode(chunk));
      });
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  /// A local stand-in for the PTY: echoes printable input, answers Enter
  /// with a new prompt and Backspace by erasing one cell.
  void _onInput(Uint8List bytes) {
    final text = utf8.decode(bytes, allowMalformed: true);
    for (final rune in text.runes) {
      if (rune == 0x0D) {
        _controller.appendText('\r\n$_prompt');
      } else if (rune == 0x7F || rune == 0x08) {
        _controller.appendText('\b \b');
      } else if (rune >= 0x20) {
        _controller.appendText(String.fromCharCode(rune));
      }
    }
  }

  void _onResize(int columns, int rows) {
    setState(() => _size = '$columns × $rows');
  }

  @override
  Widget build(BuildContext context) {
    final Widget? trailing = switch (_mode) {
      HiveTerminalMode.watch => HiveButton(
        label: 'Take over',
        icon: HiveIcons.keyboard,
        variant: HiveButtonVariant.secondary,
        size: HiveButtonSize.small,
        onPressed: () => setState(() => _mode = HiveTerminalMode.interactive),
      ),
      HiveTerminalMode.interactive => HiveButton(
        label: 'Hand back',
        icon: HiveIcons.watch,
        variant: HiveButtonVariant.secondary,
        size: HiveButtonSize.small,
        onPressed: () => setState(() => _mode = HiveTerminalMode.watch),
      ),
      HiveTerminalMode.ended => null,
    };
    final label = switch (_mode) {
      HiveTerminalMode.watch => 'Watching · read-only',
      HiveTerminalMode.interactive => 'You have control',
      HiveTerminalMode.ended => 'Session ended',
    };
    return HiveTerminalView(
      controller: _controller,
      mode: _mode,
      modeLabel: _size.isEmpty ? label : '$label · $_size',
      semanticLabel: 'Claude Code terminal',
      onInput: _onInput,
      onResize: _onResize,
      autofocus: _mode == HiveTerminalMode.interactive,
      trailing: trailing,
    );
  }
}
