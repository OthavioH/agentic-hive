import 'package:analyzer_testing/analysis_rule/analysis_rule.dart';
import 'package:hive_lints/src/rules/no_literal_duration.dart';
import 'package:test/test.dart';

void main() {
  group('NoLiteralDuration', () {
    late _NoLiteralDurationTest helper;

    setUp(() {
      helper = _NoLiteralDurationTest()..setUp();
    });

    tearDown(() async {
      await helper.tearDown();
    });

    test('flags Duration with numeric literals', () async {
      await helper.assertDiagnostics(
        '''
const d1 = Duration(milliseconds: 200);
const d2 = Duration(seconds: 1);
''',
        [helper.lint(11, 27), helper.lint(51, 20)],
      );
    });

    test('does not flag Duration.zero or token-based Duration', () async {
      await helper.assertNoDiagnostics('''
class HiveMotion {
  static const int fastMs = 150;
  static const Duration fast = Duration.zero;
}

const d1 = Duration.zero;
const d2 = Duration(milliseconds: HiveMotion.fastMs);
final d3 = HiveMotion.fast;
''');
    });
  });
}

class _NoLiteralDurationTest extends AnalysisRuleTest {
  @override
  void setUp() {
    rule = NoLiteralDuration();
    super.setUp();
  }
}
