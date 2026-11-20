import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_direct_icon_package.dart';
import 'package:test/test.dart';

void main() {
  group('NoDirectIconPackage', () {
    late _NoDirectIconPackageTest helper;

    setUp(() {
      helper = _NoDirectIconPackageTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags hugeicons import', () async {
      await helper.assertDiagnostics(
        '''
import 'package:hugeicons/hugeicons.dart';

const icon = HugeIcons.home;
''',
        [helper.lint(0, 42)],
      );
    });

    test('flags Icons.* from Flutter material', () async {
      await helper.assertDiagnostics(
        '''
import 'package:flutter/material.dart';

const icon = Icons.alarm;
''',
        [helper.lint(54, 11)],
      );
    });

    test('does not flag HiveIcons', () async {
      await helper.assertNoDiagnostics('''
class HiveIcons {
  static const int home = 1;
}

const icon = HiveIcons.home;
''');
    });
  });
}

class _NoDirectIconPackageTest extends AnalysisRuleTest {
  @override
  bool get addFlutterPackageDep => true;

  @override
  void setUp() {
    rule = NoDirectIconPackage();
    newPackage('hugeicons').addFile('lib/hugeicons.dart', '''
class HugeIcons {
  static const int home = 1;
}
''');
    super.setUp();
  }
}
