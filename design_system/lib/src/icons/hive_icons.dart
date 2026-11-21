import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:hugeicons/hugeicons.dart';
import 'package:material_ui/material_ui.dart';

/// An icon of the design system.
///
/// Features only get instances from [HiveIcons] and render them with
/// `HiveIcon`; the underlying icon package never leaks out of
/// `design_system`. Each kind of source is its own subclass, so rendering
/// never switches on the icon type.
sealed class HiveIconData {
  const new();

  /// Builds the icon at [size] in [color].
  Widget build({required double size, required Color color});
}

/// A stroke-rounded glyph from the free Hugeicons set (MIT).
final class _HugeGlyph extends HiveIconData {
  const new(this._data);

  final List<List<dynamic>> _data;

  @override
  Widget build({required double size, required Color color}) {
    return HugeIcon(icon: _data, size: size, color: color);
  }
}

/// A single-color SVG bundled in `design_system/assets/svg`.
///
/// The SVG draws in `currentColor`, so it always renders in a token color.
final class _SvgGlyph extends HiveIconData {
  const new(this._asset);

  final String _asset;

  @override
  Widget build({required double size, required Color color}) {
    return SvgPicture.asset(
      _asset,
      package: 'design_system',
      width: size,
      height: size,
      theme: SvgTheme(currentColor: color),
    );
  }
}

/// Every icon and harness logo of Agentic Hive.
///
/// Icons come from the free Hugeicons stroke-rounded set only (never
/// `hugeicons_pro`). Harness logos follow the foundation spec rule: the
/// Hugeicons free logo when it exists, else the official brand kit SVG when
/// its guidelines allow it, else the Hive robot.
abstract final class HiveIcons {
  // Navigation.

  /// Overview (home) page.
  static const HiveIconData overview = _HugeGlyph(
    HugeIcons.strokeRoundedDashboardSquare01,
  );

  /// Workflows page.
  static const HiveIconData workflows = _HugeGlyph(
    HugeIcons.strokeRoundedFlowConnection,
  );

  /// Runs page.
  static const HiveIconData runs = _HugeGlyph(
    HugeIcons.strokeRoundedPlayCircle,
  );

  /// Pauses inbox.
  static const HiveIconData pauses = _HugeGlyph(
    HugeIcons.strokeRoundedPauseCircle,
  );

  /// Agents library.
  static const HiveIconData agents = _HugeGlyph(
    HugeIcons.strokeRoundedUserGroup,
  );

  /// Harnesses page.
  static const HiveIconData harnesses = _HugeGlyph(
    HugeIcons.strokeRoundedPlugSocket,
  );

  /// Settings page.
  static const HiveIconData settings = _HugeGlyph(
    HugeIcons.strokeRoundedSettings01,
  );

  /// Expand the side rail.
  static const HiveIconData expandRail = _HugeGlyph(
    HugeIcons.strokeRoundedArrowRight01,
  );

  /// Collapse the side rail.
  static const HiveIconData collapseRail = _HugeGlyph(
    HugeIcons.strokeRoundedArrowLeft01,
  );

  // Node kinds.

  /// Command node (and terminal output).
  static const HiveIconData terminal = _HugeGlyph(
    HugeIcons.strokeRoundedComputerTerminal01,
  );

  /// Tests validator.
  static const HiveIconData validatorTests = _HugeGlyph(
    HugeIcons.strokeRoundedTestTube01,
  );

  /// Checklist validator.
  static const HiveIconData validatorChecklist = _HugeGlyph(
    HugeIcons.strokeRoundedCheckList,
  );

  /// Review validator.
  static const HiveIconData validatorReview = _HugeGlyph(
    HugeIcons.strokeRoundedShieldCheck,
  );

  /// Human approval node.
  static const HiveIconData person = _HugeGlyph(
    HugeIcons.strokeRoundedUserCheck01,
  );

  // Actions and states.

  /// Add.
  static const HiveIconData add = _HugeGlyph(HugeIcons.strokeRoundedAdd01);

  /// Close or cancel.
  static const HiveIconData close = _HugeGlyph(HugeIcons.strokeRoundedCancel01);

  /// Confirm.
  static const HiveIconData check = _HugeGlyph(HugeIcons.strokeRoundedTick02);

  /// Warning or error.
  static const HiveIconData alert = _HugeGlyph(HugeIcons.strokeRoundedAlert02);

  /// Information (info banners and toasts).
  static const HiveIconData info = _HugeGlyph(
    HugeIcons.strokeRoundedInformationCircle,
  );

  /// Success confirmation (success banners and toasts).
  static const HiveIconData success = _HugeGlyph(
    HugeIcons.strokeRoundedCheckmarkCircle02,
  );

  /// Open a dropdown or expand a section (collapsible sections); rotate for the
  /// other state.
  static const HiveIconData chevronDown = _HugeGlyph(
    HugeIcons.strokeRoundedArrowDown01,
  );

  /// Jump to the newest line of a live log.
  static const HiveIconData scrollToBottom = _HugeGlyph(
    HugeIcons.strokeRoundedArrowDownDouble,
  );

  /// Search.
  static const HiveIconData search = _HugeGlyph(
    HugeIcons.strokeRoundedSearch01,
  );

  /// Retry or reload.
  static const HiveIconData refresh = _HugeGlyph(
    HugeIcons.strokeRoundedRefresh,
  );

  /// More actions.
  static const HiveIconData more = _HugeGlyph(
    HugeIcons.strokeRoundedMoreHorizontal,
  );

  /// Start.
  static const HiveIconData play = _HugeGlyph(HugeIcons.strokeRoundedPlay);

  /// Pause.
  static const HiveIconData pause = _HugeGlyph(HugeIcons.strokeRoundedPause);

  /// Stop or cancel a run.
  static const HiveIconData stop = _HugeGlyph(HugeIcons.strokeRoundedStop);

  /// Edit.
  static const HiveIconData edit = _HugeGlyph(HugeIcons.strokeRoundedEdit02);

  /// Delete.
  static const HiveIconData delete = _HugeGlyph(
    HugeIcons.strokeRoundedDelete02,
  );

  /// Copy.
  static const HiveIconData copy = _HugeGlyph(HugeIcons.strokeRoundedCopy01);

  /// Folder or workspace.
  static const HiveIconData folder = _HugeGlyph(
    HugeIcons.strokeRoundedFolder01,
  );

  /// Git branch or snapshot.
  static const HiveIconData branch = _HugeGlyph(
    HugeIcons.strokeRoundedGitBranch,
  );

  /// Time or duration.
  static const HiveIconData clock = _HugeGlyph(HugeIcons.strokeRoundedClock01);

  /// Inbox.
  static const HiveIconData inbox = _HugeGlyph(HugeIcons.strokeRoundedInbox);

  /// Backend connected.
  static const HiveIconData connected = _HugeGlyph(
    HugeIcons.strokeRoundedWifi01,
  );

  /// Backend disconnected.
  static const HiveIconData disconnected = _HugeGlyph(
    HugeIcons.strokeRoundedWifiDisconnected01,
  );

  // Faces and harness logos.

  /// The flat Hive robot: fallback agent face.
  static const HiveIconData robot = _SvgGlyph('assets/svg/hive_robot.svg');

  /// Claude Code: the Hugeicons free Claude logo.
  static const HiveIconData harnessClaudeCode = _HugeGlyph(
    HugeIcons.strokeRoundedClaude,
  );

  /// Codex: the Hugeicons free OpenAI (ChatGPT) logo.
  static const HiveIconData harnessCodex = _HugeGlyph(
    HugeIcons.strokeRoundedChatGpt,
  );

  /// Gemini CLI: the Hugeicons free Google Gemini logo.
  static const HiveIconData harnessGeminiCli = _HugeGlyph(
    HugeIcons.strokeRoundedGoogleGemini,
  );

  /// Antigravity: reuses the Gemini logo (owner decision, 2026-11-20).
  ///
  /// Hugeicons has no Antigravity logo and Google lists product icons under
  /// "ask first", so the official press kit SVG is not bundled.
  static const HiveIconData harnessAntigravity = harnessGeminiCli;

  /// Terminal harness: the Hive robot.
  static const HiveIconData harnessTerminal = robot;

  /// Every interface icon by name, for galleries.
  static const Map<String, HiveIconData> interface = <String, HiveIconData>{
    'overview': overview,
    'workflows': workflows,
    'runs': runs,
    'pauses': pauses,
    'agents': agents,
    'harnesses': harnesses,
    'settings': settings,
    'expandRail': expandRail,
    'collapseRail': collapseRail,
    'terminal': terminal,
    'validatorTests': validatorTests,
    'validatorChecklist': validatorChecklist,
    'validatorReview': validatorReview,
    'person': person,
    'add': add,
    'close': close,
    'check': check,
    'alert': alert,
    'info': info,
    'success': success,
    'chevronDown': chevronDown,
    'scrollToBottom': scrollToBottom,
    'search': search,
    'refresh': refresh,
    'more': more,
    'play': play,
    'pause': pause,
    'stop': stop,
    'edit': edit,
    'delete': delete,
    'copy': copy,
    'folder': folder,
    'branch': branch,
    'clock': clock,
    'inbox': inbox,
    'connected': connected,
    'disconnected': disconnected,
  };

  /// Every harness logo by name, for galleries.
  static const Map<String, HiveIconData> harnessLogos = <String, HiveIconData>{
    'harnessClaudeCode': harnessClaudeCode,
    'harnessCodex': harnessCodex,
    'harnessGeminiCli': harnessGeminiCli,
    'harnessAntigravity': harnessAntigravity,
    'harnessTerminal': harnessTerminal,
  };
}

/// Renders a [HiveIconData].
///
/// Size and color default to the ambient `IconTheme`, which `HiveSurface`
/// and the catalog components set from tokens.
class HiveIcon extends StatelessWidget {
  /// Creates an icon. Pass [semanticLabel] when the icon carries meaning on
  /// its own; leave it null for decorative icons next to text.
  const new(this.icon, {this.size, this.color, this.semanticLabel, super.key});

  /// The icon to draw.
  final HiveIconData icon;

  /// Logical size; defaults to the ambient `IconTheme` size, then 24.
  final double? size;

  /// Color; defaults to the ambient `IconTheme` color.
  final Color? color;

  /// Accessibility label, or null when decorative.
  final String? semanticLabel;

  @override
  Widget build(BuildContext context) {
    final iconTheme = IconTheme.of(context);
    final glyph = icon.build(
      size: size ?? iconTheme.size ?? context.hiveSpacing.space3,
      color: color ?? iconTheme.color ?? context.hiveColors.onSurface,
    );
    final label = semanticLabel;
    if (label == null) return ExcludeSemantics(child: glyph);
    return Semantics(
      label: label,
      image: true,
      child: ExcludeSemantics(child: glyph),
    );
  }
}
