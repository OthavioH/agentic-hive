import 'package:design_system/src/components/hive_button.dart';
import 'package:design_system/src/icons/hive_icons.dart';
import 'package:design_system/src/tokens/hive_tokens_context.dart';
import 'package:flutter/scheduler.dart';
import 'package:material_ui/material_ui.dart';

/// Shared follow-bottom scrolling behavior for live streaming viewers.
///
/// States using this mixin must call [initFollowBottom] in `initState` and
/// [disposeFollowBottom] in `dispose`, attach [followScrollController] to their
/// `Scrollbar` and `ListView`, and call [onFollowContentChanged] when items
/// change.
mixin HiveFollowBottomMixin<T extends StatefulWidget> on State<T> {
  /// Scroll controller attached to the scrollable list and its scrollbar.
  final ScrollController followScrollController = ScrollController();

  bool _following = true;
  bool _scrollScheduled = false;

  /// Whether the viewer is pinned to the bottom and follows new content.
  bool get isFollowing => _following;

  /// Attaches scroll listener and schedules the initial jump to the end.
  void initFollowBottom() {
    followScrollController.addListener(_onScroll);
    _scheduleScrollToEnd();
  }

  /// Disposes [followScrollController].
  void disposeFollowBottom() {
    followScrollController.dispose();
  }

  /// Rebuilds and schedules a scroll to the end if [isFollowing] is true.
  void onFollowContentChanged() {
    setState(() {});
    if (_following) _scheduleScrollToEnd();
  }

  /// Follows again only once the user is back within `space1` of the end.
  void _onScroll() {
    if (!followScrollController.hasClients) return;
    final position = followScrollController.position;
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

  /// Jumps to the end. Lazily built items only estimate the scroll extent,
  /// so the jump repeats after layout until the extent settles.
  void _scrollToEnd({required int attemptsLeft}) {
    if (!mounted || !_following || !followScrollController.hasClients) return;
    final position = followScrollController.position;
    if (position.pixels == position.maxScrollExtent) return;
    position.jumpTo(position.maxScrollExtent);
    if (attemptsLeft > 1) {
      SchedulerBinding.instance.addPostFrameCallback(
        (_) => _scrollToEnd(attemptsLeft: attemptsLeft - 1),
      );
    }
  }

  /// Scrolls to the newest item and resumes following.
  void jumpToBottom() {
    setState(() => _following = true);
    _scrollToEnd(attemptsLeft: 3);
  }

  /// Builds the floating Jump-to-bottom button positioned in the bottom-end
  /// corner of a [Stack].
  Widget buildJumpToBottomButton(String label) {
    final spacing = context.hiveSpacing;
    return PositionedDirectional(
      end: spacing.space2,
      bottom: spacing.space2,
      child: HiveButton(
        label: label,
        icon: HiveIcons.scrollToBottom,
        variant: HiveButtonVariant.secondary,
        size: HiveButtonSize.small,
        onPressed: jumpToBottom,
      ),
    );
  }
}
