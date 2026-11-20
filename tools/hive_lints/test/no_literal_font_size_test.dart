import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_literal_font_size.dart';
import 'package:test/test.dart';

void main() {
  group('NoLiteralFontSize', () {
    late _NoLiteralFontSizeTest helper;

    setUp(() {
      helper = _NoLiteralFontSizeTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags TextStyle with literal fontSize', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/painting.dart';

const s = TextStyle(fontSize: 14);
const s2 = TextStyle(fontSize: 16.5);
''',
        [helper.lint(61, 12), helper.lint(97, 14)],
      );
    });

    test('does not flag TextStyle without literal fontSize', () async {
      await helper.assertNoDiagnostics('''
import 'package:flutter/painting.dart';

class HiveTypography {
  static const double bodySize = 14;
}

const a = TextStyle(fontSize: HiveTypography.bodySize);
const b = TextStyle();
''');
    });
  });
}

class _NoLiteralFontSizeTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoLiteralFontSize();
    super.setUp();
  }
}
