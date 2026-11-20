import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_literal_spacing.dart';
import 'package:test/test.dart';

void main() {
  group('NoLiteralSpacing', () {
    late _NoLiteralSpacingTest helper;

    setUp(() {
      helper = _NoLiteralSpacingTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags EdgeInsets literals', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/painting.dart';

const a = EdgeInsets.all(16);
const b = EdgeInsets.symmetric(horizontal: 8.0);
const c = EdgeInsets.only(left: 12);
''',
        [helper.lint(66, 2), helper.lint(114, 3), helper.lint(152, 2)],
      );
    });

    test('flags EdgeInsetsDirectional literals', () async {
      final directionalHelper = _NoLiteralDirectionalSpacingTest()..setUp();
      try {
        await directionalHelper.assertDiagnostics(
          '''
import 'package:flutter/painting.dart';

const c = EdgeInsetsDirectional.only(start: 12);
''',
          [directionalHelper.lint(85, 2)],
        );
      } finally {
        await directionalHelper.tearDown();
      }
    });

    test('flags SizedBox gaps with numeric literals including const', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/widgets.dart';

const a = SizedBox(width: 16);
const b = SizedBox(height: 8.0);
''',
        [helper.lint(66, 2), helper.lint(98, 3)],
      );
    });

    test('flags Gap-like widgets with numeric literals', () async {
      await helper.assertDiagnostics(
        '''
class Gap {
  const Gap(double mainAxisExtent);
}

class SliverGap {
  const SliverGap(double mainAxisExtent);
}

const a = Gap(16);
const b = SliverGap(8);
''',
        [helper.lint(128, 2), helper.lint(153, 1)],
      );
    });

    test('does not flag zero, shrink/expand, or tokens', () async {
      await helper.assertNoDiagnostics('''
import 'package:flutter/widgets.dart';

class HiveSpacing {
  static const double md = 16;
}

const a = EdgeInsets.zero;
const b = EdgeInsets.all(HiveSpacing.md);
const c = SizedBox.shrink();
const d = SizedBox.expand();
const e = SizedBox(width: HiveSpacing.md);
const f = SizedBox(width: double.infinity);
''');
    });
  });
}

class _NoLiteralSpacingTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoLiteralSpacing();
    super.setUp();
  }
}

class _NoLiteralDirectionalSpacingTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoLiteralSpacing();
    newPackage('flutter').addFile('lib/painting.dart', '''
class EdgeInsetsDirectional {
  const EdgeInsetsDirectional.only({double start = 0});
}
''');
    super.setUp();
  }
}
