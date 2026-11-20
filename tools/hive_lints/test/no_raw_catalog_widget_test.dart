import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_raw_catalog_widget.dart';
import 'package:test/test.dart';

void main() {
  group('NoRawCatalogWidget', () {
    late _NoRawCatalogWidgetTest helper;

    setUp(() {
      helper = _NoRawCatalogWidgetTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test(
      'flags all raw Material catalog widgets and named constructors',
      () async {
        await helper.assertDiagnostics(
          '''
import 'package:flutter/material.dart';

const a = ElevatedButton();
const b = FilledButton();
const c = OutlinedButton();
const d = TextButton();
const e = IconButton();
const f = Card();
const g = Chip();
const h = Badge();
const i = Badge.count();
const j = TextField();
const k = TextFormField();
''',
          [
            helper.lint(51, 14),
            helper.lint(79, 12),
            helper.lint(105, 14),
            helper.lint(133, 10),
            helper.lint(157, 10),
            helper.lint(181, 4),
            helper.lint(199, 4),
            helper.lint(217, 5),
            helper.lint(236, 11),
            helper.lint(261, 9),
            helper.lint(284, 13),
          ],
        );
      },
    );

    test('does not flag Hive* catalog widgets', () async {
      await helper.assertNoDiagnostics('''
class HiveButton {
  const HiveButton();
}
class HiveCard {
  const HiveCard();
}

const a = HiveButton();
const b = HiveCard();
''');
    });
  });
}

class _NoRawCatalogWidgetTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoRawCatalogWidget();
    newPackage('flutter').addFile('lib/material.dart', '''
class ElevatedButton {
  const ElevatedButton();
}
class FilledButton {
  const FilledButton();
}
class OutlinedButton {
  const OutlinedButton();
}
class TextButton {
  const TextButton();
}
class IconButton {
  const IconButton();
}
class Card {
  const Card();
}
class Chip {
  const Chip();
}
class Badge {
  const Badge();
  const Badge.count();
}
class TextField {
  const TextField();
}
class TextFormField {
  const TextFormField();
}
''');
    super.setUp();
  }
}
