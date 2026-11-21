import 'dart:async';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/pty_terminal_controller.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

/// Embedded PTY terminal view for an active (or recently completed)
/// `TerminalHarnessNode` attempt in the Run Monitor.
class PtyTerminalPanel extends ConsumerStatefulWidget {
  /// Creates a [PtyTerminalPanel].
  const new({
    required this.runId,
    required this.nodeId,
    required this.attempt,
    required this.nodeLabel,
    required this.isEnded,
    super.key,
  });

  /// ID of the run being monitored.
  final String runId;

  /// ID of the `TerminalHarnessNode` being inspected.
  final String nodeId;

  /// Attempt number of the node execution.
  final int attempt;

  /// Display label of the node for accessibility.
  final String nodeLabel;

  /// Whether the node has reached a terminal state.
  final bool isEnded;

  @override
  ConsumerState<PtyTerminalPanel> createState() => _PtyTerminalPanelState();
}

class _PtyTerminalPanelState extends ConsumerState<PtyTerminalPanel> {
  final FocusNode _focusNode = FocusNode();

  @override
  void initState() {
    super.initState();
    if (widget.isEnded) {
      _scheduleMarkEnded();
    }
  }

  @override
  void didUpdateWidget(PtyTerminalPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.isEnded &&
        (!oldWidget.isEnded ||
            oldWidget.runId != widget.runId ||
            oldWidget.nodeId != widget.nodeId ||
            oldWidget.attempt != widget.attempt)) {
      _scheduleMarkEnded();
    }
  }

  void _scheduleMarkEnded() {
    unawaited(
      Future<void>.microtask(() {
        if (!mounted) return;
        ref
            .read(
              ptyTerminalControllerProvider(
                widget.runId,
                widget.nodeId,
                widget.attempt,
              ).notifier,
            )
            .markEnded();
      }),
    );
  }

  @override
  void dispose() {
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final provider = ptyTerminalControllerProvider(
      widget.runId,
      widget.nodeId,
      widget.attempt,
    );
    final terminalState = ref.watch(provider);
    final notifier = ref.read(provider.notifier);

    final mode = terminalState.mode;
    final modeLabel = switch (mode) {
      HiveTerminalMode.watch => l10n.runTerminalModeWatchLabel,
      HiveTerminalMode.interactive => l10n.runTerminalModeInteractiveLabel,
      HiveTerminalMode.ended => l10n.runTerminalModeEndedLabel,
    };
    final (badgeLabel, badgeTone) = switch (mode) {
      HiveTerminalMode.watch => (
        l10n.runTerminalBadgeWatch,
        HiveBadgeTone.info,
      ),
      HiveTerminalMode.interactive => (
        l10n.runTerminalBadgeInteractive,
        HiveBadgeTone.accentMuted,
      ),
      HiveTerminalMode.ended => (
        l10n.runTerminalBadgeEnded,
        HiveBadgeTone.neutral,
      ),
    };

    final terminalView = HiveTerminalView(
      key: Key('run_pty_terminal_view_${widget.nodeId}_${widget.attempt}'),
      controller: terminalState.terminalController,
      mode: mode,
      modeLabel: modeLabel,
      semanticLabel: l10n.runTerminalSemanticLabel(widget.nodeLabel),
      focusNode: _focusNode,
      onInput: notifier.sendInput,
      onResize: notifier.onResize,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          HiveBadge(
            key: const Key('run_terminal_mode_badge'),
            label: badgeLabel,
            tone: badgeTone,
          ),
          if (mode != HiveTerminalMode.ended) ...<Widget>[
            SizedBox(width: spacing.space1),
            HiveButton(
              key: const Key('run_terminal_takeover_button'),
              label: mode == HiveTerminalMode.interactive
                  ? l10n.runTerminalReleaseAction
                  : l10n.runTerminalTakeOverAction,
              icon: mode == HiveTerminalMode.interactive
                  ? HiveIcons.watch
                  : HiveIcons.keyboard,
              size: HiveButtonSize.small,
              variant: mode == HiveTerminalMode.interactive
                  ? HiveButtonVariant.secondary
                  : HiveButtonVariant.primary,
              onPressed: () {
                if (mode == HiveTerminalMode.interactive) {
                  notifier.release();
                  _focusNode.unfocus();
                } else {
                  notifier.takeOver();
                  _focusNode.requestFocus();
                }
              },
            ),
          ],
        ],
      ),
    );

    if (mode == HiveTerminalMode.ended && !terminalState.hasOutput) {
      return Stack(
        children: <Widget>[
          terminalView,
          Positioned.fill(
            child: IgnorePointer(
              child: Center(
                child: Padding(
                  padding: EdgeInsets.all(spacing.space4),
                  child: Text(
                    l10n.runTerminalEndedEmptyNote,
                    key: const Key('run_terminal_ended_empty_note'),
                    textAlign: TextAlign.center,
                    style: typography.body.copyWith(
                      color: colors.onSurfaceMuted,
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      );
    }

    return terminalView;
  }
}
