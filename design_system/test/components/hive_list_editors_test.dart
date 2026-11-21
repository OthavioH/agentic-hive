import 'package:design_system/design_system.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:material_ui/material_ui.dart';

import '../helpers/hive_test_harness.dart';

typedef _Pairs = List<MapEntry<String, String>>;

Map<String, String> _asMap(_Pairs pairs) =>
    Map<String, String>.fromEntries(pairs);

EditableText _editable(WidgetTester tester, int index) =>
    tester.widget<EditableText>(find.byType(EditableText).at(index));

/// Hosts an editor that writes its value back, like a feature would.
class _Host<T> extends StatefulWidget {
  const new({required this.initial, required this.builder, this.onValue});

  final T initial;
  final Widget Function(T value, ValueChanged<T> onChanged) builder;
  final ValueChanged<T>? onValue;

  @override
  State<_Host<T>> createState() => _HostState<T>();
}

class _HostState<T> extends State<_Host<T>> {
  late T _value = widget.initial;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 640,
      child: widget.builder(_value, (value) {
        widget.onValue?.call(value);
        setState(() => _value = value);
      }),
    );
  }
}

Widget _keyValueHost({
  required _Pairs initial,
  required List<_Pairs> log,
  bool enabled = true,
  String? emptyText,
}) {
  return hiveTestApp(
    child: _Host<_Pairs>(
      initial: initial,
      onValue: log.add,
      builder: (value, onChanged) => HiveKeyValueEditor(
        label: 'Environment',
        helperText: 'Passed to the harness process.',
        keyPlaceholder: 'NAME',
        valuePlaceholder: 'value',
        addButtonLabel: 'Add variable',
        emptyText: emptyText,
        entries: value,
        enabled: enabled,
        onChanged: onChanged,
      ),
    ),
  );
}

Widget _listHost({
  required List<String> initial,
  required List<List<String>> log,
  bool enabled = true,
  String? emptyText,
}) {
  return hiveTestApp(
    child: _Host<List<String>>(
      initial: initial,
      onValue: log.add,
      builder: (value, onChanged) => HiveStringListField(
        label: 'Extra arguments',
        helperText: 'Appended to the harness command.',
        itemLabel: 'Argument',
        itemPlaceholder: '--flag',
        addButtonLabel: 'Add argument',
        emptyText: emptyText,
        items: value,
        enabled: enabled,
        onChanged: onChanged,
      ),
    ),
  );
}

void main() {
  group('HiveKeyValueEditor', () {
    testWidgets('renders the label, rows, add button and helper', (
      tester,
    ) async {
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('ANTHROPIC_MODEL', 'opus'),
            MapEntry<String, String>('LOG_LEVEL', 'debug'),
          ],
          log: <_Pairs>[],
        ),
      );

      expect(find.text('Environment'), findsOneWidget);
      expect(find.byType(HiveTextField), findsNWidgets(4));
      expect(find.text('ANTHROPIC_MODEL'), findsOneWidget);
      expect(find.text('debug'), findsOneWidget);
      expect(find.text('Add variable'), findsOneWidget);
      expect(find.text('Passed to the harness process.'), findsOneWidget);
      // Row fields hide their visible label.
      expect(find.text('Key 1'), findsNothing);
    });

    testWidgets('shows the empty text with no rows', (tester) async {
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[],
          log: <_Pairs>[],
          emptyText: 'No variables yet.',
        ),
      );

      expect(find.text('No variables yet.'), findsOneWidget);
      expect(find.byType(HiveTextField), findsNothing);
    });

    testWidgets('adding a row emits it and focuses its key', (tester) async {
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[],
          log: log,
          emptyText: 'No variables yet.',
        ),
      );

      await tester.tap(find.text('Add variable'));
      await tester.pumpAndSettle();

      expect(find.text('No variables yet.'), findsNothing);
      expect(find.byType(HiveTextField), findsNWidgets(2));
      expect(log.single, hasLength(1));
      expect(log.single.single.key, isEmpty);
      expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
    });

    testWidgets('editing a key keeps the row, its focus and its order', (
      tester,
    ) async {
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('B', '2'),
            MapEntry<String, String>('C', '3'),
          ],
          log: log,
        ),
      );

      final firstKey = find.byType(EditableText).first;
      await tester.tap(firstKey);
      await tester.pump();
      await tester.enterText(firstKey, 'Z');
      await tester.pumpAndSettle();

      expect(_asMap(log.last), <String, String>{'Z': '2', 'C': '3'});
      expect(log.last.first.key, 'Z');
      expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
      expect(_editable(tester, 0).controller.text, 'Z');
    });

    testWidgets('editing a value emits the new pair', (tester) async {
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('LOG_LEVEL', 'info'),
          ],
          log: log,
        ),
      );

      await tester.enterText(find.byType(EditableText).at(1), 'debug');
      await tester.pump();

      expect(_asMap(log.last), <String, String>{'LOG_LEVEL': 'debug'});
    });

    testWidgets('removing a row emits the rest and focuses a neighbour', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('A', '1'),
            MapEntry<String, String>('B', '2'),
          ],
          log: log,
        ),
      );

      expect(find.bySemanticsLabel('Remove A'), findsOneWidget);
      await tester.tap(find.bySemanticsLabel('Remove A'));
      await tester.pumpAndSettle();

      expect(_asMap(log.last), <String, String>{'B': '2'});
      expect(find.byType(HiveTextField), findsNWidgets(2));
      expect(_editable(tester, 0).controller.text, 'B');
      expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
      handle.dispose();
    });

    testWidgets('removing the last row focuses the add button', (tester) async {
      final handle = tester.ensureSemantics();
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('A', '1'),
          ],
          log: log,
        ),
      );

      await tester.tap(find.bySemanticsLabel('Remove A'));
      await tester.pumpAndSettle();

      expect(log.last, isEmpty);
      final button = tester.widget<HiveButton>(find.byType(HiveButton));
      expect(button.focusNode!.hasFocus, isTrue);
      handle.dispose();
    });

    testWidgets('Enter moves from key to value, then adds a row', (
      tester,
    ) async {
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('A', '1'),
          ],
          log: log,
        ),
      );

      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.next);
      await tester.pumpAndSettle();
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);

      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(HiveTextField), findsNWidgets(4));
      expect(log.last, hasLength(2));
      expect(_editable(tester, 2).focusNode.hasFocus, isTrue);
    });

    testWidgets('flags duplicate keys and empty keys with a value', (
      tester,
    ) async {
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('A', '1'),
            MapEntry<String, String>('A', '2'),
            MapEntry<String, String>('', '3'),
            MapEntry<String, String>('', ''),
          ],
          log: <_Pairs>[],
        ),
      );

      expect(find.text('Duplicate key'), findsNWidgets(2));
      expect(find.text('Key is required'), findsOneWidget);
    });

    testWidgets('shows the error text in place of the helper', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveKeyValueEditor(
            label: 'Environment',
            helperText: 'Passed to the harness process.',
            errorText: 'Fix the duplicate keys.',
            entries: const <MapEntry<String, String>>[],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Fix the duplicate keys.'), findsOneWidget);
      expect(find.text('Passed to the harness process.'), findsNothing);
    });

    testWidgets('disabled editor ignores input', (tester) async {
      final log = <_Pairs>[];
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('A', '1'),
          ],
          log: log,
          enabled: false,
        ),
      );

      expect(_editable(tester, 0).readOnly, isTrue);
      expect(
        tester.widget<HiveIconButton>(find.byType(HiveIconButton)).onPressed,
        isNull,
      );
      expect(
        tester.widget<HiveButton>(find.byType(HiveButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Add variable'), warnIfMissed: false);
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('a null onChanged disables the editor', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveKeyValueEditor(
            entries: <MapEntry<String, String>>[],
            onChanged: null,
          ),
        ),
      );

      expect(
        tester.widget<HiveButton>(find.byType(HiveButton)).onPressed,
        isNull,
      );
    });

    testWidgets('announces rows, group and buttons to semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _keyValueHost(
          initial: const <MapEntry<String, String>>[
            MapEntry<String, String>('', ''),
          ],
          log: <_Pairs>[],
        ),
      );

      expect(find.bySemanticsLabel(RegExp('Environment')), findsWidgets);
      expect(find.bySemanticsLabel(RegExp('^Key 1')), findsOneWidget);
      expect(find.bySemanticsLabel(RegExp('^Value 1')), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Key 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Add variable'), findsOneWidget);
      handle.dispose();
    });

    testWidgets('syncs rows when the parent replaces the entries', (
      tester,
    ) async {
      Widget build(_Pairs entries) => hiveTestApp(
        child: HiveKeyValueEditor(entries: entries, onChanged: (_) {}),
      );

      await tester.pumpWidget(
        build(const <MapEntry<String, String>>[
          MapEntry<String, String>('A', '1'),
        ]),
      );
      await tester.pumpWidget(
        build(const <MapEntry<String, String>>[
          MapEntry<String, String>('X', '9'),
          MapEntry<String, String>('Y', '8'),
        ]),
      );

      expect(find.byType(HiveTextField), findsNWidgets(4));
      expect(_editable(tester, 0).controller.text, 'X');
      expect(_editable(tester, 3).controller.text, '8');
    });
  });

  group('HiveStringListField', () {
    testWidgets('renders the label, items, add button and helper', (
      tester,
    ) async {
      await tester.pumpWidget(
        _listHost(
          initial: const <String>['--verbose', '--model=opus'],
          log: <List<String>>[],
        ),
      );

      expect(find.text('Extra arguments'), findsOneWidget);
      expect(find.byType(HiveTextField), findsNWidgets(2));
      expect(find.text('--verbose'), findsOneWidget);
      expect(find.text('Add argument'), findsOneWidget);
      expect(find.text('Appended to the harness command.'), findsOneWidget);
    });

    testWidgets('shows the empty text with no items', (tester) async {
      await tester.pumpWidget(
        _listHost(
          initial: const <String>[],
          log: <List<String>>[],
          emptyText: 'No extra arguments.',
        ),
      );

      expect(find.text('No extra arguments.'), findsOneWidget);
      expect(find.byType(HiveTextField), findsNothing);
    });

    testWidgets('the add button appends and focuses an item', (tester) async {
      final log = <List<String>>[];
      await tester.pumpWidget(
        _listHost(initial: const <String>['--verbose'], log: log),
      );

      await tester.tap(find.text('Add argument'));
      await tester.pumpAndSettle();

      expect(log.last, <String>['--verbose', '']);
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);

      await tester.enterText(find.byType(EditableText).at(1), '--json');
      await tester.pump();
      expect(log.last, <String>['--verbose', '--json']);
    });

    testWidgets('Enter inserts an item below a non-empty one', (tester) async {
      final log = <List<String>>[];
      await tester.pumpWidget(
        _listHost(initial: const <String>['--a', '--c'], log: log),
      );

      await tester.tap(find.byType(EditableText).first);
      await tester.pump();
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      expect(log.last, <String>['--a', '', '--c']);
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);

      // Enter on the empty item does not add another.
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();
      expect(find.byType(HiveTextField), findsNWidgets(3));
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);
    });

    testWidgets('editing keeps focus and removing emits the rest', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      final log = <List<String>>[];
      await tester.pumpWidget(
        _listHost(initial: const <String>['--a', '--b'], log: log),
      );

      await tester.tap(find.byType(EditableText).at(1));
      await tester.pump();
      await tester.enterText(find.byType(EditableText).at(1), '--bee');
      await tester.pump();
      expect(log.last, <String>['--a', '--bee']);
      expect(_editable(tester, 1).focusNode.hasFocus, isTrue);

      await tester.tap(find.bySemanticsLabel('Remove --a'));
      await tester.pumpAndSettle();
      expect(log.last, <String>['--bee']);
      expect(_editable(tester, 0).focusNode.hasFocus, isTrue);
      handle.dispose();
    });

    testWidgets('disabled field ignores input', (tester) async {
      final log = <List<String>>[];
      await tester.pumpWidget(
        _listHost(initial: const <String>['--a'], log: log, enabled: false),
      );

      expect(_editable(tester, 0).readOnly, isTrue);
      expect(
        tester.widget<HiveIconButton>(find.byType(HiveIconButton)).onPressed,
        isNull,
      );
      await tester.tap(find.text('Add argument'), warnIfMissed: false);
      await tester.pump();
      expect(log, isEmpty);
    });

    testWidgets('shows the error text in place of the helper', (tester) async {
      await tester.pumpWidget(
        hiveTestApp(
          child: HiveStringListField(
            helperText: 'Appended to the harness command.',
            errorText: 'Arguments cannot be empty.',
            items: const <String>[],
            onChanged: (_) {},
          ),
        ),
      );

      expect(find.text('Arguments cannot be empty.'), findsOneWidget);
      expect(find.text('Appended to the harness command.'), findsNothing);
    });

    testWidgets('announces items and buttons to semantics', (tester) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        _listHost(initial: const <String>[''], log: <List<String>>[]),
      );

      expect(find.bySemanticsLabel(RegExp('^Argument 1')), findsOneWidget);
      expect(find.bySemanticsLabel('Remove Argument 1'), findsOneWidget);
      expect(find.bySemanticsLabel('Add argument'), findsOneWidget);
      handle.dispose();
    });
  });

  group('HiveTextField.showLabel', () {
    testWidgets('hides the visible label but keeps it in semantics', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(
        hiveTestApp(
          child: const HiveTextField(label: 'Argument 1', showLabel: false),
        ),
      );

      expect(find.text('Argument 1'), findsNothing);
      expect(find.bySemanticsLabel(RegExp('Argument 1')), findsOneWidget);
      handle.dispose();
    });
  });

  testWidgets('Tab moves from a key to its value', (tester) async {
    await tester.pumpWidget(
      _keyValueHost(
        initial: const <MapEntry<String, String>>[
          MapEntry<String, String>('A', '1'),
        ],
        log: <_Pairs>[],
      ),
    );

    await tester.tap(find.byType(EditableText).first);
    await tester.pump();
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    expect(_editable(tester, 1).focusNode.hasFocus, isTrue);
  });
}
