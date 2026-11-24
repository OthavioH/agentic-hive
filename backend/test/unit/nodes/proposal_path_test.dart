import 'package:agentic_hive_backend/src/domain/nodes/proposal_path.dart';
import 'package:test/test.dart';

void main() {
  group('ProposalPath.resolve', () {
    const data = {
      'issues': [
        {'id': 'a', 'title': 'First'},
        {'id': 'b', 'title': 'Second'},
      ],
      'meta': {'count': 2, 'tag': 'v1'},
    };

    test('resolves top-level key', () {
      expect(ProposalPath.resolve(data, 'meta'), {'count': 2, 'tag': 'v1'});
    });

    test('resolves nested key', () {
      expect(ProposalPath.resolve(data, 'meta.count'), 2);
    });

    test('resolves list index and nested key', () {
      expect(ProposalPath.resolve(data, 'issues.1.title'), 'Second');
    });

    test('returns null for missing key', () {
      expect(ProposalPath.resolve(data, 'meta.missing'), isNull);
    });

    test('returns null for out of range index', () {
      expect(ProposalPath.resolve(data, 'issues.5'), isNull);
    });

    test('returns null for non-numeric segment on list', () {
      expect(ProposalPath.resolve(data, 'issues.first'), isNull);
    });

    test('returns null when traversing through a string', () {
      expect(ProposalPath.resolve(data, 'meta.tag.sub'), isNull);
    });
  });
}
