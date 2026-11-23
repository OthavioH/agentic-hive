import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  test('Worktree round-trips through JSON', () {
    const worktree = Worktree(
      id: 'feat',
      name: 'feat',
      path: '/data/worktrees/ws/feat',
      isPrimary: false,
      hasUncommittedChanges: true,
      branch: 'feature/a',
    );

    expect(Worktree.fromJson(worktree.toJson()), worktree);
  });

  test('the primary checkout has a fixed id', () {
    expect(primaryWorktreeId, 'primary');
  });

  test('CreateWorktreeRequest and RemoveWorktreeResponse decode', () {
    final request = CreateWorktreeRequest.fromJson({'name': 'x'});
    expect(request.branch, isNull);
    expect(request.baseBranch, isNull);

    final response = RemoveWorktreeResponse.fromJson({
      'id': 'x',
      'deleted': true,
      'branchDeleted': false,
      'notice': 'kept',
    });
    expect(response.notice, 'kept');
  });

  test('WorktreeListResponse rejects a bad shape', () {
    expect(
      () => WorktreeListResponse.fromJson({'items': 'nope'}),
      throwsFormatException,
    );
  });
}
