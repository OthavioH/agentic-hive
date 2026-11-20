import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_literal_color.dart';
import 'package:test/test.dart';

void main() {
  group('NoLiteralColor', () {
    late _NoLiteralColorTest helper;

    setUp(() {
      helper = _NoLiteralColorTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags Color constructor with hex literal', () async {
      await helper.assertDiagnostics(
        '''
import 'dart:ui';

const c = Color(0xFF112233);
''',
        [helper.lint(29, 17)],
      );
    });

    test('flags Color.fromARGB and Color.fromRGBO', () async {
      await helper.assertDiagnostics(
        '''
import 'dart:ui';

const a = Color.fromARGB(255, 10, 20, 30);
const b = Color.fromRGBO(10, 20, 30, 1.0);
''',
        [helper.lint(29, 31), helper.lint(72, 31)],
      );
    });

    test('flags Colors.* and CupertinoColors.* from Flutter', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';

const c = Colors.red;
const d = CupertinoColors.white;
''',
        [helper.lint(92, 10), helper.lint(114, 21)],
      );
    });

    test('does not flag HiveColors or context.hiveColors accessors', () async {
      await helper.assertNoDiagnostics('''
class _Palette {
  const _Palette();
  int get background => 1;
}

class HiveColors {
  static const int surface = 1;
  static const _Palette dark = _Palette();
  int get primary => 2;
  int get accent => 3;
}

class BuildContext {
  HiveColors get hiveColors => HiveColors();
}

void f(BuildContext context) {
  final a = HiveColors.surface;
  final b = HiveColors.dark.background;
  final c = context.hiveColors.accent;
  final hiveColors = context.hiveColors;
  final d = hiveColors.primary;
  final list = [a, b, c, d];
  list.length;
}
''');
    });
  });
}

class _NoLiteralColorTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoLiteralColor();
    super.setUp();
  }
}
