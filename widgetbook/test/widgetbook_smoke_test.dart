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
}
