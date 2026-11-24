import 'package:agentic_hive_shared/agentic_hive_shared.dart';
import 'package:test/test.dart';

void main() {
  group('ProposalSchema', () {
    test('checkSchema returns no issue for a valid schema', () {
      expect(ProposalSchema.checkSchema('{"type":"array"}'), isEmpty);
    });

    test('checkSchema reports text that is not JSON', () {
      final issues = ProposalSchema.checkSchema('{nope');
      expect(issues, hasLength(1));
      expect(issues.first, isNotEmpty);
    });

    test('checkSchema reports a JSON value that is not a schema', () {
      final issues = ProposalSchema.checkSchema('42');
      expect(issues, hasLength(1));
      expect(issues.first, isNotEmpty);
    });

    test('validate accepts a matching value', () {
      const schema =
          '{"type":"array","items":{"type":"object","required":["id"]}}';
      final errors = ProposalSchema.validate(
        schemaText: schema,
        value: [
          {'id': 1},
        ],
      );
      expect(errors, isEmpty);
    });

    test('validate reports each error with its instance path', () {
      const schema =
          '{"type":"array","items":{"type":"object","required":["id"]}}';
      final errors = ProposalSchema.validate(
        schemaText: schema,
        value: [
          {'x': 1},
        ],
      );
      expect(errors, isNotEmpty);
      expect(errors.first, contains('id'));
    });

    test('validate returns a message for an uncompilable schema', () {
      final errors = ProposalSchema.validate(
        schemaText: '{"type":12}',
        value: const [1],
      );
      expect(errors, isNotEmpty);
    });
  });
}
