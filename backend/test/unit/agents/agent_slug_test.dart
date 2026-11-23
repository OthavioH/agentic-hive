import 'package:agentic_hive_backend/src/core/failure.dart';
import 'package:agentic_hive_backend/src/core/result.dart';
import 'package:agentic_hive_backend/src/domain/agents/agent_slug.dart';
import 'package:test/test.dart';

void main() {
  group('validateAgentSlug', () {
    for (final valid in ['a', 'reviewer', 'code-reviewer', 'agent_1', '0x']) {
      test('accepts "$valid"', () {
        final result = validateAgentSlug(valid);
        expect(result, isA<Success<String>>());
        expect(result.valueOrNull, valid);
      });
    }

    for (final invalid in [
      '',
      'A',
      'Code-Reviewer',
      '-leading',
      '_leading',
      'has space',
      'has.dot',
      '../traversal',
      'a/b',
      'con',
      'nul',
      'com1',
      'lpt9',
      'a' * 129,
    ]) {
      test('rejects "$invalid"', () {
        final result = validateAgentSlug(invalid);
        expect(result, isA<FailureResult<String>>());
        expect(result.failureOrNull, isA<ValidationFailure>());
      });
    }
  });

  group('validateAgentLookupId', () {
    for (final valid in ['reviewer', 'My Agent', 'Upper_Case.v1', 'con']) {
      test('accepts "$valid" for read/delete lookup', () {
        final result = validateAgentLookupId(valid);
        expect(result, isA<Success<String>>());
        expect(result.valueOrNull, valid);
      });
    }

    for (final invalid in [
      '',
      '.hidden',
      '..',
      '../traversal',
      'a..b',
      'a/b',
      r'a\b',
      'a\u0000b',
      'a' * 129,
    ]) {
      test('rejects unsafe lookup id "$invalid"', () {
        final result = validateAgentLookupId(invalid);
        expect(result, isA<FailureResult<String>>());
        expect(result.failureOrNull, isA<ValidationFailure>());
      });
    }
  });
}
