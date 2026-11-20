import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_literal_radius.dart';
import 'package:test/test.dart';

void main() {
  group('NoLiteralRadius', () {
    late _NoLiteralRadiusTest helper;

    setUp(() {
      helper = _NoLiteralRadiusTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags BorderRadius and Radius with numeric literals', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/painting.dart';

final a = BorderRadius.circular(8);
const b = Radius.circular(12.0);
const c = Radius.elliptical(4, 6);
const d = BorderRadius.all(Radius.circular(12));
''',
        [
          helper.lint(73, 1),
          helper.lint(103, 4),
          helper.lint(138, 1),
          helper.lint(141, 1),
          helper.lint(188, 2),
        ],
      );
    });

    test('does not flag BorderRadius.zero, Radius.zero, or tokens', () async {
      await helper.assertNoDiagnostics('''
import 'package:flutter/painting.dart';

class HiveRadius {
  static const double md = 8;
  static const Radius card = Radius.zero;
}

const a = BorderRadius.zero;
const b = Radius.zero;
final c = BorderRadius.circular(HiveRadius.md);
const d = BorderRadius.all(HiveRadius.card);
''');
    });
  });
}

class _NoLiteralRadiusTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoLiteralRadius();
    super.setUp();
  }
}
