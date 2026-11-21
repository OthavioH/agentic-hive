import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_widgetbook/main.dart';
import 'package:material_ui/material_ui.dart';

/// Use cases selected from the navigation tree, with text each must show.
const Map<String, String> _useCases = <String, String>{
  'Colors': 'Color roles',
  'Typography': 'Type scale',
  'Motion': 'Page transition',
  'Primary · Default': 'Run workflow',
  'Collapsed (default)': '',
  'Interactive shell': 'Nothing in Overview yet',
  'Loading sizes': 'Loading sizes',
  'success · Default icon': 'Claude Code is ready',
  'Long message': '',
  'Danger · Default': 'Run workflow',
  'Single-line · Focused': 'Workflow name',
  'Single-line · Error': 'Name is required.',
  'Multi-line · Default': 'Description',
  'Select · Hovered': 'Source output',
  'Select · Error': 'An edge needs a source output.',
  'On · Focused': '',
  'With label': 'Entry node',
  'Delete confirmation': 'Delete "Release checklist"?',
  'With content': 'Release checklist (copy)',
};

void main() {
  setUp(() {
    final binding = TestWidgetsFlutterBinding.ensureInitialized();
    binding.platformDispatcher.views.first
      ..physicalSize = const Size(2560, 1600)
      ..devicePixelRatio = 1;
  });

  tearDown(() {
    TestWidgetsFlutterBinding.instance.platformDispatcher.views.first
      ..resetPhysicalSize()
      ..resetDevicePixelRatio();
  });

  for (final entry in _useCases.entries) {
    testWidgets('selecting "${entry.key}" renders without exceptions', (
      tester,
    ) async {
      await tester.pumpWidget(const HiveWidgetbook());
      await tester.pump();

      final node = find.text(entry.key).first;
      await tester.ensureVisible(node);
      await tester.pump();
      await tester.tap(node);
      for (var i = 0; i < 10; i++) {
        await tester.pump(const Duration(milliseconds: 100));
      }

      expect(tester.takeException(), isNull);
      expect(find.byType(WidgetsApp), findsWidgets);
      if (entry.value.isNotEmpty) {
        expect(find.text(entry.value), findsWidgets);
      }
    });
  }

  testWidgets('agent card composition sizes to its content', (tester) async {
    await tester.pumpWidget(const HiveWidgetbook());
    await tester.pump();

    final node = find.text('Agent card composition').first;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.tap(node);
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    final card = find.byType(HiveCard);
    expect(card, findsOneWidget);
    final avatar = find.byType(HiveAgentAvatar);
    final badge = find.byType(HiveBadge);
    final title = find.text('Review pull request');
    final detail = find.text('Gemini CLI · asking a question');
    final column = find
        .ancestor(of: title, matching: find.byType(Column))
        .first;

    // The text column hugs its two lines instead of filling the card.
    expect(
      tester.getSize(column).height,
      tester.getSize(title).height + tester.getSize(detail).height,
    );

    // The card hugs its tallest child plus `space3` padding and hairlines.
    final tallest = <double>[
      tester.getSize(avatar).height,
      tester.getSize(column).height,
      tester.getSize(badge).height,
    ].reduce((a, b) => a > b ? a : b);
    expect(
      tester.getSize(card).height,
      tallest +
          HiveSpacing.standard.space3 * 2 +
          HiveElevation.dark.hairline * 2,
    );

    // Avatar, text and badge share the top edge.
    final top = tester.getTopLeft(title).dy;
    expect(tester.getTopLeft(avatar).dy, top);
    expect(tester.getTopLeft(badge).dy, top);
  });

  testWidgets('live toast use case shows and dismisses a toast', (
    tester,
  ) async {
    await tester.pumpWidget(const HiveWidgetbook());
    await tester.pump();

    final node = find.text('Live').last;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.tap(node);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Copy path'));
    await tester.pump();
    expect(find.byType(HiveToast), findsOneWidget);
    expect(tester.takeException(), isNull);

    await tester.pump(HiveMotionTokens.standard.medium);
    await tester.pump(HiveToast.displayDuration);
    await tester.pump();
    await tester.pump(HiveMotionTokens.standard.short);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(find.byType(HiveToast), findsNothing);
  });

  testWidgets('re-check flow loads, then confirms with a toast', (
    tester,
  ) async {
    await tester.pumpWidget(const HiveWidgetbook());
    await tester.pump();

    final node = find.text('Re-check flow').first;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.tap(node);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.byType(HiveIconButton));
    await tester.pump();
    expect(find.byType(HiveIcon), findsNothing);

    await tester.pump(HiveMotionTokens.standard.long * 2);
    await tester.pump();
    expect(find.text('Claude Code is ready'), findsOneWidget);

    await tester.pump(HiveMotionTokens.standard.medium);
    await tester.pump(HiveToast.displayDuration);
    await tester.pump();
    await tester.pump(HiveMotionTokens.standard.short);
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump();
    expect(tester.takeException(), isNull);
  });
}
