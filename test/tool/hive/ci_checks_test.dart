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

  group('failingRunIds', () {
    test('extracts and de-duplicates run ids from failing and cancelled '
        'checks', () {
      final checks = [
        const CiCheck(
          name: 'Backend (ubuntu)',
          bucket: 'fail',
          link: 'https://github.com/org/repo/actions/runs/101/job/1',
        ),
        const CiCheck(
          name: 'Frontend (ubuntu)',
          bucket: 'fail',
          link: 'https://github.com/org/repo/actions/runs/101/job/2',
        ),
        const CiCheck(
          name: 'Windows',
          bucket: 'cancel',
          link: 'https://github.com/org/repo/actions/runs/202/job/3',
        ),
        const CiCheck(
          name: 'Release',
          bucket: 'fail',
          link: 'https://github.com/org/repo/actions/runs/303',
        ),
      ];
      expect(failingRunIds(checks), ['101', '202', '303']);
    });

    test('ignores non-failing checks and non-Actions links', () {
      final checks = [
        const CiCheck(
          name: 'Passed',
          bucket: 'pass',
          link: 'https://github.com/org/repo/actions/runs/101/job/1',
        ),
        const CiCheck(
          name: 'Pending',
          bucket: 'pending',
          link: 'https://github.com/org/repo/actions/runs/102/job/2',
        ),
        const CiCheck(
          name: 'Skipped',
          bucket: 'skipping',
          link: 'https://github.com/org/repo/actions/runs/103/job/3',
        ),
        const CiCheck(
          name: 'External',
          bucket: 'fail',
          link: 'https://codecov.io/gh/org/repo/pull/1',
        ),
        const CiCheck(name: 'No link', bucket: 'cancel'),
      ];
      expect(failingRunIds(checks), isEmpty);
    });
  });
}
