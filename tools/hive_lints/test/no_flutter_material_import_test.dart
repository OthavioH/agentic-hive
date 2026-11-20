import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_flutter_material_import.dart';
import 'package:test/test.dart';

void main() {
  group('NoFlutterMaterialImport', () {
    late _NoFlutterMaterialImportTest helper;

    setUp(() {
      helper = _NoFlutterMaterialImportTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags package:flutter/material.dart and cupertino.dart', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/material.dart';
import 'package:flutter/cupertino.dart';

const c1 = Colors.red;
const c2 = CupertinoColors.white;
''',
        [helper.lint(0, 39), helper.lint(40, 40)],
      );
    });

    test('does not flag widgets.dart or design_system imports', () async {
      await helper.assertNoDiagnostics('''
import 'package:design_system/design_system.dart';
import 'package:flutter/widgets.dart';

const Type t1 = HiveTheme;
const Type t2 = Widget;
''');
    });
  });
}

class _NoFlutterMaterialImportTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoFlutterMaterialImport();
    newPackage('design_system').addFile('lib/design_system.dart', '''
class HiveTheme {}
''');
    super.setUp();
  }
}
