import 'dart:async';
import 'dart:convert';

import 'package:agentic_hive_frontend/l10n/generated/app_localizations.dart';
import 'package:agentic_hive_frontend/presentation/runs/controllers/run_detail_controller.dart';
import 'package:agentic_hive_frontend/presentation/runs/utils/run_l10n.dart';
import 'package:agentic_hive_frontend/presentation/runs/widgets/pty_terminal_panel.dart';
import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:design_system/design_system.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_ui/material_ui.dart';

enum _OutputViewMode { transcript, raw }

/// Inspector panel displaying a node attempt's readable transcript, raw log,
/// or embedded PTY terminal.
class RunOutputPanel extends ConsumerStatefulWidget {
  /// Creates a [RunOutputPanel].
  const new({
    required this.runId,
    required this.detailState,
    this.isMaximized = false,
    this.onToggleMaximize,
    super.key,
  });

  /// ID of the run being monitored.
  final String runId;

  /// Current run detail state.
  final RunDetailState detailState;

  /// Whether the inspector is currently maximized.
  final bool isMaximized;

  /// Toggles maximized mode for the inspector.
  final VoidCallback? onToggleMaximize;

  @override
  ConsumerState<RunOutputPanel> createState() => _RunOutputPanelState();
}

class _RunOutputPanelState extends ConsumerState<RunOutputPanel> {
  final Set<(String, int)> _activeTerminalSessions = <(String, int)>{};
  final HiveTranscriptController _transcriptController =
      HiveTranscriptController();

  _OutputViewMode _viewMode = _OutputViewMode.transcript;
  String? _lastSyncedNodeId;
  int? _lastSyncedAttempt;
  List<TranscriptEntry> _lastSyncedEntries = const <TranscriptEntry>[];
  String? _announcedTruncationKey;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncTranscript(AppLocalizations.of(context)!);
  }

  @override
  void didUpdateWidget(RunOutputPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncTranscript(AppLocalizations.of(context)!);
  }

  @override
  void dispose() {
    _transcriptController.dispose();
    super.dispose();
  }

  void _syncTranscript(AppLocalizations l10n) {
    final detail = widget.detailState;
    final nodeChanged = detail.inspectedNodeId != _lastSyncedNodeId;
    final attemptChanged = detail.selectedAttempt != _lastSyncedAttempt;
    if (nodeChanged || attemptChanged) {
      _lastSyncedNodeId = detail.inspectedNodeId;
      _lastSyncedAttempt = detail.selectedAttempt;
      _lastSyncedEntries = const <TranscriptEntry>[];
      _transcriptController.clear();
    }

    final entries = detail.transcriptEntries;
    if (identical(entries, _lastSyncedEntries)) return;
    _lastSyncedEntries = entries;

    if (entries.isEmpty) {
      if (!_transcriptController.isEmpty) {
        _transcriptController.clear();
      }
      return;
    }

    _transcriptController.upsertAll(<HiveTranscriptBlock>[
      for (final entry in entries) _toTranscriptBlock(l10n, entry),
    ]);
  }

  static HiveTranscriptBlock _toTranscriptBlock(
    AppLocalizations l10n,
    TranscriptEntry entry,
  ) {
    return switch (entry) {
      TranscriptAgentMessage(:final id, :final text) => HiveTranscriptMessage(
        id: id,
        markdown: text,
      ),
      TranscriptThinking(:final id, :final text) => HiveTranscriptThinking(
        id: id,
        text: text,
      ),
      TranscriptToolCall(:final id, :final name, :final input) =>
        HiveTranscriptToolCall(
          id: id,
          name: name,
          input: _formatToolInput(input),
        ),
      TranscriptToolResult(:final id, :final output) =>
        HiveTranscriptToolResult(id: id, text: output),
      TranscriptError(:final id, :final message) => HiveTranscriptError(
        id: id,
        message: message,
      ),
      TranscriptFinalResult(
        :final id,
        :final status,
        :final durationMs,
        :final costUsd,
        :final inputTokens,
        :final outputTokens,
      ) =>
        HiveTranscriptFinalResult(
          id: id,
          statusLabel: status ?? l10n.runDetailTranscriptResult,
          tone: _finalResultTone(status),
          metrics: _buildFinalResultMetrics(
            l10n,
            durationMs: durationMs,
            costUsd: costUsd,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
          ),
        ),
      TranscriptPlainText(:final id, :final stream, :final text) =>
        HiveTranscriptPlainText(
          id: id,
          text: text,
          stream: stream == RunOutputStream.stderr
              ? HiveLogStream.stderr
              : HiveLogStream.stdout,
        ),
    };
  }

  static String _formatToolInput(JsonMap input) {
    if (input.isEmpty) return '';
    return jsonEncode(input);
  }

  static HiveFeedbackTone _finalResultTone(String? status) {
    final normalized = status?.toLowerCase() ?? '';
    if (normalized.contains('fail') || normalized.contains('error')) {
      return HiveFeedbackTone.danger;
    }
    return HiveFeedbackTone.success;
  }

  static List<HiveTranscriptMetric> _buildFinalResultMetrics(
    AppLocalizations l10n, {
    required int? durationMs,
    required double? costUsd,
    required int? inputTokens,
    required int? outputTokens,
  }) {
    final metrics = <HiveTranscriptMetric>[];
    if (durationMs != null) {
      metrics.add(
        HiveTranscriptMetric(
          label: l10n.runDetailTranscriptDuration,
          value: _formatDurationMs(durationMs),
        ),
      );
    }
    if (costUsd != null) {
      metrics.add(
        HiveTranscriptMetric(
          label: l10n.runDetailTranscriptCost,
          value: '\$${costUsd.toStringAsFixed(4)}',
        ),
      );
    }
    if (inputTokens != null || outputTokens != null) {
      final tokenText = switch ((inputTokens, outputTokens)) {
        (final i?, final o?) => '$i / $o',
        (final i?, null) => '$i',
        (null, final o?) => '$o',
        (null, null) => '',
      };
      if (tokenText.isNotEmpty) {
        metrics.add(
          HiveTranscriptMetric(
            label: l10n.runDetailTranscriptTokens,
            value: tokenText,
          ),
        );
      }
    }
    return metrics;
  }

  static String _formatDurationMs(int durationMs) {
    if (durationMs < 1000) return '${durationMs}ms';
    final seconds = durationMs / 1000;
    if (seconds < 60) return '${seconds.toStringAsFixed(1)}s';
    final minutes = durationMs ~/ 60000;
    final remSeconds = (durationMs % 60000) ~/ 1000;
    return '${minutes}m ${remSeconds}s';
  }

  String _visibleCopyText(
    AppLocalizations l10n,
    RunDetailController controller,
  ) {
    if (_viewMode == _OutputViewMode.raw) {
      return controller.logController.lines.map((line) => line.text).join('\n');
    }
    final parts = <String>[];
    for (final entry in widget.detailState.transcriptEntries) {
      switch (entry) {
        case TranscriptAgentMessage(:final text):
          parts.add(text);
        case TranscriptThinking(:final text):
          parts.add('${l10n.runDetailTranscriptThinking}:\n$text');
        case TranscriptToolCall(:final name, :final input):
          final formatted = _formatToolInput(input);
          parts.add(formatted.isEmpty ? name : '$name\n$formatted');
        case TranscriptToolResult(:final output):
          parts.add('${l10n.runDetailTranscriptToolResult}:\n$output');
        case TranscriptError(:final message):
          parts.add('${l10n.runDetailTranscriptError}: $message');
        case TranscriptFinalResult(
          :final status,
          :final durationMs,
          :final costUsd,
          :final inputTokens,
          :final outputTokens,
        ):
          final metrics = _buildFinalResultMetrics(
            l10n,
            durationMs: durationMs,
            costUsd: costUsd,
            inputTokens: inputTokens,
            outputTokens: outputTokens,
          );
          final label = status ?? l10n.runDetailTranscriptResult;
          if (metrics.isEmpty) {
            parts.add(label);
          } else {
            final summary = metrics
                .map((m) => '${m.label}: ${m.value}')
                .join(', ');
            parts.add('$label ($summary)');
          }
        case TranscriptPlainText(:final text):
          parts.add(text);
      }
    }
    return parts.join('\n\n');
  }

  Future<void> _copyVisible(
    BuildContext context,
    AppLocalizations l10n,
    RunDetailController controller,
  ) async {
    final text = _visibleCopyText(l10n, controller);
    await Clipboard.setData(ClipboardData(text: text));
    if (!context.mounted) return;
    HiveToast.show(context, message: l10n.runDetailTranscriptCopied);
  }

  WorkflowNode? _findNode(String? nodeId) {
    if (nodeId == null) return null;
    for (final node in widget.detailState.run.workflowDefinition.nodes) {
      if (node.id == nodeId) return node;
    }
    return null;
  }

  static bool _isNodeActive(HiveNodeStatus? status) =>
      status == HiveNodeStatus.running ||
      status == HiveNodeStatus.paused ||
      status == HiveNodeStatus.cancelling;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context)!;
    final spacing = context.hiveSpacing;
    final colors = context.hiveColors;
    final typography = context.hiveTypography;
    final detailState = widget.detailState;
    final controller = ref.read(
      runDetailControllerProvider(widget.runId).notifier,
    );

    final nodeId = detailState.inspectedNodeId;
    final node = _findNode(nodeId);
    final nodeLabel = node?.label ?? nodeId;
    final nodeStatus = nodeId != null
        ? (detailState.nodeStatuses[nodeId] ?? HiveNodeStatus.idle)
        : null;

    final isTerminalNode = node?.type == NodeTypeId.terminal;
    final attempt = detailState.selectedAttempt ?? 1;
    final isActive = _isNodeActive(nodeStatus);
    if (nodeId != null && isTerminalNode && isActive) {
      _activeTerminalSessions.add((nodeId, attempt));
    }
    final showTerminal =
        nodeId != null &&
        isTerminalNode &&
        (isActive || _activeTerminalSessions.contains((nodeId, attempt)));

    final isTruncated = _viewMode == _OutputViewMode.raw
        ? (detailState.rawLogTruncated || detailState.logsTruncated)
        : detailState.rawLogTruncated;
    if (nodeId != null && !showTerminal && isTruncated) {
      final truncationKey = '$nodeId:$attempt';
      if (_announcedTruncationKey != truncationKey) {
        _announcedTruncationKey = truncationKey;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) return;
          unawaited(
            SemanticsService.sendAnnouncement(
              View.of(context),
              l10n.runDetailTranscriptTruncated,
              Directionality.of(context),
            ),
          );
        });
      }
    }

    final transcriptLabels = HiveTranscriptLabels(
      semanticLabel: l10n.runDetailTabTranscript,
      jumpToBottom: l10n.runDetailOutputJumpToBottom,
      thinking: l10n.runDetailTranscriptThinking,
      toolResult: l10n.runDetailTranscriptToolResult,
      error: l10n.runDetailTranscriptError,
      stderr: l10n.runDetailOutputStderrLabel,
      showLess: l10n.runDetailShowLess,
      showAll: l10n.runDetailShowAll,
      emptyLabel: l10n.runDetailTranscriptEmpty,
    );

    return HiveCard(
      surface: HiveCardSurface.surface2,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final motion = context.hiveMotion;
          final elevation = context.hiveElevation;
          final header = Wrap(
            spacing: spacing.space2,
            runSpacing: spacing.space1,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: <Widget>[
              if (nodeStatus != null || nodeLabel != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (nodeStatus != null) ...<Widget>[
                      HiveStatusDot(
                        status: nodeStatus,
                        semanticLabel: RunL10n.localizeNodeStatus(
                          l10n,
                          nodeStatus,
                        ),
                        size: spacing.space2,
                      ),
                      if (nodeLabel != null) SizedBox(width: spacing.space1),
                    ],
                    if (nodeLabel != null)
                      Tooltip(
                        message: nodeLabel,
                        excludeFromSemantics: true,
                        waitDuration: motion.resolve(context, motion.long),
                        exitDuration: motion.resolve(context, motion.short),
                        padding: EdgeInsets.all(spacing.space2),
                        decoration: ShapeDecoration(
                          color: colors.surface3,
                          shape: RoundedRectangleBorder(
                            borderRadius: context.hiveRadii.card,
                            side: BorderSide(
                              color: colors.borderSubtle,
                              width: elevation.hairline,
                            ),
                          ),
                        ),
                        textStyle: typography.bodySmall.copyWith(
                          color: colors.onSurface,
                        ),
                        child: ConstrainedBox(
                          constraints: BoxConstraints(
                            maxWidth: spacing.space8 * 4,
                          ),
                          child: Text(
                            nodeLabel,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: typography.titleSmall.copyWith(
                              color: colors.onSurface,
                            ),
                          ),
                        ),
                      ),
                  ],
                ),
              if (detailState.followActiveNode)
                HiveBadge(
                  key: const Key('run_output_following_badge'),
                  label: l10n.runDetailFollowActiveBadge,
                  tone: HiveBadgeTone.info,
                )
              else
                HiveButton(
                  key: const Key('run_output_follow_active_button'),
                  label: l10n.runDetailFollowActiveButton,
                  size: HiveButtonSize.small,
                  variant: HiveButtonVariant.secondary,
                  onPressed: () => unawaited(controller.enableFollowActive()),
                ),
              if (detailState.availableAttempts.length > 1)
                SizedBox(
                  width: spacing.space8 * 2 + spacing.space4,
                  child: HiveSelect<int>(
                    key: const Key('run_output_attempt_select'),
                    label: l10n.runDetailOutputAttemptLabel,
                    options: <HiveSelectOption<int>>[
                      for (final attemptOption in detailState.availableAttempts)
                        HiveSelectOption<int>(
                          value: attemptOption,
                          label: l10n.runDetailOutputAttemptOption(
                            attemptOption,
                          ),
                        ),
                    ],
                    value: detailState.selectedAttempt,
                    onChanged: (selected) =>
                        unawaited(controller.selectAttempt(selected)),
                  ),
                ),
              if (nodeId != null && !showTerminal)
                HiveSegmentedControl<_OutputViewMode>(
                  key: const Key('run_transcript_mode_switch'),
                  semanticLabel: l10n.runDetailTabTranscript,
                  selected: _viewMode,
                  onChanged: (mode) => setState(() => _viewMode = mode),
                  segments: <HiveSegment<_OutputViewMode>>[
                    HiveSegment<_OutputViewMode>(
                      value: _OutputViewMode.transcript,
                      label: l10n.runDetailTabTranscript,
                    ),
                    HiveSegment<_OutputViewMode>(
                      value: _OutputViewMode.raw,
                      label: l10n.runDetailViewRaw,
                    ),
                  ],
                ),
              if ((nodeId != null && !showTerminal) ||
                  widget.onToggleMaximize != null)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: <Widget>[
                    if (nodeId != null && !showTerminal)
                      HiveIconButton(
                        key: const Key('run_transcript_copy_button'),
                        icon: HiveIcons.copy,
                        size: HiveButtonSize.small,
                        semanticLabel: l10n.runDetailCopy,
                        onPressed: () =>
                            unawaited(_copyVisible(context, l10n, controller)),
                      ),
                    if (nodeId != null &&
                        !showTerminal &&
                        widget.onToggleMaximize != null)
                      SizedBox(width: spacing.space1),
                    if (widget.onToggleMaximize != null)
                      HiveIconButton(
                        key: const Key('run_inspector_maximize_button'),
                        icon: widget.isMaximized
                            ? HiveIcons.restore
                            : HiveIcons.maximize,
                        size: HiveButtonSize.small,
                        semanticLabel: widget.isMaximized
                            ? l10n.runDetailRestoreInspector
                            : l10n.runDetailMaximizeInspector,
                        onPressed: widget.onToggleMaximize,
                      ),
                  ],
                ),
            ],
          );

          final banner = !showTerminal && nodeId != null && isTruncated
              ? HiveBanner(
                  key: const Key('run_transcript_truncated_banner'),
                  tone: HiveFeedbackTone.warning,
                  density: HiveBannerDensity.compact,
                  title: l10n.runDetailTranscriptTruncated,
                )
              : null;

          final body = _buildBody(
            context,
            l10n,
            spacing,
            colors,
            controller,
            nodeId: nodeId,
            nodeLabel: nodeLabel,
            attempt: attempt,
            showTerminal: showTerminal,
            isActive: isActive,
            transcriptLabels: transcriptLabels,
          );

          if (constraints.maxHeight < spacing.space8 * 4) {
            return SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                mainAxisSize: MainAxisSize.min,
                children: <Widget>[
                  header,
                  if (banner != null) ...<Widget>[
                    SizedBox(height: spacing.space2),
                    banner,
                  ],
                  SizedBox(height: spacing.space2),
                  SizedBox(height: spacing.space8 * 3, child: body),
                ],
              ),
            );
          }

          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: <Widget>[
              header,
              if (banner != null) ...<Widget>[
                SizedBox(height: spacing.space2),
                banner,
              ],
              SizedBox(height: spacing.space2),
              Expanded(child: body),
            ],
          );
        },
      ),
    );
  }

  Widget _buildBody(
    BuildContext context,
    AppLocalizations l10n,
    HiveSpacing spacing,
    HiveColors colors,
    RunDetailController controller, {
    required String? nodeId,
    required String? nodeLabel,
    required int attempt,
    required bool showTerminal,
    required bool isActive,
    required HiveTranscriptLabels transcriptLabels,
  }) {
    final detailState = widget.detailState;
    if (nodeId == null) {
      return Center(
        child: SingleChildScrollView(
          child: HiveEmptyState(
            icon: HiveIcons.terminal,
            title: l10n.runDetailTabTranscript,
            message: l10n.runDetailTranscriptSelectNode,
          ),
        ),
      );
    }

    if (showTerminal) {
      return PtyTerminalPanel(
        key: Key('run_pty_terminal_${nodeId}_$attempt'),
        runId: widget.runId,
        nodeId: nodeId,
        attempt: attempt,
        nodeLabel: nodeLabel ?? l10n.runDetailTabTranscript,
        isEnded: !isActive,
      );
    }

    if (detailState.isLoadingLogs &&
        detailState.transcriptEntries.isEmpty &&
        controller.logController.isEmpty) {
      return Center(
        child: HiveSpinner(size: spacing.space4, color: colors.accent),
      );
    }

    if (detailState.logsFailure != null &&
        detailState.transcriptEntries.isEmpty &&
        controller.logController.isEmpty) {
      return Align(
        alignment: Alignment.topCenter,
        child: HiveBanner(
          key: const Key('run_transcript_error_banner'),
          tone: HiveFeedbackTone.danger,
          density: HiveBannerDensity.compact,
          title: l10n.runDetailTranscriptLoadError,
          message: RunL10n.localizeFailure(l10n, detailState.logsFailure!),
          actions: <Widget>[
            HiveButton(
              key: const Key('run_transcript_retry_button'),
              label: l10n.runsRetryAction,
              size: HiveButtonSize.small,
              variant: HiveButtonVariant.secondary,
              onPressed: () => unawaited(controller.retryLoadLogs()),
            ),
          ],
        ),
      );
    }

    if (_viewMode == _OutputViewMode.raw) {
      return HiveLogStreamViewer(
        key: Key('run_log_viewer_$nodeId'),
        controller: controller.logController,
        semanticLabel: l10n.runDetailViewRaw,
        jumpToBottomLabel: l10n.runDetailOutputJumpToBottom,
        stderrSemanticLabel: l10n.runDetailOutputStderrLabel,
        emptyLabel: l10n.runDetailTranscriptEmpty,
      );
    }

    if (detailState.transcriptEntries.isEmpty) {
      return Center(
        child: SingleChildScrollView(
          child: HiveEmptyState(
            key: const Key('run_transcript_empty'),
            icon: HiveIcons.terminal,
            title: l10n.runDetailTabTranscript,
            message: l10n.runDetailTranscriptEmpty,
          ),
        ),
      );
    }

    return HiveTranscriptView(
      key: Key('run_transcript_view_$nodeId'),
      controller: _transcriptController,
      labels: transcriptLabels,
    );
  }
}
