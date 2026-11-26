/// One CI check of a pull request, as `gh pr checks --json` reports it.
final class CiCheck {
  /// Creates a [CiCheck].
  const new({required this.name, required this.bucket, this.link = ''});

  /// Parses one element of `gh pr checks --json name,bucket,link`.
  factory fromJson(Map<String, Object?> json) => CiCheck(
    name: json['name']! as String,
    bucket: json['bucket']! as String,
    link: (json['link'] as String?) ?? '',
  );

  /// Check name.
  final String name;

  /// `pass`, `fail`, `pending`, `skipping` or `cancel`.
  final String bucket;

  /// URL of the check run.
  final String link;
}

/// Overall state of a pull request's checks.
enum CiState {
  /// No checks yet, or at least one still running.
  pending,

  /// Every check passed or was skipped.
  passed,

  /// Every check finished and at least one failed or was cancelled.
  failed,
}

/// Reduces [checks] to one [CiState]. Waits for every check to finish so a
/// failure report lists all failing runners at once.
CiState ciStateOf(List<CiCheck> checks) {
  if (checks.isEmpty || checks.any((c) => c.bucket == 'pending')) {
    return .pending;
  }
  return checks.any(isFailing) ? .failed : .passed;
}

/// Whether [check] failed or was cancelled.
bool isFailing(CiCheck check) =>
    check.bucket == 'fail' || check.bucket == 'cancel';

final _runIdPattern = RegExp(r'/actions/runs/(\d+)(?:[/?#]|$)');

/// Distinct GitHub Actions workflow run ids for the failing or cancelled
/// checks in [checks], in order of first appearance.
List<String> failingRunIds(List<CiCheck> checks) {
  final ids = <String>{};
  for (final check in checks) {
    if (!isFailing(check)) continue;
    final match = _runIdPattern.firstMatch(check.link);
    if (match != null) ids.add(match.group(1)!);
  }
  return ids.toList();
}
