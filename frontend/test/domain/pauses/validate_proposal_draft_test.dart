import 'package:agentic_hive_frontend/domain/pauses/use_cases/validate_proposal_draft.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  const validate = ValidateProposalDraft();

  group('ValidateProposalDraft', () {
    test('returns ProposalDraftValid with decoded value when JSON is valid '
        'and no schema is provided', () {
      final result = validate(text: '{"items": [1, 2], "ok": true}');

      expect(result, isA<ProposalDraftValid>());
      final valid = result as ProposalDraftValid;
      expect(valid.value, <String, Object?>{
        'items': <Object?>[1, 2],
        'ok': true,
      });
    });

    test('returns ProposalDraftInvalid when JSON is malformed', () {
      final result = validate(text: '{bad');

      expect(result, isA<ProposalDraftInvalid>());
      final invalid = result as ProposalDraftInvalid;
      expect(invalid.messages, hasLength(1));
      expect(invalid.messages.first, startsWith('Not valid JSON'));
    });

    test('returns ProposalDraftInvalid when text is blank', () {
      final result = validate(text: '   \n\t  ');

      expect(result, isA<ProposalDraftInvalid>());
      final invalid = result as ProposalDraftInvalid;
      expect(invalid.messages, hasLength(1));
      expect(invalid.messages.first, startsWith('Not valid JSON'));
    });

    test('validates decoded JSON against non-blank schema', () {
      const schema = '{"type":"array"}';

      final failing = validate(text: '{}', schemaText: schema);
      expect(failing, isA<ProposalDraftInvalid>());
      expect((failing as ProposalDraftInvalid).messages, isNotEmpty);

      final passing = validate(text: '[]', schemaText: schema);
      expect(passing, isA<ProposalDraftValid>());
      expect((passing as ProposalDraftValid).value, isEmpty);
    });

    test('ignores null or blank schemaText', () {
      final result = validate(text: '{"a": 1}', schemaText: '   ');

      expect(result, isA<ProposalDraftValid>());
      expect((result as ProposalDraftValid).value, <String, Object?>{'a': 1});
    });

    test('caps schema validation errors at 5 messages', () {
      const schema = '''
{
  "type": "object",
  "properties": {
    "a": {"type": "integer"},
    "b": {"type": "integer"},
    "c": {"type": "integer"},
    "d": {"type": "integer"},
    "e": {"type": "integer"},
    "f": {"type": "integer"}
  }
}
''';
      const draft = '{"a":"x","b":"x","c":"x","d":"x","e":"x","f":"x"}';

      final result = validate(text: draft, schemaText: schema);

      expect(result, isA<ProposalDraftInvalid>());
      final invalid = result as ProposalDraftInvalid;
      expect(invalid.messages, hasLength(5));
    });
  });
}
