import 'package:design_system/design_system.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:hive_widgetbook/main.dart';
import 'package:material_ui/material_ui.dart';

/// Use cases selected from the navigation tree, with text each must show.
const Map<String, String> _useCases = <String, String>{
  'Colors': 'Color roles',
  'Typography': 'Type scale',
  'Icons': 'moveDown',
  'Motion': 'Page transition',
  'Primary · Default': 'Run workflow',
  'Collapsed (default)': '',
  'Interactive shell': 'Nothing in Overview yet',
  'Search input': 'Search by id, name, description or tag',
  'Mono prompt (filled)': 'Prompt',
  'Tag editor': 'design-system',
  'Tag filter row': 'backend',
  'Read-only · Default': 'login-mockup.png · 248 KB',
  'Read-only · Removed': 'login-mockup.png · 248 KB',
  'Text only': 'With errors',
  'Conflict · Changed on disk': 'Reload from disk',
  'Parse error detail': 'This agent could not be read',
  'Agent prompt': 'Execution guidance',
  'Agent editor composition': 'Capabilities & tools',
  'Narrow · Master': 'Release manager',
  'Tray icons': 'Asset keys',
  'Stop backend confirmation': 'Stop backend and quit?',
  'Interactive (modal route)': 'No choice yet',
  'Loading sizes': 'Loading sizes',
  'success · Default icon': 'Claude Code is ready',
  'Long message': '',
  'Danger · Default': 'Run workflow',
  'Danger hover · Hovered': '',
  'Single-line · Focused': 'Workflow name',
  'Single-line · Error': 'Name is required.',
  'Multi-line · Default': 'Description',
  'Select · Hovered': 'Source output',
  'Select · Error': 'An edge needs a source output.',
  'On · Focused': '',
  'With label': 'Entry node',
  'Delete confirmation': 'Delete "Release checklist"?',
  'With content': 'Release checklist (copy)',
  'Selected · Focused': 'Failed',
  'Status filter bar': 'Interrupted',
  'Title and copy': 'Checkpoint 42 · state',
  'Max height · Scrolls both ways': 'Event log · run_tests',
  'Empty payload': 'This event has no payload.',
  'Interrupted': '',
  'Cancelled': '',
  'Variables · Filled': 'ANTHROPIC_MODEL',
  'Variables · Empty': 'No environment variables.',
  'Variables · Duplicate and empty keys': 'Duplicate key',
  'Variables · Interactive': 'Add variable',
  'Arguments · Filled': '--verbose',
  'Arguments · Error': 'Remove empty arguments.',
  'Arguments · Disabled': 'Add argument',
  'Interactive · Taken over': 'Hand back',
  'Ended': 'Session ended',
  'ANSI palette': 'Take over',
  'Overview row': 'Succeeded today',
  'Long value and label': '1,284,356',
  'Title bar · Restored': '',
  'Title bar · Maximized': '',
  'Busy · Deleting': 'Deleting…',
  'Busy · Stopping runs': 'Deleting… (stopping 2 of 3 runs)',
  'Busy · with disabled actions': 'Release checklist',
  'Disabled · With reason': '',
  'Compact · Badge and action': 'Skill installed',
  'Compact · danger': 'This agent could not be read',
  'With label and helper text':
      'Automatically install the skill for newly detected harnesses.',
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

  testWidgets('interactive dialog use case opens and confirms', (tester) async {
    await tester.pumpWidget(const HiveWidgetbook());
    await tester.pump();

    final node = find.text('Interactive (modal route)').first;
    await tester.ensureVisible(node);
    await tester.pump();
    await tester.tap(node);
    await tester.pump(const Duration(milliseconds: 500));

    await tester.tap(find.text('Stop Backend & Quit'));
    await tester.pump(const Duration(milliseconds: 500));
    expect(find.byType(HiveDialog), findsOneWidget);

    await tester.tap(find.text('Stop backend'));
    await tester.pump(const Duration(milliseconds: 500));

    expect(tester.takeException(), isNull);
    expect(find.byType(HiveDialog), findsNothing);
    expect(find.text('Confirmed: stop backend'), findsOneWidget);
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
