import 'package:test/test.dart';

import '../../../tool/src/hive/ci_checks.dart';

CiCheck _check(String bucket) => CiCheck(name: bucket, bucket: bucket);

void main() {
  test('no checks yet is pending', () {
    expect(ciStateOf([]), CiState.pending);
  });

  test('waits for every check before reporting a failure', () {
    expect(ciStateOf([_check('fail'), _check('pending')]), CiState.pending);
  });

  test('failed or cancelled checks fail', () {
    expect(ciStateOf([_check('pass'), _check('fail')]), CiState.failed);
    expect(ciStateOf([_check('cancel')]), CiState.failed);
  });

  test('passed and skipped checks pass', () {
    expect(ciStateOf([_check('pass'), _check('skipping')]), CiState.passed);
  });

  test('parses gh pr checks JSON', () {
    final check = CiCheck.fromJson({
      'name': 'Workspace (ubuntu-latest)',
      'bucket': 'fail',
      'link': 'https://example.test/run/1',
    });
    expect(check.name, 'Workspace (ubuntu-latest)');
    expect(isFailing(check), isTrue);
  });
}
