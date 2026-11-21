import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

void main() {
  group('HiveMasterDetail', () {
    Future<void> pump(
      WidgetTester tester, {
      required double width,
      bool detailVisible = false,
    }) {
      return tester.pumpWidget(
        hiveTestApp(
          child: Center(
            child: SizedBox(
              width: width,
              height: 400,
              child: HiveMasterDetail(
                detailVisible: detailVisible,
                master: const Text('Agent list'),
                detail: const Text('Agent editor'),
              ),
            ),
          ),
        ),
      );
    }

    testWidgets('shows both panes with a 320 master when wide', (tester) async {
      await tester.binding.setSurfaceSize(const Size(1200, 600));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      await pump(tester, width: 1000);

      expect(find.text('Agent list'), findsOneWidget);
      expect(find.text('Agent editor'), findsOneWidget);
      final master = find
          .ancestor(
            of: find.text('Agent list'),
            matching: find.byType(SizedBox),
          )
          .first;
      expect(tester.getSize(master).width, HiveSpacing.standard.space8 * 5);
    });

    testWidgets('collapses to the master pane when narrow', (tester) async {
      await pump(tester, width: 500);

      expect(find.text('Agent list'), findsOneWidget);
      expect(find.text('Agent editor'), findsNothing);
    });

    testWidgets('collapses to the detail pane when it is visible', (
      tester,
    ) async {
      await pump(tester, width: 500, detailVisible: true);

      expect(find.text('Agent list'), findsNothing);
      expect(find.text('Agent editor'), findsOneWidget);
    });
  });

  group('HiveCollapsibleSection', () {
    Widget section({
      bool initiallyExpanded = false,
      ValueChanged<bool>? onExpansionChanged,
    }) {
      return hiveTestApp(
        child: HiveCollapsibleSection(
          title: 'Capabilities & tools',
          subtitle: '4 tools declared',
          initiallyExpanded: initiallyExpanded,
          onExpansionChanged: onExpansionChanged,
          child: const HiveTextField(label: 'Required skills'),
        ),
      );
    }

    testWidgets('starts collapsed and expands on tap', (tester) async {
      final changes = <bool>[];
      await tester.pumpWidget(section(onExpansionChanged: changes.add));

      expect(find.text('Required skills'), findsNothing);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Capabilities & tools')),
        matchesSemantics(
          label: 'Capabilities & tools',
          isButton: true,
          hasExpandedState: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );

      await tester.tap(find.text('Capabilities & tools'));
      await tester.pumpAndSettle();

      expect(changes, <bool>[true]);
      expect(find.text('Required skills'), findsOneWidget);
      expect(
        tester.getSemantics(find.bySemanticsLabel('Capabilities & tools')),
        matchesSemantics(
          label: 'Capabilities & tools',
          isButton: true,
          hasExpandedState: true,
          isExpanded: true,
          hasEnabledState: true,
          isEnabled: true,
          hasTapAction: true,
        ),
      );
    });

    testWidgets('collapses with the keyboard and keeps body state', (
      tester,
    ) async {
      await tester.pumpWidget(section(initiallyExpanded: true));
      await tester.enterText(find.byType(TextField), 'flutter-validation');
      await tester.pump();

      // Header is the first focusable control.
      FocusManager.instance.primaryFocus?.unfocus();
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pumpAndSettle();
      expect(find.text('flutter-validation'), findsNothing);

      await tester.tap(find.text('Capabilities & tools'));
      await tester.pumpAndSettle();
      expect(find.text('flutter-validation'), findsOneWidget);
    });

    testWidgets('collapsed body is out of focus traversal', (tester) async {
      await tester.pumpWidget(section());

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();

      final focused = FocusManager.instance.primaryFocus?.context;
      expect(
        focused == null ||
            find
                .descendant(
                  of: find.byType(HiveTextField),
                  matching: find.byWidget(focused.widget),
                )
                .evaluate()
                .isEmpty,
        isTrue,
      );
    });
  });

  group('HiveMarkdownView', () {
    const source = '''
# Code reviewer

Reviews **pull requests** for *style* and `dart analyze` issues.

## Responsibilities

- Read the diff
- Comment on [docs](https://dart.dev)

1. First
2. Second

> Never approve your own changes.

```
dart analyze --fatal-infos
```

| Tool | Allowed |
| --- | --- |
| git | yes |

- [x] Done
- [ ] Todo

---
''';

    testWidgets('renders headings, lists, quotes, code and tables', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const SingleChildScrollView(
            child: HiveMarkdownView(data: source),
          ),
        ),
      );

      expect(find.text('Code reviewer'), findsOneWidget);
      expect(find.text('Responsibilities'), findsOneWidget);
      expect(find.textContaining('pull requests'), findsOneWidget);
      expect(find.text('Read the diff'), findsOneWidget);
      expect(find.text('•'), findsNWidgets(4));
      expect(find.text('1.'), findsOneWidget);
      expect(find.text('2.'), findsOneWidget);
      expect(find.text('Never approve your own changes.'), findsOneWidget);
      expect(find.text('dart analyze --fatal-infos'), findsOneWidget);
      expect(find.byType(Table), findsOneWidget);
      expect(find.text('git'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('headings are semantic headers', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveMarkdownView(data: '# Code reviewer')),
      );

      expect(
        tester.getSemantics(find.text('Code reviewer')),
        matchesSemantics(label: 'Code reviewer', isHeader: true),
      );
    });

    testWidgets('uses the title role for h1 and mono for code blocks', (
      tester,
    ) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveMarkdownView(data: '# Title\n\n```\ncode\n```'),
        ),
      );

      final title = tester.widget<Text>(find.text('Title'));
      expect(
        title.textSpan?.style?.fontSize,
        HiveTypography.standard.title.fontSize,
      );
      final code = tester.widget<Text>(find.text('code'));
      expect(code.style?.fontFamily, contains(HiveFontFamilies.mono));
    });

    testWidgets('calls onTapLink with the link target', (tester) async {
      final links = <String>[];
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveMarkdownView(
            data: 'See [the docs](https://dart.dev).',
            selectable: false,
            onTapLink: links.add,
          ),
        ),
      );

      await tester.tapOnText(find.textRange.ofSubstring('the docs'));
      await tester.pump();

      expect(links, <String>['https://dart.dev']);
    });

    testWidgets('re-renders when the data changes', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveMarkdownView(data: 'First')),
      );
      expect(find.text('First'), findsOneWidget);

      await tester.pumpWidget(
        hiveTestApp(child: const HiveMarkdownView(data: 'Second')),
      );
      expect(find.text('First'), findsNothing);
      expect(find.text('Second'), findsOneWidget);
    });

    testWidgets('shows raw HTML as text', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(child: const HiveMarkdownView(data: '<b>not bold</b>')),
      );

      expect(find.textContaining('<b>'), findsOneWidget);
    });
  });
}
